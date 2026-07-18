import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fit_for_use: number;
  restricted: number;
  out_of_service: number;
  wb_issues: number;
  avg_light_output_pct: number | null;
  avg_image_lag_ms: number | null;
  fit_pct: number;
};
type CompRow = {
  component: string;
  audits: number;
  fit_for_use: number;
  wb_issues: number;
  avg_co2_accuracy_pct: number | null;
  avg_image_lag_ms: number | null;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  fit_for_use: number;
  out_of_service: number;
  wb_issues: number;
  pressure_fails: number;
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
  ot_room_code: string;
  tower_asset_tag: string;
  component: string;
  audit_date: string;
  audit_verdict: string;
  white_balance_result: string | null;
  pressure_relief_test: string | null;
  image_lag_ms: number | null;
  seal_integrity: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    compRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3182_audit_verdict_rollup'),
    supabase.rpc('founder_r3182_hospital_scorecard'),
    supabase.rpc('founder_r3182_component_matrix'),
    supabase.rpc('founder_r3182_daily_trend'),
    supabase.rpc('founder_r3182_capa_status_board'),
    supabase.rpc('founder_r3182_root_cause_pareto'),
    supabase.rpc('founder_r3182_regulatory_impact_digest'),
    supabase.rpc('founder_r3182_high_risk_audits'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const compRows: CompRow[] = (compRes.data as CompRow[]) ?? [];
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
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'restricted', header: 'Restricted' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'wb_issues', header: 'WB Issues' },
    { key: 'avg_light_output_pct', header: 'Avg Light %' },
    { key: 'avg_image_lag_ms', header: 'Avg Lag (ms)' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const compCols: Column<CompRow>[] = [
    { key: 'component', header: 'Component' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'wb_issues', header: 'WB Issues' },
    { key: 'avg_co2_accuracy_pct', header: 'Avg CO2 Accuracy %' },
    { key: 'avg_image_lag_ms', header: 'Avg Lag (ms)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'wb_issues', header: 'WB Issues' },
    { key: 'pressure_fails', header: 'Relief Fails' },
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
    { key: 'ot_room_code', header: 'OT' },
    { key: 'tower_asset_tag', header: 'Asset' },
    { key: 'component', header: 'Component' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'white_balance_result', header: 'WB' },
    { key: 'pressure_relief_test', header: 'Relief' },
    { key: 'image_lag_ms', header: 'Lag (ms)' },
    { key: 'seal_integrity', header: 'Seal' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital OT Integration Video-Tower &amp; Insufflator Function Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Laparoscopy tower QA — component &times; white-balance &times; light output %
        &times; CO2 flow accuracy &times; pressure-relief &times; image lag &times;
        cable/seal integrity &amp; CAPA closure. Founder-gated view: audit verdicts,
        hospital scorecards, component matrix, root-cause pareto, and regulatory-impact
        digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No tower audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital tower-health scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Component audit matrix</h2>
        <DataTable
          rows={compRows}
          columns={compCols}
          emptyMessage="No component rollups."
          rowKey={(r, i) => `${r.component}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk audit queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.tower_asset_tag}-${r.component}-${i}`}
        />
      </section>
    </main>
  );
}
