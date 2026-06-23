import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    decisionMakers,
    touchpoints,
    blockers,
    weakRelationships,
    chainSummary,
    touchSummary,
    followUpCalendar,
  ] = await Promise.all([
    supabase.rpc('list_decision_makers_r2435'),
    supabase.rpc('list_touchpoints_r2435'),
    supabase.rpc('blocker_focus_r2435'),
    supabase.rpc('weak_relationship_focus_r2435'),
    supabase.rpc('top_influence_chain_summary_r2435'),
    supabase.rpc('recent_touch_summary_r2435'),
    supabase.rpc('follow_up_calendar_r2435'),
  ]);

  const dmRows = (decisionMakers.data as any[]) ?? [];
  const tpRows = (touchpoints.data as any[]) ?? [];
  const blockerRows = (blockers.data as any[]) ?? [];
  const weakRows = (weakRelationships.data as any[]) ?? [];
  const chainRows = (chainSummary.data as any[]) ?? [];
  const touchRows = (touchSummary.data as any[]) ?? [];
  const followUpRows = (followUpCalendar.data as any[]) ?? [];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');
  const fmtDateTime = (v: any) => (v ? new Date(v).toLocaleString() : '—');

  const dmCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'person_name', header: 'Person', render: (r: any) => r.person_name },
    { key: 'person_title', header: 'Title', render: (r: any) => r.person_title },
    { key: 'decision_role', header: 'Role', render: (r: any) => r.decision_role },
    { key: 'influence_score', header: 'Influence', render: (r: any) => `${r.influence_score}/100` },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'last_touch_kind', header: 'Kind', render: (r: any) => r.last_touch_kind ?? '—' },
    { key: 'red_flags_md', header: 'Red Flags', render: (r: any) => r.red_flags_md ?? '—' },
  ];

  const tpCols: Column<any>[] = [
    { key: 'touch_at', header: 'When', render: (r: any) => fmtDateTime(r.touch_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'person_name', header: 'Person', render: (r: any) => r.person_name },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind },
    { key: 'agenda', header: 'Agenda', render: (r: any) => r.agenda ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'follow_up_required', header: 'Follow-up?', render: (r: any) => (r.follow_up_required ? 'Yes' : 'No') },
    { key: 'follow_up_at', header: 'Follow-up At', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const blockerCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'person_name', header: 'Person', render: (r: any) => r.person_name },
    { key: 'person_title', header: 'Title', render: (r: any) => r.person_title },
    { key: 'influence_score', header: 'Influence', render: (r: any) => `${r.influence_score}/100` },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'red_flags_md', header: 'Red Flags', render: (r: any) => r.red_flags_md ?? '—' },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
  ];

  const weakCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'person_name', header: 'Person', render: (r: any) => r.person_name },
    { key: 'decision_role', header: 'Role', render: (r: any) => r.decision_role },
    { key: 'influence_score', header: 'Influence', render: (r: any) => `${r.influence_score}/100` },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'decision_makers_count', header: 'DMs', render: (r: any) => r.decision_makers_count },
    { key: 'avg_influence', header: 'Avg Influence', render: (r: any) => r.avg_influence },
    { key: 'champions_count', header: 'Champions', render: (r: any) => r.champions_count },
    { key: 'blockers_count', header: 'Blockers', render: (r: any) => r.blockers_count },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
  ];

  const touchCols: Column<any>[] = [
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind },
    { key: 'total_touches', header: 'Total', render: (r: any) => r.total_touches },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'neutral_count', header: 'Neutral', render: (r: any) => r.neutral_count },
    { key: 'negative_count', header: 'Negative', render: (r: any) => r.negative_count },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
  ];

  const followUpCols: Column<any>[] = [
    { key: 'follow_up_at', header: 'Follow-up At', render: (r: any) => fmtDateTime(r.follow_up_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'person_name', header: 'Person', render: (r: any) => r.person_name },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind },
    { key: 'agenda', header: 'Agenda', render: (r: any) => r.agenda ?? '—' },
    { key: 'outcome', header: 'Last Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
        Hospital Chain Decision-Maker Relationship Map
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Chain > decision-maker > role > influence score > last touch > strength > red flags.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Top influence by chain</h2>
        <DataTable
          rows={chainRows}
          columns={chainCols}
          emptyMessage="No chains tracked"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>All decision makers</h2>
        <DataTable
          rows={dmRows}
          columns={dmCols}
          emptyMessage="No decision makers"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Blocker focus</h2>
        <DataTable
          rows={blockerRows}
          columns={blockerCols}
          emptyMessage="No blockers flagged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Weak relationships & high influence
        </h2>
        <DataTable
          rows={weakRows}
          columns={weakCols}
          emptyMessage="No weak high-influence contacts"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Recent touchpoints</h2>
        <DataTable
          rows={tpRows}
          columns={tpCols}
          emptyMessage="No touchpoints logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Touch kind summary</h2>
        <DataTable
          rows={touchRows}
          columns={touchCols}
          emptyMessage="No touch activity"
          rowKey={(r: any, i: number) => String(r.touch_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Follow-up calendar</h2>
        <DataTable
          rows={followUpRows}
          columns={followUpCols}
          emptyMessage="No follow-ups scheduled"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
