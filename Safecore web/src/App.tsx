import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './auth/AuthProvider';
import { RequireAdmin } from './auth/RequireAdmin';
import { Layout } from './components/Layout';
import { EmptyState, ToastProvider } from './components/ui';
import { Landing } from './pages/Landing';
import { Login } from './pages/Login';
import { SetPassword } from './pages/SetPassword';
import { Dashboard } from './pages/Dashboard';
import { Employees } from './pages/Employees';
import { EmployeeDetail } from './pages/EmployeeDetail';
import { Areas } from './pages/Areas';
import { AreaDetail } from './pages/AreaDetail';
import { Sensors } from './pages/Sensors';
import { SensorDetail } from './pages/SensorDetail';
import { Alerts } from './pages/Alerts';
import { AlertDetail } from './pages/AlertDetail';
import { Occurrences } from './pages/Occurrences';
import { Reports } from './pages/Reports';
import { Audit } from './pages/Audit';

export function App() {
  return (
    <BrowserRouter>
      <ToastProvider>
        <AuthProvider>
          <Routes>
            {/* Públicas: site, login (sem cadastro) e definição de senha por convite/recuperação */}
            <Route path="/" element={<Landing />} />
            <Route path="/login" element={<Login />} />
            <Route path="/definir-senha" element={<SetPassword />} />

            {/* Todas as demais rotas exigem administrador validado no servidor */}
            <Route element={<RequireAdmin><Layout /></RequireAdmin>}>
              <Route path="painel" element={<Dashboard />} />
              <Route path="funcionarios" element={<Employees />} />
              <Route path="funcionarios/:id" element={<EmployeeDetail />} />
              <Route path="areas" element={<Areas />} />
              <Route path="areas/:id" element={<AreaDetail />} />
              <Route path="sensores" element={<Sensors />} />
              <Route path="sensores/:id" element={<SensorDetail />} />
              <Route path="alertas" element={<Alerts />} />
              <Route path="alertas/:id" element={<AlertDetail />} />
              <Route path="ocorrencias" element={<Occurrences />} />
              <Route path="relatorios" element={<Reports />} />
              <Route path="auditoria" element={<Audit />} />
              <Route path="*" element={
                <EmptyState title="Página não encontrada" text="Verifique o endereço ou volte ao painel." />
              } />
            </Route>
          </Routes>
        </AuthProvider>
      </ToastProvider>
    </BrowserRouter>
  );
}

