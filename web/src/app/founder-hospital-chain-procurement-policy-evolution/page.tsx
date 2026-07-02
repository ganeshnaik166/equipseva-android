import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    versionsRes,
    eventsRes,
    threatsRes,
    adoptionRes,
    impactRes,
    monthlyRes,
    ownerRes,
  ] = await Promise.all([
    supabase.rpc('list_policy_versions_r2539'),
    supabase.rpc('list_evolution_events_r2539'),
    supabase.rpc('critical_threat_focus_r2539'),
    supabase.rpc('adoption_status_summary_r2539'),
    supabase.rpc('our_impact_distribution_r2539'),
    supabase.rpc('monthly_event_trend_r2539'),
    supabase.rpc('owner_load_r2539'),
  ]);

  const versions = (versionsRes.data as any[]) ?? [];
  const events = (eventsRes.data as any[]) ?? [];
  const threats = (threatsRes.data as any[]) ?? [];
  const adoption = (adoptionRes.data as any[]) ?? [];
  const impact = (impactRes.data as any[]) ?? [];
  const monthly = (monthlyRes.data as any[]) ?? [];
  const owner = (ownerRes.data as any[]) ?? [];

  const versionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'effective_at', header: 'Effective', render: (r: any) => String(r.effective_at ?? '').slice(0, 10) },
    { key: 'prior_version_label', header: 'Prior', render: (r: any) => r.prior_version_label ?? '-' },
    { key: 'our_impact_kind', header: 'Impact', render: (r: any) => r.our_impact_kind },
    { key: 'adoption_status', header: 'Adoption', render: (r: any) => r.adoption_status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'event_at', header: 'When', render: (r: any) => String(r.event_at ?? '').slice(0, 10) },
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const threatCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'effective_at', header: 'Effective', render: (r: any) => String(r.effective_at ?? '').slice(0, 10) },
    { key: 'adoption_status', header: 'Adoption', render: (r: any) => r.adoption_status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const adoptionCols: Column<any>[] = [
    { key: 'adoption_status', header: 'Status', render: (r: any) => r.adoption_status },
    { key: 'versions_count', header: 'Versions', render: (r: any) => r.versions_count },
    { key: 'critical_threat_count', header: 'Critical', render: (r: any) => r.critical_threat_count },
    { key: 'negative_count', header: 'Negative', render: (r: any) => r.negative_count },
  ];

  const impactCols: Column<any>[] = [
    { key: 'our_impact_kind', header: 'Impact', render: (r: any) => r.our_impact_kind },
    { key: 'versions_count', header: 'Versions', render: (r: any) => r.versions_count },
    { key: 'adopted_count', header: 'Adopted', render: (r: any) => r.adopted_count },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => r.blocked_count },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '').slice(0, 10) },
    { key: 'events_count', header: 'Events', render: (r: any) => r.events_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'distinct_chains', header: 'Chains', render: (r: any) => r.distinct_chains },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'versions_count', header: 'Versions', render: (r: any) => r.versions_count },
    { key: 'events_count', header: 'Events', render: (r: any) => r.events_count },
    { key: 'open_events', header: 'Open', render: (r: any) => r.open_events },
    { key: 'critical_threats', header: 'Critical', render: (r: any) => r.critical_threats },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Procurement Policy Evolution</h1>
        <p className="text-sm text-gray-600">
          Track how chain procurement policies change over time & our counter-strategy.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical Threat Focus</h2>
        <DataTable
          rows={threats}
          columns={threatCols}
          emptyMessage="No critical-threat policies right now."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Policy Versions</h2>
        <DataTable
          rows={versions}
          columns={versionCols}
          emptyMessage="No policy versions tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Evolution Events</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          emptyMessage="No evolution events yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Adoption Status Summary</h2>
        <DataTable
          rows={adoption}
          columns={adoptionCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.adoption_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Our Impact Distribution</h2>
        <DataTable
          rows={impact}
          columns={impactCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.our_impact_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Event Trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No events yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={owner}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
