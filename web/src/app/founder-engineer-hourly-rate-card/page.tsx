import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerHourlyRateCardPage() {
  const sb = await getSupabaseServerClient();

  const [ratesRes, marginRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_rates_r1852', { p_status: 'current' }),
    sb.rpc('rate_margin_summary_r1852'),
    sb.rpc('top_billable_engineers_r1852'),
    sb.rpc('recent_rate_changes_r1852'),
  ]);

  const rates: any[] = Array.isArray(ratesRes.data) ? ratesRes.data : [];
  const margins: any[] = Array.isArray(marginRes.data) ? marginRes.data : [];
  const topBillable: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalEngineers = rates.length;
  const avgBillable = rates.length > 0
    ? Math.round(rates.reduce((s, r) => s + (r.billable_rate_rupees_per_hour || 0), 0) / rates.length)
    : 0;
  const avgMargin = rates.length > 0
    ? Math.round(rates.reduce((s, r) => s + ((r.billable_rate_rupees_per_hour || 0) - (r.cost_rate_rupees_per_hour || 0)), 0) / rates.length)
    : 0;

  const rateColumns: Column<any>[] = [
    { key: 'email', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_email || r.engineer_user_id?.slice(0, 8) || '—'}</span> },
    { key: 'role', header: 'Role', render: (r: any) => <span className="px-2 py-0.5 rounded bg-blue-100 text-blue-800 text-xs">{r.role_level}</span> },
    { key: 'billable', header: 'Billable/hr', render: (r: any) => <span className="font-semibold">₹{(r.billable_rate_rupees_per_hour || 0).toLocaleString('en-IN')}</span> },
    { key: 'cost', header: 'Cost/hr', render: (r: any) => <span>₹{(r.cost_rate_rupees_per_hour || 0).toLocaleString('en-IN')}</span> },
    { key: 'margin', header: 'Margin/hr', render: (r: any) => <span className={`font-semibold ${(r.margin_rupees_per_hour || 0) > 0 ? 'text-green-700' : 'text-red-700'}`}>₹{(r.margin_rupees_per_hour || 0).toLocaleString('en-IN')}</span> },
    { key: 'effective', header: 'Effective', render: (r: any) => <span className="text-xs">{r.effective_date || '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className={`px-2 py-0.5 rounded text-xs ${r.status === 'current' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-700'}`}>{r.status}</span> },
  ];

  const marginColumns: Column<any>[] = [
    { key: 'role', header: 'Role Level', render: (r: any) => <span className="font-medium capitalize">{r.role_level}</span> },
    { key: 'count', header: 'Engineers', render: (r: any) => <span>{r.engineer_count}</span> },
    { key: 'avg_bill', header: 'Avg Billable', render: (r: any) => <span>₹{(r.avg_billable_rupees || 0).toLocaleString('en-IN')}/hr</span> },
    { key: 'avg_cost', header: 'Avg Cost', render: (r: any) => <span>₹{(r.avg_cost_rupees || 0).toLocaleString('en-IN')}/hr</span> },
    { key: 'avg_margin', header: 'Avg Margin', render: (r: any) => <span className="font-semibold text-green-700">₹{(r.avg_margin_rupees || 0).toLocaleString('en-IN')}/hr</span> },
    { key: 'pct', header: 'Margin %', render: (r: any) => <span className="font-semibold">{r.margin_pct}%</span> },
  ];

  const topColumns: Column<any>[] = [
    { key: 'email', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_email || r.engineer_user_id?.slice(0, 8) || '—'}</span> },
    { key: 'role', header: 'Role', render: (r: any) => <span className="capitalize text-sm">{r.role_level}</span> },
    { key: 'billable', header: 'Billable/hr', render: (r: any) => <span className="font-semibold">₹{(r.billable_rate_rupees_per_hour || 0).toLocaleString('en-IN')}</span> },
    { key: 'cost', header: 'Cost/hr', render: (r: any) => <span>₹{(r.cost_rate_rupees_per_hour || 0).toLocaleString('en-IN')}</span> },
    { key: 'margin', header: 'Margin/hr', render: (r: any) => <span className="font-semibold text-green-700">₹{(r.margin_rupees_per_hour || 0).toLocaleString('en-IN')}</span> },
  ];

  const changeColumns: Column<any>[] = [
    { key: 'email', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_email || '—'}</span> },
    { key: 'old', header: 'Old', render: (r: any) => <span>₹{(r.old_billable_rupees || 0).toLocaleString('en-IN')}</span> },
    { key: 'new', header: 'New', render: (r: any) => <span>₹{(r.new_billable_rupees || 0).toLocaleString('en-IN')}</span> },
    { key: 'delta', header: 'Delta', render: (r: any) => <span className={`font-semibold ${(r.delta_rupees || 0) >= 0 ? 'text-green-700' : 'text-red-700'}`}>{(r.delta_rupees || 0) >= 0 ? '+' : ''}₹{(r.delta_rupees || 0).toLocaleString('en-IN')}</span> },
    { key: 'reason', header: 'Reason', render: (r: any) => <span className="text-xs text-gray-700">{r.change_reason || '—'}</span> },
    { key: 'when', header: 'When', render: (r: any) => <span className="text-xs">{r.changed_at ? new Date(r.changed_at).toLocaleDateString() : '—'}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Hourly Rate Card</h1>
        <p className="text-sm text-gray-600 mt-1">
          Per-engineer hourly billable & cost rates for project pricing & margin tracking.
        </p>
      </header>

      <section className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Active Rate Cards</div>
          <div className="mt-1 text-2xl font-bold">{totalEngineers}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Avg Billable / hr</div>
          <div className="mt-1 text-2xl font-bold">₹{avgBillable.toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Avg Margin / hr</div>
          <div className="mt-1 text-2xl font-bold text-green-700">₹{avgMargin.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section className="rounded-lg border bg-white p-4">
        <h2 className="text-lg font-semibold mb-3">Current Rate Cards</h2>
        <DataTable rows={rates} columns={rateColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section className="rounded-lg border bg-white p-4">
        <h2 className="text-lg font-semibold mb-3">Margin Summary by Role</h2>
        <DataTable rows={margins} columns={marginColumns} rowKey={(r, i) => String(r.role_level ?? i)} />
      </section>

      <section className="rounded-lg border bg-white p-4">
        <h2 className="text-lg font-semibold mb-3">Top 25 Billable Engineers</h2>
        <DataTable rows={topBillable} columns={topColumns} rowKey={(r, i) => String(r.engineer_user_id ?? i)} />
      </section>

      <section className="rounded-lg border bg-white p-4">
        <h2 className="text-lg font-semibold mb-3">Recent Rate Changes (last 30 days)</h2>
        <DataTable rows={recent} columns={changeColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
