import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  charge_status: string;
  shipments: number;
  total_charges_rupees: number;
  pct: number;
};
type PortRow = {
  port_name: string;
  shipments: number;
  clean_clearances: number;
  heavy_or_disputed: number;
  avg_dwell_days: number;
  total_chargeable_days: number;
  total_charges_rupees: number;
  clean_pct: number;
};
type MatrixRow = {
  hold_type: string;
  charge_status: string;
  shipments: number;
  total_charges_rupees: number;
  avg_dwell_days: number;
};
type TrendRow = {
  period_month: string;
  shipments: number;
  total_demurrage_rupees: number;
  total_detention_rupees: number;
  total_storage_rupees: number;
  total_charges_rupees: number;
  avg_dwell_days: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  total_impact_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DwellRow = {
  dwell_band: string;
  shipments: number;
  avg_chargeable_days: number;
  total_charges_rupees: number;
  share_pct: number;
};
type RiskRow = {
  shipment_ref: string;
  port_name: string;
  period_month: string;
  hold_type: string;
  charge_status: string;
  dwell_days: number | null;
  chargeable_days: number | null;
  total_charges_rupees: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    portRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    dwellRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3663_charge_status_rollup'),
    supabase.rpc('founder_r3663_port_scorecard'),
    supabase.rpc('founder_r3663_hold_type_status_matrix'),
    supabase.rpc('founder_r3663_monthly_charges_trend'),
    supabase.rpc('founder_r3663_capa_status_board'),
    supabase.rpc('founder_r3663_root_cause_pareto'),
    supabase.rpc('founder_r3663_dwell_impact_digest'),
    supabase.rpc('founder_r3663_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const portRows: PortRow[] = (portRes.data as PortRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const dwellRows: DwellRow[] = (dwellRes.data as DwellRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'charge_status', header: 'Charge Status' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'total_charges_rupees', header: 'Total Charges (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const portCols: Column<PortRow>[] = [
    { key: 'port_name', header: 'Port' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'clean_clearances', header: 'No-Charge' },
    { key: 'heavy_or_disputed', header: 'Heavy / Disputed' },
    { key: 'avg_dwell_days', header: 'Avg Dwell Days' },
    { key: 'total_chargeable_days', header: 'Chargeable Days' },
    { key: 'total_charges_rupees', header: 'Total Charges (INR)' },
    { key: 'clean_pct', header: 'Clean %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'hold_type', header: 'Hold Type' },
    { key: 'charge_status', header: 'Charge Status' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'total_charges_rupees', header: 'Total Charges (INR)' },
    { key: 'avg_dwell_days', header: 'Avg Dwell Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'total_demurrage_rupees', header: 'Demurrage (INR)' },
    { key: 'total_detention_rupees', header: 'Detention (INR)' },
    { key: 'total_storage_rupees', header: 'Storage (INR)' },
    { key: 'total_charges_rupees', header: 'Total (INR)' },
    { key: 'avg_dwell_days', header: 'Avg Dwell Days' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'total_impact_rupees', header: 'Impact (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const dwellCols: Column<DwellRow>[] = [
    { key: 'dwell_band', header: 'Dwell Band' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'avg_chargeable_days', header: 'Avg Chargeable Days' },
    { key: 'total_charges_rupees', header: 'Total Charges (INR)' },
    { key: 'share_pct', header: 'Charge Share %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'shipment_ref', header: 'Shipment' },
    { key: 'port_name', header: 'Port' },
    { key: 'period_month', header: 'Month' },
    { key: 'hold_type', header: 'Hold Type' },
    { key: 'charge_status', header: 'Status' },
    { key: 'dwell_days', header: 'Dwell' },
    { key: 'chargeable_days', header: 'Chargeable' },
    { key: 'total_charges_rupees', header: 'Total (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Demurrage / Detention / Port-Storage Charges Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Import logistics charge tracker — per-shipment dwell days &times; free days &times;
        chargeable days &times; demurrage &times; detention &times; port-storage rupees across
        Nhava Sheva, Chennai, Mundra, Kolkata, Cochin &amp; the Delhi / Bengaluru / Hyderabad air
        cargo terminals. Hold types span documentation, duty payment, customs query, CDSCO NOC
        &amp; space congestion. Founder-gated view: charge-status rollups, port scorecards,
        hold-type &times; status matrix, monthly trend, dwell-band digest, root-cause pareto
        &amp; the heavy / disputed queue with CAPA closure.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Charge status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No shipment charges logged yet."
          rowKey={(r, i) => String(r.charge_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Port charges scorecard</h2>
        <DataTable
          rows={portRows}
          columns={portCols}
          emptyMessage="No port rollups."
          rowKey={(r, i) => String(r.port_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Hold type &times; charge status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No charges by hold type."
          rowKey={(r, i) => `${r.hold_type}-${r.charge_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly charges trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Dwell-band impact digest</h2>
        <DataTable
          rows={dwellRows}
          columns={dwellCols}
          emptyMessage="No dwell-band rollups."
          rowKey={(r, i) => String(r.dwell_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk charges queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No heavy or disputed charges."
          rowKey={(r, i) => `${r.shipment_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
