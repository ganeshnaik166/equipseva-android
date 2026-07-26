import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChangeTypeRow = {
  change_type: string;
  changes: number;
  affected_units: number;
  pct: number;
};
type ModelRow = {
  device_model: string;
  total_changes: number;
  supersessions: number;
  recalls: number;
  not_compatible: number;
  unnotified: number;
  total_affected_units: number;
  total_stock_on_hand: number;
};
type MatrixRow = {
  change_type: string;
  compatibility: string;
  changes: number;
  affected_units: number;
  stock_on_hand: number;
};
type TrendRow = {
  change_month: string;
  changes: number;
  supersessions: number;
  recalls: number;
  not_compatible: number;
  affected_units: number;
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
type DigestRow = {
  change_type: string;
  changes: number;
  total_affected_units: number;
  total_stock_on_hand: number;
  avg_affected_units: number;
};
type RiskRow = {
  engineer_name: string;
  change_ref: string;
  device_model: string;
  part_name: string;
  old_part_no: string;
  new_part_no: string;
  change_type: string;
  compatibility: string;
  affected_units: number;
  stock_on_hand: number;
  disposition: string;
  rollout_status: string;
  effective_date: string;
  notified: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    changeTypeRes,
    modelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3456_change_type_rollup'),
    supabase.rpc('founder_r3456_device_model_scorecard'),
    supabase.rpc('founder_r3456_change_type_compat_matrix'),
    supabase.rpc('founder_r3456_monthly_change_trend'),
    supabase.rpc('founder_r3456_capa_status_board'),
    supabase.rpc('founder_r3456_root_cause_pareto'),
    supabase.rpc('founder_r3456_affected_units_digest'),
    supabase.rpc('founder_r3456_high_risk_queue'),
  ]);

  const changeTypeRows: ChangeTypeRow[] = (changeTypeRes.data as ChangeTypeRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const changeTypeCols: Column<ChangeTypeRow>[] = [
    { key: 'change_type', header: 'Change Type' },
    { key: 'changes', header: 'Changes' },
    { key: 'affected_units', header: 'Affected Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'device_model', header: 'Device Model' },
    { key: 'total_changes', header: 'Changes' },
    { key: 'supersessions', header: 'Supersessions' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'not_compatible', header: 'Not Compatible' },
    { key: 'unnotified', header: 'Unnotified' },
    { key: 'total_affected_units', header: 'Affected Units' },
    { key: 'total_stock_on_hand', header: 'Stock On Hand' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'change_type', header: 'Change Type' },
    { key: 'compatibility', header: 'Compatibility' },
    { key: 'changes', header: 'Changes' },
    { key: 'affected_units', header: 'Affected Units' },
    { key: 'stock_on_hand', header: 'Stock On Hand' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'change_month', header: 'Month' },
    { key: 'changes', header: 'Changes' },
    { key: 'supersessions', header: 'Supersessions' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'not_compatible', header: 'Not Compatible' },
    { key: 'affected_units', header: 'Affected Units' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'change_type', header: 'Change Type' },
    { key: 'changes', header: 'Changes' },
    { key: 'total_affected_units', header: 'Affected Units' },
    { key: 'total_stock_on_hand', header: 'Stock On Hand' },
    { key: 'avg_affected_units', header: 'Avg Affected Units' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'change_ref', header: 'Change Ref' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'part_name', header: 'Part' },
    { key: 'old_part_no', header: 'Old P/N' },
    { key: 'new_part_no', header: 'New P/N' },
    { key: 'change_type', header: 'Type' },
    { key: 'compatibility', header: 'Compatibility' },
    { key: 'affected_units', header: 'Affected' },
    { key: 'stock_on_hand', header: 'Stock' },
    { key: 'disposition', header: 'Disposition' },
    { key: 'rollout_status', header: 'Status' },
    { key: 'effective_date', header: 'Effective' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Part-Number Supersession / BOM-Revision Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        OEM part-number supersession &amp; BOM-revision change tracking — change type (supersession,
        BOM revision, obsolescence, substitution, recall replacement) &times; device model &times;
        old &rarr; new part number &times; compatibility (drop-in, requires rework, requires firmware,
        not compatible) &times; affected units &times; stock-on-hand disposition &times; rollout status
        &amp; CAPA closure. Founder-gated view: change-type mix, device-model scorecards, root-cause
        pareto, affected-units impact, and a high-risk queue for not-compatible, recall, and
        large-stock exposures.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Change-type distribution</h2>
        <DataTable
          rows={changeTypeRows}
          columns={changeTypeCols}
          emptyMessage="No part changes logged yet."
          rowKey={(r, i) => String(r.change_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-model scorecard</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No device-model rollups."
          rowKey={(r, i) => String(r.device_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Change-type &times; compatibility matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No changes by type."
          rowKey={(r, i) => `${r.change_type}-${r.compatibility}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly change trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.change_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Affected-units impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact data."
          rowKey={(r, i) => String(r.change_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk change queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk changes."
          rowKey={(r, i) => `${r.change_ref}-${i}`}
        />
      </section>
    </main>
  );
}
