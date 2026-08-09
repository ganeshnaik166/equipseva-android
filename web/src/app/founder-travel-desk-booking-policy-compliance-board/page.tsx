import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; records: number; pct: number };
type DeptRow = {
  department: string;
  records: number;
  trips: number;
  compliant_records: number;
  high_risk_records: number;
  policy_violations: number;
  avg_advance_pct: number;
  avg_cost_per_trip_rupees: number;
  total_spend_rupees: number;
  out_of_policy_spend_rupees: number;
};
type MatrixRow = {
  booking_channel: string;
  compliance_status: string;
  records: number;
  trips: number;
  policy_violations: number;
  out_of_policy_spend_rupees: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  trips: number;
  total_spend_rupees: number;
  out_of_policy_spend_rupees: number;
  policy_violations: number;
  avg_advance_days: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  travel_type: string;
  records: number;
  trips: number;
  policy_violations: number;
  out_of_policy_spend_rupees: number;
  total_spend_rupees: number;
  oop_share_pct: number;
};
type RiskRow = {
  office: string;
  department: string;
  record_code: string;
  travel_type: string;
  period_month: string;
  booking_channel: string;
  compliance_status: string;
  trend_dir: string;
  policy_violations: number;
  out_of_policy_spend_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3675_compliance_status_rollup'),
    supabase.rpc('founder_r3675_department_scorecard'),
    supabase.rpc('founder_r3675_channel_status_matrix'),
    supabase.rpc('founder_r3675_monthly_spend_trend'),
    supabase.rpc('founder_r3675_capa_status_board'),
    supabase.rpc('founder_r3675_root_cause_pareto'),
    supabase.rpc('founder_r3675_out_of_policy_digest'),
    supabase.rpc('founder_r3675_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'records', header: 'Records' },
    { key: 'trips', header: 'Trips' },
    { key: 'compliant_records', header: 'Compliant' },
    { key: 'high_risk_records', header: 'High Risk' },
    { key: 'policy_violations', header: 'Violations' },
    { key: 'avg_advance_pct', header: 'Avg Advance %' },
    { key: 'avg_cost_per_trip_rupees', header: 'Avg Cost/Trip (INR)' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'out_of_policy_spend_rupees', header: 'OOP Spend (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'booking_channel', header: 'Booking Channel' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'trips', header: 'Trips' },
    { key: 'policy_violations', header: 'Violations' },
    { key: 'out_of_policy_spend_rupees', header: 'OOP Spend (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'trips', header: 'Trips' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'out_of_policy_spend_rupees', header: 'OOP Spend (INR)' },
    { key: 'policy_violations', header: 'Violations' },
    { key: 'avg_advance_days', header: 'Avg Advance Days' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'travel_type', header: 'Travel Type' },
    { key: 'records', header: 'Records' },
    { key: 'trips', header: 'Trips' },
    { key: 'policy_violations', header: 'Violations' },
    { key: 'out_of_policy_spend_rupees', header: 'OOP Spend (INR)' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'oop_share_pct', header: 'OOP Share %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'office', header: 'Office' },
    { key: 'department', header: 'Department' },
    { key: 'record_code', header: 'Record' },
    { key: 'travel_type', header: 'Travel Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'booking_channel', header: 'Channel' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'policy_violations', header: 'Violations' },
    { key: 'out_of_policy_spend_rupees', header: 'OOP Spend (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Travel-Desk Booking / Policy-Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Travel-desk policy compliance across offices &amp; departments — advance-booking window
        &times; policy violations &times; out-of-policy spend &times; cost per trip &times;
        preferred-vendor share &times; booking channel (travel desk, self OTA, corporate portal,
        direct vendor, emergency) &amp; CAPA closure. Founder-gated view: compliance-status rollup,
        department scorecards, channel &times; status matrix, monthly spend trend, root-cause
        pareto, and the high-risk queue of uncontrolled &amp; frequent-violation cells.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No travel-desk records logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Booking channel &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by booking channel."
          rowKey={(r, i) => `${r.booking_channel}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Out-of-policy spend digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No out-of-policy rollups."
          rowKey={(r, i) => String(r.travel_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk records."
          rowKey={(r, i) => `${r.record_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
