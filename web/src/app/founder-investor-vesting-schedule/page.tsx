import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function FounderInvestorVestingSchedulePage() {
  const sb = await getSupabaseServerClient();

  const [schedulesRes, summaryRes, upcomingRes] = await Promise.all([
    sb.rpc('r1693_list_schedules'),
    sb.rpc('r1693_vesting_summary'),
    sb.rpc('r1693_upcoming_vests', { p_days: 90 }),
  ]);

  const schedules = Array.isArray(schedulesRes.data) ? schedulesRes.data : [];
  const summary = Array.isArray(summaryRes.data) && summaryRes.data.length > 0 ? summaryRes.data[0] : null;
  const upcoming = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];

  const fmtNum = (n: number | null | undefined) => {
    if (n === null || n === undefined) return '0';
    return new Intl.NumberFormat('en-IN').format(Number(n));
  };

  const fmtDate = (d: string | null | undefined) => {
    if (!d) return '—';
    try { return new Date(d).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' }); } catch { return String(d); }
  };

  const scheduleCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span className="text-sm">{r.investor_email ?? '—'}</span> },
    { key: 'instrument_type', header: 'Instrument', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${
        r.instrument_type === 'option' ? 'bg-blue-100 text-blue-800' :
        r.instrument_type === 'warrant' ? 'bg-purple-100 text-purple-800' :
        'bg-amber-100 text-amber-800'
      }`}>{r.instrument_type}</span>
    )},
    { key: 'total_shares', header: 'Total Shares', render: (r: any) => <span className="font-mono text-sm">{fmtNum(r.total_shares)}</span> },
    { key: 'cumulative_vested', header: 'Vested', render: (r: any) => (
      <div className="text-sm">
        <div className="font-mono">{fmtNum(r.cumulative_vested)}</div>
        <div className="text-xs text-gray-500">
          {r.total_shares > 0 ? `${((Number(r.cumulative_vested) / Number(r.total_shares)) * 100).toFixed(1)}%` : '—'}
        </div>
      </div>
    )},
    { key: 'vest_start', header: 'Vest Start', render: (r: any) => <span className="text-sm">{fmtDate(r.vest_start)}</span> },
    { key: 'cliff_months', header: 'Cliff / Total', render: (r: any) => (
      <span className="text-sm font-mono">{r.cliff_months}m / {r.total_months}m</span>
    )},
    { key: 'tranche_count', header: 'Tranches', render: (r: any) => <span className="text-sm font-mono">{r.tranche_count ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${
        r.status === 'active' ? 'bg-green-100 text-green-800' :
        r.status === 'paused' ? 'bg-yellow-100 text-yellow-800' :
        'bg-gray-100 text-gray-800'
      }`}>{r.status}</span>
    )},
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'tranche_month', header: 'Vest Date', render: (r: any) => (
      <div>
        <div className="text-sm font-medium">{fmtDate(r.tranche_month)}</div>
        <div className="text-xs text-gray-500">in {r.days_until}d</div>
      </div>
    )},
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span className="text-sm">{r.investor_email ?? '—'}</span> },
    { key: 'instrument_type', header: 'Instrument', render: (r: any) => <span className="text-sm">{r.instrument_type}</span> },
    { key: 'shares_vested', header: 'Shares Vesting', render: (r: any) => <span className="text-sm font-mono font-semibold">{fmtNum(r.shares_vested)}</span> },
    { key: 'cumulative_vested', header: 'Cumulative After', render: (r: any) => <span className="text-sm font-mono">{fmtNum(r.cumulative_vested)}</span> },
    { key: 'priority', header: 'Priority', render: (r: any) => {
      const days = Number(r.days_until ?? 999);
      if (days <= 14) return <span className="inline-block px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">Imminent (&lt;=14d)</span>;
      if (days <= 30) return <span className="inline-block px-2 py-0.5 rounded text-xs font-medium bg-orange-100 text-orange-800">Soon (&lt;=30d)</span>;
      return <span className="inline-block px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">Later (&gt;30d)</span>;
    }},
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Investor Vesting Schedule</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track option, warrant, and SAFE vesting schedules with monthly tranches. Round r1693.
        </p>
      </div>

      <section className="mb-8">
        <h2 className="text-lg font-semibold text-gray-800 mb-3">Vesting Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white border border-gray-200 rounded-lg p-4">
            <div className="text-xs text-gray-500 uppercase">Active Schedules</div>
            <div className="text-2xl font-bold text-green-700 mt-1">{summary?.active_schedules ?? 0}</div>
            <div className="text-xs text-gray-500 mt-1">of {summary?.total_schedules ?? 0} total</div>
          </div>
          <div className="bg-white border border-gray-200 rounded-lg p-4">
            <div className="text-xs text-gray-500 uppercase">Shares Committed</div>
            <div className="text-2xl font-bold text-gray-900 mt-1">{fmtNum(summary?.total_shares_committed)}</div>
            <div className="text-xs text-gray-500 mt-1">all instruments</div>
          </div>
          <div className="bg-white border border-gray-200 rounded-lg p-4">
            <div className="text-xs text-gray-500 uppercase">Shares Vested</div>
            <div className="text-2xl font-bold text-blue-700 mt-1">{fmtNum(summary?.total_shares_vested)}</div>
            <div className="text-xs text-gray-500 mt-1">to date</div>
          </div>
          <div className="bg-white border border-gray-200 rounded-lg p-4">
            <div className="text-xs text-gray-500 uppercase">Shares Exercised</div>
            <div className="text-2xl font-bold text-purple-700 mt-1">{fmtNum(summary?.total_shares_exercised)}</div>
            <div className="text-xs text-gray-500 mt-1">
              {summary?.exercised_tranches ?? 0} / {summary?.total_tranches ?? 0} tranches
            </div>
          </div>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold text-gray-800 mb-3">
          Upcoming Vests (next 90 days)
        </h2>
        {upcoming.length === 0 ? (
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-6 text-center text-sm text-gray-600">
            No tranches vesting in the next 90 days.
          </div>
        ) : (
          <DataTable
            rows={upcoming}
            columns={upcomingCols}
            rowKey={(r: any, i: number) => String(r.tranche_id ?? i)}
          />
        )}
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold text-gray-800 mb-3">All Vesting Schedules</h2>
        {schedules.length === 0 ? (
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-6 text-center text-sm text-gray-600">
            No vesting schedules yet. Call r1693_add_schedule then r1693_generate_tranches via SQL editor or admin tool.
          </div>
        ) : (
          <DataTable
            rows={schedules}
            columns={scheduleCols}
            rowKey={(r: any, i: number) => String(r.id ?? i)}
          />
        )}
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold text-gray-800 mb-3">RPC Reference</h2>
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 text-xs font-mono space-y-1">
          <div>r1693_list_schedules() — list all vesting schedules with investor + progress</div>
          <div>r1693_add_schedule(investor_id, instrument_type, total_shares, vest_start, cliff_months, total_months, notes) — create new schedule</div>
          <div>r1693_list_tranches(schedule_id) — list tranches for a schedule (or all if null)</div>
          <div>r1693_generate_tranches(schedule_id) — auto-generate monthly tranches with cliff logic</div>
          <div>r1693_mark_exercised(tranche_id) — mark a tranche as exercised</div>
          <div>r1693_vesting_summary() — aggregate stats across all schedules</div>
          <div>r1693_upcoming_vests(days) — tranches vesting in the next N days (default 90)</div>
        </div>
      </section>
    </div>
  );
}
