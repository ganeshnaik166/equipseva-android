import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  spend_status: string;
  records: number;
  total_spend_rupees: number;
  pct: number;
};
type CarrierRow = {
  carrier: string;
  plan_groups: number;
  active_connections: number;
  idle_connections: number;
  total_spend_rupees: number;
  overage_rupees: number;
  roaming_rupees: number;
  disputes: number;
  avg_plan_optimal_pct: number;
};
type MatrixRow = {
  connection_type: string;
  spend_status: string;
  records: number;
  total_spend_rupees: number;
  idle_connections: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_spend_rupees: number;
  overage_rupees: number;
  roaming_rupees: number;
  avg_plan_optimal_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_waste_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_waste_rupees: number;
  pct: number;
};
type DigestRow = {
  connection_type: string;
  records: number;
  overage_rupees: number;
  roaming_rupees: number;
  idle_connections: number;
  idle_pct: number;
};
type RiskRow = {
  plan_group: string;
  carrier: string;
  period_month: string;
  connection_type: string;
  spend_status: string;
  trend_dir: string;
  connections_idle: number;
  data_overage_charges_rupees: number;
  disputes_open: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    carrierRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3676_spend_status_rollup'),
    supabase.rpc('founder_r3676_carrier_scorecard'),
    supabase.rpc('founder_r3676_conn_type_status_matrix'),
    supabase.rpc('founder_r3676_monthly_spend_trend'),
    supabase.rpc('founder_r3676_capa_status_board'),
    supabase.rpc('founder_r3676_root_cause_pareto'),
    supabase.rpc('founder_r3676_overage_idle_digest'),
    supabase.rpc('founder_r3676_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const carrierRows: CarrierRow[] = (carrierRes.data as CarrierRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const carrierCols: Column<CarrierRow>[] = [
    { key: 'carrier', header: 'Carrier' },
    { key: 'plan_groups', header: 'Plan Groups' },
    { key: 'active_connections', header: 'Active' },
    { key: 'idle_connections', header: 'Idle' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'overage_rupees', header: 'Overage (INR)' },
    { key: 'roaming_rupees', header: 'Roaming (INR)' },
    { key: 'disputes', header: 'Disputes' },
    { key: 'avg_plan_optimal_pct', header: 'Avg Plan-Optimal %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'connection_type', header: 'Connection Type' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'idle_connections', header: 'Idle' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'overage_rupees', header: 'Overage (INR)' },
    { key: 'roaming_rupees', header: 'Roaming (INR)' },
    { key: 'avg_plan_optimal_pct', header: 'Avg Plan-Optimal %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_waste_rupees', header: 'Avg Waste (INR/mo)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_waste_rupees', header: 'Total Waste (INR/mo)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'connection_type', header: 'Connection Type' },
    { key: 'records', header: 'Records' },
    { key: 'overage_rupees', header: 'Overage (INR)' },
    { key: 'roaming_rupees', header: 'Roaming (INR)' },
    { key: 'idle_connections', header: 'Idle Connections' },
    { key: 'idle_pct', header: 'Idle %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'plan_group', header: 'Plan Group' },
    { key: 'carrier', header: 'Carrier' },
    { key: 'period_month', header: 'Month' },
    { key: 'connection_type', header: 'Type' },
    { key: 'spend_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'connections_idle', header: 'Idle' },
    { key: 'data_overage_charges_rupees', header: 'Overage (INR)' },
    { key: 'disputes_open', header: 'Disputes' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Telecom / Mobile / Data Spend &amp; Connection Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Telecom, mobile and data-card spend board — plan group &times; carrier (Airtel, Jio, Vi,
        BSNL) &times; connection type (field engineer SIM, office mobile, data card, IoT SIM,
        broadband) &times; active/idle connections &times; monthly spend &times; overage &amp;
        roaming charges &times; plan-optimal % &times; open disputes &amp; CAPA closure.
        Founder-gated view: spend-status rollup, carrier scorecards, monthly spend trend,
        root-cause pareto, and the uncontrolled / idle-connection high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Spend status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No telecom spend records logged yet."
          rowKey={(r, i) => String(r.spend_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Carrier scorecard</h2>
        <DataTable
          rows={carrierRows}
          columns={carrierCols}
          emptyMessage="No carrier rollups."
          rowKey={(r, i) => String(r.carrier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Connection type &times; spend status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by connection type."
          rowKey={(r, i) => `${r.connection_type}-${r.spend_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overage / idle waste digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No overage or idle rollups."
          rowKey={(r, i) => String(r.connection_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk plan-group queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk plan groups."
          rowKey={(r, i) => `${r.plan_group}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
