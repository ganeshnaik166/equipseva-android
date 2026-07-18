import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { coverage_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fully_compliant: number;
  major_gap_audits: number;
  critical_failures: number;
  avg_dropout_pct: number;
  avg_latency_sec: number;
  compliance_pct: number;
};
type ZoneRow = {
  ward_zone: string;
  alarm_escalation_tiers_test: string;
  audits: number;
  total_beds: number;
  avg_dropout_pct: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  avg_dropout_pct: number;
  max_latency_sec: number;
  dead_zone_audits: number;
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
  station_code: string;
  ward_zone: string;
  audit_date: string;
  coverage_verdict: string;
  signal_dropout_pct: number;
  central_display_latency_sec: number;
  alarm_escalation_tiers_test: string;
  battery_swap_compliance: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    zoneRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3223_coverage_verdict_rollup'),
    supabase.rpc('founder_r3223_hospital_scorecard'),
    supabase.rpc('founder_r3223_ward_escalation_matrix'),
    supabase.rpc('founder_r3223_daily_dropout_trend'),
    supabase.rpc('founder_r3223_capa_status_board'),
    supabase.rpc('founder_r3223_root_cause_pareto'),
    supabase.rpc('founder_r3223_regulatory_impact_digest'),
    supabase.rpc('founder_r3223_high_risk_stations'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const zoneRows: ZoneRow[] = (zoneRes.data as ZoneRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'coverage_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'major_gap_audits', header: 'Major Gaps' },
    { key: 'critical_failures', header: 'Critical' },
    { key: 'avg_dropout_pct', header: 'Avg Dropout %' },
    { key: 'avg_latency_sec', header: 'Avg Latency (s)' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { key: 'ward_zone', header: 'Ward Zone' },
    { key: 'alarm_escalation_tiers_test', header: 'Escalation Test' },
    { key: 'audits', header: 'Audits' },
    { key: 'total_beds', header: 'Beds Monitored' },
    { key: 'avg_dropout_pct', header: 'Avg Dropout %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_dropout_pct', header: 'Avg Dropout %' },
    { key: 'max_latency_sec', header: 'Max Latency (s)' },
    { key: 'dead_zone_audits', header: 'Dead-Zone Audits' },
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
    { key: 'station_code', header: 'Station' },
    { key: 'ward_zone', header: 'Ward Zone' },
    { key: 'audit_date', header: 'Date' },
    { key: 'coverage_verdict', header: 'Verdict' },
    { key: 'signal_dropout_pct', header: 'Dropout %' },
    { key: 'central_display_latency_sec', header: 'Latency (s)' },
    { key: 'alarm_escalation_tiers_test', header: 'Escalation Test' },
    { key: 'battery_swap_compliance', header: 'Battery Swap' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Telemetry Central Station Coverage &amp; Alarm-Escalation Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Telemetry QA log &mdash; ward zone &times; beds monitored &times; transmitters active &times;
        signal dropout &times; antenna coverage gaps &times; central-display latency &times;
        alarm-escalation tier drills &times; battery-swap compliance &amp; CAPA closure. Founder-gated
        view: coverage verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Coverage verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No station audits logged yet."
          rowKey={(r, i) => String(r.coverage_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital coverage scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Ward zone &times; escalation-test matrix</h2>
        <DataTable
          rows={zoneRows}
          columns={zoneCols}
          emptyMessage="No ward-zone rollups."
          rowKey={(r, i) => `${r.ward_zone}-${r.alarm_escalation_tiers_test}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily dropout &amp; latency trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk stations queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk stations."
          rowKey={(r, i) => `${r.station_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
