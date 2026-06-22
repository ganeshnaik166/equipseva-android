import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, snapshotsRes, eligibleRes, eventsRes, distRes, kindRes, nearRes] = await Promise.all([
    sb.rpc('founder_ladder_summary_r2234'),
    sb.rpc('founder_ladder_recent_snapshots_r2234'),
    sb.rpc('founder_ladder_eligible_engineers_r2234'),
    sb.rpc('founder_ladder_promotion_events_r2234'),
    sb.rpc('founder_ladder_tier_distribution_r2234'),
    sb.rpc('founder_ladder_event_kind_breakdown_r2234'),
    sb.rpc('founder_ladder_near_promotion_r2234'),
  ]);

  const summary = (summaryRes.data?.[0] ?? {}) as any;
  const snapshots = (snapshotsRes.data ?? []) as any[];
  const eligible = (eligibleRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const distribution = (distRes.data ?? []) as any[];
  const kinds = (kindRes.data ?? []) as any[];
  const near = (nearRes.data ?? []) as any[];

  const snapshotCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'current_tier', header: 'Current Tier', render: (r: any) => String(r.current_tier ?? '') },
    { key: 'next_tier', header: 'Next Tier', render: (r: any) => String(r.next_tier ?? '') },
    { key: 'jobs_completed', header: 'Jobs Done', render: (r: any) => String(r.jobs_completed ?? '') },
    { key: 'jobs_required_next', header: 'Jobs Needed', render: (r: any) => String(r.jobs_required_next ?? '') },
    { key: 'days_active', header: 'Days Active', render: (r: any) => String(r.days_active ?? '') },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => String(r.csat_score ?? '') },
    { key: 'promotion_eligible', header: 'Eligible', render: (r: any) => (r.promotion_eligible ? 'yes' : 'no') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '') },
  ];

  const eligibleCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'current_tier', header: 'Current', render: (r: any) => String(r.current_tier ?? '') },
    { key: 'next_tier', header: 'Next', render: (r: any) => String(r.next_tier ?? '') },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => String(r.jobs_completed ?? '') },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => String(r.csat_score ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '') },
  ];

  const eventCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'from_tier', header: 'From', render: (r: any) => String(r.from_tier ?? '') },
    { key: 'to_tier', header: 'To', render: (r: any) => String(r.to_tier ?? '') },
    { key: 'event_kind', header: 'Kind', render: (r: any) => String(r.event_kind ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
    { key: 'created_at', header: 'When', render: (r: any) => String(r.created_at ?? '') },
  ];

  const distCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => String(r.tier ?? '') },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => String(r.engineer_count ?? '') },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => String(r.avg_csat ?? '') },
    { key: 'avg_jobs', header: 'Avg Jobs', render: (r: any) => String(r.avg_jobs ?? '') },
  ];

  const kindCols: Column<any>[] = [
    { key: 'event_kind', header: 'Event Kind', render: (r: any) => String(r.event_kind ?? '') },
    { key: 'event_count', header: 'Count', render: (r: any) => String(r.event_count ?? '') },
  ];

  const nearCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'current_tier', header: 'Current', render: (r: any) => String(r.current_tier ?? '') },
    { key: 'next_tier', header: 'Next', render: (r: any) => String(r.next_tier ?? '') },
    { key: 'jobs_remaining', header: 'Jobs Left', render: (r: any) => String(r.jobs_remaining ?? '') },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => String(r.days_remaining ?? '') },
    { key: 'csat_gap', header: 'CSAT Gap', render: (r: any) => String(r.csat_gap ?? '') },
  ];

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Engineer Career Ladder Visibility</h1>
      <p className="text-sm text-gray-600">
        Each engineer's current tier, next tier requirements & promotion track.
      </p>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total Engineers</div>
          <div className="text-xl font-semibold">{String(summary.total_engineers ?? 0)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Tier 1</div>
          <div className="text-xl font-semibold">{String(summary.tier1_count ?? 0)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Tier 2</div>
          <div className="text-xl font-semibold">{String(summary.tier2_count ?? 0)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Tier 3</div>
          <div className="text-xl font-semibold">{String(summary.tier3_count ?? 0)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Promotion Eligible</div>
          <div className="text-xl font-semibold">{String(summary.promotion_eligible_count ?? 0)}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Distribution</h2>
        <DataTable columns={distCols} rows={distribution} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Snapshots</h2>
        <DataTable columns={snapshotCols} rows={snapshots} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Promotion Eligible</h2>
        <DataTable columns={eligibleCols} rows={eligible} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Near Promotion (Gap Analysis)</h2>
        <DataTable columns={nearCols} rows={near} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Promotion Events</h2>
        <DataTable columns={eventCols} rows={events} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Event Kind Breakdown</h2>
        <DataTable columns={kindCols} rows={kinds} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
