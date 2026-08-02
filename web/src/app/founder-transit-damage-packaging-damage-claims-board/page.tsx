import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  claim_status: string;
  incidents: number;
  total_damage_value_rupees: number;
  pct: number;
};
type CarrierRow = {
  carrier_name: string;
  total_incidents: number;
  claims_filed: number;
  recovered: number;
  rejected: number;
  total_damage_value_rupees: number;
  total_recovered_rupees: number;
  avg_recovery_pct: number | null;
  avg_days_to_settle: number | null;
};
type MatrixRow = {
  damage_category: string;
  claim_status: string;
  incidents: number;
  total_damage_value_rupees: number;
  avg_damage_pct: number;
};
type TrendRow = {
  period_month: string;
  incidents: number;
  total_shipment_value_rupees: number;
  total_damage_value_rupees: number;
  total_recovered_rupees: number;
  avg_damage_pct: number;
  worsening_lanes: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_recovery_at_risk_rupees: number | null;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recovery_at_risk_rupees: number;
  pct: number;
};
type DigestRow = {
  trend_dir: string;
  incidents: number;
  total_damage_value_rupees: number;
  total_claim_amount_rupees: number;
  total_recovered_rupees: number;
  overall_recovery_pct: number | null;
};
type RiskRow = {
  incident_ref: string;
  lane_name: string;
  carrier_name: string;
  period_month: string;
  damage_category: string;
  claim_status: string;
  damage_value_rupees: number;
  claim_amount_rupees: number | null;
  recovery_pct: number | null;
  trend_dir: string;
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
    supabase.rpc('founder_r3664_claim_status_rollup'),
    supabase.rpc('founder_r3664_carrier_scorecard'),
    supabase.rpc('founder_r3664_category_status_matrix'),
    supabase.rpc('founder_r3664_monthly_damage_trend'),
    supabase.rpc('founder_r3664_capa_status_board'),
    supabase.rpc('founder_r3664_root_cause_pareto'),
    supabase.rpc('founder_r3664_recovery_impact_digest'),
    supabase.rpc('founder_r3664_high_risk_queue'),
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
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'total_damage_value_rupees', header: 'Damage Value (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const carrierCols: Column<CarrierRow>[] = [
    { key: 'carrier_name', header: 'Carrier' },
    { key: 'total_incidents', header: 'Incidents' },
    { key: 'claims_filed', header: 'Claims Filed' },
    { key: 'recovered', header: 'Recovered' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'total_damage_value_rupees', header: 'Damage Value (INR)' },
    { key: 'total_recovered_rupees', header: 'Recovered (INR)' },
    { key: 'avg_recovery_pct', header: 'Avg Recovery %' },
    { key: 'avg_days_to_settle', header: 'Avg Days to Settle' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'damage_category', header: 'Damage Category' },
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'total_damage_value_rupees', header: 'Damage Value (INR)' },
    { key: 'avg_damage_pct', header: 'Avg Damage %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'total_shipment_value_rupees', header: 'Shipment Value (INR)' },
    { key: 'total_damage_value_rupees', header: 'Damage Value (INR)' },
    { key: 'total_recovered_rupees', header: 'Recovered (INR)' },
    { key: 'avg_damage_pct', header: 'Avg Damage %' },
    { key: 'worsening_lanes', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_recovery_at_risk_rupees', header: 'Avg Recovery at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovery_at_risk_rupees', header: 'Recovery at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'trend_dir', header: 'Trend' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'total_damage_value_rupees', header: 'Damage Value (INR)' },
    { key: 'total_claim_amount_rupees', header: 'Claimed (INR)' },
    { key: 'total_recovered_rupees', header: 'Recovered (INR)' },
    { key: 'overall_recovery_pct', header: 'Overall Recovery %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'incident_ref', header: 'Incident' },
    { key: 'lane_name', header: 'Lane' },
    { key: 'carrier_name', header: 'Carrier' },
    { key: 'period_month', header: 'Month' },
    { key: 'damage_category', header: 'Category' },
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'damage_value_rupees', header: 'Damage (INR)' },
    { key: 'claim_amount_rupees', header: 'Claimed (INR)' },
    { key: 'recovery_pct', header: 'Recovery %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Transit-Damage / Packaging-Damage Claims Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Transit and packaging damage incidents with insurance and carrier claims per lane
        &times; carrier &mdash; shipment vs damage value, damage % &times; claim filed
        &times; claim amount vs recovered &times; recovery % &times; days-to-settle
        &times; damage category (physical impact, moisture ingress, temperature excursion,
        mishandling, packaging failure) &amp; CAPA closure. Founder-gated view: claim-status
        rollups, carrier scorecards, root-cause pareto, and recovery-impact digest across
        Indian surface, air-cargo &amp; cold-chain lanes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Claim status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No damage incidents logged yet."
          rowKey={(r, i) => String(r.claim_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Carrier scorecard</h2>
        <DataTable
          rows={carrierRows}
          columns={carrierCols}
          emptyMessage="No carrier rollups."
          rowKey={(r, i) => String(r.carrier_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Damage category &times; claim status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No incidents by category."
          rowKey={(r, i) => `${r.damage_category}-${r.claim_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly damage trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Recovery impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No recovery-impact rollups."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk claims queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk incidents."
          rowKey={(r, i) => `${r.incident_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
