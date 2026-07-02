import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + new Intl.NumberFormat('en-IN').format(n);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }); }
  catch { return s; }
}

export default async function FounderHospitalSalesReferralPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = null;
  let topReferrers: any[] = [];
  let pipeline: any[] = [];
  let stalled: any[] = [];
  let bountyQueue: any[] = [];
  let recentWins: any[] = [];

  try {
    const r = await sb.rpc('founder_referral_funnel_summary');
    summary = (r.data && r.data[0]) || null;
  } catch { summary = null; }

  try {
    const r = await sb.rpc('founder_referral_top_referrers');
    topReferrers = r.data || [];
  } catch { topReferrers = []; }

  try {
    const r = await sb.rpc('founder_referral_pipeline');
    pipeline = r.data || [];
  } catch { pipeline = []; }

  try {
    const r = await sb.rpc('founder_referral_stalled');
    stalled = r.data || [];
  } catch { stalled = []; }

  try {
    const r = await sb.rpc('founder_referral_bounty_queue');
    bountyQueue = r.data || [];
  } catch { bountyQueue = []; }

  try {
    const r = await sb.rpc('founder_referral_recent_wins');
    recentWins = r.data || [];
  } catch { recentWins = []; }

  const totalRef = summary?.total_referrals ?? 0;
  const submitted = summary?.submitted ?? 0;
  const contacted = summary?.contacted ?? 0;
  const met = summary?.met ?? 0;
  const negotiating = summary?.negotiating ?? 0;
  const closedWon = summary?.closed_won ?? 0;
  const lost = summary?.lost ?? 0;
  const conv = summary?.conversion_rate_pct ?? 0;
  const bountyPending = summary?.total_bounty_pending_rupees ?? 0;
  const bountyPaid = summary?.total_bounty_paid_rupees ?? 0;

  const queuedCount = bountyQueue.filter((p) => p.status === 'queued').length;
  const processingCount = bountyQueue.filter((p) => p.status === 'processing').length;
  const paidCount = bountyQueue.filter((p) => p.status === 'paid').length;
  const failedCount = bountyQueue.filter((p) => p.status === 'failed').length;
  const stalledCount = stalled.length;
  const activeReferrers = topReferrers.length;

  const kpis: Kpi[] = [
    { label: 'Total Referrals', value: fmtInt(totalRef) },
    { label: 'Submitted', value: fmtInt(submitted) },
    { label: 'Contacted', value: fmtInt(contacted) },
    { label: 'Met', value: fmtInt(met) },
    { label: 'Negotiating', value: fmtInt(negotiating) },
    { label: 'Closed Won', value: fmtInt(closedWon) },
    { label: 'Lost', value: fmtInt(lost) },
    { label: 'Conversion Rate', value: (conv ?? 0) + '%' },
    { label: 'Bounty Pending', value: fmtRupees(bountyPending) },
    { label: 'Bounty Paid', value: fmtRupees(bountyPaid) },
    { label: 'Active Referrers', value: fmtInt(activeReferrers) },
    { label: 'Stalled Funnel', value: fmtInt(stalledCount) },
    { label: 'Payouts Queued', value: fmtInt(queuedCount) },
    { label: 'Payouts Processing', value: fmtInt(processingCount) },
    { label: 'Payouts Paid', value: fmtInt(paidCount) },
    { label: 'Payouts Failed', value: fmtInt(failedCount) },
  ];

  const topReferrersCols: Column<any>[] = [
    { key: 'referrer_org_name', header: 'Referrer Hospital', render: (r: any) => r.referrer_org_name ?? '—' },
    { key: 'referrer_city', header: 'City', render: (r: any) => r.referrer_city ?? '—' },
    { key: 'total_referrals', header: 'Total', render: (r: any) => fmtInt(r.total_referrals) },
    { key: 'closed_referrals', header: 'Closed', render: (r: any) => fmtInt(r.closed_referrals) },
    { key: 'bounty_earned_rupees', header: 'Bounty Earned', render: (r: any) => fmtRupees(r.bounty_earned_rupees) },
    { key: 'bounty_paid_rupees', header: 'Bounty Paid', render: (r: any) => fmtRupees(r.bounty_paid_rupees) },
    { key: 'last_referral_at', header: 'Last Referral', render: (r: any) => fmtDate(r.last_referral_at) },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'referrer_org_name', header: 'Referrer', render: (r: any) => r.referrer_org_name ?? '—' },
    { key: 'referee_org_name', header: 'Referee', render: (r: any) => r.referee_org_name ?? '—' },
    { key: 'referee_city', header: 'City', render: (r: any) => r.referee_city ?? '—' },
    { key: 'referee_state', header: 'State', render: (r: any) => r.referee_state ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'expected_amc_tier', header: 'Expected Tier', render: (r: any) => r.expected_amc_tier ?? '—' },
    { key: 'expected_monthly_fee_rupees', header: 'Expected MRR', render: (r: any) => fmtRupees(r.expected_monthly_fee_rupees) },
    { key: 'days_in_funnel', header: 'Days in Funnel', render: (r: any) => (r.days_in_funnel ?? 0) + 'd' },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const stalledCols: Column<any>[] = [
    { key: 'referrer_org_name', header: 'Referrer', render: (r: any) => r.referrer_org_name ?? '—' },
    { key: 'referee_org_name', header: 'Referee', render: (r: any) => r.referee_org_name ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'days_stalled', header: 'Days Stalled', render: (r: any) => (r.days_stalled ?? 0) + 'd' },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
  ];

  const bountyCols: Column<any>[] = [
    { key: 'referrer_org_name', header: 'Referrer', render: (r: any) => r.referrer_org_name ?? '—' },
    { key: 'referee_org_name', header: 'Referee', render: (r: any) => r.referee_org_name ?? '—' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'queued_at', header: 'Queued', render: (r: any) => fmtDate(r.queued_at) },
    { key: 'days_in_queue', header: 'Days in Queue', render: (r: any) => (r.days_in_queue ?? 0) + 'd' },
    { key: 'payout_method', header: 'Method', render: (r: any) => r.payout_method ?? '—' },
  ];

  const winsCols: Column<any>[] = [
    { key: 'referrer_org_name', header: 'Referrer', render: (r: any) => r.referrer_org_name ?? '—' },
    { key: 'referee_org_name', header: 'Referee', render: (r: any) => r.referee_org_name ?? '—' },
    { key: 'expected_amc_tier', header: 'Tier', render: (r: any) => r.expected_amc_tier ?? '—' },
    { key: 'expected_monthly_fee_rupees', header: 'MRR', render: (r: any) => fmtRupees(r.expected_monthly_fee_rupees) },
    { key: 'bounty_rupees', header: 'Bounty', render: (r: any) => fmtRupees(r.bounty_rupees) },
    { key: 'bounty_status', header: 'Bounty Status', render: (r: any) => r.bounty_status ?? '—' },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Sales Referral Tracker</h1>
        <p className="text-sm text-gray-500">Hospital-to-hospital referrals, funnel status, and bounty payout queue.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {kpis.map((k) => (
            <div key={k.label} className="rounded-md border bg-white p-3">
              <div className="text-xs text-gray-500">{k.label}</div>
              <div className="text-lg font-semibold">{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Top Referrer Hospitals</h2>
        <DataTable
          rows={topReferrers}
          columns={topReferrersCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Active Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Stalled (more than 7 days)</h2>
        <DataTable
          rows={stalled}
          columns={stalledCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Bounty Payout Queue</h2>
        <DataTable
          rows={bountyQueue}
          columns={bountyCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent Wins</h2>
        <DataTable
          rows={recentWins}
          columns={winsCols}
          rowKey={(r: any) => r.id}
        />
      </section>
    </main>
  );
}
