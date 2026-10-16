# SafeCore Web — Painel administrativo

Painel web **exclusivo para administradores** (`profiles.role = 'admin'`), complemento do
aplicativo **SafeCore Mobile** (Flutter). Usa o **mesmo projeto Supabase**, a mesma tabela
`profiles`, os mesmos usuários do Supabase Auth e as mesmas políticas RLS.

| Sistema | Quem usa | Para quê |
|---------|----------|----------|
| SafeCore Web (React) | Administradores | Cadastrar contas, definir cargos e permissões por área, acompanhar a operação |
| SafeCore Mobile (Flutter) | Técnicos, supervisores e operadores | Login, áreas autorizadas, sensores, alertas e operações do cargo |

## Funcionalidades

- **Landing page** (`/`): apresentação do SafeCore, objetivo, recursos, funcionamento web + mobile,
  cargos, segurança, perguntas frequentes e **Fale conosco**, com botão de acesso ao login.
  O painel administrativo fica em `/painel`.
- **Login** com e-mail e senha (Supabase Auth), sem cadastro público. Contas que não são
  admin são bloqueadas com a mensagem de que a conta é destinada ao app mobile.
- **Painel**: funcionários por cargo, áreas, sensores online/offline/manutenção, alertas
  ativos e críticos, gráficos (alertas por dia, temperatura e pressão), condições por área
  e atividades administrativas recentes. Atualiza em tempo real com novos alertas.
- **Funcionários**: cadastro (senha inicial gerada ou convite por e-mail), edição, troca de
  e-mail, alteração de cargo (`admin_set_role`), vínculo com áreas e nível de acesso
  (`set_area_member`), redefinição de senha, desativação/reativação e exclusão (somente
  sem histórico).
- **Áreas**: cadastro, edição, área restrita, funcionários vinculados por nível, exclusão ou
  arquivamento (`delete_area`) e restauração.
- **Sensores**: lista com filtros, cadastro/edição, histórico de leituras com faixa segura.
- **Alertas**: filtros, detalhes, histórico de ações, assumir/comentar/resolver
  (`add_alert_action`, `resolve_alert`) e alertas manuais. Alertas de sensor não têm a
  medição alterada e nenhum alerta é excluído pelo painel (histórico preservado).
- **Ocorrências**: consulta e mudança de status (`update_occurrence_status`).
- **Relatórios**: indicadores do período, gráficos e exportação CSV.
- **Auditoria**: `audit_logs` com filtros, diferenças antes/depois e exportação.

## Instalação

### 1. Banco de dados (uma vez)

No **SQL Editor** do Supabase, execute
[`supabase/migrations/003_painel_web_admin.sql`](supabase/migrations/003_painel_web_admin.sql)
(depois da `migration_002_permissoes_crud.sql` que já está aplicada). Ela:

- adiciona `profiles.active` e `profiles.deactivated_at` (desativação sem perder histórico);
- faz `current_role_name()` ignorar contas desativadas (sessões abertas perdem os privilégios na hora);
- impede que não-admins alterem o cargo ou o status ativo, e que alguém desative a própria conta.

Nenhuma política existente é enfraquecida.

### 2. Edge Function `admin-users`

A criação de contas exige a chave `service_role`, que **fica somente no servidor** (Edge
Function). Publique com o Supabase CLI:

```bash
npx supabase login
npx supabase functions deploy admin-users --project-ref SEU_PROJECT_REF
# Opcional (recomendado em produção): restringir as origens do CORS
npx supabase secrets set ALLOWED_ORIGINS=https://painel.suaempresa.com,http://localhost:5173 --project-ref SEU_PROJECT_REF
```

`SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` são injetadas automaticamente pelo Supabase.
O `supabase/config.toml` desativa a verificação de JWT do gateway porque a função valida o
token por conta própria (`auth.getUser`) e confere no banco se o perfil é admin ativo.

### 2.1 Fale conosco (Edge Function `contact` + migração 004)

