# Banco de dados do SafeCore (Supabase / PostgreSQL)

## ⚡ Jeito rápido

| Situação | O que colar no **SQL Editor** |
|----------|-------------------------------|
| Banco **novo** (vazio) | `setup_completo.sql` (tudo em um arquivo) |
| Banco **já instalado** (versão anterior) | somente `migration_002_permissoes_crud.sql`: preserva todos os dados |

Usuários de demonstração (senha de exemplo `Safecore@2026`; altere pelo app):

| E-mail | Função | Acesso |
|--------|--------|--------|
| `admin@safecore.com` | Administrador | Gestão de todas as áreas, funcionários e funções |
| `demo@safecore.com` | Técnico de Segurança | Gestão: Caldeira, Produção e Armazém. Operação: demais áreas. Leitura: Laboratório |
| `operador@safecore.com` | Operador | Operação: Produção. Não vê o Laboratório (área restrita) |

## Arquivos (execute nesta ordem)

| Ordem | Arquivo        | O que faz |
|-------|----------------|-----------|
| 1     | `schema.sql`   | Tabelas, chaves, índices, triggers, regras de negócio e funções (RPC) |
| 2     | `policies.sql` | Row Level Security (RLS) e permissões por papel |
| 3     | `migration_002_permissoes_crud.sql` | Permissões por área, CRUD de áreas/alertas, auditoria e usuários demo |
| 4     | `seed.sql`     | Dados **fictícios** de demonstração (áreas, sensores, 30 dias de leituras, alertas, ocorrências) |

Os três scripts podem ser executados mais de uma vez sem erro.
Executar o `seed.sql` novamente **apaga e recria** os dados de demonstração e
atualiza os horários (útil antes de apresentar). Ele não apaga usuários.

## Passo a passo

1. Crie um projeto gratuito em <https://supabase.com> e aguarde ele ficar pronto.
2. Crie o usuário de demonstração **antes** do seed:
   - **Authentication → Users → Add user → Create new user**
   - E-mail: `demo@safecore.com`, senha à sua escolha (ex.: `Safecore2026`)
   - Marque **Auto Confirm User**.
3. Abra **SQL Editor → New query**, cole o conteúdo de `schema.sql` e clique em **Run**.
4. Repita com `policies.sql`.
5. Repita com `seed.sql`. A última consulta mostra as 8 áreas com status e alertas abertos.

O seed dá ao usuário `demo@safecore.com` o papel **técnico**: nome "Luiz Paulo",
função "Técnico de Segurança" e telefone fictício. Com esse papel ele pode
tratar alertas e executar ações simuladas.

> Se você criou o usuário depois de rodar o seed, rode o `seed.sql` de novo
> ou execute apenas:
> ```sql
> update public.profiles set role = 'tecnico', full_name = 'Luiz Paulo',
>        job_title = 'Técnico de Segurança' where email = 'demo@safecore.com';
> ```

## Estrutura

| Tabela | Descrição |
|--------|-----------|
| `profiles` | Perfil 1:1 com `auth.users` (nome, e-mail, telefone, função, papel) |
| `areas` | Setores da fábrica, status e posição no mapa da planta |
| `sensors` | Sensores por área, unidade, limites (faixa segura e crítica), último valor e `device_id` |
| `sensor_readings` | Série temporal das medições (`source`: `simulado`, `esp32` ou `manual`) |
| `alerts` | Alertas por área/sensor, severidade (`atencao`, `critico`) e status (`ativo`, `em_andamento`, `resolvido`) |
| `action_logs` | Histórico de ações: comentários, resolução e ações **simuladas** (ventilação, isolamento, liberação) |
| `occurrences` | Mural de avisos e ocorrências, com prioridade, autor, responsável e status |
| `notification_preferences` | Preferências de notificação de cada usuário |

### Regras automáticas (triggers)

