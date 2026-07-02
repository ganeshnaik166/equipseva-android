import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type WeekRow = {
  id: string;
  week_start: string;
  week_end: string;
  total_hours: number;
  customer_pct: number;
  team_pct: number;
  strategy_pct: number;
  admin_pct: number;
  ideal_customer_pct: number;
  ideal_team_pct: number;
  ideal_strategy_pct: number;
  ideal_admin_pct: number;
  customer_gap: number;
  team_gap: number;
  strategy_gap: number;
  admin_gap: number;
  variance_flag: string;
  reviewed_by_coach: boolean;
};

type BucketRow = {
  bucket: string;
  total_hours: number;
  share_pct: number;
  ideal_pct: number;
  gap_pct: number;
};

type EntryRow = {
  id: string;
  logged_on: string;
  bucket: string;
  activity_label: string;
  hours: number;
  related_org: string | null;
  notes: string | null;
};

type VarianceRow = {
  variance_flag: string;
  week_count: number;
  pct_of_weeks: number;
};

type ActivityRow = {
  activity_label: string;
  bucket: string;
  total_hours: number;
  entry_count: number;
};

function fmtGap(n: number) {
  const sign = n > 0 ? '+' : '';
  return `${sign}${n}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [weeksRes, bucketRes, entriesRes, varianceRes, activityRes] = await Promise.all([
    supabase.rpc('founder_time_weeks_list_r2401', { p_limit: 26 }),
    supabase.rpc('founder_time_bucket_rollup_r2401', { p_weeks: 12 }),
    supabase.rpc('founder_time_entries_recent_r2401', { p_limit: 50 }),
    supabase.rpc('founder_time_variance_summary_r2401'),
    supabase.rpc('founder_time_top_activities_r2401', { p_limit: 15 }),
  ]);

  const weeks: WeekRow[] = (weeksRes.data as WeekRow[]) ?? [];
  const buckets: BucketRow[] = (bucketRes.data as BucketRow[]) ?? [];
  const entries: EntryRow[] = (entriesRes.data as EntryRow[]) ?? [];
  const variance: VarianceRow[] = (varianceRes.data as VarianceRow[]) ?? [];
  const activities: ActivityRow[] = (activityRes.data as ActivityRow[]) ?? [];

  const weeksCols: Column<WeekRow>[] = [
    { key: 'week_start', header: 'Week start', render: (r: WeekRow) => r.week_start },
    { key: 'total_hours', header: 'Total hrs', render: (r: WeekRow) => r.total_hours },
    { key: 'customer_pct', header: 'Customer', render: (r: WeekRow) => `${r.customer_pct}% (${fmtGap(r.customer_gap)})` },
    { key: 'team_pct', header: 'Team', render: (r: WeekRow) => `${r.team_pct}% (${fmtGap(r.team_gap)})` },
    { key: 'strategy_pct', header: 'Strategy', render: (r: WeekRow) => `${r.strategy_pct}% (${fmtGap(r.strategy_gap)})` },
    { key: 'admin_pct', header: 'Admin', render: (r: WeekRow) => `${r.admin_pct}% (${fmtGap(r.admin_gap)})` },
    { key: 'variance_flag', header: 'Flag', render: (r: WeekRow) => r.variance_flag },
    { key: 'reviewed_by_coach', header: 'Coach', render: (r: WeekRow) => (r.reviewed_by_coach ? 'reviewed' : 'pending') },
  ];

  const bucketCols: Column<BucketRow>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: BucketRow) => r.bucket },
    { key: 'total_hours', header: 'Hours (12 wk)', render: (r: BucketRow) => r.total_hours },
    { key: 'share_pct', header: 'Actual %', render: (r: BucketRow) => `${r.share_pct}%` },
    { key: 'ideal_pct', header: 'Ideal %', render: (r: BucketRow) => `${r.ideal_pct}%` },
    { key: 'gap_pct', header: 'Gap', render: (r: BucketRow) => fmtGap(r.gap_pct) },
  ];

  const entryCols: Column<EntryRow>[] = [
    { key: 'logged_on', header: 'Date', render: (r: EntryRow) => r.logged_on },
    { key: 'bucket', header: 'Bucket', render: (r: EntryRow) => r.bucket },
    { key: 'activity_label', header: 'Activity', render: (r: EntryRow) => r.activity_label },
    { key: 'hours', header: 'Hrs', render: (r: EntryRow) => r.hours },
    { key: 'related_org', header: 'Org', render: (r: EntryRow) => r.related_org ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: EntryRow) => r.notes ?? '—' },
  ];

  const varCols: Column<VarianceRow>[] = [
    { key: 'variance_flag', header: 'Flag', render: (r: VarianceRow) => r.variance_flag },
    { key: 'week_count', header: 'Weeks', render: (r: VarianceRow) => r.week_count },
    { key: 'pct_of_weeks', header: '% of weeks', render: (r: VarianceRow) => `${r.pct_of_weeks}%` },
  ];

  const actCols: Column<ActivityRow>[] = [
    { key: 'activity_label', header: 'Activity', render: (r: ActivityRow) => r.activity_label },
    { key: 'bucket', header: 'Bucket', render: (r: ActivityRow) => r.bucket },
    { key: 'total_hours', header: 'Total hrs', render: (r: ActivityRow) => r.total_hours },
    { key: 'entry_count', header: 'Entries', render: (r: ActivityRow) => r.entry_count },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder weekly time-allocation tracker</h1>
        <p className="text-sm text-gray-600">
          Where founder hours went each week vs ideal allocation. Customer / team / strategy / admin
          buckets, gap-to-ideal, and variance flags to catch admin overload & strategy starvation.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">12-week bucket rollup</h2>
        <DataTable rows={buckets} emptyMessage="No time logged yet." rowKey={(r: BucketRow) => r.bucket} columns={bucketCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Weekly allocation (last 26 weeks)</h2>
        <DataTable rows={weeks} emptyMessage="No weeks recorded." rowKey={(r: WeekRow) => r.id} columns={weeksCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Variance flag breakdown</h2>
        <DataTable rows={variance} emptyMessage="No variance data." rowKey={(r: VarianceRow) => r.variance_flag} columns={varCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top activity labels by hours</h2>
        <DataTable rows={activities} emptyMessage="No activity data." rowKey={(r: ActivityRow) => `${r.bucket}:${r.activity_label}`} columns={actCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent time entries</h2>
        <DataTable rows={entries} emptyMessage="No entries logged." rowKey={(r: EntryRow) => r.id} columns={entryCols} />
      </section>
    </main>
  );
}
