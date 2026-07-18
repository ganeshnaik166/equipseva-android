import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  compliant: number;
  non_compliant: number;
  fail_shutdown: number;
  below_spec: number;
  changeover_fail: number;
  avg_purity_pct: number;
  compliance_pct: number;
};
type MatrixRow = {
  source_type: string;
  gas_standard: string;
  audits: number;
  compliant: number;
  avg_purity_pct: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  avg_purity_pct: number;
  compliant: number;
  non_compliant: number;
  below_spec: number;
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
  hospital_name: string;
  plant_location: string;
  source_asset_tag: string;
  audit_date: string;
  audit_verdict: string;
  o2_purity_pct: number;
  purity_verdict: string;
  dew_point_verdict: string | null;
  backup_changeover_test: string;
  alarm_test_result: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3174_verdict_rollup'),
    supabase.rpc('founder_r3174_hospital_scorecard'),
    supabase.rpc('founder_r3174_source_standard_matrix'),
    supabase.rpc('founder_r3174_purity_daily_trend'),
    supabase.rpc('founder_r3174_capa_status_board'),
    supabase.rpc('founder_r3174_root_cause_pareto'),
    supabase.rpc('founder_r3174_regulatory_impact_digest'),
    supabase.rpc('founder_r3174_high_risk_sources'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'fail_shutdown', header: 'Fail / Recall' },
    { key: 'below_spec', header: 'Below Spec' },
    { key: 'changeover_fail', header: 'Changeover Fail' },
    { key: 'avg_purity_pct', header: 'Avg Purity %' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'source_type', header: 'Source Type' },
    { key: 'gas_standard', header: 'Gas Standard' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'avg_purity_pct', header: 'Avg Purity %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_purity_pct', header: 'Avg Purity %' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'below_spec', header: 'Below Spec' },
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
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'plant_location', header: 'Location' },
    { key: 'source_asset_tag', header: 'Asset' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'o2_purity_pct', header: 'Purity %' },
    { key: 'purity_verdict', header: 'Purity Grade' },
    { key: 'dew_point_verdict', header: 'Dew Point' },
    { key: 'backup_changeover_test', header: 'Changeover' },
    { key: 'alarm_test_result', header: 'Alarm' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Oxygen-Concentrator &amp; PSA-Plant Output-Purity Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Medical O&#8322; source QA log — source type &times; gas standard &times; purity % &times; flow &times;
        dew point &times; pressure &times; sieve-bed age &times; backup-changeover &times; alarm test &amp; CAPA closure.
        Founder-gated view: audit verdicts, hospital scorecards, root-cause pareto, and regulatory-impact
        digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital purity scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Source type &times; gas standard matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by source."
          rowKey={(r, i) => `${r.source_type}-${r.gas_standard}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Purity daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk O&#8322; sources queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk sources."
          rowKey={(r, i) => `${r.source_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
