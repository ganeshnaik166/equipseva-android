import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type QuarterRow = { quarter: string; fiscal_year: number; completed_sessions: number; scheduled_sessions: number; completion_rate_pct: number | null; avg_candor: number | null; avg_morale: number | null; critical_flight_risk: number; id?: string };
type TierRow = { engineer_tier: string; sessions: number; avg_morale: number | null; avg_candor: number | null; avg_nps: number | null; id?: string };
type FlightRow = { engineer_code: string; engineer_tier: string; region: string; flight_risk: string; morale_score: number | null; top_concern: string | null; follow_up_required: boolean; id?: string };
type HeatRow = { signal_category: string; total_signals: number; critical_signals: number; open_signals: number; avg_impact: number | null; id?: string };
type OpenSig = { signal_theme: string; signal_category: string; signal_severity: string; recurrence_count: number; confidence_pct: number | null; impact_score: number | null; founder_response_status: string; id?: string };
type RegionRow = { region: string; completed: number; avg_morale: number | null; high_critical_risk: number; signals_logged: number; id?: string };
type FollowRow = { engineer_code: string; engineer_tier: string; top_concern: string | null; founder_action_committed: string | null; flight_risk: string | null; completed_at: string | null; id?: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [q, t, f, h, o, r, fu] = await Promise.all([
    supabase.rpc('r3033_quarter_pulse_summary'),
    supabase.rpc('r3033_tier_morale_breakdown'),
    supabase.rpc('r3033_flight_risk_register'),
    supabase.rpc('r3033_signal_category_heatmap'),
    supabase.rpc('r3033_open_critical_signals'),
    supabase.rpc('r3033_region_pulse_grid'),
    supabase.rpc('r3033_followup_action_queue'),
  ]);

  const quarter = (q.data ?? []) as QuarterRow[];
  const tier = (t.data ?? []) as TierRow[];
  const flight = (f.data ?? []) as FlightRow[];
  const heat = (h.data ?? []) as HeatRow[];
  const open = (o.data ?? []) as OpenSig[];
  const region = (r.data ?? []) as RegionRow[];
  const follow = (fu.data ?? []) as FollowRow[];

  const qCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (x) => `${x.quarter} FY${x.fiscal_year}` },
    { header: 'Completed', accessor: (x) => x.completed_sessions },
    { header: 'Scheduled', accessor: (x) => x.scheduled_sessions },
    { header: 'Completion %', accessor: (x) => x.completion_rate_pct ?? '—' },
    { header: 'Avg Candor', accessor: (x) => x.avg_candor ?? '—' },
    { header: 'Avg Morale', accessor: (x) => x.avg_morale ?? '—' },
    { header: 'Critical Flight Risk', accessor: (x) => x.critical_flight_risk },
  ];

  const tCols: Column<TierRow>[] = [
    { header: 'Tier', accessor: (x) => x.engineer_tier },
    { header: 'Sessions', accessor: (x) => x.sessions },
    { header: 'Avg Morale', accessor: (x) => x.avg_morale ?? '—' },
    { header: 'Avg Candor', accessor: (x) => x.avg_candor ?? '—' },
    { header: 'Avg NPS', accessor: (x) => x.avg_nps ?? '—' },
  ];

  const fCols: Column<FlightRow>[] = [
    { header: 'Engineer', accessor: (x) => x.engineer_code },
    { header: 'Tier', accessor: (x) => x.engineer_tier },
    { header: 'Region', accessor: (x) => x.region },
    { header: 'Flight Risk', accessor: (x) => x.flight_risk },
    { header: 'Morale', accessor: (x) => x.morale_score ?? '—' },
    { header: 'Top Concern', accessor: (x) => x.top_concern ?? '—' },
    { header: 'Follow-up', accessor: (x) => (x.follow_up_required ? 'yes' : 'no') },
  ];

  const hCols: Column<HeatRow>[] = [
    { header: 'Category', accessor: (x) => x.signal_category },
    { header: 'Total', accessor: (x) => x.total_signals },
    { header: 'Critical', accessor: (x) => x.critical_signals },
    { header: 'Open', accessor: (x) => x.open_signals },
    { header: 'Avg Impact', accessor: (x) => x.avg_impact ?? '—' },
  ];

  const oCols: Column<OpenSig>[] = [
    { header: 'Theme', accessor: (x) => x.signal_theme },
    { header: 'Category', accessor: (x) => x.signal_category },
    { header: 'Severity', accessor: (x) => x.signal_severity },
    { header: 'Recurrence', accessor: (x) => x.recurrence_count },
    { header: 'Confidence %', accessor: (x) => x.confidence_pct ?? '—' },
    { header: 'Impact', accessor: (x) => x.impact_score ?? '—' },
    { header: 'Status', accessor: (x) => x.founder_response_status },
  ];

  const rCols: Column<RegionRow>[] = [
    { header: 'Region', accessor: (x) => x.region },
    { header: 'Completed', accessor: (x) => x.completed },
    { header: 'Avg Morale', accessor: (x) => x.avg_morale ?? '—' },
    { header: 'High/Critical', accessor: (x) => x.high_critical_risk },
    { header: 'Signals', accessor: (x) => x.signals_logged },
  ];

  const fuCols: Column<FollowRow>[] = [
    { header: 'Engineer', accessor: (x) => x.engineer_code },
    { header: 'Tier', accessor: (x) => x.engineer_tier },
    { header: 'Concern', accessor: (x) => x.top_concern ?? '—' },
    { header: 'Founder Commit', accessor: (x) => x.founder_action_committed ?? '—' },
    { header: 'Risk', accessor: (x) => x.flight_risk ?? '—' },
    { header: 'Completed At', accessor: (x) => x.completed_at ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Quarterly Strategic Engineer-Founder Direct-Line Skip-Level Pulse Audit</h1>
        <p className="text-sm text-gray-600">Round r3033 — founder-only skip-level intelligence across tiers, regions & quarters.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Pulse Summary</h2>
        <DataTable rows={quarter} columns={qCols} emptyMessage="No quarter data yet" rowKey={(r, i) => String(r.id ?? `${r.quarter}-${r.fiscal_year}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Morale Breakdown</h2>
        <DataTable rows={tier} columns={tCols} emptyMessage="No tier data" rowKey={(r, i) => String(r.id ?? `${r.engineer_tier}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Flight Risk Register (high & critical)</h2>
        <DataTable rows={flight} columns={fCols} emptyMessage="No flight risks" rowKey={(r, i) => String(r.id ?? `${r.engineer_code}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Signal Category Heatmap</h2>
        <DataTable rows={heat} columns={hCols} emptyMessage="No signals" rowKey={(r, i) => String(r.id ?? `${r.signal_category}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Critical Signals</h2>
        <DataTable rows={open} columns={oCols} emptyMessage="No open critical signals" rowKey={(r, i) => String(r.id ?? `${r.signal_theme}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Region Pulse Grid</h2>
        <DataTable rows={region} columns={rCols} emptyMessage="No region data" rowKey={(r, i) => String(r.id ?? `${r.region}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-up Action Queue</h2>
        <DataTable rows={follow} columns={fuCols} emptyMessage="No follow-ups pending" rowKey={(r, i) => String(r.id ?? `${r.engineer_code}-fu-${i}`)} />
      </section>
    </div>
  );
}
