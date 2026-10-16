import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import {
  Bell, ClipboardList, FileBarChart, Factory, LayoutDashboard, LogOut, Menu,
  Radio, ScrollText, ShieldCheck, Users, X,
} from 'lucide-react';
import { useAdmin, useAuth } from '../auth/AuthProvider';
import { LogoMark } from './Brand';
import { Avatar } from './ui';

const NAV = [
  { to: '/painel', label: 'Painel', icon: LayoutDashboard, end: true },
  { to: '/funcionarios', label: 'Funcionários', icon: Users },
  { to: '/areas', label: 'Áreas e permissões', icon: Factory },
  { to: '/sensores', label: 'Sensores', icon: Radio },
  { to: '/alertas', label: 'Alertas', icon: Bell },
  { to: '/ocorrencias', label: 'Ocorrências', icon: ClipboardList },
  { to: '/relatorios', label: 'Relatórios', icon: FileBarChart },
  { to: '/auditoria', label: 'Auditoria', icon: ScrollText },
];

export function Layout() {
  const { profile } = useAdmin();
  const { signOut } = useAuth();
  const [open, setOpen] = useState(false);
  const location = useLocation();

  useEffect(() => setOpen(false), [location.pathname]);

  const name = profile.full_name || profile.email;

  return (
    <div className="shell">
      <aside className={`sidebar ${open ? 'open' : ''}`}>
        <div className="sidebar-brand">
          <LogoMark size={38} />
          <div>
            <div className="sidebar-title">SafeCore</div>
            <div className="sidebar-sub">Painel administrativo</div>
          </div>
          <button className="icon-btn sidebar-close" onClick={() => setOpen(false)} aria-label="Fechar menu">
            <X size={18} />
          </button>
        </div>
        <nav className="sidebar-nav">
          {NAV.map(({ to, label, icon: Icon, end }) => (
            <NavLink key={to} to={to} end={end} className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <Icon size={18} />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-foot">
          <ShieldCheck size={14} />
          <span>Acesso exclusivo para administradores</span>
        </div>
      </aside>
      {open && <div className="sidebar-backdrop" onClick={() => setOpen(false)} />}

      <div className="main">
        <header className="topbar">
          <button className="icon-btn menu-btn" onClick={() => setOpen(true)} aria-label="Abrir menu">
            <Menu size={20} />
          </button>
          <div className="topbar-spacer" />
          <div className="topbar-user">
            <Avatar name={name} size={34} />
            <div className="topbar-user-text">
              <strong>{name}</strong>
              <span>Administrador</span>
            </div>
            <button className="icon-btn" onClick={() => signOut()} title="Sair" aria-label="Sair">
              <LogOut size={18} />
            </button>
          </div>
        </header>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
