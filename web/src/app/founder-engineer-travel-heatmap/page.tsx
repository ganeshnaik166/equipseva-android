import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TravelWeek = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  week_start: string;
  total_km: number;
  total_cost_rupees: number;
  jobs_completed: number;
  productivity_per_km: number;
  cost_per_km: number;
  created_at: string;
};

type TopEngineer = {
  engineer_user_id: string;
  engineer_email: string | null;
  total_km_4w: number;
  total_cost_4w: number;
  jobs_4w: number;
  avg_cost_per_km: number;
};

type Ticket = {
  id: string;
  week_id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  week_start: string;
  suggestion_text: string;
  expected_saving_rupees: number;
  status: string;
  decided_at: string | null;
  created_at: string;
};

type Summary = {
  total_weeks: number;
  total_km_4w: number;
  total_cost_4w: number;
  avg_cost_per_km: number;
  avg_productivity_per_km: number;
  open_tickets: number;
  applied_tickets: number;
  expected_savings_open_rupees: number;
};

function rupees(n: number | null | undefined) {
  if (n == null) return '—';
  return `₹${Number(n).toLocaleString('en-IN')}`;
}

function num(n: number | null | undefined, digits = 2) {
  if (n == null) return '—';
  return Number(n).toFixed(digits);
}

export default async function FounderEngineerTravelHeatmapPage() {
  const sb = await getSupabaseServerClient();

  const [weeksRes, topRes, ticketsRes, summaryRes] = await Promise.all([
    sb.rpc('list_travel_weeks_r1668'),
    sb.rpc('top_km_engineers_r1668'),
    sb.rpc('list_tickets_r1668'),
    sb.rpc('travel_summary_r1668'),
  ]);

  const weeks: TravelWeek[] = (weeksRes.data as TravelWeek[]) ?? [];
  const top: TopEngineer[] = (topRes.data as TopEngineer[]) ?? [];
  const tickets: Ticket[] = (ticketsRes.data as Ticket[]) ?? [];
  const summary: Summary | null = Array.isArray(summaryRes.data)
    ? ((summaryRes.data[0] as Summary) ?? null)
    : ((summaryRes.data as Summary) ?? null);

  const weekCols: Column<TravelWeek>[] = [
    { key: 'week_start', header: 'Week', render: (r) => <span className="font-mono text-sm">{r.week_start}</span> },
    { key: 'engineer_email', header: 'Engineer', render: (r) => <span className="text-sm">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span> },
    { key: 'total_km', header: 'KM', render: (r) => <span className="font-mono">{r.total_km.toLocaleString('en-IN')}</span> },
    { key: 'total_cost_rupees', header: 'Cost', render: (r) => <span className="font-mono">{rupees(r.total_cost_rupees)}</span> },
    { key: 'cost_per_km', header: '₹/km', render: (r) => <span className="font-mono">{rupees(Math.round(Number(r.cost_per_km)))}</span> },
    { key: 'jobs_completed', header: 'Jobs', render: (r) => <span className="font-mono">{r.jobs_completed}</span> },
    { key: 'productivity_per_km', header: 'Jobs/km', render: (r) => <span className="font-mono">{num(r.productivity_per_km, 4)}</span> },
  ];

  const topCols: Column<TopEngineer>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => <span className="text-sm">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span> },
    { key: 'total_km_4w', header: 'KM (4w)', render: (r) => <span className="font-mono font-semibold">{r.total_km_4w.toLocaleString('en-IN')}</span> },
    { key: 'total_cost_4w', header: 'Cost (4w)', render: (r) => <span className="font-mono">{rupees(r.total_cost_4w)}</span> },
    { key: 'jobs_4w', header: 'Jobs', render: (r) => <span className="font-mono">{r.jobs_4w}</span> },
    { key: 'avg_cost_per_km', header: 'Avg ₹/km', render: (r) => <span className="font-mono">{rupees(Math.round(Number(r.avg_cost_per_km)))}</span> },
  ];

  const ticketCols: Column<Ticket>[] = [
    { key: 'week_start', header: 'Week', render: (r) => <span className="font-mono text-sm">{r.week_start}</span> },
    { key: 'engineer_email', header: 'Engineer', render: (r) => <span className="text-sm">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span> },
    { key: 'suggestion_text', header: 'Suggestion', render: (r) => <span className="text-sm">{r.suggestion_text}</span> },
    { key: 'expected_saving_rupees', header: 'Expected Saving', render: (r) => <span className="font-mono">{rupees(r.expected_saving_rupees)}</span> },
    {
      key: 'status',
      header: 'Status',
      render: (r) => {
        const cls =
          r.status === 'open'
            ? 'bg-amber-100 text-amber-800'
            : r.status === 'applied'
              ? 'bg-emerald-100 text-emerald-800'
              : 'bg-zinc-100 text-zinc-700';
        return <span className={`px-2 py-0.5 rounded text-xs font-medium ${cls}`}>{r.status}</span>;
      },
    },
    { key: 'decided_at', header: 'Decided', render: (r) => <span className="font-mono text-xs">{r.decided_at ? new Date(r.decided_at).toLocaleString() : '—'}</span> },
  ];

  return (
    <main className="min-h-screen bg-zinc-50 p-6 md:p-10">
      <div className="mx-auto max-w-7xl space-y-8">
        <header className="space-y-1">
          <h1 className="text-2xl md:text-3xl font-bold text-zinc-900">Engineer Travel Heatmap</h1>
          <p className="text-sm text-zinc-600">
            r1668 · km/week, cost/km, productivity/km · routing optimization queue
          </p>
        </header>

        <section aria-labelledby="kpis-heading" className="space-y-3">
          <h2 id="kpis-heading" className="text-lg font-semibold text-zinc-800">
            Last 28 days
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <Kpi label="KM (4w)" value={summary ? summary.total_km_4w.toLocaleString('en-IN') : '—'} />
            <Kpi label="Cost (4w)" value={summary ? rupees(summary.total_cost_4w) : '—'} />
            <Kpi label="Avg ₹/km" value={summary ? rupees(Math.round(Number(summary.avg_cost_per_km))) : '—'} />
            <Kpi label="Avg jobs/km" value={summary ? num(summary.avg_productivity_per_km, 4) : '—'} />
            <Kpi label="Total weeks logged" value={summary ? String(summary.total_weeks) : '—'} />
            <Kpi label="Open tickets" value={summary ? String(summary.open_tickets) : '—'} accent="amber" />
            <Kpi label="Applied tickets" value={summary ? String(summary.applied_tickets) : '—'} accent="emerald" />
            <Kpi
              label="Expected savings (open)"
              value={summary ? rupees(summary.expected_savings_open_rupees) : '—'}
              accent="emerald"
            />
          </div>
        </section>

        <section aria-labelledby="top-heading" className="space-y-3">
          <h2 id="top-heading" className="text-lg font-semibold text-zinc-800">
            Top KM engineers (last 4 weeks)
          </h2>
          <div className="bg-white rounded-lg shadow-sm border border-zinc-200 overflow-hidden">
            <DataTable
              rows={top}
              columns={topCols}
              rowKey={(r, i) => String(r.engineer_user_id ?? i)}
            />
          </div>
        </section>

        <section aria-labelledby="weeks-heading" className="space-y-3">
          <h2 id="weeks-heading" className="text-lg font-semibold text-zinc-800">
            Weekly travel ledger
          </h2>
          <div className="bg-white rounded-lg shadow-sm border border-zinc-200 overflow-hidden">
            <DataTable
              rows={weeks}
              columns={weekCols}
              rowKey={(r, i) => String(r.id ?? i)}
            />
          </div>
        </section>

        <section aria-labelledby="tickets-heading" className="space-y-3">
          <h2 id="tickets-heading" className="text-lg font-semibold text-zinc-800">
            Optimization queue
          </h2>
          <div className="bg-white rounded-lg shadow-sm border border-zinc-200 overflow-hidden">
            <DataTable
              rows={tickets}
              columns={ticketCols}
              rowKey={(r, i) => String(r.id ?? i)}
            />
          </div>
        </section>
      </div>
    </main>
  );
}

function Kpi({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: 'amber' | 'emerald';
}) {
  const valCls =
    accent === 'amber'
      ? 'text-amber-700'
      : accent === 'emerald'
        ? 'text-emerald-700'
        : 'text-zinc-900';
  return (
    <div className="rounded-lg bg-white border border-zinc-200 p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-zinc-500">{label}</div>
      <div className={`mt-1 text-xl font-semibold ${valCls}`}>{value}</div>
    </div>
  );
}
