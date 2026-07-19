import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; checks: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  well_managed: number;
  needs_tuning: number;
  fatigue_risk: number;
  escalation_gap: number;
  patient_safety: number;
  secondary_alerting_issues: number;
  escalation_fail: number;
  well_managed_pct: number;
};
type MatrixRow = {
  physiological_monitor_model: string;
  alarm_middleware_platform: string;
  checks: number;
  well_managed: number;
  avg_alarm_load: number;
  avg_actionable_pct: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  well_managed: number;
  patient_safety_risk: number;
  secondary_alerting_fail: number;
  escalation_fail: number;
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
  unit_code: string;
  care_area: string;
  check_date: string;
  audit_verdict: string;
  secondary_alerting_ok: string | null;
  escalation_to_nurse_call_ok: boolean | null;
  alarm_middleware_uptime_pct: number | null;
  sentinel_alarm_event: number | null;
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
    supabase.rpc('founder_r3383_verdict_rollup'),
    supabase.rpc('founder_r3383_hospital_scorecard'),
    supabase.rpc('founder_r3383_monitor_middleware_matrix'),
    supabase.rpc('founder_r3383_daily_check_trend'),
    supabase.rpc('founder_r3383_capa_status_board'),
    supabase.rpc('founder_r3383_root_cause_pareto'),
    supabase.rpc('founder_r3383_regulatory_impact_digest'),
    supabase.rpc('founder_r3383_high_risk_queue'),
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
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'well_managed', header: 'Well Managed' },
    { key: 'needs_tuning', header: 'Needs Tuning' },
    { key: 'fatigue_risk', header: 'Fatigue Risk' },
    { key: 'escalation_gap', header: 'Escalation Gap' },
    { key: 'patient_safety', header: 'Patient Safety Risk' },
    { key: 'secondary_alerting_issues', header: 'Secondary-Alert Issues' },
    { key: 'escalation_fail', header: 'Escalation Fail' },
    { key: 'well_managed_pct', header: 'Well-Managed %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'physiological_monitor_model', header: 'Monitor Platform' },
    { key: 'alarm_middleware_platform', header: 'Alarm Middleware' },
    { key: 'checks', header: 'Checks' },
    { key: 'well_managed', header: 'Well Managed' },
    { key: 'avg_alarm_load', header: 'Avg Alarm Load/Bed/Day' },
    { key: 'avg_actionable_pct', header: 'Avg Actionable %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'well_managed', header: 'Well Managed' },
    { key: 'patient_safety_risk', header: 'Patient Safety Risk' },
    { key: 'secondary_alerting_fail', header: 'Secondary-Alert Fail' },
    { key: 'escalation_fail', header: 'Escalation Fail' },
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
    { key: 'unit_code', header: 'Unit' },
    { key: 'care_area', header: 'Care Area' },
    { key: 'check_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'secondary_alerting_ok', header: 'Secondary Alerting' },
    { key: 'escalation_to_nurse_call_ok', header: 'Nurse-Call Escalation' },
    { key: 'alarm_middleware_uptime_pct', header: 'Middleware Uptime %' },
    { key: 'sentinel_alarm_event', header: 'Sentinel Events' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Clinical Alarm-Management, Alarm-Fatigue &amp; Secondary-Alerting Escalation Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per unit/system alarm review — care area &times; physiological-monitor platform &times; alarm
        middleware &times; alarm load per bed/day &times; actionable ratio &times; default-limit
        customization &times; secondary alerting &times; nurse-call escalation &times; silence-policy
        adherence &times; middleware uptime &times; sentinel alarm events &amp; CAPA closure.
        Founder-gated view: audit verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No alarm-management checks logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital alarm-management scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Monitor platform &times; alarm-middleware matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by platform."
          rowKey={(r, i) => `${r.physiological_monitor_model}-${r.alarm_middleware_platform}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily check trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk alarm-management queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.unit_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
