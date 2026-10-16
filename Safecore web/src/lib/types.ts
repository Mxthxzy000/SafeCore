export type Role = 'operador' | 'tecnico' | 'supervisor' | 'admin';
export type AccessLevel = 'leitura' | 'operacao' | 'gestao';

export interface Profile {
  id: string;
  full_name: string;
  email: string;
  phone: string | null;
  job_title: string | null;
  role: Role;
  active: boolean;
  deactivated_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface Area {
  id: string;
  code: string;
  name: string;
  description: string | null;
  area_type: string;
  status: 'segura' | 'atencao' | 'critica' | 'interditada' | 'desconectada';
  status_note: string | null;
  restricted: boolean;
  archived_at: string | null;
  map_x: number;
  map_y: number;
  map_w: number;
  map_h: number;
  created_at: string;
  updated_at: string;
}

export interface Sensor {
  id: string;
  area_id: string;
  code: string;
  name: string;
  sensor_type: string;
  unit: string;
  ref_min: number | null;
  ref_max: number | null;
  critical_min: number | null;
  critical_max: number | null;
  status: 'online' | 'offline' | 'manutencao';
  level: 'normal' | 'atencao' | 'critico';
  last_value: number | null;
  last_reading_at: string | null;
  device_id: string | null;
  is_simulated: boolean;
  created_at: string;
}

export interface Reading {
  id: number;
  sensor_id: string;
  value: number;
  recorded_at: string;
  source: string;
}

export interface Alert {
  id: string;
  area_id: string;
  sensor_id: string | null;
  title: string;
  description: string | null;
  severity: 'atencao' | 'critico';
  status: 'ativo' | 'em_andamento' | 'resolvido';
  detected_value: number | null;
  unit: string | null;
  detected_at: string;
  resolved_at: string | null;
  resolved_by: string | null;
  resolution_note: string | null;
  is_simulated: boolean;
  origin: 'sensor' | 'manual';
  category: string;
  created_at: string;
}

export interface ActionLog {
  id: string;
  area_id: string | null;
  alert_id: string | null;
  user_id: string | null;
  user_name: string;
  action_type: string;
  description: string;
  is_simulation: boolean;
  created_at: string;
}

export interface Occurrence {
  id: string;
  area_id: string | null;
  kind: 'aviso' | 'ocorrencia';
  title: string;
  description: string;
  priority: 'baixa' | 'media' | 'alta';
  status: 'aberta' | 'em_analise' | 'resolvida';
  reported_by: string | null;
  reported_by_name: string;
  responsible_name: string | null;
  created_at: string;
  updated_at: string;
}

export interface AreaMember {
  user_id: string;
  area_id: string;
  access_level: AccessLevel;
  created_at: string;
  updated_at: string;
}

export interface AuditLog {
  id: number;
  user_id: string | null;
  user_name: string;
  action: 'insert' | 'update' | 'delete';
  entity: string;
  entity_id: string | null;
  details: Record<string, unknown> | null;
  created_at: string;
}
