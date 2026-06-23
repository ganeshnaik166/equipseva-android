import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [bidsRes, compRes, topRes, funnelRes, posRes, monthRes, threatsRes] = await Promise.all([
    sb.rpc('list_bids_r2515'),
    sb.rpc('list_competitor_analysis_r2515'),
    sb.rpc('top_value_bids_r2515'),
    sb.rpc('decision_funnel_r2515'),
    sb.rpc('our_position_distribution_r2515'),
    sb.rpc('monthly_bid_trend_r2515'),
    sb.rpc('top_competitor_threats_r2515'),
  ]);

  const bids: any[] = (bidsRes.data as any[] | null) ?? [];
  const comps: any[] = (compRes.data as any[] | null) ?? [];
  const top: any[] = (topRes.data as any[] | null) ?? [];
  const funnel: any[] = (funnelRes.data as any[] | null) ?? [];
  const pos: any[] = (posRes.data as any[] | null) ?? [];
  const month: any[] = (monthRes.data as any[] | null) ?? [];
  const threats: any[] = (threatsRes.data as any[] | null) ?? [];

  const fmt = (n: number | null | undefined): string => {
    if (n == null) return '—';
    return '₹' + Number(n).toLocaleString('en-IN');
  };

  const bidCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'tender_external_ref', header: 'Tender', render: (r: any) => r.tender_external_ref },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => r.submitted_at ? String(r.submitted_at).slice(0, 10) : '—' },
    { key: 'bid_amount_rupees', header: 'Our bid', render: (r: any) => fmt(r.bid_amount_rupees) },
    { key: 'technical_score', header: 'Tech', render: (r: any) => r.technical_score },
    { key: 'commercial_score', header: 'Comm', render: (r: any) => r.commercial_score },
    { key: 'competitor_count', header: 'Competitors', render: (r: any) => r.competitor_count },
    { key: 'our_position', header: 'Position', render: (r: any) => r.our_position },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const compCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'tender_external_ref', header: 'Tender', render: (r: any) => r.tender_external_ref },
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'competitor_bid_rupees', header: 'Their bid', render: (r: any) => fmt(r.competitor_bid_rupees) },
    { key: 'competitor_position', header: 'Their pos', render: (r: any) => r.competitor_position },
    { key: 'our_counter_strategy_md', header: 'Counter strategy', render: (r: any) => r.our_counter_strategy_md ?? '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'tender_external_ref', header: 'Tender', render: (r: any) => r.tender_external_ref },
    { key: 'bid_amount_rupees', header: 'Our bid', render: (r: any) => fmt(r.bid_amount_rupees) },
    { key: 'our_position', header: 'Position', render: (r: any) => r.our_position },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision },
    { key: 'bid_count', header: 'Bids', render: (r: any) => r.bid_count },
    { key: 'total_value_rupees', header: 'Total value', render: (r: any) => fmt(r.total_value_rupees) },
    { key: 'avg_technical_score', header: 'Avg tech', render: (r: any) => r.avg_technical_score },
    { key: 'avg_commercial_score', header: 'Avg comm', render: (r: any) => r.avg_commercial_score },
  ];

  const posCols: Column<any>[] = [
    { key: 'our_position', header: 'Position', render: (r: any) => r.our_position },
    { key: 'bid_count', header: 'Bids', render: (r: any) => r.bid_count },
    { key: 'total_value_rupees', header: 'Total value', render: (r: any) => fmt(r.total_value_rupees) },
    { key: 'won_count', header: 'Won', render: (r: any) => r.won_count },
    { key: 'lost_count', header: 'Lost', render: (r: any) => r.lost_count },
  ];

  const monthCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? String(r.month_start).slice(0, 7) : '—' },
    { key: 'bid_count', header: 'Bids', render: (r: any) => r.bid_count },
    { key: 'total_value_rupees', header: 'Total', render: (r: any) => fmt(r.total_value_rupees) },
    { key: 'won_value_rupees', header: 'Won', render: (r: any) => fmt(r.won_value_rupees) },
    { key: 'lost_value_rupees', header: 'Lost', render: (r: any) => fmt(r.lost_value_rupees) },
    { key: 'pending_value_rupees', header: 'Pending', render: (r: any) => fmt(r.pending_value_rupees) },
  ];

  const threatCols: Column<any>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'appearances', header: 'Appearances', render: (r: any) => r.appearances },
    { key: 'avg_position', header: 'Avg position', render: (r: any) => r.avg_position },
    { key: 'total_competitor_value_rupees', header: 'Their total bids', render: (r: any) => fmt(r.total_competitor_value_rupees) },
    { key: 'l1_count', header: 'L1 wins', render: (r: any) => r.l1_count },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Bid Response Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Tender bids against hospital chains: our bid value, technical & commercial scores, competitor count, our L1/L2/L3 position, and the final decision.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All bids ({bids.length})</h2>
        <DataTable rows={bids} columns={bidCols} rowKey={(r: any, i: number) => String(r.id ?? i)} emptyMessage="No bids submitted yet." />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Competitor analysis ({comps.length})</h2>
        <DataTable rows={comps} columns={compCols} rowKey={(r: any, i: number) => String(r.id ?? i)} emptyMessage="No competitor analyses captured." />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top value bids ({top.length})</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} emptyMessage="No bids ranked by value." />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Decision funnel ({funnel.length})</h2>
        <DataTable rows={funnel} columns={funnelCols} rowKey={(r: any, i: number) => String(r.decision ?? i)} emptyMessage="No decisions yet." />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Our position distribution ({pos.length})</h2>
        <DataTable rows={pos} columns={posCols} rowKey={(r: any, i: number) => String(r.our_position ?? i)} emptyMessage="No position data." />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly bid trend ({month.length})</h2>
        <DataTable rows={month} columns={monthCols} rowKey={(r: any, i: number) => String(r.month_start ?? i)} emptyMessage="No monthly data." />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top competitor threats ({threats.length})</h2>
        <DataTable rows={threats} columns={threatCols} rowKey={(r: any, i: number) => String(r.competitor_name ?? i)} emptyMessage="No competitor threats." />
      </section>
    </div>
  );
}
