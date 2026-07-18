import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { cert_status: string; certs: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_certs: number;
  valid_certs: number;
  expiring_soon: number;
  expired: number;
  recalled: number;
  suspended: number;
  compliance_pct: number;
};
type MatrixRow = {
  instrument_type: string;
  calibration_standard: string;
  certs: number;
  valid_certs: number;
  avg_uncertainty: number;
};
type TrendRow = {
  expiry_date: string;
  certs: number;
  valid_certs: number;
  expiring_soon: number;
  expired: number;
  recalled: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  hospital_name: string;
  engineer_name: string;
  instrument_type: string;
  cert_number: string;
  nabl_lab_name: string;
  expiry_date: string;
  cert_status: string;
  measurement_uncertainty: number;
  uncertainty_unit: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3139_cert_status_rollup'),
    supabase.rpc('founder_r3139_hospital_scorecard'),
    supabase.rpc('founder_r3139_instrument_standard_matrix'),
    supabase.rpc('founder_r3139_expiry_trend'),
    supabase.rpc('founder_r3139_capa_status_board'),
    supabase.rpc('founder_r3139_root_cause_pareto'),
    supabase.rpc('founder_r3139_regulatory_impact_digest'),
    supabase.rpc('founder_r3139_priority_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cert_status', header: 'Status' },
    { key: 'certs', header: 'Certs' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_certs', header: 'Certs' },
    { key: 'valid_certs', header: 'Valid' },
    { key: 'expiring_soon', header: 'Expiring' },
    { key: 'expired', header: 'Expired' },
    { key: 'recalled', header: 'Recalled' },
    { key: 'suspended', header: 'Suspended' },
    { key: 'compliance_pct', header: 'Valid %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'instrument_type', header: 'Instrument' },
    { key: 'calibration_standard', header: 'Traceability Standard' },
    { key: 'certs', header: 'Certs' },
    { key: 'valid_certs', header: 'Valid' },
    { key: 'avg_uncertainty', header: 'Avg Uncertainty' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'expiry_date', header: 'Expiry Date' },
    { key: 'certs', header: 'Certs' },
    { key: 'valid_certs', header: 'Valid' },
    { key: 'expiring_soon', header: 'Expiring' },
    { key: 'expired', header: 'Expired' },
    { key: 'recalled', header: 'Recalled' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'instrument_type', header: 'Instrument' },
    { key: 'cert_number', header: 'Cert No.' },
    { key: 'nabl_lab_name', header: 'NABL Lab' },
    { key: 'expiry_date', header: 'Expiry' },
    { key: 'cert_status', header: 'Status' },
    { key: 'measurement_uncertainty', header: 'Uncertainty' },
    { key: 'uncertainty_unit', header: 'Unit' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Calibration Certificate Expiry &amp; Traceability Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-instrument calibration certificates — instrument type &times; NABL lab &times; issued/expiry
        &times; traceability standard &times; measurement uncertainty &times; status. Founder-gated view:
        certificate-status rollups, hospital scorecards, root-cause pareto, and regulatory-impact digest
        across NABL, CDSCO &amp; ISO 13485 surfaces, with renewal &amp; CAPA closure.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Certificate status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No calibration certificates logged yet."
          rowKey={(r, i) => String(r.cert_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital traceability scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Instrument &times; traceability standard matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No certificates by standard."
          rowKey={(r, i) => `${r.instrument_type}-${r.calibration_standard}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Certificate expiry timeline</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No expiry timeline data."
          rowKey={(r, i) => String(r.expiry_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA &amp; renewal status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk certificate priority queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk certificates."
          rowKey={(r, i) => `${r.cert_number}-${r.expiry_date}-${i}`}
        />
      </section>
    </main>
  );
}
