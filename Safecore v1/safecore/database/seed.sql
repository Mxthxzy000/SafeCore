-- =====================================================================
-- SafeCore — Dados FICTÍCIOS para demonstração
-- Execute DEPOIS de schema.sql, policies.sql e migration_002_permissoes_crud.sql.
--
-- ATENÇÃO: todos os dados abaixo são SIMULADOS (sensors.is_simulated = true,
-- sensor_readings.source = 'simulado'). Não representam medições reais da
-- Quimex Industrial. As datas são relativas ao momento da execução; execute
-- o script novamente antes de uma apresentação para "atualizar" os horários.
--
-- O script apaga e recria áreas, sensores, leituras, alertas, histórico de
-- ações e ocorrências. Perfis de usuários NÃO são apagados.
-- =====================================================================

-- Desativa a geração automática de alertas enquanto o histórico é inserido
select set_config('safecore.seeding', 'on', false);
select setseed(0.42);

delete from public.occurrences;
delete from public.areas; -- remove em cascata sensores, leituras, alertas e ações

-- ---------------------------------------------------------------------
-- Áreas (posição relativa no mapa da planta)
-- ---------------------------------------------------------------------
insert into public.areas (code, name, description, area_type, status, map_x, map_y, map_w, map_h) values
  ('ESC', 'Escritório',            'Administração, recepção e sala de controle.',          'escritorio',  'segura', 0.05, 0.04, 0.40, 0.16),
  ('LAB', 'Laboratório',           'Controle de qualidade e análises químicas.',           'laboratorio', 'segura', 0.55, 0.04, 0.40, 0.16),
  ('PRD', 'Produção',              'Linha de mistura e envase de produtos químicos.',      'producao',    'segura', 0.05, 0.26, 0.55, 0.26),
  ('CLD', 'Caldeira',              'Geração de vapor para o processo produtivo.',          'caldeira',    'segura', 0.66, 0.26, 0.29, 0.26),
  ('ARM', 'Armazém',               'Estoque de matérias-primas e produtos acabados.',      'armazem',     'segura', 0.05, 0.58, 0.40, 0.18),
  ('TNQ', 'Tanques Químicos',      'Tancagem de solventes e reagentes.',                   'tanques',     'segura', 0.51, 0.58, 0.44, 0.18),
  ('EXP', 'Expedição',             'Carregamento e saída de mercadorias.',                 'expedicao',   'segura', 0.05, 0.82, 0.40, 0.14),
  ('ETE', 'Estação de Tratamento', 'Tratamento de efluentes industriais.',                 'tratamento',  'segura', 0.51, 0.82, 0.44, 0.14);

-- ---------------------------------------------------------------------
-- Sensores (4 por área = 32) e parâmetros da simulação
-- ---------------------------------------------------------------------
drop table if exists seed_specs;
create temporary table seed_specs (
  area_code text, code text, name text, sensor_type text, unit text,
  ref_min numeric, ref_max numeric, crit_min numeric, crit_max numeric,
  base numeric, amp numeric, noise numeric, current_value numeric
);

