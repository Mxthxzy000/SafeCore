// SafeCore — Edge Function "contact" (Fale conosco da landing page)
//
// Recebe a mensagem do site, valida, aplica limite de envios por IP, grava em
// public.contact_messages e envia um e-mail para a equipe de suporte via Resend.
//
// Variáveis (Supabase → Edge Functions → Secrets):
//   RESEND_API_KEY   chave da API do Resend (https://resend.com) — obrigatória para enviar e-mail
//   CONTACT_TO       destinatário (padrão: suporte@bitlayerdev.com)
//   CONTACT_FROM     remetente com domínio verificado no Resend, ex.: "SafeCore <contato@seudominio.com>"
//   ALLOWED_ORIGINS  origens permitidas no CORS, separadas por vírgula (padrão: *)
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são injetadas pelo Supabase.

import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const CONTACT_TO = Deno.env.get('CONTACT_TO') ?? 'suporte@bitlayerdev.com';
const CONTACT_FROM = Deno.env.get('CONTACT_FROM') ?? 'SafeCore <onboarding@resend.dev>';
const ALLOWED_ORIGINS = (Deno.env.get('ALLOWED_ORIGINS') ?? '*').split(',').map((o) => o.trim()).filter(Boolean);

const MAX_PER_WINDOW = 3;       // mensagens por IP
const WINDOW_MINUTES = 15;
const SUBJECTS = ['Conhecer o SafeCore', 'Demonstração', 'Suporte técnico', 'Parcerias', 'Outro'];

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin') ?? '';
  const allow = ALLOWED_ORIGINS.includes('*') ? '*'
    : ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0] ?? '';
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json',
    Vary: 'Origin',
  };
}

const clean = (v: unknown, max: number) => (typeof v === 'string' ? v.trim().slice(0, max) : '');
const escapeHtml = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

async function sha256(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  const headers = corsHeaders(req);
  const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers });
  if (req.method === 'OPTIONS') return new Response('ok', { headers });
  if (req.method !== 'POST') return reply(405, { error: 'Método não permitido.' });

  const body = await req.json().catch(() => null);
  if (!body || typeof body !== 'object') return reply(400, { error: 'Requisição inválida.' });

  // Honeypot: robôs preenchem o campo oculto "website". Responde OK sem gravar.
  if (clean(body.website, 200)) return reply(200, { ok: true });

  const name = clean(body.name, 120);
  const email = clean(body.email, 254).toLowerCase();
  const company = clean(body.company, 120);
  const phone = clean(body.phone, 30);
  const subject = SUBJECTS.includes(body.subject) ? body.subject as string : 'Outro';
  const message = clean(body.message, 4000);

  if (name.length < 2) return reply(400, { error: 'Informe seu nome.' });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply(400, { error: 'Informe um e-mail válido.' });
  if (message.length < 10) return reply(400, { error: 'A mensagem deve ter pelo menos 10 caracteres.' });

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  // Limite de envios por IP (armazenado apenas como hash)
  const ip = (req.headers.get('x-forwarded-for') ?? '').split(',')[0].trim() || 'desconhecido';
  const ipHash = await sha256(`${ip}:${SERVICE_ROLE_KEY.slice(-12)}`);
  const since = new Date(Date.now() - WINDOW_MINUTES * 60000).toISOString();
  const { count } = await admin.from('contact_messages')
    .select('id', { count: 'exact', head: true }).eq('ip_hash', ipHash).gte('created_at', since);
  if ((count ?? 0) >= MAX_PER_WINDOW) {
    return reply(429, { error: 'Você enviou várias mensagens em pouco tempo. Tente novamente em alguns minutos.' });
  }

  const { data: saved, error: saveError } = await admin.from('contact_messages').insert({
    name, email, company: company || null, phone: phone || null, subject, message, ip_hash: ipHash,
  }).select('id').single();
  if (saveError) {
    console.error(saveError);
    return reply(500, { error: 'Não foi possível registrar sua mensagem. Tente novamente.' });
  }

  // Envio do e-mail para o suporte
  let delivered = false;
  if (RESEND_API_KEY) {
    const rows: [string, string][] = [
      ['Nome', name], ['E-mail', email], ['Empresa', company || '—'], ['Telefone', phone || '—'], ['Assunto', subject],
    ];
    const html = `
      <div style="font-family:Arial,sans-serif;color:#2F4858;max-width:600px">
        <div style="background:#014D90;color:#fff;padding:16px 20px;border-radius:8px 8px 0 0">
          <strong style="font-size:18px">SafeCore</strong> · Nova mensagem do site
        </div>
        <div style="border:1px solid #D7DEE5;border-top:0;padding:20px;border-radius:0 0 8px 8px">
          <table style="border-collapse:collapse;width:100%;font-size:14px">
            ${rows.map(([k, v]) => `<tr><td style="padding:6px 0;color:#5E7280;width:110px">${k}</td><td style="padding:6px 0;font-weight:600">${escapeHtml(v)}</td></tr>`).join('')}
          </table>
          <p style="margin:16px 0 6px;color:#5E7280;font-size:13px">Mensagem</p>
          <div style="background:#F3F5F8;padding:14px;border-radius:8px;white-space:pre-wrap;font-size:14px;line-height:1.5">${escapeHtml(message)}</div>
          <p style="margin-top:16px;color:#5E7280;font-size:12px">Responda este e-mail para falar diretamente com ${escapeHtml(name)}.</p>
        </div>
      </div>`;
    const text = `${rows.map(([k, v]) => `${k}: ${v}`).join('\n')}\n\nMensagem:\n${message}`;

    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: CONTACT_FROM,
          to: [CONTACT_TO],
          reply_to: email,
          subject: `[SafeCore] ${subject} — ${name}`,
          html,
          text,
        }),
      });
      delivered = res.ok;
      if (!res.ok) console.error('Resend', res.status, await res.text());
    } catch (e) {
      console.error('Resend', e);
    }
    if (delivered) await admin.from('contact_messages').update({ delivered: true }).eq('id', saved.id);
  } else {
    console.warn('RESEND_API_KEY não configurada: mensagem gravada, e-mail não enviado.');
  }

  // A mensagem fica registrada mesmo que o e-mail falhe; o visitante recebe confirmação.
  return reply(200, { ok: true });
});
