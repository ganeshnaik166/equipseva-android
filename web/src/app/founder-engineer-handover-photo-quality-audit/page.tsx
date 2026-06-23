import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_audits: number;
  excellent_count: number;
  good_count: number;
  marginal_count: number;
  poor_count: number;
  dispute_risk_count: number;
  disputes_raised: number;
  signoff_capture_rate: number | null;
  avg_quality_score: number | null;
};

type RecentRow = {
  id: string;
  engineer_email: string | null;
  hospital_org_name: string;
  equipment_label: string;
  handover_completed_at: string;
  photo_count: number;
  quality_score: number | null;
  quality_band: string;
  customer_signoff_captured: boolean;
  dispute_risk_flag: boolean;
  dispute_raised: boolean;
};

type BandRow = {
  quality_band: string;
  audit_count: number;
  dispute_count: number;
  avg_quality_score: number | null;
};

type LeaderRow = {
  engineer_email: string | null;
  total_handovers: number;
  avg_quality_score: number | null;
  poor_count: number;
  dispute_count: number;
  signoff_rate: number | null;
};

type FindingRow = {
  finding_category: string;
  finding_count: number;
  total_occurrences: number;
  critical_count: number;
  high_count: number;
};

type WatchRow = {
  audit_id: string;
  engineer_email: string | null;
  hospital_org_name: string;
  equipment_label: string;
  handover_completed_at: string;
  quality_score: number | null;
  quality_band: string;
  dispute_raised: boolean;
  reviewer_notes: string | null;
};