insert into seed_specs values
  -- Produção
  ('PRD','PRD-TMP-01','Temperatura Produção','temperatura','°C', 15,40,5,55,   26,2,0.8,   26.4),
  ('PRD','PRD-PRS-01','Pressão Produção','pressao','bar',        0.9,1.3,0.7,1.6, 1.05,0.03,0.02, 1.40),
  ('PRD','PRD-UMD-01','Umidade Produção','umidade','%',          35,70,20,85,  48,4,2,     47),
  ('PRD','PRD-VNT-01','Ventilação Produção','ventilacao','m/s',  0.8,3,0.3,4.5, 1.6,0.2,0.1, 1.62),
  -- Armazém
  ('ARM','ARM-TMP-01','Temperatura Armazém','temperatura','°C',  15,40,5,55,   24,2,0.8,   23.8),
  ('ARM','ARM-PRS-01','Pressão Armazém','pressao','bar',         0.9,1.3,0.7,1.6, 0.98,0.02,0.02, 0.98),
  ('ARM','ARM-UMD-01','Umidade Armazém','umidade','%',           35,70,20,85,  50,4,2,     50),
  ('ARM','ARM-FUM-01','Detector de Fumaça Armazém','fumaca','%obs/m', null,1.5,null,4, 0.2,0.05,0.1, 0.18),
  -- Caldeira
  ('CLD','CLD-TMP-01','Temperatura Caldeira','temperatura','°C', 15,50,5,55,   44,3,1,     58.7),
  ('CLD','CLD-PRS-01','Pressão Caldeira','pressao','bar',        0.9,1.3,0.7,1.6, 1.1,0.03,0.02, 1.12),
  ('CLD','CLD-UMD-01','Umidade Caldeira','umidade','%',          35,70,20,85,  42,3,2,     41),
  ('CLD','CLD-GAS-01','Gás Combustível Caldeira','gas','%LEL',   null,10,null,25, 3,0.8,0.6, 3.4),
  -- Laboratório
  ('LAB','LAB-TMP-01','Temperatura Laboratório','temperatura','°C', 15,40,5,55, 22,1,0.5,  22.1),
  ('LAB','LAB-PRS-01','Pressão Laboratório','pressao','bar',     0.9,1.3,0.7,1.6, 0.98,0.02,0.02, 0.98),
  ('LAB','LAB-UMD-01','Umidade Laboratório','umidade','%',       35,70,20,85,  50,3,2,     50),
  ('LAB','LAB-GAS-01','Gás Tóxico Laboratório','gas','%LEL',     null,10,null,25, 2,0.5,0.5, 1.9),
  -- Escritório
  ('ESC','ESC-TMP-01','Temperatura Escritório','temperatura','°C', 15,40,5,55, 22,1,0.5,   21.8),
  ('ESC','ESC-PRS-01','Pressão Escritório','pressao','bar',      0.9,1.3,0.7,1.6, 0.99,0.02,0.02, 0.99),
  ('ESC','ESC-UMD-01','Umidade Escritório','umidade','%',        35,70,20,85,  50,3,2,     50),
  ('ESC','ESC-FUM-01','Detector de Fumaça Escritório','fumaca','%obs/m', null,1.5,null,4, 0.1,0.03,0.05, 0.10),
  -- Tanques Químicos
  ('TNQ','TNQ-TMP-01','Temperatura Tanques','temperatura','°C',  15,40,5,55,   25,2,0.8,   25.3),
  ('TNQ','TNQ-PRS-01','Pressão Tanques','pressao','bar',         0.9,1.3,0.7,1.6, 1.02,0.03,0.02, 1.03),
  ('TNQ','TNQ-UMD-01','Umidade Tanques','umidade','%',           35,70,20,85,  55,4,2,     54),
  ('TNQ','TNQ-GAS-01','Vapores Inflamáveis Tanques','gas','%LEL', null,10,null,25, 4,1,0.8, 4.2),
  -- Expedição (fica desconectada: sem leituras nas últimas 3 horas)
  ('EXP','EXP-TMP-01','Temperatura Expedição','temperatura','°C', 15,40,5,55,  27,2,0.8,   null),
  ('EXP','EXP-PRS-01','Pressão Expedição','pressao','bar',       0.9,1.3,0.7,1.6, 1.0,0.02,0.02, null),
  ('EXP','EXP-UMD-01','Umidade Expedição','umidade','%',         35,70,20,85,  60,4,2,     null),
  ('EXP','EXP-VNT-01','Ventilação Expedição','ventilacao','m/s', 0.8,3,0.3,4.5, 1.4,0.2,0.1, null),
  -- Estação de Tratamento
  ('ETE','ETE-TMP-01','Temperatura ETE','temperatura','°C',      15,40,5,55,   23,2,0.8,   23.4),
  ('ETE','ETE-PRS-01','Pressão ETE','pressao','bar',             0.9,1.3,0.7,1.6, 1.01,0.02,0.02, 1.01),
  ('ETE','ETE-UMD-01','Umidade ETE','umidade','%',               40,80,25,90,  62,4,2,     63),
  ('ETE','ETE-VNT-01','Ventilação ETE','ventilacao','m/s',       0.8,3,0.3,4.5, 1.8,0.2,0.1, 1.79);

insert into public.sensors (area_id, code, name, sensor_type, unit, ref_min, ref_max,
                            critical_min, critical_max, device_id, is_simulated)
select a.id, s.code, s.name, s.sensor_type, s.unit, s.ref_min, s.ref_max, s.crit_min, s.crit_max,
       'SIM-' || s.code, true
from seed_specs s join public.areas a on a.code = s.area_code;

