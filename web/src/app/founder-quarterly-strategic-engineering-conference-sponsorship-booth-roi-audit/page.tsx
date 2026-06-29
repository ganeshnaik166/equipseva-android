import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Sponsorship = {
  id: string;
  conference_name: string;
  host_org: string;
  city: string;
  start_date: string;
  end_date: string;
  tier: string;
  total_invested_rupees: number;
  closed_won_rupees: number;
  roi_multiple: number;
  payback_days: number | null;
  nps_score: number | null;
  status: string;
};

type RoiRow = {
  conference_name: string;
  city: string;
  tier: string;
  total_invested_rupees: number;
  closed_won_rupees: number;
  roi_multiple: number;
  payback_days: number | null;
  rank: number;
};

type TierRow = {
  tier: string;
  events: number;
  total_invested: number;
  total_pipeline: number;
  total_closed: number;
  avg_roi: number;
  avg_nps: number | null;
};

type CityRow = {
  city: string;
  events: number;
  total_invested: number;
  total_closed: number;
  avg_roi: number;
  audited_events: number;
};

type ActivityRow = {
  conference_name: string;
  total_hours: number;
  total_demos: number;
  total_hot_leads: number;
  total_warm_leads: number;
  total_scans: number;
  avg_rating: number | null;
  best_cpl_rupees: number | null;
};

type UnderRow = {
  conference_name: string;
  city: string;
  tier: string;
  roi_multiple: number;
  total_invested: number;
  closed_won: number;
  reason: string;
};

type FunnelRow = {
  stage: string;
  count_value: number;
  rupee_value: number;
};

