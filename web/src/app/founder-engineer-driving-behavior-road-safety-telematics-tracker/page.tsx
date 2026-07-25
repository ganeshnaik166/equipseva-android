import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { safety_verdict: string; records: number; pct: number };
type EngineerRow = {
  engineer_name: string;
  periods: number;
  total_km: number;
  harsh_braking: number;
  harsh_accel: number;
  overspeeding: number;
  fatigue_alerts: number;
  mobile_use: number;
  accidents: number;
  near_misses: number;
  avg_safety_score: number;
  avg_seatbelt_pct: number;
};
type MatrixRow = {
  region: string;
  period_month: string;
  records: number;
  avg_safety_score: number;
  accidents: number;
  near_misses: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_km: number;
  accidents: number;
  near_misses: number;
  avg_safety_score: number;
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
  escalation_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  period_month: string;
  safety_score: number | null;
  safety_verdict: string;
  accidents: number;
  near_misses: number;
  overspeeding_events: number;
  fatigue_alert_count: number;
  mobile_use_while_driving_events: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engineerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3420_safety_verdict_rollup'),
    supabase.rpc('founder_r3420_engineer_scorecard'),
    supabase.rpc('founder_r3420_region_period_matrix'),
    supabase.rpc('founder_r3420_period_trend'),
    supabase.rpc('founder_r3420_capa_status_board'),
    supabase.rpc('founder_r3420_root_cause_pareto'),
    supabase.rpc('founder_r3420_escalation_impact_digest'),
    supabase.rpc('founder_r3420_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'safety_verdict', header: 'Verdict' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'periods', header: 'Periods' },
    { key: 'total_km', header: 'Total KM' },
    { key: 'harsh_braking', header: 'Harsh Braking' },
    { key: 'harsh_accel', header: 'Harsh Accel' },
    { key: 'overspeeding', header: 'Overspeeding' },
    { key: 'fatigue_alerts', header: 'Fatigue Alerts' },
    { key: 'mobile_use', header: 'Mobile Use' },
    { key: 'accidents', header: 'Accidents' },
    { key: 'near_misses', header: 'Near Misses' },
    { key: 'avg_safety_score', header: 'Avg Safety Score' },
    { key: 'avg_seatbelt_pct', header: 'Avg Seatbelt %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Period' },
    { key: 'records', header: 'Records' },
    { key: 'avg_safety_score', header: 'Avg Safety Score' },
    { key: 'accidents', header: 'Accidents' },
    { key: 'near_misses', header: 'Near Misses' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'records', header: 'Records' },
    { key: 'total_km', header: 'Total KM' },
    { key: 'accidents', header: 'Accidents' },
    { key: 'near_misses', header: 'Near Misses' },
    { key: 'avg_safety_score', header: 'Avg Safety Score' },
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
    { key: 'escalation_impact', header: 'Escalation Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Period' },
    { key: 'safety_score', header: 'Safety Score' },
    { key: 'safety_verdict', header: 'Verdict' },
    { key: 'accidents', header: 'Accidents' },
    { key: 'near_misses', header: 'Near Misses' },
    { key: 'overspeeding_events', header: 'Overspeeding' },
    { key: 'fatigue_alert_count', header: 'Fatigue Alerts' },
    { key: 'mobile_use_while_driving_events', header: 'Mobile Use' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Driving-Behavior Road-Safety Telematics Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer driving safety &amp; accident-prevention telematics — engineer &times; region
        &times; period &times; km driven &times; harsh braking &amp; acceleration &times; overspeeding
        &times; night-driving hours &times; fatigue alerts &times; seatbelt compliance &times; mobile-use
        while driving &times; safety score &times; accidents &amp; near-misses &times; license &amp;
        defensive-training currency &amp; CAPA closure. Founder-gated view: safety verdicts, engineer
        scorecards, root-cause pareto, and escalation-impact digest to flag risky drivers before
        accidents happen.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Safety verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No telematics records logged yet."
          rowKey={(r, i) => String(r.safety_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer safety scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Region &times; period matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by region."
          rowKey={(r, i) => `${r.region}-${r.period_month}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Period trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Escalation impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No escalation-impact rollups."
          rowKey={(r, i) => String(r.escalation_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk driving queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk records."
          rowKey={(r, i) => `${r.engineer_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