type TrendRow = {
  week_start: string;
  audit_count: number;
  avg_quality_score: number | null;
  poor_count: number;
  dispute_count: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, recentRes, bandRes, leaderRes, findingRes, watchRes, trendRes] = await Promise.all([
    supabase.rpc('handover_audit_overview_r2390'),
    supabase.rpc('handover_audit_recent_r2390', { p_limit: 100 }),
    supabase.rpc('handover_audit_band_breakdown_r2390'),
    supabase.rpc('handover_audit_engineer_leaderboard_r2390'),
    supabase.rpc('handover_audit_finding_breakdown_r2390'),
    supabase.rpc('handover_audit_dispute_watchlist_r2390'),
    supabase.rpc('handover_audit_weekly_trend_r2390'),
  ]);

  const overview: Overview | null = (overviewRes.data?.[0] as Overview) ?? null;
  const recent: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];
  const bands: BandRow[] = (bandRes.data as BandRow[]) ?? [];
  const leaders: LeaderRow[] = (leaderRes.data as LeaderRow[]) ?? [];
  const findings: FindingRow[] = (findingRes.data as FindingRow[]) ?? [];
  const watch: WatchRow[] = (watchRes.data as WatchRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];

  const recentCols: Column<RecentRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '-' },
    { key: 'hospital_org_name', header: 'Hospital', render: (r) => r.hospital_org_name },
    { key: 'equipment_label', header: 'Equipment', render: (r) => r.equipment_label },
    { key: 'handover_completed_at', header: 'Handover', render: (r) => new Date(r.handover_completed_at).toLocaleString() },
    { key: 'photo_count', header: 'Photos', render: (r) => String(r.photo_count) },
    { key: 'quality_score', header: 'Score', render: (r) => r.quality_score == null ? '-' : Number(r.quality_score).toFixed(2) },
    { key: 'quality_band', header: 'Band', render: (r) => r.quality_band },
    { key: 'customer_signoff_captured', header: 'Sign-off', render: (r) => r.customer_signoff_captured ? 'yes' : 'no' },
    { key: 'dispute_risk_flag', header: 'Risk', render: (r) => r.dispute_risk_flag ? 'flag' : '-' },
    { key: 'dispute_raised', header: 'Dispute', render: (r) => r.dispute_raised ? 'yes' : '-' },
  ];

  const bandCols: Column<BandRow>[] = [
    { key: 'quality_band', header: 'Band', render: (r) => r.quality_band },
    { key: 'audit_count', header: 'Audits', render: (r) => String(r.audit_count) },
    { key: 'dispute_count', header: 'Disputes', render: (r) => String(r.dispute_count) },
    { key: 'avg_quality_score', header: 'Avg score', render: (r) => r.avg_quality_score == null ? '-' : Number(r.avg_quality_score).toFixed(2) },
  ];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '-' },
    { key: 'total_handovers', header: 'Handovers', render: (r) => String(r.total_handovers) },
    { key: 'avg_quality_score', header: 'Avg score', render: (r) => r.avg_quality_score == null ? '-' : Number(r.avg_quality_score).toFixed(2) },
    { key: 'poor_count', header: 'Poor', render: (r) => String(r.poor_count) },
    { key: 'dispute_count', header: 'Disputes', render: (r) => String(r.dispute_count) },
    { key: 'signoff_rate', header: 'Sign-off %', render: (r) => r.signoff_rate == null ? '-' : Number(r.signoff_rate).toFixed(1) },
  ];

  const findingCols: Column<FindingRow>[] = [
    { key: 'finding_category', header: 'Category', render: (r) => r.finding_category },
    { key: 'finding_count', header: 'Findings', render: (r) => String(r.finding_count) },
    { key: 'total_occurrences', header: 'Occurrences', render: (r) => String(r.total_occurrences) },
    { key: 'critical_count', header: 'Critical', render: (r) => String(r.critical_count) },
    { key: 'high_count', header: 'High', render: (r) => String(r.high_count) },
  ];

  const watchCols: Column<WatchRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '-' },
    { key: 'hospital_org_name', header: 'Hospital', render: (r) => r.hospital_org_name },
    { key: 'equipment_label', header: 'Equipment', render: (r) => r.equipment_label },
    { key: 'handover_completed_at', header: 'Handover', render: (r) => new Date(r.handover_completed_at).toLocaleString() },
    { key: 'quality_score', header: 'Score', render: (r) => r.quality_score == null ? '-' : Number(r.quality_score).toFixed(2) },
    { key: 'quality_band', header: 'Band', render: (r) => r.quality_band },
    { key: 'dispute_raised', header: 'Dispute', render: (r) => r.dispute_raised ? 'yes' : '-' },
    { key: 'reviewer_notes', header: 'Notes', render: (r) => r.reviewer_notes ?? '-' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_start', header: 'Week', render: (r) => r.week_start },
    { key: 'audit_count', header: 'Audits', render: (r) => String(r.audit_count) },
    { key: 'avg_quality_score', header: 'Avg score', render: (r) => r.avg_quality_score == null ? '-' : Number(r.avg_quality_score).toFixed(2) },
    { key: 'poor_count', header: 'Poor', render: (r) => String(r.poor_count) },
    { key: 'dispute_count', header: 'Disputes', render: (r) => String(r.dispute_count) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 600 }}>Engineer handover photo-quality audit</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Photo evidence quality & customer sign-off coverage at engineer handover — dispute prevention signal.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
        <Stat label="Total audits" value={overview?.total_audits ?? 0} />
        <Stat label="Excellent" value={overview?.excellent_count ?? 0} />
        <Stat label="Good" value={overview?.good_count ?? 0} />
        <Stat label="Marginal" value={overview?.marginal_count ?? 0} />
        <Stat label="Poor" value={overview?.poor_count ?? 0} />
        <Stat label="Dispute risk" value={overview?.dispute_risk_count ?? 0} />
        <Stat label="Disputes raised" value={overview?.disputes_raised ?? 0} />
        <Stat label="Sign-off %" value={overview?.signoff_capture_rate == null ? '-' : Number(overview.signoff_capture_rate).toFixed(1)} />
        <Stat label="Avg score" value={overview?.avg_quality_score == null ? '-' : Number(overview.avg_quality_score).toFixed(2)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent handovers</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r) => r.id}
          emptyMessage="No handover audits recorded yet."
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Quality-band breakdown</h2>
        <DataTable
          rows={bands}
          columns={bandCols}
          rowKey={(r) => r.quality_band}
          emptyMessage="No band data."
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer leaderboard</h2>
        <DataTable
          rows={leaders}
          columns={leaderCols}
          rowKey={(r) => r.engineer_email ?? Math.random().toString()}
          emptyMessage="No engineer data."
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Finding categories</h2>
        <DataTable
          rows={findings}
          columns={findingCols}
          rowKey={(r) => r.finding_category}
          emptyMessage="No findings logged."
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Dispute watchlist</h2>
        <DataTable
          rows={watch}
          columns={watchCols}
          rowKey={(r) => r.audit_id}
          emptyMessage="No dispute risk."
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>12-week trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          rowKey={(r) => r.week_start}
          emptyMessage="No trend data."
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}
