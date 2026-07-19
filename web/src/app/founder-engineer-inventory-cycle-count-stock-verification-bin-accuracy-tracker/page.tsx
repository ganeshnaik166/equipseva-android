import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { count_verdict: string; counts: number; pct: number };
type StoreRow = {
  store_location: string;
  total_counts: number;
  accurate: number;
  minor_variance: number;
  major_variance: number;
  investigate: number;
  total_variance_units: number;
  total_variance_value_rupees: number;
  avg_bin_accuracy_pct: number;
  accurate_pct: number;
};
type MatrixRow = {
  store_location: string;
  equipment_family: string;
  counts: number;
  accurate: number;
  avg_variance_value_rupees: number;
  avg_bin_accuracy_pct: number;
};
type TrendRow = {
  count_date: string;
  counts: number;
  accurate: number;
  major_variance: number;
  total_variance_value_rupees: number;
  avg_bin_accuracy_pct: number;
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
type FinRow = {
  financial_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  store_location: string;
  count_code: string;
  equipment_family: string;
  count_date: string;
  count_verdict: string;
  variance_units: number;
  variance_value_rupees: number;
  bin_location_accuracy_pct: number;
  root_cause: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    storeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    finRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3352_count_verdict_rollup'),
    supabase.rpc('founder_r3352_store_scorecard'),
    supabase.rpc('founder_r3352_location_family_matrix'),
    supabase.rpc('founder_r3352_daily_count_trend'),
    supabase.rpc('founder_r3352_capa_status_board'),
    supabase.rpc('founder_r3352_root_cause_pareto'),
    supabase.rpc('founder_r3352_financial_impact_digest'),
    supabase.rpc('founder_r3352_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const storeRows: StoreRow[] = (storeRes.data as StoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const finRows: FinRow[] = (finRes.data as FinRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'count_verdict', header: 'Verdict' },
    { key: 'counts', header: 'Counts' },
    { key: 'pct', header: 'Share %' },
  ];

  const storeCols: Column<StoreRow>[] = [
    { key: 'store_location', header: 'Store / Van' },
    { key: 'total_counts', header: 'Counts' },
    { key: 'accurate', header: 'Accurate' },
    { key: 'minor_variance', header: 'Minor Var' },
    { key: 'major_variance', header: 'Major Var' },
    { key: 'investigate', header: 'Investigate / Reconcile' },
    { key: 'total_variance_units', header: 'Var Units' },
    { key: 'total_variance_value_rupees', header: 'Var Value (INR)' },
    { key: 'avg_bin_accuracy_pct', header: 'Avg Bin Acc %' },
    { key: 'accurate_pct', header: 'Accurate %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'store_location', header: 'Store / Van' },
    { key: 'equipment_family', header: 'Equipment Family' },
    { key: 'counts', header: 'Counts' },
    { key: 'accurate', header: 'Accurate' },
    { key: 'avg_variance_value_rupees', header: 'Avg Var Value (INR)' },
    { key: 'avg_bin_accuracy_pct', header: 'Avg Bin Acc %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'count_date', header: 'Date' },
    { key: 'counts', header: 'Counts' },
    { key: 'accurate', header: 'Accurate' },
    { key: 'major_variance', header: 'Major / Investigate' },
    { key: 'total_variance_value_rupees', header: 'Var Value (INR)' },
    { key: 'avg_bin_accuracy_pct', header: 'Avg Bin Acc %' },
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

  const finCols: Column<FinRow>[] = [
    { key: 'financial_impact', header: 'Financial Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'store_location', header: 'Store / Van' },
    { key: 'count_code', header: 'Count' },
    { key: 'equipment_family', header: 'Family' },
    { key: 'count_date', header: 'Date' },
    { key: 'count_verdict', header: 'Verdict' },
    { key: 'variance_units', header: 'Var Units' },
    { key: 'variance_value_rupees', header: 'Var Value (INR)' },
    { key: 'bin_location_accuracy_pct', header: 'Bin Acc %' },
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Inventory Cycle-Count, Stock-Verification &amp; Bin-Accuracy Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Store &amp; van-stock inventory ops — store location &times; count type &times; equipment
        family &times; system-vs-physical variance units &times; variance value &times; bin-location
        accuracy &times; root cause &amp; CAPA closure. Founder-gated view: count verdicts, store
        scorecards, root-cause pareto, and financial-impact digest across EquipSeva hubs &amp; pooled
        van stock.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Count verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cycle counts logged yet."
          rowKey={(r, i) => String(r.count_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Store-location scorecard</h2>
        <DataTable
          rows={storeRows}
          columns={storeCols}
          emptyMessage="No store rollups."
          rowKey={(r, i) => String(r.store_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Store &times; equipment-family matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No counts by store and family."
          rowKey={(r, i) => `${r.store_location}-${r.equipment_family}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily count trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.count_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial impact digest</h2>
        <DataTable
          rows={finRows}
          columns={finCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.financial_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk count queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk counts."
          rowKey={(r, i) => `${r.count_code}-${r.count_date}-${i}`}
        />
      </section>
    </main>
  );
}
