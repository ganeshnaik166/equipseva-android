import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalRepeatBookingDriversPage() {
  const sb = await getSupabaseServerClient();

  const [driversRes, logsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_drivers_r1907'),
    sb.rpc('list_logs_r1907'),
    sb.rpc('top_drivers_r1907'),
    sb.rpc('recent_logs_r1907'),
  ]);

  const drivers: any[] = (driversRes.data as any[]) ?? [];
  const logs: any[] = (logsRes.data as any[]) ?? [];
  const top: any[] = (topRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const totalDrivers = drivers.length;
  const strongCount = drivers.filter((d) => d.status === 'strong').length;
  const decliningCount = drivers.filter((d) => d.status === 'declining').length;
  const avgScore =
    logs.length > 0
      ? Math.round(
          (logs.reduce((s, l) => s + Number(l.repeat_score ?? 0), 0) / logs.length) * 10
        ) / 10
      : 0;

  const driverColumns: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span>{r.hospital_email ?? r.hospital_id}</span> },
    { key: 'driver_category', header: 'Driver', render: (r: any) => <span>{r.driver_category}</span> },
    { key: 'weight', header: 'Weight', render: (r: any) => <span>{r.weight}/10</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span>{r.captured_at ? new Date(r.captured_at).toLocaleString() : '-'}</span> },
  ];

  const topColumns: Column<any>[] = [
    { key: 'driver_category', header: 'Category', render: (r: any) => <span>{r.driver_category}</span> },
    { key: 'total_count', header: 'Total', render: (r: any) => <span>{r.total_count}</span> },
    { key: 'avg_weight', header: 'Avg weight', render: (r: any) => <span>{r.avg_weight}</span> },
    { key: 'strong_count', header: 'Strong', render: (r: any) => <span>{r.strong_count}</span> },
  ];

  const logColumns: Column<any>[] = [
    { key: 'driver_category', header: 'Category', render: (r: any) => <span>{r.driver_category ?? '-'}</span> },
    { key: 'repeat_score', header: 'Repeat score', render: (r: any) => <span>{r.repeat_score}/100</span> },
    { key: 'booking_id', header: 'Booking', render: (r: any) => <span className="font-mono text-xs">{r.booking_id ? String(r.booking_id).slice(0, 8) : '-'}</span> },
    { key: 'note_md', header: 'Note', render: (r: any) => <span className="text-sm text-gray-700">{r.note_md ?? '-'}</span> },
    { key: 'logged_at', header: 'Logged', render: (r: any) => <span>{r.logged_at ? new Date(r.logged_at).toLocaleString() : '-'}</span> },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'driver_category', header: 'Category', render: (r: any) => <span>{r.driver_category ?? '-'}</span> },
    { key: 'repeat_score', header: 'Score', render: (r: any) => <span>{r.repeat_score}</span> },
    { key: 'note_md', header: 'Note', render: (r: any) => <span className="text-sm text-gray-700">{r.note_md ?? '-'}</span> },
    { key: 'logged_at', header: 'When', render: (r: any) => <span>{r.logged_at ? new Date(r.logged_at).toLocaleString() : '-'}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Hospital Repeat Booking Drivers</h1>
        <p className="text-sm text-gray-600 mt-1">
          Why hospitals come back: track engineer quality, price, turnaround & relationship signals across the book of business.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Total drivers tracked</div>
          <div className="text-2xl font-bold mt-1">{totalDrivers}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Strong signal</div>
          <div className="text-2xl font-bold mt-1 text-emerald-600">{strongCount}</div>
          <div className="text-xs text-gray-500 mt-1">weight &gt;= 7 typical</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Declining</div>
          <div className="text-2xl font-bold mt-1 text-rose-600">{decliningCount}</div>
          <div className="text-xs text-gray-500 mt-1">needs intervention</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Avg repeat score</div>
          <div className="text-2xl font-bold mt-1">{avgScore}</div>
          <div className="text-xs text-gray-500 mt-1">scale 0 &lt;= score &lt;= 100</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top drivers by category</h2>
        <p className="text-sm text-gray-600 mb-3">
          Aggregated across hospitals. Strong count = drivers marked status = strong.
        </p>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.driver_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All drivers</h2>
        <p className="text-sm text-gray-600 mb-3">Last 200 captured driver signals.</p>
        <DataTable
          rows={drivers}
          columns={driverColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent booking logs (last 30 days)</h2>
        <p className="text-sm text-gray-600 mb-3">
          Bookings annotated with the driver that won them & the repeat-score given.
        </p>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Full log history</h2>
        <p className="text-sm text-gray-600 mb-3">Last 200 booking-driver attributions.</p>
        <DataTable
          rows={logs}
          columns={logColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
