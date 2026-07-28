import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  fefo_status: string;
  items: number;
  total_qty: number;
  value_at_risk_rupees: number;
  pct: number;
};
type TypeRow = {
  consumable_type: string;
  total_items: number;
  fresh: number;
  use_soon: number;
  expiring: number;
  expired: number;
  quarantined: number;
  value_at_risk_rupees: number;
  expired_pct: number;
};
type MatrixRow = {
  consumable_type: string;
  fefo_status: string;
  items: number;
  total_qty: number;
  avg_shelf_life_used_pct: number;
  value_at_risk_rupees: number;
};
type TrendRow = {
  expiry_month: string;
  items: number;
  expiring: number;
  expired: number;
  quarantined: number;
  value_at_risk_rupees: number;
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
  location_name: string;
  items: number;
  expiring: number;
  expired: number;
  quarantined: number;
  value_at_risk_rupees: number;
  avg_shelf_life_used_pct: number;
};
type RiskRow = {
  engineer_name: string;
  location_name: string;
  consumable_name: string;
  batch_lot: string;
  consumable_type: string;
  expiry_date: string;
  days_to_expiry: number;
  fefo_status: string;
  action: string | null;
  value_at_risk_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    typeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3520_fefo_status_rollup'),
    supabase.rpc('founder_r3520_consumable_type_scorecard'),
    supabase.rpc('founder_r3520_type_status_matrix'),
    supabase.rpc('founder_r3520_monthly_expiry_trend'),
    supabase.rpc('founder_r3520_capa_status_board'),
    supabase.rpc('founder_r3520_root_cause_pareto'),
    supabase.rpc('founder_r3520_value_at_risk_digest'),
    supabase.rpc('founder_r3520_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'fefo_status', header: 'FEFO Status' },
    { key: 'items', header: 'Items' },
    { key: 'total_qty', header: 'Total Qty' },
    { key: 'value_at_risk_rupees', header: 'Value at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'consumable_type', header: 'Consumable Type' },
    { key: 'total_items', header: 'Items' },
    { key: 'fresh', header: 'Fresh' },
    { key: 'use_soon', header: 'Use Soon' },
    { key: 'expiring', header: 'Expiring' },
    { key: 'expired', header: 'Expired' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'value_at_risk_rupees', header: 'Value at Risk (INR)' },
    { key: 'expired_pct', header: 'Expired %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'consumable_type', header: 'Consumable Type' },
    { key: 'fefo_status', header: 'FEFO Status' },
    { key: 'items', header: 'Items' },
    { key: 'total_qty', header: 'Total Qty' },
    { key: 'avg_shelf_life_used_pct', header: 'Avg Shelf-Life Used %' },
    { key: 'value_at_risk_rupees', header: 'Value at Risk (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'expiry_month', header: 'Expiry Month' },
    { key: 'items', header: 'Items' },
    { key: 'expiring', header: 'Expiring' },
    { key: 'expired', header: 'Expired' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'value_at_risk_rupees', header: 'Value at Risk (INR)' },
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
    { key: 'location_name', header: 'Location' },
    { key: 'items', header: 'Items' },
    { key: 'expiring', header: 'Expiring' },
    { key: 'expired', header: 'Expired' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'value_at_risk_rupees', header: 'Value at Risk (INR)' },
    { key: 'avg_shelf_life_used_pct', header: 'Avg Shelf-Life Used %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'location_name', header: 'Location' },
    { key: 'consumable_name', header: 'Consumable' },
    { key: 'batch_lot', header: 'Batch/Lot' },
    { key: 'consumable_type', header: 'Type' },
    { key: 'expiry_date', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'fefo_status', header: 'FEFO Status' },
    { key: 'action', header: 'Action' },
    { key: 'value_at_risk_rupees', header: 'Value at Risk (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Consumable-Expiry / FEFO Shelf-Life Rotation Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field &amp; van consumable expiry log with first-expiry-first-out (FEFO) rotation and
        shelf-life tracking — consumable type (reagents, filters, electrodes, batteries, calibration
        gas, test strips, lubricants) &times; location &times; batch/lot &times; qty-on-hand &times;
        expiry date &times; days-to-expiry &times; shelf-life used &times; FEFO status &times;
        rotation action &times; value-at-risk &amp; CAPA closure. Founder-gated view: FEFO status
        distribution, consumable-type scorecards, root-cause pareto, and value-at-risk digest across
        stores &amp; service vans.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. FEFO status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No consumable items logged yet."
          rowKey={(r, i) => String(r.fefo_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Consumable-type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No consumable-type rollups."
          rowKey={(r, i) => String(r.consumable_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Consumable type &times; FEFO status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No items by consumable type."
          rowKey={(r, i) => `${r.consumable_type}-${r.fefo_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly expiry trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.expiry_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Value-at-risk digest by location</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No value-at-risk rollups."
          rowKey={(r, i) => String(r.location_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk expiry queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk items."
          rowKey={(r, i) => `${r.batch_lot}-${r.expiry_date}-${i}`}
        />
      </section>
    </main>
  );
}
