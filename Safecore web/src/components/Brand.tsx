/** Logo do SafeCore (escudo com capacete e selo verde), igual ao do app mobile. */
export function LogoMark({ size = 40, color = '#fff' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" role="img" aria-label="Logo SafeCore">
      <g fill="none" stroke={color} strokeLinecap="round" strokeLinejoin="round">
        <path d="M24 5 L39 10.5 L39 22 C39 32.5 32.5 40 24 43.5 C15.5 40 9 32.5 9 22 L9 10.5 Z" strokeWidth="2.6" />
        <path d="M15 30 C15 22 19 18.5 24 18.5 C29 18.5 33 22 33 30" strokeWidth="2.2" />
        <path d="M13 30.5 H35" strokeWidth="2.6" />
        <path d="M24 18.5 V24.5" strokeWidth="2.2" />
        <path d="M20 33.5 H28" strokeWidth="1.8" />
      </g>
      <circle cx="37" cy="9" r="7.2" fill="#fff" />
      <circle cx="37" cy="9" r="6" fill="#79CC4B" />
      <path d="M33.8 9.2 L36.2 11.4 L40.2 6.8" fill="none" stroke="#fff" strokeWidth="1.8"
            strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export function Wordmark({ size = 30, subtitle = true }: { size?: number; subtitle?: boolean }) {
  return (
    <div className="wordmark" aria-label="SafeCore — Monitoramento e Segurança">
      <div className="wordmark-name" style={{ fontSize: size }}>
        <span className="wm-safe">Safe</span><span className="wm-core">Core</span>
      </div>
      {subtitle && <div className="wordmark-sub" style={{ fontSize: size * 0.21 }}>MONITORAMENTO E SEGURANÇA</div>}
    </div>
  );
}

/** Ilustração industrial em traço (fundo do login), versão SVG do app mobile. */
export function IndustrialIllustration() {
  return (
    <svg className="industrial" viewBox="0 0 400 300" preserveAspectRatio="xMaxYMax meet" aria-hidden>
      <g fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
        <path d="M0 288 H400" />
        <rect x="280" y="135" width="88" height="153" rx="10" />
        <path d="M280 165.6 H368 M280 196.2 H368 M280 226.8 H368 M280 257.4 H368" />
        <path d="M374 143 V288 M382 143 V288" />
        {Array.from({ length: 14 }, (_, i) => <path key={i} d={`M374 ${151 + i * 10} H382`} />)}
        <rect x="120" y="186" width="120" height="102" rx="6" />
        <circle cx="180" cy="224.8" r="20.4" />
        <path d="M180 224.8 L192 214.6" />
        <circle cx="144" cy="276" r="4" /><circle cx="180" cy="276" r="4" /><circle cx="216" cy="276" r="4" />
        <path d="M226 186 V165 H280 M234 186 V173 H280" />
        <path d="M256 161 V177 M268 161 V177" />
        <circle cx="64" cy="210" r="20" />
        <path d="M44 210 H84 M64 190 V230 M64 230 V288" />
        <path d="M0 246 H64 M64 258 H120" />
        <rect x="176" y="90" width="24" height="96" />
        <path d="M173 90 H203" />
      </g>
    </svg>
  );
}
