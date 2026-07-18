import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { overall_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  compliant: number;
  critical_fails: number;
  interlock_fails: number;
  pressure_fails: number;
  card_log_down: number;
  compliance_pct: number;
};
type ZoneRow = {
  zone_type: string;
  audits: number;
  compliant: number;
  critical_fails: number;
  avg_pressure_pa: number | null;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  compliant: number;
  critical_fails: number;
  pressure_issues: number;
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
  zone_code: string;
  zone_type: string;
  audit_date: string;
  overall_verdict: string;
  interlock_pair_test: string;
  pressure_cascade_verdict: string;
  emergency_release_test: string;
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
    supabase.rpc('founder_r3231_verdict_rollup'),
    supabase.rpc('founder_r3231_hospital_scorecard'),
    supabase.rpc('founder_r3231_zone_type_matrix'),
    supabase.rpc('founder_r3231_daily_trend'),
    supabase.rpc('founder_r3231_capa_status_board'),
    supabase.rpc('founder_r3231_root_cause_pareto'),
    supabase.rpc('founder_r3231_regulatory_impact_digest'),
    supabase.rpc('founder_r3231_high_risk_queue'),
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
    { key: 'overall_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'critical_fails', header: 'Critical Fails' },
    { key: 'interlock_fails', header: 'Interlock Fails' },
    { key: 'pressure_fails', header: 'Pressure Fails' },
    { key: 'card_log_down', header: 'Card Log Down' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { key: 'zone_type', header: 'Zone Type' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'critical_fails', header: 'Critical Fails' },
    { key: 'avg_pressure_pa', header: 'Avg Cascade (Pa)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'critical_fails', header: 'Critical Fails' },
    { key: 'pressure_issues', header: 'Pressure Issues' },
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
    { key: 'zone_code', header: 'Zone' },
    { key: 'zone_type', header: 'Zone Type' },
    { key: 'audit_date', header: 'Date' },
    { key: 'overall_verdict', header: 'Verdict' },
    { key: 'interlock_pair_test', header: 'Interlock' },
    { key: 'pressure_cascade_verdict', header: 'Cascade' },
    { key: 'emergency_release_test', header: 'Emergency Release' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital OT/ICU Door-Interlock, Access-Control &amp; Pressure-Cascade Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Access QA log — zone &times; interlock pair test &times; auto-door sensor &times;
        access-card log &times; pressure cascade (Pa) &times; door seal &times; emergency release
        &amp; CAPA closure. Founder-gated view: verdict rollups, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; fire-safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Overall verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.overall_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital access-compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Zone-type matrix</h2>
        <DataTable
          rows={zoneRows}
          columns={zoneCols}
          emptyMessage="No audits by zone type."
          rowKey={(r, i) => String(r.zone_type ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk zones queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk zones."
          rowKey={(r, i) => `${r.zone_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