- Ao cadastrar um usuário no Auth, o banco cria o `profile` e as preferências de notificação.
- Ao inserir uma leitura em `sensor_readings`:
  1. o sensor recebe o último valor e o nível (`normal`, `atencao`, `critico`);
  2. se o valor sair da faixa segura, um alerta é aberto (ou escalonado para crítico);
  3. o status da área é recalculado (`segura`, `atencao`, `critica`, `desconectada`).
  Áreas `interditada` só mudam por ação de um técnico.
- Um usuário não consegue alterar o próprio papel (somente `admin`).

### Funções chamadas pelo app (RPC)

`simulate_readings()`, `add_alert_action()`, `resolve_alert()`,
`simulate_area_action()`, `update_occurrence_status()`, `report_series()`.

## Permissões por área (migração 002)

Cada funcionário pode ser vinculado às áreas (tabela `area_members`) com um nível:

| Nível | Permite |
|-------|---------|
| `leitura` | Visualizar a área (necessário em áreas **restritas**) |
| `operacao` | + tratar/resolver alertas, cadastrar e editar alertas manuais, ações simuladas |
| `gestao` | + editar a área e excluir alertas manuais |

- Administradores e supervisores têm gestão de todas as áreas.
- Operadores podem receber no máximo `operacao`.
- Áreas não restritas são visíveis a todos.
- Áreas com `restricted = true` (ex.: Laboratório) só aparecem para quem tem vínculo.
- Todas as regras são aplicadas no banco: RLS mais as funções `area_access`,
  `delete_area`, `admin_set_role` e `set_area_member`.
- Novos cadastros entram como **operador**, sem privilégios.

**Exclusão de área:** se a área tiver sensores, leituras, alertas ou ocorrências,
ela é **arquivada** (`archived_at`). Some das listas, mas o histórico é preservado.
Só áreas sem histórico são apagadas de fato.

**Alertas:** a coluna `origin` diferencia os gerados por sensor (`sensor`) dos
cadastrados no app (`manual`).
- Em alertas de sensor, só título, descrição e status podem ser alterados.
- Alertas de sensor só podem ser excluídos por administradores.
- Alertas manuais nunca são vinculados a sensores, então editá-los ou excluí-los
  não afeta as medições.

**Auditoria:** criação, edição e exclusão de áreas e alertas, mudanças de
permissão e alterações de perfil feitas pelos usuários ficam em `audit_logs`
(leitura para supervisores e administradores).

## Permissões por função (base)

| Papel | Pode |
|-------|------|
| `operador` (padrão no cadastro) | Ver dados, comentar alertas, registrar ocorrências |
| `tecnico` | + assumir/resolver alertas, ações simuladas, publicar avisos, alterar status de ocorrências |
| `supervisor` | + cadastrar/editar áreas, sensores e leituras manuais; ver perfis da equipe |
| `admin` | + alterar o papel dos usuários |

Para promover um usuário:

```sql
update public.profiles set role = 'supervisor' where email = 'fulano@empresa.com';
```

Usuários anônimos (sem login) não acessam nenhuma tabela.

## Integração futura com ESP32 / IoT

A estrutura já está preparada:

- cada sensor tem um `device_id` (hoje `SIM-<código>`);
- uma leitura real é só um `insert` em `sensor_readings` com `source = 'esp32'`;
- alertas e status das áreas são gerados automaticamente pelo trigger.

**Importante:** o ESP32 não deve usar a chave `service_role` nem a conta de um
usuário. O caminho recomendado é uma **Supabase Edge Function** que:

1. recebe o POST do dispositivo com um token próprio do equipamento;
2. valida o token e o `device_id`;
3. grava a leitura usando a chave secreta, guardada somente no servidor.

Depois, marque o sensor como real:
`update sensors set is_simulated = false, device_id = 'ESP32-XYZ' where code = '...'`.

## Validação

Os scripts foram testados em PostgreSQL (PGlite) com o schema `auth` simulado:

- execução dupla de todos os arquivos;
- contagens do seed;
- permissões de técnico e operador (RLS);
- funções RPC;
- geração automática de alertas por leitura.
