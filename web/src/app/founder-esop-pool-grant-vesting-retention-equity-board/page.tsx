import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  retention_risk_verdict: string;
  grants: number;
  total_units: number;
  pct: number;
};
type EntityRow = {
  entity_name: string;
  total_grants: number;
  active_grants: number;
  flight_risk: number;
  total_units: number;
  exercised_units: number;
  avg_vested_pct: number;
};
type MatrixRow = {
  grantee_role: string;
  vesting_schedule: string;
  grants: number;
  total_units: number;
  avg_vested_pct: number;
};
type TrendRow = {
  vest_start_date: string;
  grants: number;
  units_granted: number;
  avg_cliff_months: number;
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
type RiskRow = {
  entity_name: string;
  grantee_name: string;
  grantee_role: string;
  grant_code: string;
  grant_units: number;
  vested_pct: number;
  exercised_units: number;
  leaver_status: string;
  retention_risk_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3225_retention_verdict_rollup'),
    supabase.rpc('founder_r3225_entity_scorecard'),
    supabase.rpc('founder_r3225_role_schedule_matrix'),
    supabase.rpc('founder_r3225_vest_start_trend'),
    supabase.rpc('founder_r3225_capa_status_board'),
    supabase.rpc('founder_r3225_root_cause_pareto'),
    supabase.rpc('founder_r3225_regulatory_impact_digest'),
    supabase.rpc('founder_r3225_high_risk_grants'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'retention_risk_verdict', header: 'Retention Verdict' },
    { key: 'grants', header: 'Grants' },
    { key: 'total_units', header: 'Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity / Hospital Account' },
    { key: 'total_grants', header: 'Grants' },
    { key: 'active_grants', header: 'Active' },
    { key: 'flight_risk', header: 'Flight Risk' },
    { key: 'total_units', header: 'Units' },
    { key: 'exercised_units', header: 'Exercised' },
    { key: 'avg_vested_pct', header: 'Avg Vested %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'grantee_role', header: 'Role' },
    { key: 'vesting_schedule', header: 'Schedule' },
    { key: 'grants', header: 'Grants' },
    { key: 'total_units', header: 'Units' },
    { key: 'avg_vested_pct', header: 'Avg Vested %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'vest_start_date', header: 'Vest Start' },
    { key: 'grants', header: 'Grants' },
    { key: 'units_granted', header: 'Units Granted' },
    { key: 'avg_cliff_months', header: 'Avg Cliff (mo)' },
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

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'grantee_name', header: 'Grantee' },
    { key: 'grantee_role', header: 'Role' },
    { key: 'grant_code', header: 'Grant' },
    { key: 'grant_units', header: 'Units' },
    { key: 'vested_pct', header: 'Vested %' },
    { key: 'exercised_units', header: 'Exercised' },
    { key: 'leaver_status', header: 'Leaver Status' },
    { key: 'retention_risk_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder ESOP Pool, Grant Vesting &amp; Retention Equity Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ESOP grant log &mdash; grantee role &times; grant units &times; strike price &times; vest
        start &times; cliff &times; vested % &times; exercised units &times; leaver status &times;
        pool remaining &amp; CAPA closure. Founder-gated view: retention-risk verdicts, entity
        scorecards, role &times; schedule matrix, root-cause pareto, and regulatory-impact digest
        across Companies Act &amp; TDS surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Retention-risk verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No grants logged yet."
          rowKey={(r, i) => String(r.retention_risk_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity / hospital-account scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Role &times; vesting schedule matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No grants by role."
          rowKey={(r, i) => `${r.grantee_role}-${r.vesting_schedule}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Vest-start date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.vest_start_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk grants queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk grants."
          rowKey={(r, i) => `${r.grant_code}-${i}`}
        />
      </section>
    </main>
  );
}
