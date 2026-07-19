import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { replenishment_verdict: string; lines: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_lines: number;
  healthy: number;
  reorder_now: number;
  stockout_risk: number;
  stocked_out: number;
  expiry_action: number;
  auto_reorder_on: number;
  healthy_pct: number;
};
type MatrixRow = {
  consumable_type: string;
  linked_equipment: string;
  lines: number;
  at_risk: number;
  avg_days_of_cover: number | null;
  total_stockout_events: number;
};
type TrendRow = {
  check_date: string;
  lines: number;
  reorder_now: number;
  stockout_risk: number;
  stocked_out: number;
  expiry_action: number;
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
type ImpactRow = {
  clinical_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  tracking_ref: string;
  consumable_type: string;
  linked_equipment: string;
  check_date: string;
  days_of_cover: number | null;
  on_hand_qty: number;
  replenishment_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3376_replenishment_verdict_rollup'),
    supabase.rpc('founder_r3376_hospital_scorecard'),
    supabase.rpc('founder_r3376_consumable_equipment_matrix'),
    supabase.rpc('founder_r3376_daily_check_trend'),
    supabase.rpc('founder_r3376_capa_status_board'),
    supabase.rpc('founder_r3376_root_cause_pareto'),
    supabase.rpc('founder_r3376_clinical_impact_digest'),
    supabase.rpc('founder_r3376_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'replenishment_verdict', header: 'Verdict' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'reorder_now', header: 'Reorder Now' },
    { key: 'stockout_risk', header: 'Stockout Risk' },
    { key: 'stocked_out', header: 'Stocked Out' },
    { key: 'expiry_action', header: 'Expiry Action' },
    { key: 'auto_reorder_on', header: 'Auto-Reorder On' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'consumable_type', header: 'Consumable' },
    { key: 'linked_equipment', header: 'Equipment' },
    { key: 'lines', header: 'Lines' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'avg_days_of_cover', header: 'Avg Days Cover' },
    { key: 'total_stockout_events', header: 'Stockout Events (90d)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'lines', header: 'Lines' },
    { key: 'reorder_now', header: 'Reorder Now' },
    { key: 'stockout_risk', header: 'Stockout Risk' },
    { key: 'stocked_out', header: 'Stocked Out' },
    { key: 'expiry_action', header: 'Expiry Action' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'clinical_impact', header: 'Clinical Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'tracking_ref', header: 'Ref' },
    { key: 'consumable_type', header: 'Consumable' },
    { key: 'linked_equipment', header: 'Equipment' },
    { key: 'check_date', header: 'Date' },
    { key: 'days_of_cover', header: 'Days Cover' },
    { key: 'on_hand_qty', header: 'On Hand' },
    { key: 'replenishment_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer &amp; Customer-Site Consumables Replenishment / Stockout-Prevention Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-ops replenishment log — consumable type &times; linked equipment &times; days-of-cover
        &times; reorder point &times; lead time &times; expiry-risk qty &times; auto-reorder &times;
        stockout events &amp; CAPA closure. Equipment-specific consumables (electrodes, strips,
        reagents, filters, printer paper, cuffs) run out and halt clinical use; engineers must
        proactively replenish. Founder-gated view: verdict rollup, hospital scorecards,
        root-cause pareto, and clinical / cost-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Replenishment verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No replenishment lines logged yet."
          rowKey={(r, i) => String(r.replenishment_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital replenishment scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Consumable &times; equipment matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by consumable."
          rowKey={(r, i) => `${r.consumable_type}-${r.linked_equipment}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily check trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Clinical &amp; cost-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.clinical_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk replenishment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.tracking_ref}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
