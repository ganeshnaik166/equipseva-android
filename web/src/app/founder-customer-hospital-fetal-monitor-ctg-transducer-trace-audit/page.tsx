import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fit_for_use: number;
  needs_service: number;
  removed: number;
  alarm_fails: number;
  avg_us_signal_pct: number;
  fit_pct: number;
};
type ModelTraceRow = {
  monitor_model: string;
  trace_legibility: string;
  audits: number;
  fit_for_use: number;
  avg_us_signal_pct: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  alarm_pass: number;
  alarm_fail: number;
  fhr_out_of_tolerance: number;
  avg_paper_speed_dev_pct: number;
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
  ward_code: string;
  monitor_asset_tag: string;
  monitor_model: string;
  audit_date: string;
  audit_verdict: string;
  toco_sensitivity: string;
  alarm_limits_test: string;
  trace_legibility: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    modelTraceRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3202_verdict_rollup'),
    supabase.rpc('founder_r3202_hospital_scorecard'),
    supabase.rpc('founder_r3202_model_trace_matrix'),
    supabase.rpc('founder_r3202_daily_trend'),
    supabase.rpc('founder_r3202_capa_status_board'),
    supabase.rpc('founder_r3202_root_cause_pareto'),
    supabase.rpc('founder_r3202_regulatory_impact_digest'),
    supabase.rpc('founder_r3202_high_risk_monitors'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const modelTraceRows: ModelTraceRow[] = (modelTraceRes.data as ModelTraceRow[]) ?? [];
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
    { key: 'needs_service', header: 'Needs Service' },
    { key: 'removed', header: 'Removed' },
    { key: 'alarm_fails', header: 'Alarm Fails' },
    { key: 'avg_us_signal_pct', header: 'Avg US Signal %' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const modelTraceCols: Column<ModelTraceRow>[] = [
    { key: 'monitor_model', header: 'Monitor Model' },
    { key: 'trace_legibility', header: 'Trace Legibility' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'avg_us_signal_pct', header: 'Avg US Signal %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'alarm_pass', header: 'Alarm Pass' },
    { key: 'alarm_fail', header: 'Alarm Fail' },
    { key: 'fhr_out_of_tolerance', header: 'FHR Out of Tol' },
    { key: 'avg_paper_speed_dev_pct', header: 'Avg Paper Dev %' },
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
    { key: 'ward_code', header: 'Ward' },
    { key: 'monitor_asset_tag', header: 'Asset' },
    { key: 'monitor_model', header: 'Model' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'toco_sensitivity', header: 'Toco' },
    { key: 'alarm_limits_test', header: 'Alarms' },
    { key: 'trace_legibility', header: 'Trace' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Fetal-Monitor (CTG) Transducer &amp; Trace-Quality Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        CTG QA log &mdash; monitor model &times; toco sensitivity &times; US transducer signal &times;
        paper-speed accuracy &times; FHR simulator vs display &times; alarm limits &times; belt/strap &amp;
        trace legibility with CAPA closure. Founder-gated view: audit verdicts, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No CTG audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital CTG fleet scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Monitor model &times; trace legibility matrix</h2>
        <DataTable
          rows={modelTraceRows}
          columns={modelTraceCols}
          emptyMessage="No audits by model."
          rowKey={(r, i) => `${r.monitor_model}-${r.trace_legibility}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily alarm &amp; FHR accuracy trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk monitors queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk monitors."
          rowKey={(r, i) => `${r.monitor_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
