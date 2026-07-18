import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { stock_status: string; lines: number; pct: number };
type HospRow = {
  base_hospital_name: string;
  total_lines: number;
  in_stock: number;
  low_stock: number;
  stockouts: number;
  critical_lines: number;
  avg_consumption: number;
  health_pct: number;
};
type CatRow = {
  part_category: string;
  criticality: string;
  lines: number;
  stockouts: number;
  avg_on_hand: number;
};
type TrendRow = {
  last_replenished_date: string;
  replenished: number;
  stockouts: number;
  low_stock: number;
  avg_on_hand: number;
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
type PriorityRow = {
  engineer_name: string;
  base_hospital_name: string;
  van_registration: string;
  part_name: string;
  part_category: string;
  on_hand_qty: number;
  min_qty: number;
  criticality: string;
  stock_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    catRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    priorityRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3148_stock_status_rollup'),
    supabase.rpc('founder_r3148_hospital_scorecard'),
    supabase.rpc('founder_r3148_category_matrix'),
    supabase.rpc('founder_r3148_replenishment_trend'),
    supabase.rpc('founder_r3148_capa_status_board'),
    supabase.rpc('founder_r3148_root_cause_pareto'),
    supabase.rpc('founder_r3148_regulatory_impact_digest'),
    supabase.rpc('founder_r3148_priority_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const priorityRows: PriorityRow[] = (priorityRes.data as PriorityRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'stock_status', header: 'Stock Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'base_hospital_name', header: 'Base Hospital' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'in_stock', header: 'In Stock' },
    { key: 'low_stock', header: 'Low Stock' },
    { key: 'stockouts', header: 'Stockouts' },
    { key: 'critical_lines', header: 'Critical' },
    { key: 'avg_consumption', header: 'Avg Use/Wk' },
    { key: 'health_pct', header: 'Health %' },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'part_category', header: 'Part Category' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'lines', header: 'Lines' },
    { key: 'stockouts', header: 'Stockouts' },
    { key: 'avg_on_hand', header: 'Avg On-Hand' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'last_replenished_date', header: 'Replenished On' },
    { key: 'replenished', header: 'Lines' },
    { key: 'stockouts', header: 'Stockouts' },
    { key: 'low_stock', header: 'Low Stock' },
    { key: 'avg_on_hand', header: 'Avg On-Hand' },
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

  const priorityCols: Column<PriorityRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'base_hospital_name', header: 'Base Hospital' },
    { key: 'van_registration', header: 'Van' },
    { key: 'part_name', header: 'Part' },
    { key: 'part_category', header: 'Category' },
    { key: 'on_hand_qty', header: 'On-Hand' },
    { key: 'min_qty', header: 'Min' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'stock_status', header: 'Status' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Field-Service Van Stock &amp; Consumables Replenishment Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-engineer van boot-stock lines — engineer &times; part category &times; on-hand vs
        min/reorder &times; stockout flag &times; consumption rate &amp; CAPA closure. Founder-gated
        view: stock-status mix, base-hospital scorecards, category matrix, root-cause pareto, and
        regulatory-impact digest across SLA &amp; patient-safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Stock status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No van-stock lines logged yet."
          rowKey={(r, i) => String(r.stock_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Base-hospital stock scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.base_hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Part category &times; criticality matrix</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No lines by category."
          rowKey={(r, i) => `${r.part_category}-${r.criticality}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Replenishment daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.last_replenished_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Priority replenishment queue</h2>
        <DataTable
          rows={priorityRows}
          columns={priorityCols}
          emptyMessage="No priority lines."
          rowKey={(r, i) => `${r.van_registration}-${r.part_name}-${i}`}
        />
      </section>
    </main>
  );
}
