import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyKeyCustomerPersonalRelationshipPage() {
  const supabase = await getSupabaseServerClient();

  const [
    relationsRes,
    touchLogRes,
    topLoyaltyRes,
    bondDistRes,
    dormantRes,
    trendRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_relations_r2581'),
    supabase.rpc('list_touch_log_r2581'),
    supabase.rpc('top_loyalty_customers_r2581'),
    supabase.rpc('bond_kind_distribution_r2581'),
    supabase.rpc('dormant_focus_r2581'),
    supabase.rpc('monthly_touch_trend_r2581'),
    supabase.rpc('founder_pulse_summary_r2581'),
  ]);

  const relations = (relationsRes.data ?? []) as any[];
  const touchLog = (touchLogRes.data ?? []) as any[];
  const topLoyalty = (topLoyaltyRes.data ?? []) as any[];
  const bondDist = (bondDistRes.data ?? []) as any[];
  const dormant = (dormantRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const pulse = (pulseRes.data ?? []) as any[];

  const fmtDt = (s: string | null) =>
    s ? new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '—';
  const fmtD = (s: string | null) =>
    s ? new Date(s).toLocaleDateString('en-IN', { dateStyle: 'medium' }) : '—';

  const relationsCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'decision_maker_name', header: 'Decision-maker', render: (r: any) => r.decision_maker_name },
    { key: 'customer_decision_maker_email', header: 'Email', render: (r: any) => r.customer_decision_maker_email },
    { key: 'personal_bond_kind', header: 'Bond', render: (r: any) => r.personal_bond_kind },
    { key: 'loyalty_score', header: 'Loyalty', render: (r: any) => `${r.loyalty_score}/100` },
    { key: 'event_attendance_count', header: 'Events', render: (r: any) => r.event_attendance_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'shared_interests_md', header: 'Shared interests', render: (r: any) => r.shared_interests_md ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const touchCols: Column<any>[] = [
    { key: 'decision_maker_name', header: 'Decision-maker', render: (r: any) => r.decision_maker_name },
    { key: 'touch_at', header: 'Touch at', render: (r: any) => fmtDt(r.touch_at) },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtD(r.follow_up_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topLoyaltyCols: Column<any>[] = [
    { key: 'decision_maker_name', header: 'Decision-maker', render: (r: any) => r.decision_maker_name },
    { key: 'customer_decision_maker_email', header: 'Email', render: (r: any) => r.customer_decision_maker_email },
    { key: 'personal_bond_kind', header: 'Bond', render: (r: any) => r.personal_bond_kind },
    { key: 'loyalty_score', header: 'Loyalty', render: (r: any) => `${r.loyalty_score}/100` },
    { key: 'event_attendance_count', header: 'Events', render: (r: any) => r.event_attendance_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const bondCols: Column<any>[] = [
    { key: 'personal_bond_kind', header: 'Bond kind', render: (r: any) => r.personal_bond_kind },
    { key: 'relation_count', header: 'Count', render: (r: any) => r.relation_count },
    { key: 'avg_loyalty', header: 'Avg loyalty', render: (r: any) => r.avg_loyalty },
  ];

  const dormantCols: Column<any>[] = [
    { key: 'decision_maker_name', header: 'Decision-maker', render: (r: any) => r.decision_maker_name },
    { key: 'customer_decision_maker_email', header: 'Email', render: (r: any) => r.customer_decision_maker_email },
    { key: 'personal_bond_kind', header: 'Bond', render: (r: any) => r.personal_bond_kind },
    { key: 'loyalty_score', header: 'Loyalty', render: (r: any) => r.loyalty_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => fmtDt(r.last_touch_at) },
    { key: 'days_since_touch', header: 'Days since', render: (r: any) => r.days_since_touch ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_bucket', header: 'Month', render: (r: any) => r.month_bucket },
    { key: 'touch_count', header: 'Touches', render: (r: any) => r.touch_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'negative_count', header: 'Negative', render: (r: any) => r.negative_count },
  ];

  const pulseCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric },
    { key: 'value', header: 'Value', render: (r: any) => r.value },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Founder Monthly Key Customer Personal Relationship
        </h1>
        <p style={{ color: '#555', maxWidth: 820 }}>
          Founder-owned personal bond & loyalty tracker for key hospital decision-makers. Bond kind
          (weak => developing => strong => champion), shared interests, event attendance, founder touch
          log and dormant focus list.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Founder pulse</h2>
        <DataTable
          rows={pulse}
          columns={pulseCols}
          emptyMessage="No pulse rows."
          rowKey={(r: any, i: number) => String(r.metric ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top loyalty customers</h2>
        <DataTable
          rows={topLoyalty}
          columns={topLoyaltyCols}
          emptyMessage="No top loyalty rows."
          rowKey={(r: any, i: number) => String(r.customer_decision_maker_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Bond kind distribution</h2>
        <DataTable
          rows={bondDist}
          columns={bondCols}
          emptyMessage="No bond distribution rows."
          rowKey={(r: any, i: number) => String(r.personal_bond_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Dormant / strained focus list</h2>
        <DataTable
          rows={dormant}
          columns={dormantCols}
          emptyMessage="No dormant relationships."
          rowKey={(r: any, i: number) => String(r.customer_decision_maker_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly touch trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All key customer relations</h2>
        <DataTable
          rows={relations}
          columns={relationsCols}
          emptyMessage="No relations on file."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Founder touch log</h2>
        <DataTable
          rows={touchLog}
          columns={touchCols}
          emptyMessage="No touches logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
