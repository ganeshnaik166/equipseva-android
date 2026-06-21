import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Incident = {
  id: string;
  engineer_email: string | null;
  hospital_name: string | null;
  incident_type: string;
  severity: string;
  occurred_at: string;
  status: string;
};

type SeverityRow = { severity: string; cnt: number };

type OpenRow = {
  id: string;
  engineer_email: string | null;
  hospital_name: string | null;
  incident_type: string;
  severity: string;
  occurred_at: string;
  status: string;
  open_actions: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [incidentsRes, sevRes, openRes] = await Promise.all([
    sb.rpc('list_incidents_r1684'),
    sb.rpc('severity_distribution_r1684'),
    sb.rpc('open_incidents_top_n_r1684', { p_limit: 25 }),
  ]);

  const incidents: Incident[] = (incidentsRes.data as Incident[]) ?? [];
  const sevs: SeverityRow[] = (sevRes.data as SeverityRow[]) ?? [];
  const open: OpenRow[] = (openRes.data as OpenRow[]) ?? [];

  const totalIncidents = incidents.length;
  const totalOpen = open.length;
  const sevMap: Record<string, number> = {};
  for (const s of sevs) sevMap[s.severity] = s.cnt;
  const fatalCount = sevMap['fatal'] ?? 0;
  const severeCount = sevMap['severe'] ?? 0;

  const incidentCols: Column<Incident>[] = [
    { key: 'occurred_at', header: 'When', render: (r: Incident) => new Date(r.occurred_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: Incident) => r.engineer_email ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: Incident) => r.hospital_name ?? '—' },
    { key: 'incident_type', header: 'Type', render: (r: Incident) => r.incident_type },
    { key: 'severity', header: 'Severity', render: (r: Incident) => r.severity },
    { key: 'status', header: 'Status', render: (r: Incident) => r.status },
  ];

  const openCols: Column<OpenRow>[] = [
    { key: 'severity', header: 'Severity', render: (r: OpenRow) => r.severity },
    { key: 'engineer_email', header: 'Engineer', render: (r: OpenRow) => r.engineer_email ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: OpenRow) => r.hospital_name ?? '—' },
    { key: 'incident_type', header: 'Type', render: (r: OpenRow) => r.incident_type },
    { key: 'occurred_at', header: 'When', render: (r: OpenRow) => new Date(r.occurred_at).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: OpenRow) => r.status },
    { key: 'open_actions', header: 'Open RCA', render: (r: OpenRow) => String(r.open_actions) },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity', render: (r: SeverityRow) => r.severity },
    { key: 'cnt', header: 'Count', render: (r: SeverityRow) => String(r.cnt) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer Health & Safety Incidents</h1>
        <p style={{ color: '#666' }}>On-site injury / near-miss log with RCA tracking. Severe (&gt;= severe) demands escalation.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>KPIs</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12 }}>
          <Kpi label="Total Incidents" value={String(totalIncidents)} />
          <Kpi label="Open / Investigating" value={String(totalOpen)} />
          <Kpi label="Severe" value={String(severeCount)} />
          <Kpi label="Fatal" value={String(fatalCount)} />
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Severity Distribution</h2>
        <DataTable rows={sevs} columns={sevCols} rowKey={(r, i) => String((r as SeverityRow).severity ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Queue — Open Incidents</h2>
        <DataTable rows={open} columns={openCols} rowKey={(r, i) => String((r as OpenRow).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Incidents</h2>
        <DataTable rows={incidents} columns={incidentCols} rowKey={(r, i) => String((r as Incident).id ?? i)} />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
