import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Trip = {
  id: string;
  trip_name: string;
  destination_city: string;
  depart_date: string;
  return_date: string;
  trip_purpose: string;
  total_budget_rupees: number;
  actual_spend_rupees: number;
  roi_score: number | null;
  meeting_count: number;
  created_at: string;
};

type RoiRow = {
  trip_purpose: string;
  trip_count: number;
  total_budget_rupees: number;
  total_actual_spend_rupees: number;
  avg_roi_score: number | null;
  total_meetings: number;
};

type Upcoming = {
  id: string;
  trip_name: string;
  destination_city: string;
  depart_date: string;
  return_date: string;
  trip_purpose: string;
  days_until_depart: number;
  meeting_count: number;
  total_budget_rupees: number;
};

function rupees(v: number | null | undefined) {
  const n = Number(v ?? 0);
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [tripsRes, roiRes, upcomingRes] = await Promise.all([
    sb.rpc('list_trips_r1734'),
    sb.rpc('trip_roi_summary_r1734'),
    sb.rpc('upcoming_trips_r1734'),
  ]);

  const trips: Trip[] = (tripsRes.data as Trip[] | null) ?? [];
  const roi: RoiRow[] = (roiRes.data as RoiRow[] | null) ?? [];
  const upcoming: Upcoming[] = (upcomingRes.data as Upcoming[] | null) ?? [];

  const totalBudget = trips.reduce((a, t) => a + Number(t.total_budget_rupees || 0), 0);
  const totalSpend = trips.reduce((a, t) => a + Number(t.actual_spend_rupees || 0), 0);
  const totalMeetings = trips.reduce((a, t) => a + Number(t.meeting_count || 0), 0);

  const tripCols: Column<Trip>[] = [
    { key: 'trip_name', header: 'Trip', render: (r: any) => <span className="font-medium">{r.trip_name}</span> },
    { key: 'destination_city', header: 'City', render: (r: any) => r.destination_city },
    { key: 'depart_date', header: 'Depart', render: (r: any) => r.depart_date },
    { key: 'return_date', header: 'Return', render: (r: any) => r.return_date },
    { key: 'trip_purpose', header: 'Purpose', render: (r: any) => <span className="rounded bg-zinc-100 px-2 py-0.5 text-xs">{r.trip_purpose}</span> },
    { key: 'total_budget_rupees', header: 'Budget', render: (r: any) => rupees(r.total_budget_rupees) },
    { key: 'actual_spend_rupees', header: 'Spend', render: (r: any) => rupees(r.actual_spend_rupees) },
    { key: 'roi_score', header: 'ROI', render: (r: any) => r.roi_score ?? '—' },
    { key: 'meeting_count', header: 'Meetings', render: (r: any) => r.meeting_count },
  ];

  const roiCols: Column<RoiRow>[] = [
    { key: 'trip_purpose', header: 'Purpose', render: (r: any) => <span className="font-medium">{r.trip_purpose}</span> },
    { key: 'trip_count', header: 'Trips', render: (r: any) => r.trip_count },
    { key: 'total_budget_rupees', header: 'Budget', render: (r: any) => rupees(r.total_budget_rupees) },
    { key: 'total_actual_spend_rupees', header: 'Spend', render: (r: any) => rupees(r.total_actual_spend_rupees) },
    { key: 'avg_roi_score', header: 'Avg ROI', render: (r: any) => (r.avg_roi_score == null ? '—' : Number(r.avg_roi_score).toFixed(2)) },
    { key: 'total_meetings', header: 'Meetings', render: (r: any) => r.total_meetings },
  ];

  const upcomingCols: Column<Upcoming>[] = [
    { key: 'trip_name', header: 'Trip', render: (r: any) => <span className="font-medium">{r.trip_name}</span> },
    { key: 'destination_city', header: 'City', render: (r: any) => r.destination_city },
    { key: 'depart_date', header: 'Depart', render: (r: any) => r.depart_date },
    { key: 'return_date', header: 'Return', render: (r: any) => r.return_date },
    { key: 'trip_purpose', header: 'Purpose', render: (r: any) => r.trip_purpose },
    { key: 'days_until_depart', header: 'Days Until', render: (r: any) => <span className={Number(r.days_until_depart) <= 7 ? 'font-semibold text-amber-700' : ''}>{r.days_until_depart}</span> },
    { key: 'meeting_count', header: 'Meetings', render: (r: any) => r.meeting_count },
    { key: 'total_budget_rupees', header: 'Budget', render: (r: any) => rupees(r.total_budget_rupees) },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Founder Travel Itinerary Planner</h1>
        <p className="mt-1 text-sm text-zinc-600">
          Plan founder travel and meeting density per trip. Track budget vs actual spend and ROI score 1–10.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-zinc-500">Trips</div>
          <div className="mt-1 text-2xl font-semibold">{trips.length}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-zinc-500">Total Budget</div>
          <div className="mt-1 text-2xl font-semibold">{rupees(totalBudget)}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-zinc-500">Total Spend</div>
          <div className="mt-1 text-2xl font-semibold">{rupees(totalSpend)}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-zinc-500">Total Meetings</div>
          <div className="mt-1 text-2xl font-semibold">{totalMeetings}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Upcoming Trips</h2>
        <p className="text-sm text-zinc-600">Trips with depart date &gt;= today, sorted by depart date.</p>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">ROI Summary by Purpose</h2>
        <p className="text-sm text-zinc-600">Aggregate budget, spend, and average ROI by trip purpose category.</p>
        <DataTable rows={roi} columns={roiCols} rowKey={(r: any, i: number) => String(r.trip_purpose ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Trips</h2>
        <p className="text-sm text-zinc-600">Complete trip ledger across all purposes. ROI rated 1–10.</p>
        <DataTable rows={trips} columns={tripCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
