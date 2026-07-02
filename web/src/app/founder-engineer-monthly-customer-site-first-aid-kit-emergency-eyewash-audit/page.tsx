import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = { audit_month: string; sites_audited: number; compliant_sites: number; critical_sites: number; avg_compliance: number; total_replenish_rupees: number };
type CriticalRow = { site_code: string; hospital_name: string; city: string; compliance_score: number; items_missing: number; items_expired: number; replenished: boolean };
type LeaderRow = { engineer_code: string; audits_completed: number; avg_compliance: number; critical_findings: number };
type EyewashStatusRow = { status: string; station_count: number; total_remediation_rupees: number; avg_flow_lpm: number };
type AnsiRow = { site_code: string; hospital_name: string; station_location: string; flow_rate_lpm: number; water_temp_celsius: number; activation_time_seconds: number; status: string };
type CityRow = { city: string; kit_avg_compliance: number; eyewash_pass_rate: number; total_sites: number };
type BacklogRow = { site_code: string; hospital_name: string; city: string; replenishment_cost_rupees: number; status: string; notes: string | null };
type MomRow = { site_code: string; hospital_name: string; current_score: number; previous_score: number; delta: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, critical, leaders, ewStatus, ansi, city, backlog, mom] = await Promise.all([
    supabase.rpc('rpc_r2934_monthly_compliance_overview'),
    supabase.rpc('rpc_r2934_critical_sites'),
    supabase.rpc('rpc_r2934_engineer_leaderboard'),
    supabase.rpc('rpc_r2934_eyewash_status_snapshot'),
    supabase.rpc('rpc_r2934_ansi_z358_failures'),
    supabase.rpc('rpc_r2934_city_rollup'),
    supabase.rpc('rpc_r2934_replenishment_backlog'),
    supabase.rpc('rpc_r2934_mom_trend'),
  ]);

  const overviewRows: OverviewRow[] = (overview.data ?? []) as OverviewRow[];
  const criticalRows: CriticalRow[] = (critical.data ?? []) as CriticalRow[];
  const leaderRows: LeaderRow[] = (leaders.data ?? []) as LeaderRow[];
  const ewRows: EyewashStatusRow[] = (ewStatus.data ?? []) as EyewashStatusRow[];
  const ansiRows: AnsiRow[] = (ansi.data ?? []) as AnsiRow[];
  const cityRows: CityRow[] = (city.data ?? []) as CityRow[];
  const backlogRows: BacklogRow[] = (backlog.data ?? []) as BacklogRow[];
  const momRows: MomRow[] = (mom.data ?? []) as MomRow[];

  const overviewCols: Column<OverviewRow>[] = [
    { key: 'audit_month', header: 'Month', render: (r) => r.audit_month },
    { key: 'sites_audited', header: 'Sites', render: (r) => r.sites_audited },
    { key: 'compliant_sites', header: 'Compliant', render: (r) => r.compliant_sites },
    { key: 'critical_sites', header: 'Critical', render: (r) => r.critical_sites },
    { key: 'avg_compliance', header: 'Avg %', render: (r) => r.avg_compliance },
    { key: 'total_replenish_rupees', header: 'Replenish ₹', render: (r) => r.total_replenish_rupees },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { key: 'site_code', header: 'Site', render: (r) => r.site_code },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'compliance_score', header: 'Score %', render: (r) => r.compliance_score },
    { key: 'items_missing', header: 'Missing', render: (r) => r.items_missing },
    { key: 'items_expired', header: 'Expired', render: (r) => r.items_expired },
    { key: 'replenished', header: 'Replenished', render: (r) => (r.replenished ? 'yes' : 'no') },
  ];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'audits_completed', header: 'Audits', render: (r) => r.audits_completed },
    { key: 'avg_compliance', header: 'Avg %', render: (r) => r.avg_compliance },
    { key: 'critical_findings', header: 'Critical findings', render: (r) => r.critical_findings },
  ];

  const ewCols: Column<EyewashStatusRow>[] = [
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'station_count', header: 'Stations', render: (r) => r.station_count },
    { key: 'total_remediation_rupees', header: 'Remediation ₹', render: (r) => r.total_remediation_rupees },
    { key: 'avg_flow_lpm', header: 'Avg flow LPM', render: (r) => r.avg_flow_lpm },
  ];

  const ansiCols: Column<AnsiRow>[] = [
    { key: 'site_code', header: 'Site', render: (r) => r.site_code },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'station_location', header: 'Station', render: (r) => r.station_location },
    { key: 'flow_rate_lpm', header: 'Flow LPM (min 11.4)', render: (r) => r.flow_rate_lpm },
    { key: 'water_temp_celsius', header: 'Temp °C', render: (r) => r.water_temp_celsius },
    { key: 'activation_time_seconds', header: 'Activation s (max 1.0)', render: (r) => r.activation_time_seconds },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'kit_avg_compliance', header: 'Kit avg %', render: (r) => r.kit_avg_compliance },
    { key: 'eyewash_pass_rate', header: 'Eyewash pass %', render: (r) => r.eyewash_pass_rate },
    { key: 'total_sites', header: 'Sites', render: (r) => r.total_sites },
  ];

  const backlogCols: Column<BacklogRow>[] = [
    { key: 'site_code', header: 'Site', render: (r) => r.site_code },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'replenishment_cost_rupees', header: 'Cost ₹', render: (r) => r.replenishment_cost_rupees },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
  ];

  const momCols: Column<MomRow>[] = [
    { key: 'site_code', header: 'Site', render: (r) => r.site_code },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'current_score', header: 'Now', render: (r) => r.current_score },
    { key: 'previous_score', header: 'Prev', render: (r) => r.previous_score },
    { key: 'delta', header: 'Delta', render: (r) => r.delta },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1>Engineer Monthly First-Aid Kit &amp; Emergency Eyewash Audit</h1>
        <p>Round r2934 — site-level safety compliance for customer hospital sites. Threshold: ANSI Z358.1 = flow &gt;=11.4 LPM, activation &lt;=1.0s.</p>
      </header>

      <section>
        <h2>Monthly compliance overview</h2>
        <DataTable rows={overviewRows} columns={overviewCols} emptyMessage="No audit months recorded yet" rowKey={(r, i) => String((r as OverviewRow).audit_month ?? i)} />
      </section>

      <section>
        <h2>Critical & major gap sites (latest month)</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="No critical sites" rowKey={(r, i) => String((r as CriticalRow).site_code ?? i)} />
      </section>

      <section>
        <h2>Engineer leaderboard</h2>
        <DataTable rows={leaderRows} columns={leaderCols} emptyMessage="No engineer data" rowKey={(r, i) => String((r as LeaderRow).engineer_code ?? i)} />
      </section>

      <section>
        <h2>Eyewash status snapshot</h2>
        <DataTable rows={ewRows} columns={ewCols} emptyMessage="No eyewash records" rowKey={(r, i) => String((r as EyewashStatusRow).status ?? i)} />
      </section>

      <section>
        <h2>ANSI Z358.1 non-compliant stations</h2>
        <DataTable rows={ansiRows} columns={ansiCols} emptyMessage="All stations compliant" rowKey={(r, i) => String((r as AnsiRow).site_code ?? i)} />
      </section>

      <section>
        <h2>City rollup</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No city data" rowKey={(r, i) => String((r as CityRow).city ?? i)} />
      </section>

      <section>
        <h2>Replenishment backlog</h2>
        <DataTable rows={backlogRows} columns={backlogCols} emptyMessage="Backlog clear" rowKey={(r, i) => String((r as BacklogRow).site_code ?? i)} />
      </section>

      <section>
        <h2>Month-over-month trend (worst regressions first)</h2>
        <DataTable rows={momRows} columns={momCols} emptyMessage="No comparable months" rowKey={(r, i) => String((r as MomRow).site_code ?? i)} />
      </section>
    </main>
  );
}