type QuarterRow = {
  quarter: string;
  events: number;
  invested: number;
  closed_won: number;
  blended_roi: number;
  avg_nps: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, leaderboard, tiers, cities, activity, under, funnel, quarters] = await Promise.all([
    supabase.rpc('founder_r3029_sponsorships_overview'),
    supabase.rpc('founder_r3029_roi_leaderboard'),
    supabase.rpc('founder_r3029_tier_summary'),
    supabase.rpc('founder_r3029_city_breakdown'),
    supabase.rpc('founder_r3029_booth_activity_rollup'),
    supabase.rpc('founder_r3029_underperformers'),
    supabase.rpc('founder_r3029_pipeline_funnel'),
    supabase.rpc('founder_r3029_quarter_health'),
  ]);

  const sponsorships: Sponsorship[] = (overview.data as Sponsorship[]) ?? [];
  const roi: RoiRow[] = (leaderboard.data as RoiRow[]) ?? [];
  const tierRows: TierRow[] = (tiers.data as TierRow[]) ?? [];
  const cityRows: CityRow[] = (cities.data as CityRow[]) ?? [];
  const activityRows: ActivityRow[] = (activity.data as ActivityRow[]) ?? [];
  const underRows: UnderRow[] = (under.data as UnderRow[]) ?? [];
  const funnelRows: FunnelRow[] = (funnel.data as FunnelRow[]) ?? [];
  const quarterRows: QuarterRow[] = (quarters.data as QuarterRow[]) ?? [];

  const fmt = (n: number | null | undefined) =>
    n == null ? '—' : '₹' + Number(n).toLocaleString('en-IN');

  const spCols: Column<Sponsorship>[] = [
    { header: 'Conference', accessor: (r) => r.conference_name },
    { header: 'Host', accessor: (r) => r.host_org },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Tier', accessor: (r) => r.tier },
    { header: 'Start', accessor: (r) => r.start_date },
    { header: 'Invested', accessor: (r) => fmt(r.total_invested_rupees) },
    { header: 'Closed', accessor: (r) => fmt(r.closed_won_rupees) },
    { header: 'ROI x', accessor: (r) => r.roi_multiple },
    { header: 'Payback (d)', accessor: (r) => r.payback_days ?? '—' },
    { header: 'NPS', accessor: (r) => r.nps_score ?? '—' },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const roiCols: Column<RoiRow>[] = [
    { header: 'Rank', accessor: (r) => r.rank },
    { header: 'Conference', accessor: (r) => r.conference_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Tier', accessor: (r) => r.tier },
    { header: 'Invested', accessor: (r) => fmt(r.total_invested_rupees) },
    { header: 'Closed', accessor: (r) => fmt(r.closed_won_rupees) },
    { header: 'ROI x', accessor: (r) => r.roi_multiple },
    { header: 'Payback (d)', accessor: (r) => r.payback_days ?? '—' },
  ];

  const tierCols: Column<TierRow>[] = [
    { header: 'Tier', accessor: (r) => r.tier },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Invested', accessor: (r) => fmt(r.total_invested) },
    { header: 'Pipeline', accessor: (r) => fmt(r.total_pipeline) },
    { header: 'Closed', accessor: (r) => fmt(r.total_closed) },
    { header: 'Avg ROI', accessor: (r) => r.avg_roi },
    { header: 'Avg NPS', accessor: (r) => r.avg_nps ?? '—' },
  ];

  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Invested', accessor: (r) => fmt(r.total_invested) },
    { header: 'Closed', accessor: (r) => fmt(r.total_closed) },
    { header: 'Avg ROI', accessor: (r) => r.avg_roi },
    { header: 'Audited', accessor: (r) => r.audited_events },
  ];

  const actCols: Column<ActivityRow>[] = [
    { header: 'Conference', accessor: (r) => r.conference_name },
    { header: 'Hours', accessor: (r) => r.total_hours },
    { header: 'Demos', accessor: (r) => r.total_demos },
    { header: 'Hot', accessor: (r) => r.total_hot_leads },
    { header: 'Warm', accessor: (r) => r.total_warm_leads },
    { header: 'Scans', accessor: (r) => r.total_scans },
    { header: 'Avg Rating', accessor: (r) => r.avg_rating ?? '—' },
    { header: 'Best CPL', accessor: (r) => fmt(r.best_cpl_rupees) },
  ];

  const underCols: Column<UnderRow>[] = [
    { header: 'Conference', accessor: (r) => r.conference_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Tier', accessor: (r) => r.tier },
    { header: 'ROI x', accessor: (r) => r.roi_multiple },
    { header: 'Invested', accessor: (r) => fmt(r.total_invested) },
    { header: 'Closed', accessor: (r) => fmt(r.closed_won) },
    { header: 'Reason', accessor: (r) => r.reason },
  ];

  const funnelCols: Column<FunnelRow>[] = [
    { header: 'Stage', accessor: (r) => r.stage },
    { header: 'Count', accessor: (r) => r.count_value },
    { header: 'Rupee Value', accessor: (r) => fmt(r.rupee_value) },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Invested', accessor: (r) => fmt(r.invested) },
    { header: 'Closed', accessor: (r) => fmt(r.closed_won) },
    { header: 'Blended ROI', accessor: (r) => r.blended_roi },
    { header: 'Avg NPS', accessor: (r) => r.avg_nps ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Quarterly Strategic Engineering Conference Sponsorship &amp; Booth ROI Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Audit every sponsored engineering conference — sponsorship spend, booth activity, leads, pipeline, closed-won &amp; payback. ROI &gt;= 1.5x is the bar.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Sponsorships</h2>
        <DataTable
          rows={sponsorships}
          columns={spCols}
          emptyMessage="No sponsorships yet"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>ROI Leaderboard (Audited)</h2>
        <DataTable
          rows={roi}
          columns={roiCols}
          emptyMessage="No audited events yet"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tier Summary</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>City Breakdown</h2>
        <DataTable
          rows={cityRows}
          columns={cityCols}
          emptyMessage="No city data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Booth Activity Rollup</h2>
        <DataTable
          rows={activityRows}
          columns={actCols}
          emptyMessage="No booth activity logged"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Underperformers (ROI &lt; 1.5x or NPS &lt; 40)</h2>
        <DataTable
          rows={underRows}
          columns={underCols}
          emptyMessage="No underperformers — every audited event cleared the bar"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pipeline Funnel (Audited)</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No funnel data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarter Health</h2>
        <DataTable
          rows={quarterRows}
          columns={quarterCols}
          emptyMessage="No quarter data"
          rowKey={(r, i) => String(i)}
        />
      </section>
    </main>
  );
}
