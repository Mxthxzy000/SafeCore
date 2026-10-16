import type { ReactNode } from 'react';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from './accordion-ghost-utils/accordion';

export interface AccordionGhostSection {
  value: string;
  title: string;
  body: ReactNode;
}

/** Lista numerada (01, 02…) com um item aberto por vez e indicador "+". */
export default function AccordionGhost({ sections, className }: {
  sections: AccordionGhostSection[];
  className?: string;
}) {
  return (
    <Accordion type="single" collapsible variant="ghost" indicator="plus" className={className}>
      {sections.map((section, index) => (
        <AccordionItem key={section.value} value={section.value}>
          <AccordionTrigger>
            <span className="acc-title">
              <span className="acc-index">{String(index + 1).padStart(2, '0')}</span>
              {section.title}
            </span>
          </AccordionTrigger>
          <AccordionContent className="acc-indent">{section.body}</AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}