As mensagens do formulário da landing page são gravadas em `public.contact_messages` (somente
administradores podem consultar) e enviadas por e-mail para **suporte@bitlayerdev.com** pelo
[Resend](https://resend.com). A função tem campo-isca contra robôs e limite de 3 envios por IP a cada 15 min.

1. Execute [`supabase/migrations/004_fale_conosco.sql`](supabase/migrations/004_fale_conosco.sql) no SQL Editor.
2. Crie uma conta no Resend, verifique o domínio do remetente e gere uma API key.
3. Configure e publique:

```bash
npx supabase secrets set RESEND_API_KEY=re_xxx CONTACT_FROM="SafeCore <contato@seudominio.com>" --project-ref SEU_PROJECT_REF
# opcional: CONTACT_TO (padrão suporte@bitlayerdev.com)
npx supabase functions deploy contact --project-ref SEU_PROJECT_REF
```

Sem `RESEND_API_KEY` a mensagem é gravada no banco, mas o e-mail não é enviado. Se a função
estiver fora do ar, o formulário mostra o endereço de e-mail como alternativa.

### 3. Configurações do Supabase Auth

Em **Authentication → URL Configuration → Redirect URLs**, adicione:

- `http://localhost:5173/definir-senha` (desenvolvimento)
- `https://SEU-DOMINIO/definir-senha` (produção)

Em **Authentication → Sign In / Providers → Email**, desative **Allow new users to sign up**.
O administrador continua criando contas pela Edge Function (a API administrativa não é
afetada por essa opção).

### 4. Rodar o painel

```bash
cp .env.example .env   # preencha URL e chave PÚBLICA (publishable/anon)
npm install
npm run dev            # http://localhost:5173
npm run build          # gera dist/ para hospedagem estática
```

Para hospedagem estática, `public/_redirects` (Netlify) e `vercel.json` (Vercel) já
redirecionam todas as rotas para o `index.html`.

## Fluxo com o app mobile

1. O administrador entra no SafeCore Web.
2. Cadastra o funcionário e define o cargo.
3. Vincula o funcionário às áreas e define o nível (`leitura`, `operacao`, `gestao`).
4. O funcionário recebe a senha inicial (por um canal seguro) ou um convite por e-mail. O link do
   convite abre `/definir-senha`; depois de criar a senha, o funcionário é orientado a usar o app.
5. O funcionário entra no SafeCore Mobile e o app carrega apenas o que as políticas permitem.
6. Mudanças de cargo, permissões e desativação valem imediatamente nas políticas do banco.

## Segurança — camadas de acesso exclusivo de administrador

| Camada | Onde |
|--------|------|
| Rotas protegidas no React | [`RequireAdmin`](src/auth/RequireAdmin.tsx): nenhuma página administrativa renderiza sem verificação |
| Verificação do cargo após o login | [`verifyAdmin`](src/auth/AuthProvider.tsx): `auth.getUser()` (validado no servidor) + `profiles.role = 'admin'` + conta ativa + RPC `is_admin()`. Repetida a cada 2 min, ao voltar para a aba e a cada renovação do token |
| Autorização no backend | [Edge Function](supabase/functions/admin-users/index.ts): valida o token e o perfil admin ativo no banco a cada chamada |
| RLS no Supabase | Políticas da migração 002 (inalteradas) |
| Validação nas funções | `admin_set_role`, `set_area_member`, `delete_area`, `resolve_alert` etc. validam o cargo no banco |

Sobre supervisores: `is_supervisor()` continua permitindo que supervisores gerenciem permissões
por área e áreas **no aplicativo mobile**, como já acontecia. O painel web não usa essa regra para
decidir quem entra: só aceita `role = 'admin'`. Um supervisor que chame a API direto consegue
apenas o que as políticas já permitem a ele. Criar contas, alterar cargos e desativar ou excluir
usuários continua exclusivo de administradores (Edge Function e `admin_set_role`).

## Pendências recomendadas

- **Trocar as senhas das contas de demonstração** (`Safecore@2026` está no README do banco),
  principalmente a de `admin@safecore.com`.
- **Remover a tela de cadastro do app mobile** (`lib/features/auth/register_screen.dart`)
  e desativar o cadastro público no Supabase (passo 3), já que os funcionários não se cadastram sozinhos.