-- ---------------------------------------------------------------------
-- Leituras: histórico de 30 dias a cada 2 horas (ciclo diário + ruído)
-- ---------------------------------------------------------------------
insert into public.sensor_readings (sensor_id, value, recorded_at, source)
select se.id,
       round(greatest(sp.base
             + sp.amp * sin(2 * pi() * (extract(hour from t) - 9) / 24)::numeric
             + sp.noise * (random() - 0.5)::numeric * 2, 0), 2),
       t,
       'simulado'
from seed_specs sp
join public.sensors se on se.code = sp.code
cross join lateral generate_series(
  date_trunc('hour', now()) - interval '30 days',
  date_trunc('hour', now()) - case when sp.area_code = 'EXP' then interval '3 hours'
                                   else interval '2 hours' end,
  interval '2 hours') as t
order by t;

-- Picos históricos (correspondem aos alertas resolvidos abaixo)
insert into public.sensor_readings (sensor_id, value, recorded_at, source)
select se.id, v.value, now() + v.offset_time, 'simulado'
from (values
  ('ARM-FUM-01', 2.10, interval '-20 days -10 minutes'),
  ('ARM-FUM-01', 4.60, interval '-20 days'),
  ('ARM-FUM-01', 1.20, interval '-20 days +40 minutes'),
  ('LAB-GAS-01', 14.80, interval '-12 days -15 minutes'),
  ('LAB-GAS-01', 27.00, interval '-12 days'),
  ('LAB-GAS-01', 6.10, interval '-12 days +50 minutes'),
  ('PRD-TMP-01', 41.50, interval '-8 days'),
  ('PRD-TMP-01', 34.20, interval '-8 days +1 hour'),
  ('CLD-TMP-01', 52.10, interval '-5 days'),
  ('CLD-TMP-01', 47.30, interval '-5 days +1 hour'),
  ('ARM-UMD-01', 33.00, interval '-2 days -1 hour'),
  ('ARM-UMD-01', 28.00, interval '-2 days'),
  ('ARM-UMD-01', 36.50, interval '-2 days +2 hours'),
  ('TNQ-GAS-01', 12.40, interval '-1 day'),
  ('TNQ-GAS-01', 5.20, interval '-1 day +1 hour')
) as v(code, value, offset_time)
join public.sensors se on se.code = v.code;

-- Evolução recente que originou os alertas ativos
insert into public.sensor_readings (sensor_id, value, recorded_at, source)
select se.id, v.value, now() + v.offset_time, 'simulado'
from (values
  ('CLD-TMP-01', 50.80, interval '-90 minutes'),
  ('CLD-TMP-01', 53.90, interval '-60 minutes'),
  ('CLD-TMP-01', 56.20, interval '-35 minutes'),
  ('PRD-PRS-01', 1.27,  interval '-130 minutes'),
  ('PRD-PRS-01', 1.33,  interval '-120 minutes'),
  ('PRD-PRS-01', 1.37,  interval '-60 minutes')
) as v(code, value, offset_time)
join public.sensors se on se.code = v.code;

-- Leitura atual de cada sensor conectado
insert into public.sensor_readings (sensor_id, value, recorded_at, source)
select se.id, sp.current_value,
       now() - make_interval(mins => 5 + (row_number() over (order by sp.code))::int % 7),
       'simulado'
from seed_specs sp
join public.sensors se on se.code = sp.code
where sp.current_value is not null;

-- Expedição: sensores sem comunicação
update public.sensors set status = 'offline'
where area_id = (select id from public.areas where code = 'EXP');

-- ---------------------------------------------------------------------
-- Alertas (coerentes com as leituras acima)
-- ---------------------------------------------------------------------
insert into public.alerts (area_id, sensor_id, title, description, severity, status,
                           detected_value, unit, detected_at, resolved_at, resolution_note,
                           origin, category)
select a.id, se.id, v.title, v.description, v.severity, v.status, v.value, v.unit,
       now() + v.detected, case when v.resolved is null then null else now() + v.resolved end,
       v.note, 'sensor', coalesce(se.sensor_type, 'comunicacao')
