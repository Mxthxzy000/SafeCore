import { useMemo, type ReactNode } from 'react';
import { motion, useReducedMotion } from 'motion/react';

// Fundo animado de linhas flutuantes (adaptado do componente FloatingPathsBackground).
// O projeto não usa Tailwind: as classes utilitárias originais viraram CSS em
// landing.css (.fp-*). A cor das linhas vem de `color` do elemento (currentColor),
// então o mesmo componente funciona sobre fundos claros e escuros.

function buildPaths(position: number) {
  return Array.from({ length: 36 }, (_, i) => ({
    id: i,
    d: `M-${380 - i * 5 * position} -${189 + i * 6}C-${
      380 - i * 5 * position
    } -${189 + i * 6} -${312 - i * 5 * position} ${216 - i * 6} ${
      152 - i * 5 * position
    } ${343 - i * 6}C${616 - i * 5 * position} ${470 - i * 6} ${
      684 - i * 5 * position
    } ${875 - i * 6} ${684 - i * 5 * position} ${875 - i * 6}`,
    width: 0.5 + i * 0.03,
    // Duração sorteada uma única vez (não muda a cada nova renderização)
    duration: 20 + Math.random() * 10,
  }));
}

export function FloatingPaths({ position }: { position: number }) {
  const paths = useMemo(() => buildPaths(position), [position]);
  const reduceMotion = useReducedMotion();

  return (
    <svg className="fp-svg" viewBox="0 0 696 316" fill="none" preserveAspectRatio="xMidYMid slice" aria-hidden>
      {paths.map((path) => (
        <motion.path
          key={path.id}
          d={path.d}
          stroke="currentColor"
          strokeWidth={path.width}
          strokeOpacity={0.1 + path.id * 0.03}
          initial={{ pathLength: 0.3, opacity: 0.6 }}
          animate={reduceMotion
            ? { pathLength: 1, opacity: 0.45 }
            : { pathLength: 1, opacity: [0.3, 0.6, 0.3], pathOffset: [0, 1, 0] }}
          transition={reduceMotion
            ? { duration: 0 }
            : { duration: path.duration, repeat: Number.POSITIVE_INFINITY, ease: 'linear' }}
        />
      ))}
    </svg>
  );
}

export function FloatingPathsBackground({
  position,
  children,
  className = '',
}: {
  position: number;
  className?: string;
  children?: ReactNode;
}) {
  return (
    <div className={`fp-root ${className}`}>
      <div className="fp-layer">
        <FloatingPaths position={position} />
      </div>
      {children}
    </div>
  );
}
