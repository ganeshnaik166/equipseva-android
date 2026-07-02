import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_checks: number;
  authentic_count: number;
  suspicious_count: number;
  fraudulent_count: number;
  avg_authenticity_score: number;
  open_incidents: number;
  total_loss_rupees: number;
};

type RecentCheck = {
  id: string;
  visit_date: string;
  hospital_name: string;
  engineer_handle: string;
  photo_count: number;
  authenticity_score: number;
  verdict: string;
};

type FraudulentEngineer = {
  engineer_handle: string;
  fraud_count: number;
  total_loss: number;
  worst_severity: string;
};

type IncidentBreakdown = {
  incident_type: string;
  occurrences: number;
  open_count: number;
  total_loss: number;
};

type HospitalAuth = {
  hospital_name: string;
  check_count: number;
  avg_score: number;
  fraud_count: number;
};

type OpenP0 = {
  id: string;
  incident_type: string;
  engineer_handle: string;
  hospital_name: string;
  detected_at: string;
  loss_amount_rupees: number;
  resolution_action: string;
};

type FailureMode = {
  failure_mode: string;
  failed_count: number;
  pct_of_total: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpi, recent, fraudEng, incBreak, hospAuth, openP0, failModes] = await Promise.all([
    supabase.rpc('r2924_kpi_summary'),
    supabase.rpc('r2924_recent_checks'),
    supabase.rpc('r2924_fraudulent_engineers'),
    supabase.rpc('r2924_incident_breakdown'),
    supabase.rpc('r2924_hospital_authenticity'),
    supabase.rpc('r2924_open_p0_incidents'),
    supabase.rpc('r2924_check_failure_modes'),
  ]);

  const k: KpiRow = (kpi.data?.[0] ?? {
    total_checks: 0, authentic_count: 0, suspicious_count: 0, fraudulent_count: 0,
    avg_authenticity_score: 0, open_incidents: 0, total_loss_rupees: 0,
  }) as KpiRow;

  const recentCols: Column<RecentCheck>[] = [
    { key: 'visit_date', header: 'Visit', render: (r) => r.visit_date },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'engineer_handle', header: 'Engineer', render: (r) => r.engineer_handle },
    { key: 'photo_count', header: 'Photos', render: (r) => r.photo_count },
    { key: 'authenticity_score', header: 'Score', render: (r) => r.authenticity_score },
    { key: 'verdict', header: 'Verdict', render: (r) => r.verdict },
  ];

  const fraudCols: Column<FraudulentEngineer>[] = [
    { key: 'engineer_handle', header: 'Engineer', render: (r) => r.engineer_handle },
    { key: 'fraud_count', header: 'Incidents', render: (r) => r.fraud_count },
    { key: 'total_loss', header: 'Loss (Rs)', render: (r) => r.total_loss },
    { key: 'worst_severity', header: 'Worst', render: (r) => r.worst_severity },
  ];

  const incCols: Column<IncidentBreakdown>[] = [
    { key: 'incident_type', header: 'Type', render: (r) => r.incident_type },
    { key: 'occurrences', header: 'Total', render: (r) => r.occurrences },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
    { key: 'total_loss', header: 'Loss (Rs)', render: (r) => r.total_loss },
  ];

  const hospCols: Column<HospitalAuth>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'check_count', header: 'Checks', render: (r) => r.check_count },
    { key: 'avg_score', header: 'Avg Score', render: (r) => r.avg_score },
    { key: 'fraud_count', header: 'Fraud', render: (r) => r.fraud_count },
  ];

  const p0Cols: Column<OpenP0>[] = [
    { key: 'incident_type', header: 'Type', render: (r) => r.incident_type },
    { key: 'engineer_handle', header: 'Engineer', render: (r) => r.engineer_handle },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'detected_at', header: 'Detected', render: (r) => new Date(r.detected_at).toLocaleString() },
    { key: 'loss_amount_rupees', header: 'Loss (Rs)', render: (r) => r.loss_amount_rupees },
    { key: 'resolution_action', header: 'Action', render: (r) => r.resolution_action },
  ];

  const failCols: Column<FailureMode>[] = [
    { key: 'failure_mode', header: 'Failure Mode', render: (r) => r.failure_mode },
    { key: 'failed_count', header: 'Failed', render: (r) => r.failed_count },
    { key: 'pct_of_total', header: 'Pct', render: (r) => r.pct_of_total + '%' },
  ];

  return (
    <div style={{ padding: '24px', fontFamily: 'system-ui' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Visit-Photo Time-Stamp Authenticity Verification
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Round r2924 — monthly engineer visit photo authenticity, EXIF & GPS verification
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        <KpiCard label="Total Checks" value={k.total_checks} />
        <KpiCard label="Authentic" value={k.authentic_count} />
        <KpiCard label="Suspicious" value={k.suspicious_count} />
        <KpiCard label="Fraudulent" value={k.fraudulent_count} />
        <KpiCard label="Avg Score" value={k.avg_authenticity_score} />
        <KpiCard label="Open Incidents" value={k.open_incidents} />
        <KpiCard label="Total Loss (Rs)" value={k.total_loss_rupees} />
      </div>

      <Section title="Recent Authenticity Checks (last 20)">
        <DataTable
          rows={(recent.data ?? []) as RecentCheck[]}
          columns={recentCols}
          emptyMessage="no recent checks"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Engineers With Fraud Incidents">
        <DataTable
          rows={(fraudEng.data ?? []) as FraudulentEngineer[]}
          columns={fraudCols}
          emptyMessage="no fraud incidents"
          rowKey={(r, i) => String(r.engineer_handle ?? i)}
        />
      </Section>

      <Section title="Incident Type Breakdown">
        <DataTable
          rows={(incBreak.data ?? []) as IncidentBreakdown[]}
          columns={incCols}
          emptyMessage="no incidents"
          rowKey={(r, i) => String(r.incident_type ?? i)}
        />
      </Section>

      <Section title="Hospital Authenticity (ranked worst-first)">
        <DataTable
          rows={(hospAuth.data ?? []) as HospitalAuth[]}
          columns={hospCols}
          emptyMessage="no hospital data"
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </Section>

      <Section title="Open P0/P1 Incidents">
        <DataTable
          rows={(openP0.data ?? []) as OpenP0[]}
          columns={p0Cols}
          emptyMessage="no open critical incidents"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Check Failure Modes">
        <DataTable
          rows={(failModes.data ?? []) as FailureMode[]}
          columns={failCols}
          emptyMessage="no failures"
          rowKey={(r, i) => String(r.failure_mode ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px', background: '#fafafa' }}>
      <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</div>
      <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '32px' }}>
      <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>{title}</h2>
      {children}
    </section>
  );
}
