# SafeCore — Monitoramento e Segurança Industrial

Aplicativo mobile do **SafeCore**, projeto de conclusão do curso Técnico em
Desenvolvimento de Sistemas do SENAI. Ele acompanha as condições ambientais
da fábrica da Quimex Industrial:

- temperatura, pressão, umidade, gases, fumaça e ventilação;
- áreas monitoradas, mapa da planta e alertas;
- relatórios e mural de avisos e ocorrências.

**Tecnologias:** Flutter, Dart, Supabase (PostgreSQL, Auth, Realtime e RLS).

> **Dados simulados:** nesta versão as medições dos sensores são fictícias e
> aparecem no app com o selo "Dados simulados". Ações como "ativar ventilação"
> e "isolar área" são **simulações**: ficam registradas no histórico, mas
> nenhum equipamento é acionado.

---

## 1. Pré-requisitos

- Flutter 3.38 ou superior (testado com Flutter 3.47 / Dart 3.13)
- Android Studio (emulador ou celular Android) ou VS Code com a extensão Flutter
- Uma conta gratuita no [Supabase](https://supabase.com)

## 2. Configurar o banco no Supabase

Siga o passo a passo de [`database/README.md`](database/README.md). Em resumo:

1. Crie o projeto no Supabase.
2. Crie o usuário `demo@safecore.com`:
   - **Authentication → Users → Add user**;
   - marque **Auto Confirm User**.
3. No **SQL Editor**, cole e execute `database/setup_completo.sql` (banco novo)
   ou somente `database/migration_002_permissoes_crud.sql` (banco já instalado
   na versão anterior: preserva os dados).

## 3. Conectar o app ao Supabase

1. Na raiz do projeto, copie `.env.example` para `.env` (o ZIP já traz um `.env` modelo).
2. Em **Supabase → Project Settings → API Keys**, copie:
   - **Project URL** → `SUPABASE_URL`
   - **Publishable key** (ou a antiga *anon public*) → `SUPABASE_PUBLISHABLE_KEY`

```env
SUPABASE_URL=https://abcdefghijk.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxxxxxx
AUTH_REDIRECT_URL=br.senai.safecore://login-callback
```

> ⚠️ **Nunca** coloque a chave `service_role` / `secret` no aplicativo.
> O `.env` está no `.gitignore` e não deve ir para o GitHub.

Sem o `.env` configurado, o app abre uma tela explicando o que falta.

### Autenticação (Supabase → Authentication)

- **URL Configuration → Redirect URLs:** adicione `br.senai.safecore://login-callback`.
  Assim os links de recuperação de senha e de confirmação abrem o app.
- **Sign In / Providers → Email:** para a demonstração, você pode desativar
  *Confirm email*. Assim o cadastro entra direto no app.
- **Recuperação de senha por código (opcional):** em **Emails → Reset Password**,
  acrescente `{{ .Token }}` ao template. O usuário poderá digitar o código no app
  em vez de abrir o link.

## 4. Executar

```bash
flutter pub get
flutter run
```

Entre com um dos usuários de demonstração (senha de exemplo `Safecore@2026`):

- `admin@safecore.com`: administrador
- `demo@safecore.com`: técnico de segurança
- `operador@safecore.com`: operador da Produção

Comandos de verificação:

```bash
flutter analyze   # análise estática (sem problemas)
flutter test      # 20 testes: regras dos sensores, resumo da planta, validações e telas
```

## 5. Telas e funcionalidades

| Tela | Funcionalidades |
|------|-----------------|
| **Login / Cadastro** | Login por e-mail e senha, cadastro (nome, e-mail, senha), validação dos campos, mensagens de erro em português, sessão persistida e renovada automaticamente |
| **Recuperar senha** | Envio do e-mail, link de retorno ao app (deep link) ou código, definição da nova senha |
| **Painel** | Saudação, status geral da planta, áreas, sensores ativos, alertas ativos, disponibilidade, temperatura média, qualidade do ar, ventilação, acesso rápido (mapa, sensores, mural), geração de leitura simulada |
| **Áreas** | Lista com busca e filtro por status (segura, atenção, crítica, interditada, desconectada), medições de cada setor |
| **Mapa da planta** | Planta esquemática com zoom; cada área tem a cor do seu status e abre os detalhes ao toque |
| **Detalhe da área** | Sensores, alertas abertos, ações simuladas (ventilação, isolar/liberar), registro de ocorrência, histórico de ações |
| **Sensores** | Lista com filtro por tipo e por "fora do normal"; detalhe com valor, unidade, estado, última atualização, limites de referência e gráfico do histórico (24 h, 7 dias, 30 dias) |
| **Alertas** | Lista com busca, filtros (abertos, crítico, atenção, resolvido) e filtro por área; detalhe com valor detectado, descrição, horário, severidade, registro de ações, assumir, ações simuladas e resolução |
| **Relatórios** | Resumo diário, semanal, mensal ou de período personalizado; gráficos de temperatura e pressão; indicadores (críticos/atenção, tempo médio de resolução, área com mais alertas, máximas); histórico de ocorrências |
| **Mural de avisos** | Avisos e ocorrências por área, com filtros, prioridade, autor, responsável e status; cadastro de relatos; assumir, concluir e reabrir |
| **Perfil** | Seções independentes, cada dado com o próprio editar/salvar (nome, e-mail com confirmação, telefone, cargo); senha (pede a senha atual); preferências de notificação; minhas permissões por área; sair da conta |
| **Áreas (CRUD)** | Cadastrar (administrador/supervisor), editar (gestão da área) e excluir com confirmação. Se a área tiver histórico, ela é arquivada |
| **Alertas (CRUD)** | Cadastrar alerta manual (operação na área), editar e excluir com confirmação. Alertas gerados por sensor preservam a medição |
| **Funcionários** | Administradores definem a função; administradores e supervisores definem o acesso de cada funcionário a cada área (leitura, operação, gestão) |

O Painel e os Relatórios calculam os indicadores a partir dos mesmos registros
do banco (`PlantSummary` em `lib/models/plant_summary.dart`). Nenhum número
fica fixo na interface.

Com o app aberto, novos alertas chegam em tempo real pelo Supabase Realtime e
aparecem como aviso na tela, respeitando as preferências de notificação.

## 6. Estrutura do projeto

```text
safecore/
├── assets/images/        # logo/ilustração oficiais opcionais (ver LEIA-ME.txt)
├── database/             # schema.sql, policies.sql, seed.sql, README.md
├── lib/
│   ├── main.dart         # inicialização (.env, Supabase, datas pt-BR)
│   ├── app.dart          # MaterialApp, tema e AuthGate (sessão)
│   ├── core/             # tema (app_theme.dart, app_colors.dart), env, formatadores, validações
│   ├── models/           # Area, Sensor, Alert, Occurrence, Profile, PlantSummary, enums de status
│   ├── repositories/     # todo acesso ao Supabase (consultas e RPCs)
│   ├── services/         # cliente Supabase e sessão do usuário
│   ├── routes/           # rotas nomeadas
│   ├── shared/widgets/   # barra azul com logo, cartões, gráficos, estados de carregando/erro/vazio
│   └── features/         # auth, dashboard, areas, industrial_map, sensors, alerts,
│                         # reports, occurrences, profile, shell (navegação inferior)
├── test/                 # testes unitários e de widgets
├── .env.example
└── pubspec.yaml
```

As telas não acessam o banco diretamente: usam os repositórios
(`lib/repositories/`).

## 7. Identidade visual

- A paleta do Figma está centralizada em `lib/core/theme/app_colors.dart` e
  `lib/core/theme/app_theme.dart`:
  - `#014D90` (azul principal)
  - `#86BBD8` (azul claro)
  - `#2F4858` (azul acinzentado)
  - `#79CC4B` (verde)
  - `#FFFFFF` (branco)
- A logo (escudo com capacete e selo verde) e a ilustração industrial do
  Login/Cadastro são desenhadas em vetor.
- **Para usar os arquivos originais do Figma**, exporte-os como PNG e salve em
  `assets/images/logo.png` e `assets/images/industrial.png`. O app passa a
  usá-los automaticamente.

## 8. O que depende de configuração externa

| Item | O que fazer |
|------|-------------|
| Projeto Supabase, URL e chave pública | Criar o projeto e preencher o `.env` (seção 3) |
| Tabelas, políticas e dados | Executar os 3 scripts SQL |
| Usuário de demonstração | Criar `demo@safecore.com` no Supabase Auth |
| E-mails de confirmação e recuperação | Usam o envio padrão do Supabase, que tem limite de envios por hora. Para uso real, configure um SMTP próprio em **Authentication → Emails** |
| Deep link da recuperação de senha | Adicionar a Redirect URL (seção 3) |
| Notificações push com o app fechado | Exigem Firebase Cloud Messaging e uma Edge Function. As preferências já ficam salvas no banco; com o app aberto, os alertas chegam em tempo real |
| Sensores físicos (ESP32) | Edge Function para receber as leituras (ver `database/README.md`). Nesta versão as leituras são simuladas |
| Logo e ilustração originais | Copiar os PNGs do Figma para `assets/images/` |

## 9. Problemas comuns

- **"Configuração do Supabase necessária":** o `.env` está faltando ou ainda tem os
  valores de exemplo. Corrija o arquivo, pare o app e rode `flutter run` de novo
  (o *hot reload* não relê o `.env`).
- **"Banco de dados não configurado":** os scripts SQL não foram executados.
- **"E-mail ou senha incorretos" com o usuário demo:** confira se ele foi criado com
  *Auto Confirm User*.
- **Botões de resolver ou isolar desativados:** o usuário tem o papel `operador`.
  Promova-o com `update profiles set role = 'tecnico' where email = '...'`.
- **Erro `detected dubious ownership` ao rodar o Flutter** (computador compartilhado):
  execute `git config --global --add safe.directory C:/src/flutter`.
