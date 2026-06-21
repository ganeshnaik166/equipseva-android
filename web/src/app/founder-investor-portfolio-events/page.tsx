import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type EventRow = {
  id: string;
  investor_name: string;
  event_title: string;
  event_kind: string;
  starts_at: string;
  ends_at: string | null;
  location: string | null;
  is_virtual: boolean;
  rsvp_status: string;
  importance: string;
  agenda_item_count: number;
};

type WeekRow = {
  week_start: string;
  event_count: number;
  accepted_count: number;
  pending_count: number;
  high_importance_count: number;
};

type RsvpRow = {
  rsvp_status: string;
  event_count: number;
  next_starts_at: string | null;
};

type InvestorRow = {
  investor_name: string;
  total_events: number;
  upcoming_events: number;
  attended_events: number;
  last_event_at: string | null;
  next_event_at: string | null;
};

export default async function FounderInvestorPortfolioEventsPage() {
  const sb = await getSupabaseServerClient();

  const eventsRes = await sb.rpc('founder_list_investor_portfolio_events', { p_days_ahead: 90 });
  const scheduleRes = await sb.rpc('founder_investor_portfolio_events_schedule');
  const rsvpRes = await sb.rpc('founder_investor_portfolio_events_rsvp_summary');
  const investorsRes = await sb.rpc('founder_investor_portfolio_events_by_investor');

  const events = (eventsRes.data ?? []) as EventRow[];
  const schedule = (scheduleRes.data ?? []) as WeekRow[];
  const rsvps = (rsvpRes.data ?? []) as RsvpRow[];
  const investors = (investorsRes.data ?? []) as InvestorRow[];

  const eventCols: Column<EventRow>[] = [
    { key: 'starts_at', header: 'When', render: (r) => new Date(r.starts_at).toLocaleString() },
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'event_title', header: 'Title', render: (r) => r.event_title ?? '—' },
    { key: 'event_kind', header: 'Kind', render: (r) => r.event_kind ?? '—' },
    { key: 'location', header: 'Location', render: (r) => (r.is_virtual ? 'Virtual' : (r.location ?? '—')) },
    { key: 'rsvp_status', header: 'RSVP', render: (r) => r.rsvp_status ?? '—' },
    { key: 'importance', header: 'Importance', render: (r) => r.importance ?? '—' },
    { key: 'agenda_item_count', header: 'Agenda', render: (r) => String(r.agenda_item_count ?? 0) },
  ];

  const weekCols: Column<WeekRow>[] = [
    { key: 'week_start', header: 'Week Of', render: (r) => r.week_start ?? '—' },
    { key: 'event_count', header: 'Events', render: (r) => String(r.event_count ?? 0) },
    { key: 'accepted_count', header: 'Accepted', render: (r) => String(r.accepted_count ?? 0) },
    { key: 'pending_count', header: 'Pending', render: (r) => String(r.pending_count ?? 0) },
    { key: 'high_importance_count', header: 'High Importance', render: (r) => String(r.high_importance_count ?? 0) },
  ];

  const rsvpCols: Column<RsvpRow>[] = [
    { key: 'rsvp_status', header: 'RSVP', render: (r) => r.rsvp_status ?? '—' },
    { key: 'event_count', header: 'Count', render: (r) => String(r.event_count ?? 0) },
    { key: 'next_starts_at', header: 'Next', render: (r) => (r.next_starts_at ? new Date(r.next_starts_at).toLocaleString() : '—') },
  ];

  const investorCols: Column<InvestorRow>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'total_events', header: 'Total', render: (r) => String(r.total_events ?? 0) },
    { key: 'upcoming_events', header: 'Upcoming', render: (r) => String(r.upcoming_events ?? 0) },
    { key: 'attended_events', header: 'Attended', render: (r) => String(r.attended_events ?? 0) },
    { key: 'last_event_at', header: 'Last', render: (r) => (r.last_event_at ? new Date(r.last_event_at).toLocaleDateString() : '—') },
    { key: 'next_event_at', header: 'Next', render: (r) => (r.next_event_at ? new Date(r.next_event_at).toLocaleDateString() : '—') },
  ];

  const upcomingCount = events.filter((e) => new Date(e.starts_at) >= new Date()).length;
  const pendingRsvp = events.filter((e) => e.rsvp_status === 'pending').length;
  const highImportance = events.filter((e) => e.importance === 'high' || e.importance === 'critical').length;

  return (
    <div className="mx-auto max-w-7xl px-6 py-10">
      <header className="mb-8">
        <p className="text-xs uppercase tracking-widest text-slate-500">Capital · r1637</p>
        <h1 className="mt-1 text-3xl font-semibold text-slate-900">Investor Portfolio Events Calendar</h1>
        <p className="mt-2 text-sm text-slate-600">
          Calendar of portfolio investor events: annual meetings, conferences, demo days. Per-event RSVP, agenda, founder schedule.
        </p>
      </header>

      <section className="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs uppercase tracking-wide text-slate-500">Upcoming (90d)</p>
          <p className="mt-1 text-2xl font-semibold text-slate-900">{upcomingCount}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs uppercase tracking-wide text-slate-500">RSVP Pending</p>
          <p className="mt-1 text-2xl font-semibold text-amber-600">{pendingRsvp}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs uppercase tracking-wide text-slate-500">High Importance</p>
          <p className="mt-1 text-2xl font-semibold text-rose-600">{highImportance}</p>
        </div>
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">Schedule (next 90 days)</h2>
        <DataTable<EventRow> rows={events} columns={eventCols} rowKey={(r) => r.id} />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">Weekly Burn</h2>
        <DataTable<WeekRow> rows={schedule} columns={weekCols} rowKey={(r) => r.week_start} />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">RSVP Summary</h2>
        <DataTable<RsvpRow> rows={rsvps} columns={rsvpCols} rowKey={(r) => r.rsvp_status} />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">By Investor</h2>
        <DataTable<InvestorRow> rows={investors} columns={investorCols} rowKey={(r) => r.investor_name} />
      </section>
    </div>
  );
}
