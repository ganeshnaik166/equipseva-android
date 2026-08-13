import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { program_status: string; trade_ins: number; pct: number };
type ModelRow = {
  equipment_model: string;
  total_trade_ins: number;
  profitable: number;
  credit_heavy: number;
  stuck_inventory: number;
  loss_making: number;
  attach_rate_pct: number;
  avg_net_margin_rupees: number;
};
type MatrixRow = {
  route_class: string;
  program_status: string;
  trade_ins: number;
  avg_net_margin_rupees: number;
  avg_days_to_disposition: number;
};
type TrendRow = {
  period_month: string;
  trade_ins: number;
  total_valuation_rupees: number;
  total_credit_issued_rupees: number;
  total_resale_recovery_rupees: number;
  total_net_margin_rupees: number;
  stuck_inventory: number;
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
type StuckRow = {
  route_class: string;
  units: number;
  avg_days_to_disposition: number;
  total_valuation_rupees: number;
  total_net_margin_rupees: number;
};
type RiskRow = {
  trade_in_ref: string;
  equipment_model: string;
  customer_name: string;
  period_month: string;
  program_status: string;
  route_class: string;
  days_to_disposition: number | null;
  net_program_margin_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    modelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    stuckRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3716_program_status_rollup'),
    supabase.rpc('founder_r3716_equipment_model_scorecard'),
    supabase.rpc('founder_r3716_route_program_matrix'),
    supabase.rpc('founder_r3716_monthly_margin_trend'),
    supabase.rpc('founder_r3716_capa_status_board'),
    supabase.rpc('founder_r3716_root_cause_pareto'),
    supabase.rpc('founder_r3716_stuck_inventory_digest'),
    supabase.rpc('founder_r3716_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const stuckRows: StuckRow[] = (stuckRes.data as StuckRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'program_status', header: 'Program Status' },
    { key: 'trade_ins', header: 'Trade-Ins' },
    { key: 'pct', header: 'Share %' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'equipment_model', header: 'Equipment Model' },
    { key: 'total_trade_ins', header: 'Trade-Ins' },
    { key: 'profitable', header: 'Profitable' },
    { key: 'credit_heavy', header: 'Credit Heavy' },
    { key: 'stuck_inventory', header: 'Stuck Inventory' },
    { key: 'loss_making', header: 'Loss Making' },
    { key: 'attach_rate_pct', header: 'Attach Rate %' },
    { key: 'avg_net_margin_rupees', header: 'Avg Net Margin (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'route_class', header: 'Route Class' },
    { key: 'program_status', header: 'Program Status' },
    { key: 'trade_ins', header: 'Trade-Ins' },
    { key: 'avg_net_margin_rupees', header: 'Avg Net Margin (INR)' },
    { key: 'avg_days_to_disposition', header: 'Avg Days to Disposition' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'trade_ins', header: 'Trade-Ins' },
    { key: 'total_valuation_rupees', header: 'Total Valuation (INR)' },
    { key: 'total_credit_issued_rupees', header: 'Total Credit Issued (INR)' },
    { key: 'total_resale_recovery_rupees', header: 'Total Resale Recovery (INR)' },
    { key: 'total_net_margin_rupees', header: 'Total Net Margin (INR)' },
    { key: 'stuck_inventory', header: 'Stuck Inventory' },
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

  const stuckCols: Column<StuckRow>[] = [
    { key: 'route_class', header: 'Route Class' },
    { key: 'units', header: 'Units' },
    { key: 'avg_days_to_disposition', header: 'Avg Days to Disposition' },
    { key: 'total_valuation_rupees', header: 'Total Valuation (INR)' },
    { key: 'total_net_margin_rupees', header: 'Total Net Margin (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'trade_in_ref', header: 'Trade-In Ref' },
    { key: 'equipment_model', header: 'Equipment Model' },
    { key: 'customer_name', header: 'Customer' },
    { key: 'period_month', header: 'Month' },
    { key: 'program_status', header: 'Program Status' },
    { key: 'route_class', header: 'Route Class' },
    { key: 'days_to_disposition', header: 'Days to Disposition' },
    { key: 'net_program_margin_rupees', header: 'Net Margin (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Equipment Trade-In / Buyback Program Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Equipment trade-in &amp; buyback program log — old-unit valuation &times; credit issued
        against new sales &times; new-sale attach &times; resale recovery &times; net program
        margin &times; days to disposition &times; disposition route (refurb resale, parts
        harvest, scrap, OEM return, pending disposition) &amp; CAPA closure. Founder-gated view:
        program-status distribution, equipment-model scorecards, route &times; status matrix,
        monthly margin trend, root-cause pareto, and a high-risk queue of loss-making &amp;
        stuck-inventory trade-ins.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Program-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No trade-ins logged yet."
          rowKey={(r, i) => String(r.program_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Equipment-model scorecard</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No equipment-model rollups."
          rowKey={(r, i) => String(r.equipment_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Route class &times; program status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No trade-ins by route class."
          rowKey={(r, i) => `${r.route_class}-${r.program_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly margin trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Stuck-inventory digest</h2>
        <DataTable
          rows={stuckRows}
          columns={stuckCols}
          emptyMessage="No stuck-inventory rollups."
          rowKey={(r, i) => String(r.route_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk trade-in queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk trade-ins."
          rowKey={(r, i) => `${r.trade_in_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
