import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalNetworkHealthTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [contactsRes, eventsRes, dormantRes, recipRes, tierRes, trendRes, statusRes] = await Promise.all([
    supabase.rpc('list_contacts_r2525'),
    supabase.rpc('list_touch_events_r2525'),
    supabase.rpc('dormant_focus_r2525'),
    supabase.rpc('top_reciprocity_contacts_r2525'),
    supabase.rpc('tier_distribution_r2525'),
    supabase.rpc('monthly_touch_trend_r2525'),
    supabase.rpc('status_breakdown_r2525'),
  ]);

  const contacts = (contactsRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const dormant = (dormantRes.data ?? []) as any[];
  const recip = (recipRes.data ?? []) as any[];
  const tiers = (tierRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const statuses = (statusRes.data ?? []) as any[];

  const fmt = (v: any) => (v == null ? '—' : String(v));
  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');
  const fmtMonth = (v: any) => (v ? new Date(v).toLocaleDateString(undefined, { year: 'numeric', month: 'short' }) : '—');

  const contactCols: Column<any>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => fmt(r.contact_name) },
    { key: 'contact_email', header: 'Email', render: (r: any) => fmt(r.contact_email) },
    { key: 'tier', header: 'Tier', render: (r: any) => fmt(r.tier) },
    { key: 'relationship_kind', header: 'Kind', render: (r: any) => fmt(r.relationship_kind) },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'help_asked_count', header: 'Asked', render: (r: any) => fmt(r.help_asked_count) },
    { key: 'help_given_count', header: 'Given', render: (r: any) => fmt(r.help_given_count) },
    { key: 'reciprocity_score', header: 'Reciprocity', render: (r: any) => fmt(r.reciprocity_score) },
    { key: 'status', header: 'Status', render: (r: any) => fmt(r.status) },
  ];

  const eventCols: Column<any>[] = [
    { key: 'touch_at', header: 'When', render: (r: any) => fmtDate(r.touch_at) },
    { key: 'contact_name', header: 'Contact', render: (r: any) => fmt(r.contact_name) },
    { key: 'tier', header: 'Tier', render: (r: any) => fmt(r.tier) },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => fmt(r.touch_kind) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => fmt(r.outcome) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => fmt(r.owner_email) },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'notes', header: 'Notes', render: (r: any) => fmt(r.notes) },
  ];

  const dormantCols: Column<any>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => fmt(r.contact_name) },
    { key: 'tier', header: 'Tier', render: (r: any) => fmt(r.tier) },
    { key: 'relationship_kind', header: 'Kind', render: (r: any) => fmt(r.relationship_kind) },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'days_since_touch', header: 'Days since', render: (r: any) => fmt(r.days_since_touch) },
    { key: 'status', header: 'Status', render: (r: any) => fmt(r.status) },
  ];

  const recipCols: Column<any>[] = [
    { key: 'contact_name', header: 'Contact', render: (r: any) => fmt(r.contact_name) },
    { key: 'tier', header: 'Tier', render: (r: any) => fmt(r.tier) },
    { key: 'help_asked_count', header: 'Asked', render: (r: any) => fmt(r.help_asked_count) },
    { key: 'help_given_count', header: 'Given', render: (r: any) => fmt(r.help_given_count) },
    { key: 'reciprocity_score', header: 'Reciprocity', render: (r: any) => fmt(r.reciprocity_score) },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => fmt(r.tier) },
    { key: 'contact_count', header: 'Contacts', render: (r: any) => fmt(r.contact_count) },
    { key: 'avg_reciprocity', header: 'Avg reciprocity', render: (r: any) => fmt(r.avg_reciprocity) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'touch_count', header: 'Touches', render: (r: any) => fmt(r.touch_count) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => fmt(r.positive_count) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => fmt(r.status) },
    { key: 'contact_count', header: 'Contacts', render: (r: any) => fmt(r.contact_count) },
    { key: 'total_help_asked', header: 'Total asked', render: (r: any) => fmt(r.total_help_asked) },
    { key: 'total_help_given', header: 'Total given', render: (r: any) => fmt(r.total_help_given) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder personal network health tracker</h1>
        <p className="text-sm text-gray-600">
          Contacts & touches: tier, last touch, help asked vs given, reciprocity score.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Contacts</h2>
        <DataTable
          rows={contacts}
          columns={contactCols}
          emptyMessage="No contacts logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent touch events</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          emptyMessage="No touch events."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Dormant / strained focus list</h2>
        <DataTable
          rows={dormant}
          columns={dormantCols}
          emptyMessage="No dormant contacts."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top reciprocity contacts</h2>
        <DataTable
          rows={recip}
          columns={recipCols}
          emptyMessage="No reciprocity data."
          rowKey={(r: any, i: number) => String(r.contact_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Tier distribution</h2>
        <DataTable
          rows={tiers}
          columns={tierCols}
          emptyMessage="No tier data."
          rowKey={(r: any, i: number) => String(r.tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly touch trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Status breakdown</h2>
        <DataTable
          rows={statuses}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </main>
  );
}
