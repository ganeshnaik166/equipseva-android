import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ReferralLink = {
  id: string;
  referred_customer_id: string;
  referred_customer_email: string | null;
  source_customer_id: string;
  source_customer_email: string | null;
  referral_code: string;
  referral_channel: string;
  signed_up_at: string;
  first_paid_job_at: string | null;
  lifetime_revenue_paise: number;
  job_count: number;
  status: string;
  notes: string | null;
  created_at: string;
};

type BonusPayout = {
  id: string;
  referral_link_id: string;
  source_customer_id: string;
  source_customer_email: string | null;
  bonus_amount_paise: number;
  bonus_type: string;
  trigger_revenue_paise: number;
  status: string;
  approved_by_email: string | null;
  approved_at: string | null;
  paid_at: string | null;
  payment_reference: string | null;
  notes: string | null;
  created_at: string;
};

type TopReferrer = {
  source_customer_id: string;
  source_customer_email: string | null;
  total_referred: number;
  active_referred: number;
  total_lifetime_revenue_paise: number;
  total_bonus_paid_paise: number;
  bonus_pending_paise: number;
};

type Totals = {
  total_links: number;
  active_links: number;
  pending_links: number;
  churned_links: number;
  total_lifetime_revenue_paise: number;
  total_bonus_paid_paise: number;
  total_bonus_pending_paise: number;
  unique_referrers: number;
  avg_revenue_per_link_paise: number;
};

function rupees(paise: number | null | undefined): string {
  const v = Number(paise ?? 0);
  return '₹' + (v / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [linksRes, bonusRes, topRes, totalsRes] = await Promise.all([
    sb.rpc('founder_r2288_list_referral_links'),
    sb.rpc('founder_r2288_list_bonus_payouts'),
    sb.rpc('founder_r2288_top_referrers'),
    sb.rpc('founder_r2288_program_totals'),
  ]);

  const links: ReferralLink[] = (linksRes.data as ReferralLink[] | null) ?? [];
  const bonuses: BonusPayout[] = (bonusRes.data as BonusPayout[] | null) ?? [];
  const top: TopReferrer[] = (topRes.data as TopReferrer[] | null) ?? [];
  const totalsRow = (totalsRes.data as Totals[] | null)?.[0];
  const totals: Totals = totalsRow ?? {
    total_links: 0,
    active_links: 0,
    pending_links: 0,
    churned_links: 0,
    total_lifetime_revenue_paise: 0,
    total_bonus_paid_paise: 0,
    total_bonus_pending_paise: 0,
    unique_referrers: 0,
    avg_revenue_per_link_paise: 0,
  };

  const linkCols: Column<ReferralLink>[] = [
    { key: 'referred_customer_email', header: 'Referred', render: (r) => r.referred_customer_email ?? r.referred_customer_id.slice(0, 8) },
    { key: 'source_customer_email', header: 'Source', render: (r) => r.source_customer_email ?? r.source_customer_id.slice(0, 8) },
    { key: 'referral_channel', header: 'Channel', render: (r) => r.referral_channel },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'lifetime_revenue_paise', header: 'Lifetime Revenue', render: (r) => rupees(r.lifetime_revenue_paise) },
    { key: 'job_count', header: 'Jobs', render: (r) => String(r.job_count) },
    { key: 'signed_up_at', header: 'Signed Up', render: (r) => new Date(r.signed_up_at).toLocaleDateString('en-IN') },
  ];

  const bonusCols: Column<BonusPayout>[] = [
    { key: 'source_customer_email', header: 'Source Customer', render: (r) => r.source_customer_email ?? r.source_customer_id.slice(0, 8) },
    { key: 'bonus_type', header: 'Type', render: (r) => r.bonus_type },
    { key: 'bonus_amount_paise', header: 'Amount', render: (r) => rupees(r.bonus_amount_paise) },
    { key: 'trigger_revenue_paise', header: 'Trigger Revenue', render: (r) => rupees(r.trigger_revenue_paise) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'approved_by_email', header: 'Approved By', render: (r) => r.approved_by_email ?? '—' },
    { key: 'paid_at', header: 'Paid At', render: (r) => (r.paid_at ? new Date(r.paid_at).toLocaleDateString('en-IN') : '—') },
    { key: 'payment_reference', header: 'Ref', render: (r) => r.payment_reference ?? '—' },
  ];

  const topCols: Column<TopReferrer>[] = [
    { key: 'source_customer_email', header: 'Referrer', render: (r) => r.source_customer_email ?? r.source_customer_id.slice(0, 8) },
    { key: 'total_referred', header: 'Total Referred', render: (r) => String(r.total_referred) },
    { key: 'active_referred', header: 'Active', render: (r) => String(r.active_referred) },
    { key: 'total_lifetime_revenue_paise', header: 'Revenue Driven', render: (r) => rupees(r.total_lifetime_revenue_paise) },
    { key: 'total_bonus_paid_paise', header: 'Bonus Paid', render: (r) => rupees(r.total_bonus_paid_paise) },
    { key: 'bonus_pending_paise', header: 'Bonus Pending', render: (r) => rupees(r.bonus_pending_paise) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Customer Referral Revenue Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Customers acquired via referral — source customer, lifetime revenue, and bonus payouts owed.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Referral Links</div>
          <div className="text-2xl font-semibold">{totals.total_links}</div>
          <div className="text-xs text-gray-500 mt-1">
            {totals.active_links} active · {totals.pending_links} pending · {totals.churned_links} churned
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Lifetime Revenue Driven</div>
          <div className="text-2xl font-semibold">{rupees(totals.total_lifetime_revenue_paise)}</div>
          <div className="text-xs text-gray-500 mt-1">avg {rupees(totals.avg_revenue_per_link_paise)} / link</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Bonus Paid</div>
          <div className="text-2xl font-semibold">{rupees(totals.total_bonus_paid_paise)}</div>
          <div className="text-xs text-gray-500 mt-1">{rupees(totals.total_bonus_pending_paise)} pending</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Unique Referrers</div>
          <div className="text-2xl font-semibold">{totals.unique_referrers}</div>
          <div className="text-xs text-gray-500 mt-1">customers driving growth</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Referrers</h2>
        <DataTable<TopReferrer> rows={top} columns={topCols} rowKey={(r) => r.source_customer_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Referral Links</h2>
        <DataTable<ReferralLink> rows={links} columns={linkCols} rowKey={(r) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Bonus Payouts</h2>
        <DataTable<BonusPayout> rows={bonuses} columns={bonusCols} rowKey={(r) => r.id} />
      </section>
    </div>
  );
}
