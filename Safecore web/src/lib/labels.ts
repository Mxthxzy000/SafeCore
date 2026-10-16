import type { AccessLevel, Role } from './types';

export type Tone = 'safe' | 'warning' | 'critical' | 'blocked' | 'offline' | 'info' | 'neutral';

export const ROLE_LABEL: Record<Role, string> = {
  admin: 'Administrador',
  supervisor: 'Supervisor',
  tecnico: 'Técnico',
  operador: 'Operador',
};
export const ROLES: Role[] = ['admin', 'supervisor', 'tecnico', 'operador'];

export const ACCESS_LABEL: Record<AccessLevel, string> = {
  leitura: 'Leitura',
  operacao: 'Operação',
  gestao: 'Gestão',
};
export const ACCESS_HINT: Record<AccessLevel, string> = {
  leitura: 'Somente consulta',
  operacao: 'Consulta e ações operacionais autorizadas',
  gestao: 'Gerenciamento da área conforme as regras do banco',
};

export const AREA_STATUS: Record<string, { label: string; tone: Tone }> = {
  segura: { label: 'Segura', tone: 'safe' },
  atencao: { label: 'Atenção', tone: 'warning' },
  critica: { label: 'Crítica', tone: 'critical' },
  interditada: { label: 'Interditada', tone: 'blocked' },
  desconectada: { label: 'Desconectada', tone: 'offline' },
};
export const AREA_STATUS_PRIORITY: Record<string, number> = {
  critica: 0, interditada: 1, atencao: 2, desconectada: 3, segura: 4,
};

export const AREA_TYPES: Record<string, string> = {
  producao: 'Produção',
  armazem: 'Armazém',
  caldeira: 'Caldeira',
  laboratorio: 'Laboratório',
  escritorio: 'Escritório',
  tanques: 'Tanques',
  expedicao: 'Expedição',
  tratamento: 'Tratamento',
};

export const SENSOR_STATUS: Record<string, { label: string; tone: Tone }> = {
  online: { label: 'Online', tone: 'safe' },
  offline: { label: 'Sem comunicação', tone: 'offline' },
  manutencao: { label: 'Em manutenção', tone: 'blocked' },
};
export const SENSOR_LEVEL: Record<string, { label: string; tone: Tone }> = {
  normal: { label: 'Normal', tone: 'safe' },
  atencao: { label: 'Atenção', tone: 'warning' },
  critico: { label: 'Crítico', tone: 'critical' },
};
export const SENSOR_TYPES: Record<string, { label: string; unit: string }> = {
  temperatura: { label: 'Temperatura', unit: '°C' },
  pressao: { label: 'Pressão', unit: 'bar' },
  umidade: { label: 'Umidade', unit: '%' },
  gas: { label: 'Gases', unit: 'ppm' },
  fumaca: { label: 'Fumaça', unit: 'ppm' },
  ventilacao: { label: 'Ventilação', unit: 'm/s' },
};

export const ALERT_SEVERITY: Record<string, { label: string; tone: Tone }> = {
  atencao: { label: 'Atenção', tone: 'warning' },
  critico: { label: 'Crítico', tone: 'critical' },
};
export const ALERT_STATUS: Record<string, { label: string; tone: Tone }> = {
  ativo: { label: 'Ativo', tone: 'critical' },
  em_andamento: { label: 'Em andamento', tone: 'warning' },
  resolvido: { label: 'Resolvido', tone: 'safe' },
};
export const ALERT_ORIGIN: Record<string, string> = {
  sensor: 'Gerado por sensor',
  manual: 'Cadastro manual',
};
export const ALERT_CATEGORY: Record<string, string> = {
  temperatura: 'Temperatura',
  pressao: 'Pressão',
  umidade: 'Umidade',
  gas: 'Gases',
  fumaca: 'Fumaça / incêndio',
  ventilacao: 'Ventilação',
  comunicacao: 'Comunicação',
  eletrico: 'Elétrico',
  mecanico: 'Mecânico',
  quimico: 'Químico',
  outro: 'Outro',
};

export const OCC_STATUS: Record<string, { label: string; tone: Tone }> = {
  aberta: { label: 'Aberta', tone: 'info' },
  em_analise: { label: 'Em análise', tone: 'warning' },
  resolvida: { label: 'Resolvida', tone: 'safe' },
};
export const OCC_KIND: Record<string, string> = { aviso: 'Aviso', ocorrencia: 'Ocorrência' };
export const PRIORITY: Record<string, { label: string; tone: Tone }> = {
  baixa: { label: 'Baixa', tone: 'offline' },
  media: { label: 'Média', tone: 'warning' },
  alta: { label: 'Alta', tone: 'critical' },
};

export const ACTION_TYPE: Record<string, string> = {
  comentario: 'Comentário',
  reconhecido: 'Alerta assumido',
  resolvido: 'Resolvido',
  reaberto: 'Reaberto',
  ventilacao: 'Ventilação (simulação)',
  isolamento: 'Isolamento (simulação)',
  liberacao: 'Liberação (simulação)',
  sistema: 'Sistema',
};

export const AUDIT_ACTION: Record<string, { label: string; tone: Tone }> = {
  insert: { label: 'Criação', tone: 'safe' },
  update: { label: 'Alteração', tone: 'info' },
  delete: { label: 'Exclusão', tone: 'critical' },
};
export const AUDIT_ENTITY: Record<string, string> = {
  area: 'Área',
  alerta: 'Alerta',
  permissao_area: 'Permissão de área',
  perfil: 'Perfil',
  funcionario: 'Conta de funcionário',
};
