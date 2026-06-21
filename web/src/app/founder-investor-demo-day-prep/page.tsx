import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toLocaleString('en-IN');
}

export default async function FounderInvestorDemoDayPrepPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpi: any = null;
  let targets: any[] = [];
  let upcoming: any[] = [];
  let rehearsals: any[] = [];
  let breakdown: any[] = [];

  try {
    const r = await sb.rpc('founder_demo_day_kpi_snapshot');
    kpi = (r.data && r.data[0]) ?? null;
  } catch (_e) { kpi = null; }

  try {
    const r = await sb.rpc('founder_demo_day_target_list');
    targets = (r.data as any[]) ?? [];
  } catch (_e) { targets = []; }

  try {
    const r = await sb.rpc('founder_demo_day_upcoming_30d');
    upcoming = (r.data as any[]) ?? [];
  } catch (_e) { upcoming = []; }

  try {
    const r = await sb.rpc('founder_demo_day_rehearsal_log', { p_target_id: null });
    rehearsals = (r.data as any[]) ?? [];
  } catch (_e) { rehearsals = []; }

  try {
    const r = await sb.rpc('founder_demo_day_pitch_status_breakdown');
    breakdown = (r.data as any[]) ?? [];
  } catch (_e) { breakdown = []; }

  try { await sb.rpc('log_founder_demo_day_view', { p_view_name: 'page' }); } catch (_e) {}

  const finalRate = kpi && Number(kpi.total_targets) > 0
    ? ((Number(kpi.finalized_pitches) / Number(kpi.total_targets)) * 100).toFixed(0) + '%'
    : '—';
  const deckGap = kpi && Number(kpi.total_targets) > 0
    ? ((Number(kpi.targets_missing_deck) / Number(kpi.total_targets)) * 100).toFixed(0) + '%'
    : '—';

  const kpis: Kpi[] = [
    { label: 'Targets', value: fmtNum(kpi?.total_targets) },
    { label: 'P0 Targets', value: fmtNum(kpi?.p0_targets) },
    { label: 'Upcoming 30d', value: fmtNum(kpi?.upcoming_30d) },
    { label: 'Pitches Final', value: fmtNum(kpi?.finalized_pitches) },
    { label: 'Final Rate', value: finalRate },
    { label: 'Rehearsals 30d', value: fmtNum(kpi?.total_rehearsals_30d) },
    { label: 'Avg Self Score', value: kpi?.avg_self_score != null ? String(kpi.avg_self_score) : '—' },
    { label: '1-on-1 Slots', value: fmtNum(kpi?.total_1on1_slots) },
    { label: 'Missing Deck', value: fmtNum(kpi?.targets_missing_deck) },
    { label: 'Deck Gap %', value: deckGap },
    { label: 'Upcoming Listed', value: fmtNum(upcoming.length) },
    { label: 'Rehearsals Logged', value: fmtNum(rehearsals.length) },
    { label: 'Status Buckets', value: fmtNum(breakdown.length) },
    { label: 'Targets Listed', value: fmtNum(targets.length) },
    { label: 'Pitch Slot Default', value: '5 min' },
    { label: 'Round', value: 'r1576' },
  ];

  const targetCols: Column<any>[] = [
    { key: 'accelerator_name', header: 'Accelerator', render: (r: any) => r.accelerator_name ?? '—' },
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => r.cohort_label ?? '—' },
    { key: 'demo_day_date', header: 'Demo Date', render: (r: any) => r.demo_day_date ?? '—' },
    { key: 'days_until', header: 'Days Left', render: (r: any) => r.days_until ?? '—' },
    { key: 'deck_slot_minutes', header: 'Slot (min)', render: (r: any) => r.deck_slot_minutes ?? '—' },
    { key: 'pitch_status', header: 'Pitch', render: (r: any) => r.pitch_status ?? '—' },
    { key: 'one_on_one_count', header: '1-on-1', render: (r: any) => r.one_on_one_count ?? '—' },
    { key: 'priority', header: 'Pri', render: (r: any) => r.priority ?? '—' },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'accelerator_name', header: 'Accelerator', render: (r: any) => r.accelerator_name ?? '—' },
    { key: 'demo_day_date', header: 'Date', render: (r: any) => r.demo_day_date ?? '—' },
    { key: 'days_until', header: 'Days Left', render: (r: any) => r.days_until ?? '—' },
    { key: 'pitch_status', header: 'Pitch', render: (r: any) => r.pitch_status ?? '—' },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority ?? '—' },
  ];

  const rehearsalCols: Column<any>[] = [
    { key: 'rehearsed_at', header: 'Rehearsed', render: (r: any) => r.rehearsed_at ? new Date(r.rehearsed_at).toLocaleString('en-IN') : '—' },
    { key: 'accelerator_name', header: 'Target', render: (r: any) => r.accelerator_name ?? '—' },
    { key: 'duration_seconds', header: 'Duration (s)', render: (r: any) => r.duration_seconds ?? '—' },
    { key: 'self_score', header: 'Self Score', render: (r: any) => r.self_score ?? '—' },
    { key: 'weak_slide_count', header: 'Weak Slides', render: (r: any) => r.weak_slide_count ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'pitch_status', header: 'Pitch Status', render: (r: any) => r.pitch_status ?? '—' },
    { key: 'target_count', header: 'Targets', render: (r: any) => r.target_count ?? '—' },
    { key: 'p0_count', header: 'P0', render: (r: any) => r.p0_count ?? '—' },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-8">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-widest text-zinc-500">Capital · r1576</p>
        <h1 className="text-3xl font-semibold tracking-tight">Investor Demo Day Prep Tracker</h1>
        <p className="text-sm text-zinc-600">
          Per-target deck slot, 5-min pitch, 1-on-1 schedule, and founder rehearsal log for accelerator demo days.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border border-zinc-200 bg-white p-3">
            <div className="text-[11px] uppercase tracking-wider text-zinc-500">{k.label}</div>
            <div className="text-lg font-semibold text-zinc-900 mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All targets</h2>
        <DataTable columns={targetCols} rows={targets} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Upcoming (next 30 days)</h2>
        <DataTable columns={upcomingCols} rows={upcoming} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Founder rehearsal log</h2>
        <DataTable columns={rehearsalCols} rows={rehearsals} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pitch status breakdown</h2>
        <DataTable columns={breakdownCols} rows={breakdown} rowKey={(r: any) => r.pitch_status} />
      </section>
    </main>
  );
}
