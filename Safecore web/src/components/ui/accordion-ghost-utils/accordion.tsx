import { createContext, forwardRef, useContext, type ComponentPropsWithoutRef, type ElementRef } from 'react';
import * as AccordionPrimitive from '@radix-ui/react-accordion';
import { ChevronDown, Plus } from 'lucide-react';

// Accordion (base shadcn/Radix) adaptado ao projeto, que não usa Tailwind:
// as classes utilitárias viraram CSS (.acc-*) em landing.css, incluindo as
// animações accordion-down/accordion-up. Acrescenta as props `variant` e
// `indicator` usadas pelo AccordionGhost.

type Variant = 'default' | 'ghost';
type Indicator = 'chevron' | 'plus';

const AccordionStyle = createContext<{ indicator: Indicator }>({ indicator: 'chevron' });

const cx = (...c: (string | false | undefined)[]) => c.filter(Boolean).join(' ');

type AccordionProps = ComponentPropsWithoutRef<typeof AccordionPrimitive.Root> & {
  variant?: Variant;
  indicator?: Indicator;
};

function Accordion({ variant = 'default', indicator = 'chevron', className, ...props }: AccordionProps) {
  return (
    <AccordionStyle.Provider value={{ indicator }}>
      <AccordionPrimitive.Root className={cx('acc', `acc-${variant}`, className)} {...props} />
    </AccordionStyle.Provider>
  );
}

const AccordionItem = forwardRef<
  ElementRef<typeof AccordionPrimitive.Item>,
  ComponentPropsWithoutRef<typeof AccordionPrimitive.Item>
>(({ className, ...props }, ref) => (
  <AccordionPrimitive.Item ref={ref} className={cx('acc-item', className)} {...props} />
));
AccordionItem.displayName = 'AccordionItem';

const AccordionTrigger = forwardRef<
  ElementRef<typeof AccordionPrimitive.Trigger>,
  ComponentPropsWithoutRef<typeof AccordionPrimitive.Trigger>
>(({ className, children, ...props }, ref) => {
  const { indicator } = useContext(AccordionStyle);
  const Icon = indicator === 'plus' ? Plus : ChevronDown;
  return (
    <AccordionPrimitive.Header className="acc-header">
      <AccordionPrimitive.Trigger ref={ref} className={cx('acc-trigger', className)} {...props}>
        {children}
        <Icon className={cx('acc-icon', `acc-icon-${indicator}`)} aria-hidden />
      </AccordionPrimitive.Trigger>
    </AccordionPrimitive.Header>
  );
});
AccordionTrigger.displayName = AccordionPrimitive.Trigger.displayName;

const AccordionContent = forwardRef<
  ElementRef<typeof AccordionPrimitive.Content>,
  ComponentPropsWithoutRef<typeof AccordionPrimitive.Content>
>(({ className, children, ...props }, ref) => (
  <AccordionPrimitive.Content ref={ref} className="acc-content" {...props}>
    <div className={cx('acc-content-inner', className)}>{children}</div>
  </AccordionPrimitive.Content>
));
AccordionContent.displayName = AccordionPrimitive.Content.displayName;

export { Accordion, AccordionItem, AccordionTrigger, AccordionContent };
