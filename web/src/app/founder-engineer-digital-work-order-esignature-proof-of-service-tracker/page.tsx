import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { integrity_verdict: string; work_orders: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_orders: number;
  signed_complete: number;
  unsigned_risk: number;
  rejected: number;
  esign_missing: number;
  gps_missing: number;
  sync_pending: number;
  defensible_pct: number;
};
type MatrixRow = {
  service_type: string;
  work_order_status: string;
  work_orders: number;
  defensible: number;
  avg_photos: number | null;
  avg_sync_delay_hours: number | null;
};
type TrendRow = {
  completed_date: string;
  work_orders: number;
  signed: number;
  unsigned: number;
  esign_missing: number;
  sync_pending: number;
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
type BillingRow = {
  billing_risk: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  hospital_name: string;
  work_order_code: string;
  completed_date: string;
  service_type: string;
  work_order_status: string;
  integrity_verdict: string;
  before_after_photos_count: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    billingRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3380_integrity_verdict_rollup'),
    supabase.rpc('founder_r3380_engineer_scorecard'),
    supabase.rpc('founder_r3380_service_status_matrix'),
    supabase.rpc('founder_r3380_daily_completion_trend'),
    supabase.rpc('founder_r3380_capa_status_board'),
    supabase.rpc('founder_r3380_root_cause_pareto'),
    supabase.rpc('founder_r3380_billing_risk_digest'),
    supabase.rpc('founder_r3380_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const billingRows: BillingRow[] = (billingRes.data as BillingRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'integrity_verdict', header: 'Integrity Verdict' },
    { key: 'work_orders', header: 'Work Orders' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_orders', header: 'Orders' },
    { key: 'signed_complete', header: 'Signed Complete' },
    { key: 'unsigned_risk', header: 'Unsigned / Evidence Risk' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'esign_missing', header: 'e-Sign Missing' },
    { key: 'gps_missing', header: 'GPS Missing' },
    { key: 'sync_pending', header: 'Sync Pending' },
    { key: 'defensible_pct', header: 'Defensible %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_type', header: 'Service Type' },
    { key: 'work_order_status', header: 'WO Status' },
    { key: 'work_orders', header: 'Work Orders' },
    { key: 'defensible', header: 'Defensible' },
    { key: 'avg_photos', header: 'Avg Photos' },
    { key: 'avg_sync_delay_hours', header: 'Avg Sync Delay (h)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'completed_date', header: 'Date' },
    { key: 'work_orders', header: 'Work Orders' },
    { key: 'signed', header: 'Signed' },
    { key: 'unsigned', header: 'Unsigned' },
    { key: 'esign_missing', header: 'e-Sign Missing' },
    { key: 'sync_pending', header: 'Sync Pending' },
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

  const billingCols: Column<BillingRow>[] = [
    { key: 'billing_risk', header: 'Billing / Dispute Risk' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'work_order_code', header: 'WO Code' },
    { key: 'completed_date', header: 'Date' },
    { key: 'service_type', header: 'Service' },
    { key: 'work_order_status', header: 'Status' },
    { key: 'integrity_verdict', header: 'Verdict' },
    { key: 'before_after_photos_count', header: 'Photos' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Digital Work-Order e-Signature &amp; Proof-of-Service Completion-Integrity Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-ops proof-of-service log — service type &times; work-order status &times; customer
        e-signature &times; signatory name/designation &times; GPS &amp; timestamp &times;
        before/after photos &times; parts/labour &amp; checklist &times; offline-sync delay &times;
        dispute defensibility &amp; CAPA closure. Every service visit needs a complete, signed digital
        work order to defend billing and disputes; unsigned or evidence-light closeouts leak revenue.
        Founder-gated view: integrity verdicts, engineer scorecards, root-cause pareto, and
        billing / dispute-risk digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Integrity verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No work orders logged yet."
          rowKey={(r, i) => String(r.integrity_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer proof-of-service scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Service type &times; work-order status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No work orders by service type."
          rowKey={(r, i) => `${r.service_type}-${r.work_order_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily completion trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.completed_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Billing &amp; dispute-risk digest</h2>
        <DataTable
          rows={billingRows}
          columns={billingCols}
          emptyMessage="No billing-risk rollups."
          rowKey={(r, i) => String(r.billing_risk ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk work-order queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk work orders."
          rowKey={(r, i) => `${r.work_order_code}-${r.completed_date}-${i}`}
        />
      </section>
    </main>
  );
}
