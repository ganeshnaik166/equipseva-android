import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { system_verdict: string; systems: number; pct: number };
type SiteRow = {
  site_name: string;
  total_systems: number;
  healthy: number;
  service_due: number;
  critical: number;
  faults_open_systems: number;
  compliance_gap: number;
  avg_uptime_pct: number;
  monthly_cost_rupees: number;
};
type MatrixRow = {
  system_type: string;
  system_verdict: string;
  systems: number;
  avg_uptime_pct: number;
  total_open_faults: number;
};
type CalendarRow = {
  next_service_due: string;
  systems: number;
  amc_expiring: number;
  critical: number;
  faults_open: number;
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
  site_name: string;
  city: string;
  system_type: string;
  system_asset_tag: string;
  system_verdict: string;
  amc_end: string | null;
  next_service_due: string | null;
  uptime_pct: number | null;
  open_faults: number | null;
  spare_availability: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    siteRes,
    matrixRes,
    calendarRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3281_system_verdict_rollup'),
    supabase.rpc('founder_r3281_site_scorecard'),
    supabase.rpc('founder_r3281_systemtype_verdict_matrix'),
    supabase.rpc('founder_r3281_service_due_calendar'),
    supabase.rpc('founder_r3281_capa_status_board'),
    supabase.rpc('founder_r3281_root_cause_pareto'),
    supabase.rpc('founder_r3281_regulatory_impact_digest'),
    supabase.rpc('founder_r3281_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const calendarRows: CalendarRow[] = (calendarRes.data as CalendarRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'system_verdict', header: 'Verdict' },
    { key: 'systems', header: 'Systems' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'total_systems', header: 'Systems' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'service_due', header: 'Service / AMC Due' },
    { key: 'critical', header: 'Critical' },
    { key: 'faults_open_systems', header: 'Faults Open' },
    { key: 'compliance_gap', header: 'Compliance Gap' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'monthly_cost_rupees', header: 'Monthly Cost (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'system_type', header: 'System Type' },
    { key: 'system_verdict', header: 'Verdict' },
    { key: 'systems', header: 'Systems' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'total_open_faults', header: 'Open Faults' },
  ];

  const calendarCols: Column<CalendarRow>[] = [
    { key: 'next_service_due', header: 'Next Service Due' },
    { key: 'systems', header: 'Systems' },
    { key: 'amc_expiring', header: 'AMC Expiring' },
    { key: 'critical', header: 'Critical' },
    { key: 'faults_open', header: 'Faults Open' },
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
    { key: 'site_name', header: 'Site' },
    { key: 'city', header: 'City' },
    { key: 'system_type', header: 'System Type' },
    { key: 'system_asset_tag', header: 'Asset' },
    { key: 'system_verdict', header: 'Verdict' },
    { key: 'amc_end', header: 'AMC End' },
    { key: 'next_service_due', header: 'Next Service Due' },
    { key: 'uptime_pct', header: 'Uptime %' },
    { key: 'open_faults', header: 'Open Faults' },
    { key: 'spare_availability', header: 'Spares' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Facility BMS, Access-Control, CCTV &amp; Fire-Safety Systems Maintenance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        EquipSeva office &amp; warehouse building systems — system type &times; site &times; AMC
        window &times; service-due &times; uptime % &times; open faults &times; spare availability
        &times; compliance cert (fire NOC) &times; monthly cost &amp; CAPA closure. Founder-gated
        governance: verdict rollups, site scorecards, root-cause pareto, and regulatory-impact digest
        across fire-NOC &amp; statutory-compliance surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. System verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No facility systems logged yet."
          rowKey={(r, i) => String(r.system_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site maintenance scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. System type &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No systems by type."
          rowKey={(r, i) => `${r.system_type}-${r.system_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Service-due calendar</h2>
        <DataTable
          rows={calendarRows}
          columns={calendarCols}
          emptyMessage="No service-due data."
          rowKey={(r, i) => String(r.next_service_due ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk systems queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk systems."
          rowKey={(r, i) => `${r.system_asset_tag}-${r.next_service_due}-${i}`}
        />
      </section>
    </main>
  );
}