from (values
  ('CLD', 'CLD-TMP-01', 'Temperatura Elevada',
   'Temperatura acima do limite seguro (50 °C). Limite crítico de 55 °C ultrapassado.',
   'critico', 'ativo', 58.70, '°C', interval '-90 minutes', null::interval, null),
  ('PRD', 'PRD-PRS-01', 'Pressão Elevada',
   'Pressão acima do limite seguro (1,30 bar) na linha de mistura.',
   'atencao', 'em_andamento', 1.40, 'bar', interval '-120 minutes', null, null),
  ('EXP', null, 'Sensores sem comunicação',
   'Os 4 sensores da Expedição não enviam leituras há mais de 2 horas.',
   'atencao', 'ativo', null, null, interval '-2 hours -50 minutes', null, null),
  ('TNQ', 'TNQ-GAS-01', 'Vapores Inflamáveis',
   'Concentração de vapores acima do limite seguro (10 %LEL).',
   'atencao', 'resolvido', 12.40, '%LEL', interval '-1 day', interval '-23 hours',
   'Vazamento em válvula identificado. Área interditada para manutenção.'),
  ('ARM', 'ARM-UMD-01', 'Umidade abaixo do ideal',
   'Umidade abaixo do ideal para armazenamento de matérias-primas.',
   'atencao', 'resolvido', 28.00, '%', interval '-2 days', interval '-2 days +3 hours',
   'Umidificador do armazém religado.'),
  ('CLD', 'CLD-TMP-01', 'Temperatura Elevada',
   'Temperatura acima do limite seguro durante pico de produção.',
   'atencao', 'resolvido', 52.10, '°C', interval '-5 days', interval '-5 days +2 hours',
   'Carga da caldeira reduzida; temperatura normalizada.'),
  ('PRD', 'PRD-TMP-01', 'Temperatura Elevada',
   'Temperatura acima de 40 °C na linha de produção.',
   'atencao', 'resolvido', 41.50, '°C', interval '-8 days', interval '-8 days +90 minutes',
   'Exaustores adicionais ligados.'),
  ('LAB', 'LAB-GAS-01', 'Concentração de Gás',
   'Concentração de gás tóxico acima do limite crítico (25 %LEL).',
   'critico', 'resolvido', 27.00, '%LEL', interval '-12 days', interval '-12 days +1 hour',
   'Capela de exaustão reparada. Laboratório evacuado preventivamente por 40 minutos.'),
  ('ARM', 'ARM-FUM-01', 'Fumaça Detectada',
   'Detector de fumaça acima do limite crítico no corredor B.',
   'critico', 'resolvido', 4.60, '%obs/m', interval '-20 days', interval '-20 days +45 minutes',
   'Superaquecimento de empilhadeira elétrica. Sem feridos.')
) as v(area_code, sensor_code, title, description, severity, status, value, unit,
       detected, resolved, note)
join public.areas a on a.code = v.area_code
left join public.sensors se on se.code = v.sensor_code;

-- ---------------------------------------------------------------------
-- Histórico de ações
-- ---------------------------------------------------------------------
insert into public.action_logs (area_id, alert_id, user_name, action_type, description,
                                is_simulation, created_at)
select al.area_id, al.id, v.user_name, v.action_type, v.description, v.is_sim, now() + v.at
from (values
  ('Temperatura Elevada', 'ativo', 'Sistema', 'sistema',
   'Alerta gerado: temperatura de 50,8 °C acima da faixa segura.', false, interval '-90 minutes'),
  ('Temperatura Elevada', 'ativo', 'Sistema', 'sistema',
   'Alerta escalonado para crítico: 56,2 °C.', false, interval '-35 minutes'),
  ('Temperatura Elevada', 'ativo', 'Carla Mendes', 'comentario',
   'Equipe de manutenção acionada para inspecionar o queimador.', false, interval '-25 minutes'),
  ('Pressão Elevada', 'em_andamento', 'Sistema', 'sistema',
   'Alerta gerado: pressão de 1,33 bar acima da faixa segura.', false, interval '-120 minutes'),
  ('Pressão Elevada', 'em_andamento', 'Ricardo Alves', 'reconhecido',
   'Alerta assumido. Verificando válvula de alívio da linha 2.', false, interval '-100 minutes'),
  ('Pressão Elevada', 'em_andamento', 'Ricardo Alves', 'ventilacao',
   '[SIMULAÇÃO] Ventilação de emergência acionada na área Produção.', true, interval '-95 minutes'),
  ('Sensores sem comunicação', 'ativo', 'Sistema', 'sistema',
   'Perda de comunicação com o gateway da Expedição.', false, interval '-2 hours -50 minutes'),
  ('Vapores Inflamáveis', 'resolvido', 'Carla Mendes', 'isolamento',
   '[SIMULAÇÃO] Área Tanques Químicos isolada e interditada.', true, interval '-23 hours -30 minutes'),
  ('Vapores Inflamáveis', 'resolvido', 'Carla Mendes', 'resolvido',
   'Vazamento em válvula identificado. Área interditada para manutenção.', false, interval '-23 hours'),
  ('Umidade abaixo do ideal', 'resolvido', 'Ricardo Alves', 'resolvido',
   'Umidificador do armazém religado.', false, interval '-2 days +3 hours'),
  ('Concentração de Gás', 'resolvido', 'Carla Mendes', 'resolvido',
   'Capela de exaustão reparada. Laboratório evacuado preventivamente por 40 minutos.', false,
   interval '-12 days +1 hour'),
  ('Fumaça Detectada', 'resolvido', 'Ricardo Alves', 'resolvido',
   'Superaquecimento de empilhadeira elétrica. Sem feridos.', false, interval '-20 days +45 minutes')
) as v(title, status, user_name, action_type, description, is_sim, at)
join public.alerts al on al.title = v.title and al.status = v.status
where (v.title <> 'Temperatura Elevada' or al.area_id = (select id from public.areas where code = 'CLD'));

