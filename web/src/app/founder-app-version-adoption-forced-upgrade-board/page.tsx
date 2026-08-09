import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { adoption_status: string; releases: number; pct: number };
type ChannelRow = {
  release_channel: string;
  total_releases: number;
  healthy: number;
  lagging: number;
  fragmented_or_blocked: number;
  forced_active: number;
  legacy_devices: number;
  avg_adoption_pct: number;
  avg_crash_free_pct: number;
};
type MatrixRow = {
  channel_class: string;
  adoption_status: string;
  releases: number;
  avg_adoption_pct: number;
  legacy_devices: number;
};
type TrendRow = {
  period_month: string;
  releases: number;
  avg_adoption_pct: number;
  avg_crash_free_pct: number;
  forced_active: number;
  legacy_devices: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impacted_installs: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impacted_installs: number;
  pct: number;
};
type LegacyRow = {
  release_channel: string;
  releases: number;
  releases_with_legacy: number;
  total_legacy_devices: number;
  forced_walls_active: number;
  avg_prompt_ctr_pct: number;
};
type RiskRow = {
  version_name: string;
  release_channel: string;
  channel_class: string;
  period_month: string;
  adoption_status: string;
  trend_dir: string;
  adoption_pct: number | null;
  target_adoption_pct: number | null;
  devices_below_min_version: number;
  forced_upgrade_active: boolean;
  crash_free_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    channelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    legacyRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3694_adoption_status_rollup'),
    supabase.rpc('founder_r3694_channel_scorecard'),
    supabase.rpc('founder_r3694_channel_class_status_matrix'),
    supabase.rpc('founder_r3694_monthly_adoption_trend'),
    supabase.rpc('founder_r3694_capa_status_board'),
    supabase.rpc('founder_r3694_root_cause_pareto'),
    supabase.rpc('founder_r3694_legacy_device_digest'),
    supabase.rpc('founder_r3694_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const channelRows: ChannelRow[] = (channelRes.data as ChannelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const legacyRows: LegacyRow[] = (legacyRes.data as LegacyRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'adoption_status', header: 'Adoption Status' },
    { key: 'releases', header: 'Releases' },
    { key: 'pct', header: 'Share %' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'release_channel', header: 'Channel' },
    { key: 'total_releases', header: 'Releases' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'lagging', header: 'Lagging' },
    { key: 'fragmented_or_blocked', header: 'Fragmented / Blocked' },
    { key: 'forced_active', header: 'Forced Walls' },
    { key: 'legacy_devices', header: 'Legacy Devices' },
    { key: 'avg_adoption_pct', header: 'Avg Adoption %' },
    { key: 'avg_crash_free_pct', header: 'Avg Crash-Free %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'channel_class', header: 'Channel Class' },
    { key: 'adoption_status', header: 'Adoption Status' },
    { key: 'releases', header: 'Releases' },
    { key: 'avg_adoption_pct', header: 'Avg Adoption %' },
    { key: 'legacy_devices', header: 'Legacy Devices' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'releases', header: 'Releases' },
    { key: 'avg_adoption_pct', header: 'Avg Adoption %' },
    { key: 'avg_crash_free_pct', header: 'Avg Crash-Free %' },
    { key: 'forced_active', header: 'Forced Walls' },
    { key: 'legacy_devices', header: 'Legacy Devices' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impacted_installs', header: 'Avg Impacted Installs' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impacted_installs', header: 'Total Impacted Installs' },
    { key: 'pct', header: 'Share %' },
  ];

  const legacyCols: Column<LegacyRow>[] = [
    { key: 'release_channel', header: 'Channel' },
    { key: 'releases', header: 'Releases' },
    { key: 'releases_with_legacy', header: 'With Legacy Tail' },
    { key: 'total_legacy_devices', header: 'Legacy Devices' },
    { key: 'forced_walls_active', header: 'Forced Walls' },
    { key: 'avg_prompt_ctr_pct', header: 'Avg Prompt CTR %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'version_name', header: 'Version' },
    { key: 'release_channel', header: 'Channel' },
    { key: 'channel_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'adoption_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'adoption_pct', header: 'Adoption %' },
    { key: 'target_adoption_pct', header: 'Target %' },
    { key: 'devices_below_min_version', header: 'Legacy Devices' },
    { key: 'forced_upgrade_active', header: 'Forced Wall' },
    { key: 'crash_free_pct', header: 'Crash-Free %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        App-Version Adoption / Forced-Upgrade Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        EquipSeva app version adoption per release channel — version &times; channel class
        (production, beta, internal testing, staged rollout, hotfix) &times; days since release
        &times; installs &times; adoption vs target &times; devices below min version &times;
        forced-upgrade wall &times; upgrade-prompt CTR &times; crash-free % &amp; CAPA closure.
        Founder-gated view: adoption-status rollups, channel scorecards, monthly trend,
        root-cause pareto, legacy-device digest, and the blocked-legacy / fragmented queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Adoption status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No version-adoption rows logged yet."
          rowKey={(r, i) => String(r.adoption_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Release-channel scorecard</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No channel rollups."
          rowKey={(r, i) => String(r.release_channel ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Channel class &times; adoption status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.channel_class}-${r.adoption_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly adoption trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Legacy-device digest</h2>
        <DataTable
          rows={legacyRows}
          columns={legacyCols}
          emptyMessage="No legacy-device rollups."
          rowKey={(r, i) => `${r.release_channel}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk adoption queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk releases."
          rowKey={(r, i) => `${r.version_name}-${r.release_channel}-${i}`}
        />
      </section>
    </main>
  );
}
