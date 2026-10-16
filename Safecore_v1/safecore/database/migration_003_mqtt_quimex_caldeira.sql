-- =====================================================================
-- SafeCore — Migração IoT MQTT: Quimex (Setor Caldeira Ativo)
-- Desativa a simulação de sensores em todos os setores e define
-- todos os setores como 'desconectada' (offline), exceto a Caldeira (CLD),
-- que recebe dados reais em JSON do ESP32 (Wokwi) via broker.mqtt.cool
-- no tópico: safecore/quimex/caldeira/telemetry
-- =====================================================================

-- 1. Desativa o modo de simulação em todos os sensores
update public.sensors
   set is_simulated = false;

-- 2. Todos os setores exceto Caldeira (CLD) ficam desconectados e sem valores simulados
update public.sensors
   set status = 'offline',
       level = 'normal',
       last_value = null,
       last_reading_at = null
 where area_id <> (select id from public.areas where code = 'CLD');

update public.areas
   set status = 'desconectada',
       status_note = 'Setor desconectado do broker MQTT (safecore/quimex/' || lower(code) || ').'
 where code <> 'CLD';

-- 3. Configura os sensores da Caldeira (CLD) com o device_id do ESP32 da Quimex
update public.sensors
   set device_id = 'quimex-caldeira-01',
       status = 'online',
       is_simulated = false
 where area_id = (select id from public.areas where code = 'CLD');

update public.areas
   set status = 'segura',
       status_note = 'Conectado ao broker MQTT (safecore/quimex/caldeira).'
 where code = 'CLD';
