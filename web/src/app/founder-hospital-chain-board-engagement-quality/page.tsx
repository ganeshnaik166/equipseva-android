import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [engagementsRes, followUpsRes, topDealRes, kindSummaryRes, dealDistRes, monthlyTrendRes, ownerLoadRes] = await Promise.all([
    supabase.rpc('list_engagements_r2559'),
    supabase.rpc('list_follow_ups_r2559'),
    supabase.rpc('top_deal_advancement_r2559'),
    supabase.rpc('engagement_kind_summary_r2559'),
    supabase.rpc('deal_advancement_distribution_r2559'),
    supabase.rpc('monthly_engagement_trend_r2559'),
    supabase.rpc('owner_load_r2559'),
  ]);

  const engagements = (engagementsRes.data ?? []) as any[];
  const followUps = (followUpsRes.data ?? []) as any[];
  const topDeals = (topDealRes.data ?? []) as any[];
  const kindSummary = (kindSummaryRes.data ?? []) as any[];
  const dealDist = (dealDistRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const fmtDate = (d: string | null) => (d ? new Date(d).toLocaleString('en-IN') : '-');
  const fmtMonth = (d: string | null) => (d ? new Date(d).toLocaleDateString('en-IN', { month: 'short', year: 'numeric' }) : '-');
  const fmtRupees = (n: number | null) => `₹${Number(n ?? 0).toLocaleString('en-IN')}`;

  const engagementCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'board_exposure_at', header: 'Board Exposure', render: (r: any) => fmtDate(r.board_exposure_at) },
    { key: 'engagement_kind', header: 'Kind', render: (r: any) => r.engagement_kind },
    { key: 'engagement_score', header: 'Score', render: (r: any) => r.engagement_score },
    { key: 'deal_advancement_kind', header: 'Advancement', render: (r: any) => r.deal_advancement_kind },
    { key: 'arr_advanced_rupees', header: 'ARR Advanced', render: (r: any) => fmtRupees(r.arr_advanced_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const followUpCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'follow_up_at', header: 'Follow-Up At', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'follow_up_kind', header: 'Kind', render: (r: any) => r.follow_up_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topDealCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'engagement_count', header: 'Engagements', render: (r: any) => r.engagement_count },
    { key: 'total_arr_rupees', header: 'Total ARR Advanced', render: (r: any) => fmtRupees(r.total_arr_rupees) },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => r.avg_score },
  ];

  const kindSummaryCols: Column<any>[] = [
    { key: 'engagement_kind', header: 'Kind', render: (r: any) => r.engagement_kind },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => r.avg_score },
    { key: 'total_arr_rupees', header: 'Total ARR', render: (r: any) => fmtRupees(r.total_arr_rupees) },
  ];

  const dealDistCols: Column<any>[] = [
    { key: 'deal_advancement_kind', header: 'Advancement', render: (r: any) => r.deal_advancement_kind },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
    { key: 'total_arr_rupees', header: 'Total ARR', render: (r: any) => fmtRupees(r.total_arr_rupees) },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'n', header: 'Engagements', render: (r: any) => r.n },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => r.avg_score },
    { key: 'total_arr_rupees', header: 'Total ARR', render: (r: any) => fmtRupees(r.total_arr_rupees) },
  ];

  const ownerLoadCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'engagements', header: 'Engagements', render: (r: any) => r.engagements },
    { key: 'follow_ups', header: 'Follow-Ups', render: (r: any) => r.follow_ups },
    { key: 'open_follow_ups', header: 'Open', render: (r: any) => r.open_follow_ups },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Board Engagement Quality</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Chain &gt; board exposure &gt; our board reach &gt; engagement &gt; deal advancement.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Engagements</h2>
        <DataTable
          rows={engagements}
          columns={engagementCols}
          emptyMessage="No engagements yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Follow-Ups</h2>
        <DataTable
          rows={followUps}
          columns={followUpCols}
          emptyMessage="No follow-ups yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Deal Advancement by Chain</h2>
        <DataTable
          rows={topDeals}
          columns={topDealCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Engagement Kind Summary</h2>
        <DataTable
          rows={kindSummary}
          columns={kindSummaryCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.engagement_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Deal Advancement Distribution</h2>
        <DataTable
          rows={dealDist}
          columns={dealDistCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.deal_advancement_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Engagement Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerLoadCols}
          emptyMessage="No owners"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
