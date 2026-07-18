import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { dispatch_verdict: string; checks: number; pct: number };
type HospRow = {
  destination_hospital_name: string;
  total_checks: number;
  cleared: number;
  conditional: number;
  hold_blocked: number;
  stood_down: number;
  avg_readiness_score: number;
  clearance_pct: number;
};
type CategoryRow = {
  kit_category: string;
  checks: number;
  cleared: number;
  avg_readiness_score: number;
  avg_expected_items: number;
  avg_present_items: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  cleared: number;
  conditional: number;
  hold_blocked: number;
  avg_readiness_score: number;
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
  destination_hospital_name: string;
  engineer_name: string;
  dispatch_ref: string;
  kit_category: string;
  check_date: string;
  dispatch_verdict: string;
  calibrated_tool_status: string;
  ppe_status: string;
  spare_stock_status: string;
  fuel_vehicle_status: string;
  readiness_score: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    categoryRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3168_dispatch_verdict_rollup'),
    supabase.rpc('founder_r3168_hospital_scorecard'),
    supabase.rpc('founder_r3168_kit_category_matrix'),
    supabase.rpc('founder_r3168_readiness_daily_trend'),
    supabase.rpc('founder_r3168_capa_status_board'),
    supabase.rpc('founder_r3168_root_cause_pareto'),
    supabase.rpc('founder_r3168_regulatory_impact_digest'),
    supabase.rpc('founder_r3168_priority_dispatch_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'dispatch_verdict', header: 'Dispatch Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'destination_hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'hold_blocked', header: 'Hold / Blocked' },
    { key: 'stood_down', header: 'Stood Down' },
    { key: 'avg_readiness_score', header: 'Avg Readiness' },
    { key: 'clearance_pct', header: 'Clearance %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'kit_category', header: 'Kit Category' },
    { key: 'checks', header: 'Checks' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'avg_readiness_score', header: 'Avg Readiness' },
    { key: 'avg_expected_items', header: 'Avg Expected' },
    { key: 'avg_present_items', header: 'Avg Present' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'hold_blocked', header: 'Hold / Blocked' },
    { key: 'avg_readiness_score', header: 'Avg Readiness' },
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
    { key: 'destination_hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'dispatch_ref', header: 'Ref' },
    { key: 'kit_category', header: 'Kit' },
    { key: 'check_date', header: 'Date' },
    { key: 'dispatch_verdict', header: 'Verdict' },
    { key: 'calibrated_tool_status', header: 'Cal Tools' },
    { key: 'ppe_status', header: 'PPE' },
    { key: 'spare_stock_status', header: 'Spares' },
    { key: 'fuel_vehicle_status', header: 'Fuel / Van' },
    { key: 'readiness_score', header: 'Readiness' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Tool-Kit Completeness &amp; Van-Readiness Pre-Dispatch Check
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Pre-dispatch readiness log — engineer &times; kit category &times; items expected/present &times;
        calibrated-tool validity &times; PPE completeness &times; spare stock &times; fuel/vehicle status &times;
        readiness score &amp; dispatch verdict, with CAPA closure. Founder-gated view: verdict rollup,
        hospital scorecards, kit-category matrix, root-cause pareto, and regulatory-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Dispatch verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No pre-dispatch checks logged yet."
          rowKey={(r, i) => String(r.dispatch_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital readiness scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.destination_hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Kit category readiness matrix</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No checks by kit category."
          rowKey={(r, i) => `${r.kit_category}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Readiness daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Priority dispatch queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk dispatches."
          rowKey={(r, i) => `${r.dispatch_ref}-${i}`}
        />
      </section>
    </main>
  );
}
