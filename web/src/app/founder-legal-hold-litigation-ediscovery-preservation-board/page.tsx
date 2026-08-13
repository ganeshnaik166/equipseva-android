import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { hold_status: string; holds: number; pct: number };
type CustodianRow = {
  custodian_name: string;
  total_holds: number;
  active_compliant: number;
  active_gap: number;
  pending_acknowledgment: number;
  released: number;
  spoliation_risk_count: number;
  ack_pct: number | null;
  avg_days_active: number | null;
};
type MatrixRow = {
  matter_class: string;
  hold_status: string;
  holds: number;
  avg_days_active: number | null;
};
type TrendRow = {
  period_month: string;
  holds: number;
  acknowledged: number;
  preservation_confirmed: number;
  spoliation_risk_count: number;
  worsening_count: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  matter_class: string;
  holds: number;
  spoliation_risk_holds: number;
  unacknowledged_holds: number;
  unconfirmed_preservation_holds: number;
  outside_counsel_involved_holds: number;
};
type RiskRow = {
  matter_ref: string;
  custodian_name: string;
  matter_class: string;
  hold_status: string;
  period_month: string;
  days_active: number | null;
  data_sources_count: number | null;
  spoliation_risk: boolean;
  outside_counsel_involved: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    custodianRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3728_hold_status_rollup'),
    supabase.rpc('founder_r3728_custodian_scorecard'),
    supabase.rpc('founder_r3728_matter_class_status_matrix'),
    supabase.rpc('founder_r3728_monthly_hold_issuance_trend'),
    supabase.rpc('founder_r3728_capa_status_board'),
    supabase.rpc('founder_r3728_root_cause_pareto'),
    supabase.rpc('founder_r3728_spoliation_risk_digest'),
    supabase.rpc('founder_r3728_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const custodianRows: CustodianRow[] = (custodianRes.data as CustodianRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'hold_status', header: 'Hold Status' },
    { key: 'holds', header: 'Holds' },
    { key: 'pct', header: 'Share %' },
  ];

  const custodianCols: Column<CustodianRow>[] = [
    { key: 'custodian_name', header: 'Custodian' },
    { key: 'total_holds', header: 'Total Holds' },
    { key: 'active_compliant', header: 'Active Compliant' },
    { key: 'active_gap', header: 'Active Gap' },
    { key: 'pending_acknowledgment', header: 'Pending Ack' },
    { key: 'released', header: 'Released' },
    { key: 'spoliation_risk_count', header: 'Spoliation Risk' },
    { key: 'ack_pct', header: 'Ack %' },
    { key: 'avg_days_active', header: 'Avg Days Active' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'matter_class', header: 'Matter Class' },
    { key: 'hold_status', header: 'Hold Status' },
    { key: 'holds', header: 'Holds' },
    { key: 'avg_days_active', header: 'Avg Days Active' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'holds', header: 'Holds' },
    { key: 'acknowledged', header: 'Acknowledged' },
    { key: 'preservation_confirmed', header: 'Preservation Confirmed' },
    { key: 'spoliation_risk_count', header: 'Spoliation Risk' },
    { key: 'worsening_count', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'matter_class', header: 'Matter Class' },
    { key: 'holds', header: 'Holds' },
    { key: 'spoliation_risk_holds', header: 'Spoliation Risk' },
    { key: 'unacknowledged_holds', header: 'Unacknowledged' },
    { key: 'unconfirmed_preservation_holds', header: 'Unconfirmed Preservation' },
    { key: 'outside_counsel_involved_holds', header: 'Outside Counsel Involved' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'matter_ref', header: 'Matter Ref' },
    { key: 'custodian_name', header: 'Custodian' },
    { key: 'matter_class', header: 'Matter Class' },
    { key: 'hold_status', header: 'Hold Status' },
    { key: 'period_month', header: 'Month' },
    { key: 'days_active', header: 'Days Active' },
    { key: 'data_sources_count', header: 'Data Sources' },
    { key: 'spoliation_risk', header: 'Spoliation Risk' },
    { key: 'outside_counsel_involved', header: 'Outside Counsel' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Legal Hold / Litigation E-Discovery Preservation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Legal-hold notices and litigation e-discovery preservation obligations — matter &amp;
        custodian &times; period month &times; data sources under hold &times; custodian
        acknowledgment &amp; preservation confirmation &times; hold release/expiry tracking
        &times; spoliation risk &amp; outside-counsel involvement &amp; CAPA remediation.
        Founder-gated view: hold-status distribution, custodian scorecards, matter-class &times;
        status matrix, monthly issuance trend, root-cause pareto, a spoliation-risk digest, and a
        high-risk queue of active gaps &amp; spoliation-risk holds.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Hold-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No legal-hold rows logged yet."
          rowKey={(r, i) => String(r.hold_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Custodian scorecard</h2>
        <DataTable
          rows={custodianRows}
          columns={custodianCols}
          emptyMessage="No custodian rollups."
          rowKey={(r, i) => String(r.custodian_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Matter class &times; hold status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matters by class."
          rowKey={(r, i) => `${r.matter_class}-${r.hold_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly hold-issuance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Spoliation-risk digest by matter class</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No spoliation-risk rollups."
          rowKey={(r, i) => String(r.matter_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk hold queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk holds."
          rowKey={(r, i) => `${r.matter_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
