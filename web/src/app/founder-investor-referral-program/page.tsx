import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-3 shadow-sm">
      <div className="text-xs text-slate-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-slate-900">{value}</div>
    </div>
  );
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [overview, ladder, top, pipeline, payoutsDue, wins] = await Promise.all([
    sb.rpc('rpc_investor_referral_overview'),
    sb.rpc('rpc_investor_referral_ladder'),
    sb.rpc('rpc_investor_referral_top_referrers'),
    sb.rpc('rpc_investor_referral_pipeline'),
    sb.rpc('rpc_investor_referral_payouts_due'),
    sb.rpc('rpc_investor_referral_recent_wins'),
  ]);

  const o: any = overview.data?.[0] ?? {};
  const ladderRows: any[] = ladder.data ?? [];
  const topRows: any[] = top.data ?? [];
  const pipeRows: any[] = pipeline.data ?? [];
  const dueRows: any[] = payoutsDue.data ?? [];
  const winRows: any[] = wins.data ?? [];

  const ladderCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => <span className="font-medium capitalize">{r.stage}</span> },
    { key: 'count', header: 'Count', render: (r: any) => r.count ?? 0 },
    { key: 'total_check_rupees', header: 'Check value', render: (r: any) => formatRupees(r.total_check_rupees ?? 0) },
    { key: 'conversion_from_intro_pct', header: 'Pct of intros', render: (r: any) => `${r.conversion_from_intro_pct ?? 0}%` },
  ];

  const topCols: Column<any>[] = [
    { key: 'referrer_name', header: 'Referrer', render: (r: any) => <span className="font-medium">{r.referrer_name ?? "—"}</span> },
    { key: 'referrer_fund', header: 'Fund', render: (r: any) => r.referrer_fund ?? "—" },
    { key: 'referrals_count', header: 'Referrals', render: (r: any) => r.referrals_count ?? 0 },
    { key: 'checks_count', header: 'Checks', render: (r: any) => r.checks_count ?? 0 },
    { key: 'total_check_rupees', header: 'Check value', render: (r: any) => formatRupees(r.total_check_rupees ?? 0) },
    { key: 'total_bounty_rupees', header: 'Bounty owed', render: (r: any) => formatRupees(r.total_bounty_rupees ?? 0) },
    { key: 'paid_bounty_rupees', header: 'Bounty paid', render: (r: any) => formatRupees(r.paid_bounty_rupees ?? 0) },
  ];

  const pipeCols: Column<any>[] = [
    { key: 'referrer_name', header: 'Referrer', render: (r: any) => r.referrer_name ?? "—" },
    { key: 'referee_name', header: 'Referee', render: (r: any) => <span className="font-medium">{r.referee_name ?? "—"}</span> },
    { key: 'referee_fund', header: 'Fund', render: (r: any) => r.referee_fund ?? "—" },
    { key: 'stage', header: 'Stage', render: (r: any) => <span className="capitalize">{r.stage}</span> },
    { key: 'check_amount_rupees', header: 'Target check', render: (r: any) => formatRupees(r.check_amount_rupees ?? 0) },
    { key: 'bounty_rupees', header: 'Bounty', render: (r: any) => formatRupees(r.bounty_rupees ?? 0) },
    { key: 'days_in_pipeline', header: 'Days', render: (r: any) => `${r.days_in_pipeline ?? 0}d` },
  ];

  const dueCols: Column<any>[] = [
    { key: 'referrer_name', header: 'Referrer', render: (r: any) => <span className="font-medium">{r.referrer_name ?? "—"}</span> },
    { key: 'referrer_email', header: 'Email', render: (r: any) => r.referrer_email ?? "—" },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => formatRupees(r.amount_rupees ?? 0) },
    { key: 'days_outstanding', header: 'Outstanding', render: (r: any) => `${r.days_outstanding ?? 0}d` },
  ];

  const winCols: Column<any>[] = [
    { key: 'referrer_name', header: 'Referrer', render: (r: any) => r.referrer_name ?? "—" },
    { key: 'referee_name', header: 'Referee', render: (r: any) => <span className="font-medium">{r.referee_name ?? "—"}</span> },
    { key: 'referee_fund', header: 'Fund', render: (r: any) => r.referee_fund ?? "—" },
    { key: 'check_amount_rupees', header: 'Check', render: (r: any) => formatRupees(r.check_amount_rupees ?? 0) },
    { key: 'bounty_rupees', header: 'Bounty', render: (r: any) => formatRupees(r.bounty_rupees ?? 0) },
    { key: 'check_at', header: 'Closed', render: (r: any) => r.check_at ? new Date(r.check_at).toLocaleDateString() : "—" },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <div>
        <h1 className="text-2xl font-semibold text-slate-900">Investor Referral Program</h1>
        <p className="mt-1 text-sm text-slate-600">Track investor-to-investor referrals, conversion ladder, and per-referrer bounty payouts.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total referrals" value={String(o.total_referrals ?? 0)} />
        <Kpi label="Unique referrers" value={String(o.total_referrers ?? 0)} />
        <Kpi label="Intros" value={String(o.intro_count ?? 0)} />
        <Kpi label="Meetings" value={String(o.meeting_count ?? 0)} />
        <Kpi label="Diligence" value={String(o.diligence_count ?? 0)} />
        <Kpi label="Checks closed" value={String(o.check_count ?? 0)} />
        <Kpi label="Dead" value={String(o.dead_count ?? 0)} />
        <Kpi label="Active pipeline" value={String(o.active_pipeline_count ?? 0)} />
        <Kpi label="This month intros" value={String(o.this_month_intros ?? 0)} />
        <Kpi label="Total check value" value={formatRupees(o.total_check_rupees ?? 0)} />
        <Kpi label="Avg check size" value={formatRupees(o.avg_check_rupees ?? 0)} />
        <Kpi label="Conversion rate" value={`${o.conversion_rate_pct ?? 0}%`} />
        <Kpi label="Intro to check" value={`${Math.round(o.intro_to_check_days ?? 0)}d`} />
        <Kpi label="Bounty owed (all)" value={formatRupees(o.total_bounty_rupees ?? 0)} />
        <Kpi label="Bounty paid" value={formatRupees(o.paid_bounty_rupees ?? 0)} />
        <Kpi label="Bounty pending" value={formatRupees(o.pending_bounty_rupees ?? 0)} />
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Conversion ladder</h2>
        <DataTable<any> rows={ladderRows} columns={ladderCols} rowKey={(r: any) => r.stage} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Top referrers</h2>
        <DataTable<any> rows={topRows} columns={topCols} rowKey={(r: any) => r.referrer_email ?? r.referrer_name} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Active pipeline</h2>
        <DataTable<any> rows={pipeRows} columns={pipeCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Bounty payouts due</h2>
        <DataTable<any> rows={dueRows} columns={dueCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Recent wins</h2>
        <DataTable<any> rows={winRows} columns={winCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
