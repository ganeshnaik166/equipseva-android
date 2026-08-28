import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { claim_status: string; claims: number; pct: number };
type LocationRow = {
  incident_location: string;
  total_claims: number;
  settled_on_time: number;
  settled_delayed: number;
  litigation_pending: number;
  fatal_claims: number;
  total_claim_amount_rupees: number;
  total_settlement_amount_rupees: number;
  avg_days_to_settlement: number | null;
};
type MatrixRow = {
  injury_class: string;
  claim_status: string;
  claims: number;
  avg_disability_pct: number | null;
  total_settlement_amount_rupees: number;
};
type TrendRow = {
  period_month: string;
  claims: number;
  total_claim_amount_rupees: number;
  total_settlement_amount_rupees: number;
  avg_days_to_settlement: number | null;
  litigation_claims: number;
};
type CapaRow = { capa_status: string; actions: number; overdue_flag: number };
type CauseRow = { root_cause: string | null; occurrences: number; pct: number };
type DelayRow = {
  incident_location: string;
  delayed_or_pending_claims: number;
  avg_days_to_settlement: number | null;
  max_days_to_settlement: number | null;
  litigation_claims: number;
  disputed_claims: number;
  amount_at_risk_rupees: number;
};
type RiskRow = {
  employee_name: string;
  incident_location: string;
  period_month: string;
  injury_class: string;
  claim_status: string;
  claim_amount_rupees: number | null;
  disability_pct: number | null;
  litigation_involved: boolean;
  insurer_name: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    locationRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    delayRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3753_claim_status_rollup'),
    supabase.rpc('founder_r3753_incident_location_scorecard'),
    supabase.rpc('founder_r3753_injury_class_status_matrix'),
    supabase.rpc('founder_r3753_monthly_settlement_trend'),
    supabase.rpc('founder_r3753_capa_status_board'),
    supabase.rpc('founder_r3753_root_cause_pareto'),
    supabase.rpc('founder_r3753_delay_digest'),
    supabase.rpc('founder_r3753_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const locationRows: LocationRow[] = (locationRes.data as LocationRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const delayRows: DelayRow[] = (delayRes.data as DelayRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'pct', header: 'Share %' },
  ];

  const locationCols: Column<LocationRow>[] = [
    { key: 'incident_location', header: 'Location' },
    { key: 'total_claims', header: 'Total Claims' },
    { key: 'settled_on_time', header: 'Settled On Time' },
    { key: 'settled_delayed', header: 'Settled Delayed' },
    { key: 'litigation_pending', header: 'Litigation Pending' },
    { key: 'fatal_claims', header: 'Fatal Claims' },
    { key: 'total_claim_amount_rupees', header: 'Claim Amount (INR)' },
    { key: 'total_settlement_amount_rupees', header: 'Settlement Amount (INR)' },
    { key: 'avg_days_to_settlement', header: 'Avg Days to Settlement' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'injury_class', header: 'Injury Class' },
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'avg_disability_pct', header: 'Avg Disability %' },
    { key: 'total_settlement_amount_rupees', header: 'Settlement Amount (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'claims', header: 'Claims' },
    { key: 'total_claim_amount_rupees', header: 'Claim Amount (INR)' },
    { key: 'total_settlement_amount_rupees', header: 'Settlement Amount (INR)' },
    { key: 'avg_days_to_settlement', header: 'Avg Days to Settlement' },
    { key: 'litigation_claims', header: 'Litigation Claims' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const delayCols: Column<DelayRow>[] = [
    { key: 'incident_location', header: 'Location' },
    { key: 'delayed_or_pending_claims', header: 'Delayed / Pending Claims' },
    { key: 'avg_days_to_settlement', header: 'Avg Days to Settlement' },
    { key: 'max_days_to_settlement', header: 'Max Days to Settlement' },
    { key: 'litigation_claims', header: 'Litigation Claims' },
    { key: 'disputed_claims', header: 'Disputed Claims' },
    { key: 'amount_at_risk_rupees', header: 'Amount at Risk (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'incident_location', header: 'Location' },
    { key: 'period_month', header: 'Month' },
    { key: 'injury_class', header: 'Injury Class' },
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'claim_amount_rupees', header: 'Claim Amount (INR)' },
    { key: 'disability_pct', header: 'Disability %' },
    { key: 'litigation_involved', header: 'Litigation' },
    { key: 'insurer_name', header: 'Insurer' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Workmen-Compensation (WC) Claims Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Employee&apos;s Compensation Act claims for on-duty injuries to field engineers &amp;
        site staff — claim filed &amp; settlement dates, insurer, turnaround time (TAT),
        disability classification, litigation exposure &amp; CAPA closure. This tracks the
        insurance-claim / compensation process, distinct from safety-incident, near-miss, or
        PPE-compliance logging. Founder-gated view: claim-status distribution, location
        scorecards, injury-class &times; status matrix, monthly settlement trend, CAPA board,
        root-cause pareto, settlement-delay digest, and a high-risk claims queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Claim-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No WC claims logged yet."
          rowKey={(r, i) => String(r.claim_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Incident-location scorecard</h2>
        <DataTable
          rows={locationRows}
          columns={locationCols}
          emptyMessage="No location rollups."
          rowKey={(r, i) => String(r.incident_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Injury class &times; claim status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No injury-class data."
          rowKey={(r, i) => `${r.injury_class}-${r.claim_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly settlement trend</h2>
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
          emptyMessage="No CAPA actions."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Settlement-delay digest</h2>
        <DataTable
          rows={delayRows}
          columns={delayCols}
          emptyMessage="No delay rollups."
          rowKey={(r, i) => String(r.incident_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk claims queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk claims."
          rowKey={(r, i) => `${r.employee_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
