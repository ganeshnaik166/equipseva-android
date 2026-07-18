import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  healthy: number;
  watch: number;
  degraded: number;
  replace_needed: number;
  critical_fail: number;
  avg_runtime_min: number;
  avg_battery_age_months: number;
  healthy_pct: number;
};
type LocTopoRow = {
  ups_location: string;
  ups_topology: string;
  audits: number;
  avg_load_pct: number;
  avg_runtime_min: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  healthy: number;
  watch: number;
  degraded_or_replace: number;
  critical_fail: number;
  avg_runtime_min: number;
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
  ups_asset_tag: string;
  ups_location: string;
  audit_date: string;
  audit_verdict: string;
  thermal_scan_result: string;
  backup_runtime_min: number | null;
  battery_age_months: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    locTopoRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3199_verdict_rollup'),
    supabase.rpc('founder_r3199_hospital_scorecard'),
    supabase.rpc('founder_r3199_location_topology_matrix'),
    supabase.rpc('founder_r3199_daily_trend'),
    supabase.rpc('founder_r3199_capa_status_board'),
    supabase.rpc('founder_r3199_root_cause_pareto'),
    supabase.rpc('founder_r3199_regulatory_impact_digest'),
    supabase.rpc('founder_r3199_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const locTopoRows: LocTopoRow[] = (locTopoRes.data as LocTopoRow[]) ?? [];
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
    { key: 'healthy', header: 'Healthy' },
    { key: 'watch', header: 'Watch' },
    { key: 'degraded', header: 'Degraded' },
    { key: 'replace_needed', header: 'Replace' },
    { key: 'critical_fail', header: 'Critical' },
    { key: 'avg_runtime_min', header: 'Avg Runtime (min)' },
    { key: 'avg_battery_age_months', header: 'Avg Age (mo)' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const locTopoCols: Column<LocTopoRow>[] = [
    { key: 'ups_location', header: 'Location' },
    { key: 'ups_topology', header: 'Topology' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_load_pct', header: 'Avg Load %' },
    { key: 'avg_runtime_min', header: 'Avg Runtime (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'watch', header: 'Watch' },
    { key: 'degraded_or_replace', header: 'Degraded / Replace' },
    { key: 'critical_fail', header: 'Critical' },
    { key: 'avg_runtime_min', header: 'Avg Runtime (min)' },
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
    { key: 'ups_asset_tag', header: 'Asset' },
    { key: 'ups_location', header: 'Location' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'thermal_scan_result', header: 'Thermal' },
    { key: 'backup_runtime_min', header: 'Runtime (min)' },
    { key: 'battery_age_months', header: 'Age (mo)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital OT &amp; ICU UPS / Inverter Battery-Bank Health Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        UPS battery-bank QA log &mdash; location &times; capacity kVA &times; load % &times;
        bank voltage &times; backup runtime &times; transfer time &times; battery age &times;
        thermal scan &amp; CAPA closure. Founder-gated view: audit verdicts, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; electrical-safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No UPS audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital battery-bank scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Location &times; topology matrix</h2>
        <DataTable
          rows={locTopoRows}
          columns={locTopoCols}
          emptyMessage="No audits by location."
          rowKey={(r, i) => `${r.ups_location}-${r.ups_topology}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk UPS queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk UPS units."
          rowKey={(r, i) => `${r.ups_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
