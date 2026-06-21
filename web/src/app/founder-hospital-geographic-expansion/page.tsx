import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalGeographicExpansionPage() {
  const sb = await getSupabaseServerClient();

  const [marketsRes, milestonesRes, topGrowthRes, totalsRes] = await Promise.all([
    sb.rpc('list_markets_r1855'),
    sb.rpc('list_milestones_r1855', { p_market_id: null }),
    sb.rpc('top_growth_markets_r1855'),
    sb.rpc('total_expansion_arr_r1855'),
  ]);

  const markets: any[] = Array.isArray(marketsRes.data) ? marketsRes.data : [];
  const milestones: any[] = Array.isArray(milestonesRes.data) ? milestonesRes.data : [];
  const topGrowth: any[] = Array.isArray(topGrowthRes.data) ? topGrowthRes.data : [];
  const totalsRow: any = Array.isArray(totalsRes.data) && totalsRes.data.length > 0 ? totalsRes.data[0] : null;

  const fmtRupees = (n: number | null | undefined) => {
    if (n == null) return '₹0';
    return '₹' + Number(n).toLocaleString('en-IN');
  };
  const fmtDate = (s: string | null | undefined) => {
    if (!s) return '—';
    try { return new Date(s).toLocaleDateString('en-IN'); } catch { return s; }
  };
  const fmtDateTime = (s: string | null | undefined) => {
    if (!s) return '—';
    try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
  };

  const marketCols: Column<any>[] = [
    { key: 'market_name', header: 'Market', render: (r: any) => <span className="font-medium">{r.market_name ?? '—'}</span> },
    { key: 'city', header: 'City', render: (r: any) => <span>{r.city ?? '—'}</span> },
    { key: 'state', header: 'State', render: (r: any) => <span>{r.state ?? '—'}</span> },
    { key: 'launched_at', header: 'Launched', render: (r: any) => <span className="text-xs text-slate-600">{fmtDate(r.launched_at)}</span> },
    { key: 'total_hospitals', header: 'Hospitals', render: (r: any) => <span className="tabular-nums">{r.total_hospitals ?? 0}</span> },
    { key: 'total_arr_rupees', header: 'ARR', render: (r: any) => <span className="tabular-nums">{fmtRupees(r.total_arr_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => {
        const s = String(r.status ?? '');
        const cls = s === 'active' ? 'bg-emerald-100 text-emerald-700'
          : s === 'exited' ? 'bg-rose-100 text-rose-700'
          : 'bg-slate-100 text-slate-700';
        return <span className={`inline-block rounded px-2 py-0.5 text-xs ${cls}`}>{s || '—'}</span>;
      } },
    { key: 'exited_at', header: 'Exited', render: (r: any) => <span className="text-xs text-slate-600">{fmtDate(r.exited_at)}</span> },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'market_name', header: 'Market', render: (r: any) => <span className="font-medium">{r.market_name ?? '—'}</span> },
    { key: 'milestone', header: 'Milestone', render: (r: any) => {
        const m = String(r.milestone ?? '');
        const label = m.replace(/_/g, ' ');
        return <span className="inline-block rounded bg-indigo-100 px-2 py-0.5 text-xs text-indigo-700">{label}</span>;
      } },
    { key: 'achieved_at', header: 'Achieved', render: (r: any) => <span className="text-xs text-slate-600">{fmtDateTime(r.achieved_at)}</span> },
  ];

  const topGrowthCols: Column<any>[] = [
    { key: 'market_name', header: 'Market', render: (r: any) => <span className="font-medium">{r.market_name ?? '—'}</span> },
    { key: 'city', header: 'City', render: (r: any) => <span>{r.city ?? '—'}</span> },
    { key: 'state', header: 'State', render: (r: any) => <span>{r.state ?? '—'}</span> },
    { key: 'total_hospitals', header: 'Hospitals', render: (r: any) => <span className="tabular-nums">{r.total_hospitals ?? 0}</span> },
    { key: 'total_arr_rupees', header: 'ARR', render: (r: any) => <span className="tabular-nums font-medium">{fmtRupees(r.total_arr_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status ?? '—'}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Hospital Geographic Expansion</h1>
        <p className="text-sm text-slate-600">
          Track new geographic markets entered & revenue performance. Markets launched, hospitals onboarded, ARR booked, milestones hit.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <div className="rounded border border-slate-200 bg-white p-4">
          <div className="text-xs text-slate-500">Total markets</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums">{totalsRow?.total_markets ?? 0}</div>
        </div>
        <div className="rounded border border-slate-200 bg-white p-4">
          <div className="text-xs text-slate-500">Active</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums text-emerald-700">{totalsRow?.active_markets ?? 0}</div>
        </div>
        <div className="rounded border border-slate-200 bg-white p-4">
          <div className="text-xs text-slate-500">Exited</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums text-rose-700">{totalsRow?.exited_markets ?? 0}</div>
        </div>
        <div className="rounded border border-slate-200 bg-white p-4">
          <div className="text-xs text-slate-500">Hospitals onboarded</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums">{totalsRow?.total_hospitals ?? 0}</div>
        </div>
        <div className="rounded border border-slate-200 bg-white p-4">
          <div className="text-xs text-slate-500">Total ARR</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums">{fmtRupees(totalsRow?.total_arr_rupees)}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">All markets</h2>
        <p className="text-xs text-slate-500">Most recently launched first. Limit 200.</p>
        <DataTable
          rows={markets}
          columns={marketCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Top growth markets</h2>
        <p className="text-xs text-slate-500">Active markets ranked by ARR & hospital count. Top 25.</p>
        <DataTable
          rows={topGrowth}
          columns={topGrowthCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent milestones</h2>
        <p className="text-xs text-slate-500">first_hospital → first_engineer → first_arr_lakh → break_even → first_amc. Limit 200.</p>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
