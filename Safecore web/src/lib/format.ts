const dtf = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
const df = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short' });
const nf = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 2 });

export const fmtDateTime = (v?: string | null) => (v ? dtf.format(new Date(v)) : '—');
export const fmtDate = (v?: string | null) => (v ? df.format(new Date(v)) : '—');
export const fmtNumber = (v?: number | null) =>
  v === null || v === undefined ? '—' : nf.format(Number(v));

export function fmtRelative(v?: string | null): string {
  if (!v) return '—';
  const diff = (Date.now() - new Date(v).getTime()) / 1000;
  if (diff < 60) return 'agora';
  if (diff < 3600) return `há ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `há ${Math.floor(diff / 3600)} h`;
  if (diff < 86400 * 7) return `há ${Math.floor(diff / 86400)} d`;
  return fmtDate(v);
}

export function fmtDuration(ms: number): string {
  if (!isFinite(ms) || ms <= 0) return '—';
  const min = Math.round(ms / 60000);
  if (min < 60) return `${min} min`;
  const h = Math.floor(min / 60);
  if (h < 48) return `${h} h ${min % 60} min`;
  return `${Math.floor(h / 24)} d ${h % 24} h`;
}

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return '?';
  return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
}

/** Traduz mensagens de erro do Supabase/PostgREST para o usuário. */
export function errorMessage(e: unknown): string {
  const msg =
    typeof e === 'object' && e && 'message' in e
      ? String((e as { message: unknown }).message)
      : String(e);
  const m = msg.toLowerCase();
  if (m.includes('row-level security') || m.includes('permission denied')) {
    return 'Operação não permitida pelas regras de segurança do banco.';
  }
  if (m.includes('duplicate key')) return 'Já existe um registro com estes dados (código repetido).';
  if (m.includes('violates check constraint')) return 'Dados inválidos: verifique os campos preenchidos.';
  if (m.includes('failed to fetch') || m.includes('network')) return 'Falha de conexão com o servidor.';
  if (m.includes('jwt') && m.includes('expired')) return 'Sua sessão expirou. Entre novamente.';
  return msg || 'Erro inesperado.';
}

export function downloadCsv(filename: string, rows: (string | number | null | undefined)[][]) {
  const esc = (v: string | number | null | undefined) => {
    const s = v === null || v === undefined ? '' : String(v);
    return /[";\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const csv = '﻿' + rows.map((r) => r.map(esc).join(';')).join('\n');
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

/** Senha inicial forte (letras, números e símbolos) gerada no navegador. */
export function generatePassword(): string {
  const lower = 'abcdefghijkmnpqrstuvwxyz';
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const digits = '23456789';
  const symbols = '@#$%&*!';
  const all = lower + upper + digits + symbols;
  const rand = new Uint32Array(14);
  crypto.getRandomValues(rand);
  const pick = (set: string, i: number) => set[rand[i] % set.length];
  const chars = [pick(lower, 0), pick(upper, 1), pick(digits, 2), pick(symbols, 3)];
  for (let i = 4; i < 14; i++) chars.push(pick(all, i));
  for (let i = chars.length - 1; i > 0; i--) {
    const j = rand[i] % (i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}
