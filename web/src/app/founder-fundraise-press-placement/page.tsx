import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

async function loadData() {
  const sb = await getSupabaseServerClient();
  let overview: any = null;
  let placements: any[] = [];
  let outlets: any[] = [];
  let embargoes: any[] = [];
  let touchpoints: any[] = [];
  let followups: any[] = [];

  try {
    const r = await sb.rpc('founder_press_placements_overview');
    overview = r.data?.[0] ?? null;
  } catch { overview = null; }
  try {
    const r = await sb.rpc('founder_press_placements_list', { p_limit: 100 });
    placements = r.data ?? [];
  } catch { placements = []; }
  try {
    const r = await sb.rpc('founder_press_outlet_breakdown');
    outlets = r.data ?? [];
  } catch { outlets = []; }
  try {
    const r = await sb.rpc('founder_press_active_embargoes');
    embargoes = r.data ?? [];
  } catch { embargoes = []; }
  try {
    const r = await sb.rpc('founder_press_recent_touchpoints', { p_limit: 50 });
    touchpoints = r.data ?? [];
  } catch { touchpoints = []; }
  try {
    const r = await sb.rpc('founder_press_followups_due');
    followups = r.data ?? [];
  } catch { followups = []; }

  return { overview, placements, outlets, embargoes, touchpoints, followups };
}

export default async function FounderFundraisePressPlacementPage() {
  await requireFounder();
  const { overview, placements, outlets, embargoes, touchpoints, followups } = await loadData();

  const o = overview ?? {};
  const kpis: Kpi[] = [
    { label: 'Total Placements', value: String(o.total_placements ?? 0) },
    { label: 'Exclusives', value: String(o.exclusives ?? 0) },
    { label: 'Broadcasts', value: String(o.broadcasts ?? 0) },
    { label: 'Embargoed', value: String(o.embargoed ?? 0) },
    { label: 'Published', value: String(o.published ?? 0) },
    { label: 'Pending', value: String(o.pending ?? 0) },
    { label: 'Spiked', value: String(o.spiked ?? 0) },
    { label: 'Outlets Engaged', value: String(o.outlets_engaged ?? 0) },
    { label: 'Active Embargoes', value: String(o.active_embargoes ?? 0) },
    { label: 'Avg Days to Publish', value: String(o.avg_days_to_publish ?? '—') },
    { label: 'Est Total Reach', value: String(o.total_estimated_reach ?? 0) },
    { label: 'Acceptance Rate %', value: String(o.acceptance_rate_pct ?? 0) },
    { label: 'Followups Due', value: String(followups.length ?? 0) },
    { label: 'Outlets Tracked', value: String(outlets.length ?? 0) },
    { label: 'Touchpoints Logged', value: String(touchpoints.length ?? 0) },
    { label: 'Round', value: 'r1585' },
  ];

  const placementsCols: Column<any>[] = [
    { key: 'outlet', header: 'Outlet', render: (r: any) => r.outlet ?? '—' },
    { key: 'reporter_name', header: 'Reporter', render: (r: any) => r.reporter_name ?? '—' },
    { key: 'placement_kind', header: 'Kind', render: (r: any) => r.placement_kind ?? '—' },
    { key: 'fundraise_round_label', header: 'Round', render: (r: any) => r.fundraise_round_label ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'spokesperson', header: 'Spokesperson', render: (r: any) => r.spokesperson ?? '—' },
    { key: 'embargo_until', header: 'Embargo Until', render: (r: any) => r.embargo_until ?? '—' },
    { key: 'pitched_at', header: 'Pitched', render: (r: any) => r.pitched_at ?? '—' },
  ];

  const outletsCols: Column<any>[] = [
    { key: 'outlet', header: 'Outlet', render: (r: any) => r.outlet ?? '—' },
    { key: 'pitches', header: 'Pitches', render: (r: any) => String(r.pitches ?? 0) },
    { key: 'published', header: 'Published', render: (r: any) => String(r.published ?? 0) },
    { key: 'spiked', header: 'Spiked', render: (r: any) => String(r.spiked ?? 0) },
    { key: 'avg_response_days', header: 'Avg Resp Days', render: (r: any) => String(r.avg_response_days ?? '—') },
    { key: 'est_total_reach', header: 'Est Reach', render: (r: any) => String(r.est_total_reach ?? 0) },
  ];

  const embargoesCols: Column<any>[] = [
    { key: 'outlet', header: 'Outlet', render: (r: any) => r.outlet ?? '—' },
    { key: 'reporter_name', header: 'Reporter', render: (r: any) => r.reporter_name ?? '—' },
    { key: 'fundraise_round_label', header: 'Round', render: (r: any) => r.fundraise_round_label ?? '—' },
    { key: 'embargo_until', header: 'Lifts At', render: (r: any) => r.embargo_until ?? '—' },
    { key: 'hours_until_lift', header: 'Hrs Until Lift', render: (r: any) => String(r.hours_until_lift ?? '—') },
    { key: 'approved_quote', header: 'Approved Quote', render: (r: any) => r.approved_quote ?? '—' },
  ];

  const touchpointsCols: Column<any>[] = [
    { key: 'outlet', header: 'Outlet', render: (r: any) => r.outlet ?? '—' },
    { key: 'touchpoint_kind', header: 'Kind', render: (r: any) => r.touchpoint_kind ?? '—' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'occurred_at', header: 'When', render: (r: any) => r.occurred_at ?? '—' },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary ?? '—' },
  ];

  const followupsCols: Column<any>[] = [
    { key: 'outlet', header: 'Outlet', render: (r: any) => r.outlet ?? '—' },
    { key: 'reporter_name', header: 'Reporter', render: (r: any) => r.reporter_name ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'next_action_due', header: 'Due', render: (r: any) => r.next_action_due ?? '—' },
    { key: 'hours_overdue', header: 'Hrs Overdue', render: (r: any) => String(r.hours_overdue ?? '—') },
    { key: 'last_summary', header: 'Last Note', render: (r: any) => r.last_summary ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-semibold">Fundraise Press Placement</h1>
        <p className="text-sm text-gray-500">r1585 — orchestrate TC/YourStory/ET/Inc42 placements, exclusives vs broadcasts, embargo + spokesperson quotes.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border bg-white p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Placements</h2>
        <DataTable columns={placementsCols} rows={placements} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outlet Breakdown</h2>
        <DataTable columns={outletsCols} rows={outlets} rowKey={(r: any) => r.outlet} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active Embargoes</h2>
        <DataTable columns={embargoesCols} rows={embargoes} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Touchpoints</h2>
        <DataTable columns={touchpointsCols} rows={touchpoints} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Followups Due</h2>
        <DataTable columns={followupsCols} rows={followups} rowKey={(r: any) => r.placement_id} />
      </section>
    </div>
  );
}
