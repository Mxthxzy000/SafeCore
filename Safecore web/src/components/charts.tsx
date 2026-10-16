import {
  Bar, BarChart, CartesianGrid, Legend, Line, LineChart, ReferenceLine,
  ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts';
import { fmtNumber } from '../lib/format';

// Cores: série única no azul principal do SafeCore; cores de status reservadas
// para severidade (sempre acompanhadas de legenda com rótulo).
export const CHART = {
  primary: '#014D90',
  warning: '#E59A12',
  critical: '#D32F2F',
  grid: '#E4E9EE',
  axis: '#5E7280',
  ref: '#5BAE2E',
};

const axisProps = {
  tick: { fill: CHART.axis, fontSize: 12 },
  axisLine: false,
  tickLine: false,
} as const;

const tooltipStyle = {
  contentStyle: {
    borderRadius: 8, border: '1px solid #D7DEE5', boxShadow: '0 4px 14px rgba(47,72,88,.12)', fontSize: 13,
  },
  labelStyle: { color: '#2F4858', fontWeight: 600, marginBottom: 4 },
  itemStyle: { color: '#2F4858' },
};

/** Alertas por dia, empilhados por severidade. */
export function AlertsByDayChart({ data, height = 240 }: {
  data: { label: string; atencao: number; critico: number }[]; height?: number;
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -18 }} barCategoryGap="28%">
        <CartesianGrid vertical={false} stroke={CHART.grid} />
        <XAxis dataKey="label" {...axisProps} interval="preserveStartEnd" minTickGap={12} />
        <YAxis allowDecimals={false} {...axisProps} />
        <Tooltip {...tooltipStyle} cursor={{ fill: 'rgba(1,77,144,.06)' }} />
        <Legend iconType="circle" iconSize={9} wrapperStyle={{ fontSize: 12, color: CHART.axis }} />
        <Bar dataKey="atencao" name="Atenção" stackId="s" fill={CHART.warning} stroke="#fff" strokeWidth={1} />
        <Bar dataKey="critico" name="Crítico" stackId="s" fill={CHART.critical} stroke="#fff" strokeWidth={1}
             radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}

/** Série temporal de uma única medida (uma unidade, um eixo). */
export function MeasureLineChart({ data, name, unit, height = 220, refMin, refMax, color = CHART.primary }: {
  data: { label: string; value: number | null }[];
  name: string; unit: string; height?: number;
  refMin?: number | null; refMax?: number | null; color?: string;
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data} margin={{ top: 8, right: 12, bottom: 0, left: -12 }}>
        <CartesianGrid vertical={false} stroke={CHART.grid} />
        <XAxis dataKey="label" {...axisProps} interval="preserveStartEnd" minTickGap={24} />
        <YAxis {...axisProps} domain={['auto', 'auto']} tickFormatter={(v) => fmtNumber(v)} />
        <Tooltip
          {...tooltipStyle}
          cursor={{ stroke: CHART.axis, strokeDasharray: '3 3' }}
          formatter={(v: number) => [`${fmtNumber(v)} ${unit}`, name]}
        />
        {refMin !== null && refMin !== undefined && (
          <ReferenceLine y={refMin} stroke={CHART.ref} strokeDasharray="4 4"
                         label={{ value: `mín. ${fmtNumber(refMin)}`, fill: CHART.axis, fontSize: 11, position: 'insideBottomRight' }} />
        )}
        {refMax !== null && refMax !== undefined && (
          <ReferenceLine y={refMax} stroke={CHART.warning} strokeDasharray="4 4"
                         label={{ value: `máx. ${fmtNumber(refMax)}`, fill: CHART.axis, fontSize: 11, position: 'insideTopRight' }} />
        )}
        <Line type="monotone" dataKey="value" name={name} stroke={color} strokeWidth={2}
              dot={false} activeDot={{ r: 5, stroke: '#fff', strokeWidth: 2 }} connectNulls />
      </LineChart>
    </ResponsiveContainer>
  );
}

/** Barras horizontais de uma única série (ex.: alertas por área). */
export function HBarChart({ data, name, height }: {
  data: { label: string; value: number }[]; name: string; height?: number;
}) {
  const h = height ?? Math.max(160, data.length * 34 + 30);
  return (
    <ResponsiveContainer width="100%" height={h}>
      <BarChart data={data} layout="vertical" margin={{ top: 4, right: 24, bottom: 0, left: 8 }} barCategoryGap="30%">
        <CartesianGrid horizontal={false} stroke={CHART.grid} />
        <XAxis type="number" allowDecimals={false} {...axisProps} />
        <YAxis type="category" dataKey="label" width={130} {...axisProps} />
        <Tooltip {...tooltipStyle} cursor={{ fill: 'rgba(1,77,144,.06)' }} />
        <Bar dataKey="value" name={name} fill={CHART.primary} radius={[0, 4, 4, 0]}
             label={{ position: 'right', fill: CHART.axis, fontSize: 12 }} />
      </BarChart>
    </ResponsiveContainer>
  );
}