-- ---------------------------------------------------------------------
-- Mural de avisos e ocorrências
-- ---------------------------------------------------------------------
insert into public.occurrences (area_id, kind, title, description, priority, status,
                                reported_by_name, responsible_name, created_at)
select a.id, v.kind, v.title, v.description, v.priority, v.status, v.reporter, v.responsible,
       now() + v.at
from (values
  ('TNQ', 'aviso', 'Tanques Químicos interditados',
   'Área interditada para manutenção preventiva das válvulas. Acesso somente com autorização da segurança.',
   'alta', 'em_analise', 'Carla Mendes', 'Equipe de Manutenção', interval '-22 hours'),
  ('CLD', 'aviso', 'Uso obrigatório de EPI térmico',
   'Durante a inspeção do queimador é obrigatório o uso de luvas e avental térmicos na Caldeira.',
   'alta', 'aberta', 'Carla Mendes', null, interval '-20 minutes'),
  (null, 'aviso', 'Simulado de evacuação',
   'Simulado geral de evacuação na próxima sexta-feira às 15h. Ponto de encontro: estacionamento.',
   'media', 'aberta', 'Segurança do Trabalho', null, interval '-3 days'),
  ('EXP', 'ocorrencia', 'Gateway da Expedição sem energia',
   'Tomada do gateway de sensores desligada durante limpeza. Sensores sem comunicação.',
   'media', 'aberta', 'Marcos Silva', null, interval '-2 hours -30 minutes'),
  ('PRD', 'ocorrencia', 'Ruído anormal na bomba 2',
   'Operadores relataram ruído metálico na bomba de recirculação da linha 2.',
   'media', 'em_analise', 'Juliana Rocha', 'Ricardo Alves', interval '-1 day -4 hours'),
  ('ARM', 'ocorrencia', 'Corredor B obstruído',
   'Paletes bloqueando parcialmente a rota de fuga do corredor B.',
   'baixa', 'resolvida', 'Marcos Silva', 'Ricardo Alves', interval '-6 days'),
  ('LAB', 'ocorrencia', 'Capela de exaustão com falha',
   'Capela de exaustão 3 apresentou baixa vazão durante análise de solventes.',
   'alta', 'resolvida', 'Juliana Rocha', 'Carla Mendes', interval '-12 days -30 minutes')
) as v(area_code, kind, title, description, priority, status, reporter, responsible, at)
left join public.areas a on a.code = v.area_code;

-- ---------------------------------------------------------------------
-- Estado final das áreas
-- ---------------------------------------------------------------------
select set_config('safecore.seeding', 'off', false);

select public.refresh_area_status(id) from public.areas;

update public.areas
   set status = 'interditada',
       status_note = 'Manutenção preventiva das válvulas (ver mural de avisos).'
 where code = 'TNQ';

-- ---------------------------------------------------------------------
-- Usuários de demonstração: funções e vínculos com as áreas
-- (os usuários são criados pela migration_002_permissoes_crud.sql)
-- ---------------------------------------------------------------------
select public.apply_demo_permissions();

drop table if exists seed_specs;

-- Conferência rápida
select a.name, a.status,
       count(s.*) as sensores,
       (select count(*) from public.alerts al where al.area_id = a.id and al.status <> 'resolvido') as alertas_ativos
from public.areas a
left join public.sensors s on s.area_id = a.id
group by a.id
order by a.name;
