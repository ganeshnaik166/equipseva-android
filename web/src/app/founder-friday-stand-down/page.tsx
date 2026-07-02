import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

export default async function FounderFridayStandDownPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = null;
  let recent: any[] = [];
  let mood: any[] = [];
  let journal: any[] = [];
  let shipSlip: any[] = [];

  try {
    const { data } = await sb.rpc('friday_stand_down_summary_v2');
    summary = Array.isArray(data) ? data[0] : data;
  } catch {}

  try {
    const { data } = await sb.rpc('friday_stand_down_recent_v2');
    recent = data ?? [];
  } catch {}

  try {
    const { data } = await sb.rpc('friday_mood_trend_v2');
    mood = data ?? [];
  } catch {}

  try {
    const { data } = await sb.rpc('friday_journal_recent_v2');
    journal = data ?? [];
  } catch {}

  try {
    const { data } = await sb.rpc('friday_ship_slip_log_v2');
    shipSlip = data ?? [];
  } catch {}

  const s = summary ?? {};

  const kpis: Kpi[] = [
    { label: 'Total Weeks Logged', value: String(s.total_weeks ?? '—') },
    { label: 'Avg Mood (1-10)', value: String(s.avg_mood ?? '—') },
    { label: 'Avg Energy (1-10)', value: String(s.avg_energy ?? '—') },
    { label: 'Avg Focus (1-10)', value: String(s.avg_focus ?? '—') },
    { label: 'Total Ships', value: String(s.total_ships ?? '—') },
    { label: 'Total Slips', value: String(s.total_slips ?? '—') },
    { label: 'Ship/Slip Ratio', value: s.total_slips > 0 ? String((Number(s.total_ships) / Number(s.total_slips)).toFixed(2)) : '∞' },
    { label: 'Weeks High Burnout', value: String(s.weeks_high_burnout ?? '—') },
    { label: 'Weeks Low Mood', value: String(s.weeks_low_mood ?? '—') },
    { label: 'Last Week Ending', value: String(s.last_week_ending ?? '—') },
    { label: 'Last Mood', value: String(s.last_mood ?? '—') },
    { label: 'Last Energy', value: String(s.last_energy ?? '—') },
    { label: 'Ships Last Week', value: String(s.ships_last_week ?? '—') },
    { label: 'Slips Last Week', value: String(s.slips_last_week ?? '—') },
    { label: 'Journal Entries', value: String(s.total_journal_entries ?? '—') },
    { label: 'Wins / Losses / Lessons', value: `${s.total_wins ?? 0} / ${s.total_losses ?? 0} / ${s.total_lessons ?? 0}` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'week_ending', header: 'Week Ending', render: (r: any) => r.week_ending ?? '—' },
    { key: 'ships_count', header: 'Ships', render: (r: any) => r.ships_count ?? '—' },
    { key: 'slips_count', header: 'Slips', render: (r: any) => r.slips_count ?? '—' },
    { key: 'mood_score', header: 'Mood', render: (r: any) => r.mood_score ?? '—' },
    { key: 'energy_score', header: 'Energy', render: (r: any) => r.energy_score ?? '—' },
    { key: 'focus_score', header: 'Focus', render: (r: any) => r.focus_score ?? '—' },
    { key: 'burnout_risk', header: 'Burnout', render: (r: any) => r.burnout_risk ?? '—' },
    { key: 'next_week_priority', header: 'Next Week Priority', render: (r: any) => r.next_week_priority ?? '—' },
  ];

  const moodCols: Column<any>[] = [
    { key: 'week_ending', header: 'Week', render: (r: any) => r.week_ending ?? '—' },
    { key: 'mood_score', header: 'Mood', render: (r: any) => r.mood_score ?? '—' },
    { key: 'energy_score', header: 'Energy', render: (r: any) => r.energy_score ?? '—' },
    { key: 'focus_score', header: 'Focus', render: (r: any) => r.focus_score ?? '—' },
    { key: 'burnout_risk', header: 'Burnout', render: (r: any) => r.burnout_risk ?? '—' },
    { key: 'delta_mood', header: 'Mood Δ', render: (r: any) => (r.delta_mood == null ? '—' : (r.delta_mood > 0 ? `+${r.delta_mood}` : String(r.delta_mood))) },
  ];

  const journalCols: Column<any>[] = [
    { key: 'week_ending', header: 'Week', render: (r: any) => r.week_ending ?? '—' },
    { key: 'entry_kind', header: 'Kind', render: (r: any) => r.entry_kind ?? '—' },
    { key: 'entry_text', header: 'Entry', render: (r: any) => r.entry_text ?? '—' },
    { key: 'created_at', header: 'Logged', render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleString() : '—') },
  ];

  const shipSlipCols: Column<any>[] = [
    { key: 'week_ending', header: 'Week', render: (r: any) => r.week_ending ?? '—' },
    { key: 'what_shipped', header: 'Shipped', render: (r: any) => r.what_shipped ?? '—' },
    { key: 'what_slipped', header: 'Slipped', render: (r: any) => r.what_slipped ?? '—' },
    { key: 'what_learned', header: 'Learned', render: (r: any) => r.what_learned ?? '—' },
    { key: 'ships_count', header: 'Ships #', render: (r: any) => r.ships_count ?? '—' },
    { key: 'slips_count', header: 'Slips #', render: (r: any) => r.slips_count ?? '—' },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Founder Friday Stand-Down Log</h1>
        <p className="text-sm text-gray-600">
          End-of-week review {">"} what shipped, slipped, learned + mood/energy {"<"} weekly journal.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="border rounded-lg p-3 bg-white">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Stand-Downs (12 weeks)</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Mood / Energy / Focus Trend</h2>
        <DataTable columns={moodCols} rows={mood} rowKey={(r: any) => r.week_ending} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Ship / Slip / Learn Log</h2>
        <DataTable columns={shipSlipCols} rows={shipSlip} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Journal Entries</h2>
        <DataTable columns={journalCols} rows={journal} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
