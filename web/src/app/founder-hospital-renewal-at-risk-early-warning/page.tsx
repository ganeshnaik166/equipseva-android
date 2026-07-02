import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, signalsRes, interventionsRes] = await Promise.all([
    sb.rpc('rar_r1887_critical_signals_summary'),
    sb.rpc('rar_r1887_list_signals', { p_status: null, p_limit: 100 }),
    sb.rpc('rar_r1887_recent_interventions', { p_limit: 50 }),
  ]);

  const summary = (summaryRes.data && summaryRes.data[0]) || {
    total_open: 0,
    total_critical_open: 0,
    total_warning_open: 0,
    total_info_open: 0,
    total_in_intervention: 0,
    total_cleared: 0,
    total_lost: 0,
    hospitals_at_risk: 0,
  };

  const signals: any[] = signalsRes.data || [];
  const interventions: any[] = interventionsRes.data || [];

  const signalCols: Column<any>[] = [
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email || '—' },
    { key: 'org_name', header: 'Org', render: (r: any) => r.org_name || '—' },
    { key: 'signal_type', header: 'Type', render: (r: any) => r.signal_type || '—' },
    { key: 'signal_severity', header: 'Severity', render: (r: any) => r.signal_severity || '—' },
    { key: 'signal_value', header: 'Value', render: (r: any) => r.signal_value || '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '—' },
  ];

  const intvCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email || '—' },
    { key: 'intervention_type', header: 'Type', render: (r: any) => r.intervention_type || '—' },
    { key: 'signal_severity', header: 'Signal severity', render: (r: any) => r.signal_severity || '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome || '—' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Hospital Renewal-At-Risk Early Warning</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Detect renewal-at-risk hospitals before AMC contract expires — signals & interventions.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Risk summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <Stat label="Open signals" value={summary.total_open} />
          <Stat label="Critical open" value={summary.total_critical_open} />
          <Stat label="Warning open" value={summary.total_warning_open} />
          <Stat label="Info open" value={summary.total_info_open} />
          <Stat label="In intervention" value={summary.total_in_intervention} />
          <Stat label="Cleared" value={summary.total_cleared} />
          <Stat label="Lost" value={summary.total_lost} />
          <Stat label="Hospitals at risk" value={summary.hospitals_at_risk} />
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Signals (latest 100)</h2>
        <DataTable rows={signals} columns={signalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent interventions</h2>
        <DataTable rows={interventions} columns={intvCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ fontSize: 12, color: '#888' }}>
        <p>
          Signal types: tickets_spike, satisfaction_drop, payment_delay, engineer_change, competitive_visit, champion_left.
          Severities: info &lt; warning &lt; critical. Statuses: open → in_intervention → cleared/lost.
        </p>
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string | null | undefined }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value ?? 0}</div>
    </div>
  );
}
