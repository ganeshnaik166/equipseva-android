import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainCoMarketingDealsPage() {
  const supabase = await getSupabaseServerClient();

  const [dealsRes, leadsRes, topRoiRes, kindSummaryRes, monthlyTrendRes, topChainsRes, statusFunnelRes] = await Promise.all([
    supabase.rpc('list_co_marketing_deals_r2487'),
    supabase.rpc('list_lead_attributions_r2487'),
    supabase.rpc('top_roi_campaigns_r2487'),
    supabase.rpc('campaign_kind_summary_r2487'),
    supabase.rpc('monthly_lead_trend_r2487'),
    supabase.rpc('top_chains_by_roi_r2487'),
    supabase.rpc('status_funnel_r2487'),
  ]);

  const deals = (dealsRes.data ?? []) as any[];
  const leads = (leadsRes.data ?? []) as any[];
  const topRoi = (topRoiRes.data ?? []) as any[];
  const kindSummary = (kindSummaryRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const topChains = (topChainsRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];

  const fmtRupees = (v: any) => {
    const n = Number(v ?? 0);
    return '₹' + n.toLocaleString('en-IN');
  };
  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString('en-IN') : '—');
  const fmtMonth = (v: any) => (v ? new Date(v).toLocaleDateString('en-IN', { year: 'numeric', month: 'short' }) : '—');

  const dealCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'campaign_name', header: 'Campaign', render: (r: any) => r.campaign_name },
    { key: 'campaign_kind', header: 'Kind', render: (r: any) => r.campaign_kind },
    { key: 'started_at', header: 'Started', render: (r: any) => fmtDate(r.started_at) },
    { key: 'ended_at', header: 'Ended', render: (r: any) => fmtDate(r.ended_at) },
    { key: 'our_spend_rupees', header: 'Our Spend', render: (r: any) => fmtRupees(r.our_spend_rupees) },
    { key: 'their_spend_rupees', header: 'Their Spend', render: (r: any) => fmtRupees(r.their_spend_rupees) },
    { key: 'leads_generated', header: 'Leads', render: (r: any) => r.leads_generated },
    { key: 'deals_influenced_rupees', header: 'Influenced', render: (r: any) => fmtRupees(r.deals_influenced_rupees) },
    { key: 'roi_multiple', header: 'ROI', render: (r: any) => Number(r.roi_multiple ?? 0).toFixed(2) + 'x' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const leadCols: Column<any>[] = [
    { key: 'lead_at', header: 'Lead At', render: (r: any) => fmtDate(r.lead_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'campaign_name', header: 'Campaign', render: (r: any) => r.campaign_name },
    { key: 'lead_kind', header: 'Kind', render: (r: any) => r.lead_kind },
    { key: 'lead_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.lead_value_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topRoiCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'campaign_name', header: 'Campaign', render: (r: any) => r.campaign_name },
    { key: 'campaign_kind', header: 'Kind', render: (r: any) => r.campaign_kind },
    { key: 'total_spend_rupees', header: 'Total Spend', render: (r: any) => fmtRupees(r.total_spend_rupees) },
    { key: 'deals_influenced_rupees', header: 'Influenced', render: (r: any) => fmtRupees(r.deals_influenced_rupees) },
    { key: 'roi_multiple', header: 'ROI', render: (r: any) => Number(r.roi_multiple ?? 0).toFixed(2) + 'x' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindCols: Column<any>[] = [
    { key: 'campaign_kind', header: 'Kind', render: (r: any) => r.campaign_kind },
    { key: 'campaign_count', header: 'Count', render: (r: any) => r.campaign_count },
    { key: 'total_our_spend', header: 'Our Spend', render: (r: any) => fmtRupees(r.total_our_spend) },
    { key: 'total_their_spend', header: 'Their Spend', render: (r: any) => fmtRupees(r.total_their_spend) },
    { key: 'total_leads', header: 'Leads', render: (r: any) => r.total_leads },
    { key: 'total_influenced', header: 'Influenced', render: (r: any) => fmtRupees(r.total_influenced) },
    { key: 'avg_roi', header: 'Avg ROI', render: (r: any) => Number(r.avg_roi ?? 0).toFixed(2) + 'x' },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'lead_count', header: 'Leads', render: (r: any) => r.lead_count },
    { key: 'total_lead_value', header: 'Lead Value', render: (r: any) => fmtRupees(r.total_lead_value) },
    { key: 'closed_won_count', header: 'Won', render: (r: any) => r.closed_won_count },
    { key: 'closed_won_value', header: 'Won Value', render: (r: any) => fmtRupees(r.closed_won_value) },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'campaign_count', header: 'Campaigns', render: (r: any) => r.campaign_count },
    { key: 'total_spend', header: 'Total Spend', render: (r: any) => fmtRupees(r.total_spend) },
    { key: 'total_influenced', header: 'Influenced', render: (r: any) => fmtRupees(r.total_influenced) },
    { key: 'avg_roi', header: 'Avg ROI', render: (r: any) => Number(r.avg_roi ?? 0).toFixed(2) + 'x' },
    { key: 'total_leads', header: 'Leads', render: (r: any) => r.total_leads },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'campaign_count', header: 'Count', render: (r: any) => r.campaign_count },
    { key: 'total_spend', header: 'Total Spend', render: (r: any) => fmtRupees(r.total_spend) },
    { key: 'total_influenced', header: 'Influenced', render: (r: any) => fmtRupees(r.total_influenced) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Co-Marketing Deals</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Chain & co-marketing campaign & spend split & leads generated & deals influenced & ROI.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Co-Marketing Deals</h2>
        <DataTable
          rows={deals}
          columns={dealCols}
          emptyMessage="No co-marketing deals logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top ROI Campaigns</h2>
        <DataTable
          rows={topRoi}
          columns={topRoiCols}
          emptyMessage="No campaigns ranked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Chains by ROI</h2>
        <DataTable
          rows={topChains}
          columns={chainCols}
          emptyMessage="No chains ranked yet."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Campaign Kind Summary</h2>
        <DataTable
          rows={kindSummary}
          columns={kindCols}
          emptyMessage="No campaign kinds tracked."
          rowKey={(r: any, i: number) => String(r.campaign_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Monthly Lead Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyCols}
          emptyMessage="No lead trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Lead Attributions</h2>
        <DataTable
          rows={leads}
          columns={leadCols}
          emptyMessage="No lead attributions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
