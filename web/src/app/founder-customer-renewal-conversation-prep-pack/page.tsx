import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerRenewalConversationPrepPackPage() {
  const supabase = await getSupabaseServerClient();

  const [packs, outcomes, risks, topRevenue, funnel, trend, upcoming] = await Promise.all([
    supabase.rpc('list_prep_packs_r2504'),
    supabase.rpc('list_conversation_outcomes_r2504'),
    supabase.rpc('top_risk_hospitals_r2504'),
    supabase.rpc('top_revenue_outcomes_r2504'),
    supabase.rpc('prep_status_funnel_r2504'),
    supabase.rpc('monthly_renewal_outcome_trend_r2504'),
    supabase.rpc('upcoming_renewals_r2504'),
  ]);

  const packCols: Column<any>[] = [
    { key: 'renewal_due_at', header: 'Renewal Due', render: (r: any) => new Date(r.renewal_due_at).toLocaleDateString() },
    { key: 'prep_status', header: 'Prep Status', render: (r: any) => r.prep_status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'risk_flags_md', header: 'Risk Flags', render: (r: any) => <pre className="whitespace-pre-wrap text-xs">{r.risk_flags_md}</pre> },
    { key: 'upsell_hints_md', header: 'Upsell Hints', render: (r: any) => <pre className="whitespace-pre-wrap text-xs">{r.upsell_hints_md}</pre> },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'conversation_at', header: 'Conversation At', render: (r: any) => new Date(r.conversation_at).toLocaleString() },
    { key: 'conversation_kind', header: 'Kind', render: (r: any) => r.conversation_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'revenue_outcome_rupees', header: 'Revenue (Rs)', render: (r: any) => Number(r.revenue_outcome_rupees ?? 0).toLocaleString() },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const riskCols: Column<any>[] = [
    { key: 'renewal_due_at', header: 'Renewal Due', render: (r: any) => new Date(r.renewal_due_at).toLocaleDateString() },
    { key: 'risk_flags_md', header: 'Risk Flags', render: (r: any) => <pre className="whitespace-pre-wrap text-xs">{r.risk_flags_md}</pre> },
    { key: 'prep_status', header: 'Prep Status', render: (r: any) => r.prep_status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const topRevCols: Column<any>[] = [
    { key: 'conversation_at', header: 'Conversation At', render: (r: any) => new Date(r.conversation_at).toLocaleDateString() },
    { key: 'conversation_kind', header: 'Kind', render: (r: any) => r.conversation_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'revenue_outcome_rupees', header: 'Revenue (Rs)', render: (r: any) => Number(r.revenue_outcome_rupees ?? 0).toLocaleString() },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'prep_status', header: 'Prep Status', render: (r: any) => r.prep_status },
    { key: 'pack_count', header: 'Pack Count', render: (r: any) => String(r.pack_count) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'conversation_count', header: 'Conversations', render: (r: any) => String(r.conversation_count) },
    { key: 'revenue_sum_rupees', header: 'Revenue Sum (Rs)', render: (r: any) => Number(r.revenue_sum_rupees ?? 0).toLocaleString() },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'renewal_due_at', header: 'Renewal Due', render: (r: any) => new Date(r.renewal_due_at).toLocaleDateString() },
    { key: 'prep_status', header: 'Prep Status', render: (r: any) => r.prep_status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Renewal Conversation Prep Pack</h1>
        <p className="text-sm text-gray-600">Hospital renewal context, performance history, upsell hints & risk flags.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Renewals (next 20)</h2>
        <DataTable
          rows={upcoming.data ?? []}
          columns={upcomingCols}
          emptyMessage="No upcoming renewals."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Prep Status Funnel</h2>
        <DataTable
          rows={funnel.data ?? []}
          columns={funnelCols}
          emptyMessage="No funnel data."
          rowKey={(r: any, i: number) => String(r.prep_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Risk Hospitals</h2>
        <DataTable
          rows={risks.data ?? []}
          columns={riskCols}
          emptyMessage="No risk-flagged hospitals."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Revenue Outcomes</h2>
        <DataTable
          rows={topRevenue.data ?? []}
          columns={topRevCols}
          emptyMessage="No revenue outcomes yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Outcome Trend</h2>
        <DataTable
          rows={trend.data ?? []}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String((r.month_label ?? '') + '-' + (r.outcome ?? '') + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Prep Packs</h2>
        <DataTable
          rows={packs.data ?? []}
          columns={packCols}
          emptyMessage="No prep packs."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Conversation Outcomes</h2>
        <DataTable
          rows={outcomes.data ?? []}
          columns={outcomeCols}
          emptyMessage="No conversation outcomes."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
