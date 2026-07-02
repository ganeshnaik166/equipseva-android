import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [prefsRes, switchesRes, mixRes, costRes, reasonsRes, kpisRes, recentRes] = await Promise.all([
    sb.rpc('r2276_list_preferences'),
    sb.rpc('r2276_list_switches'),
    sb.rpc('r2276_mode_mix'),
    sb.rpc('r2276_cost_ranking'),
    sb.rpc('r2276_switch_reasons'),
    sb.rpc('r2276_kpis'),
    sb.rpc('r2276_recent_switches'),
  ]);

  const prefs = (prefsRes.data ?? []) as any[];
  const switches = (switchesRes.data ?? []) as any[];
  const mix = (mixRes.data ?? []) as any[];
  const cost = (costRes.data ?? []) as any[];
  const reasons = (reasonsRes.data ?? []) as any[];
  const kpis = ((kpisRes.data ?? [])[0] ?? {}) as any;
  const recent = (recentRes.data ?? []) as any[];

  const fmt = (n: number) => '₹' + (Number(n) || 0).toLocaleString('en-IN');

  const prefCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'primary_mode', header: 'Primary', render: (r) => String(r.primary_mode).toUpperCase() },
    { key: 'secondary_mode', header: 'Secondary', render: (r) => r.secondary_mode ? String(r.secondary_mode).toUpperCase() : '—' },
    { key: 'monthly_volume_rupees', header: 'Monthly vol', render: (r) => fmt(r.monthly_volume_rupees) },
    { key: 'txn_count_30d', header: 'Txns 30d', render: (r: any) => String(r.txn_count_30d ?? '') },
    { key: 'avg_settlement_hours', header: 'Avg settle (h)', render: (r) => Number(r.avg_settlement_hours).toFixed(1) },
    { key: 'cost_to_serve_rupees', header: 'Cost-to-serve', render: (r) => fmt(r.cost_to_serve_rupees) },
    { key: 'failure_rate_pct', header: 'Fail %', render: (r) => Number(r.failure_rate_pct).toFixed(2) + '%' },
  ];

  const switchCols: Column<any>[] = [
    { key: 'switched_at', header: 'When', render: (r) => new Date(r.switched_at).toLocaleDateString('en-IN') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'from_mode', header: 'From', render: (r) => String(r.from_mode).toUpperCase() },
    { key: 'to_mode', header: 'To', render: (r) => String(r.to_mode).toUpperCase() },
    { key: 'switch_reason', header: 'Reason', render: (r: any) => String(r.switch_reason ?? '') },
    { key: 'cost_delta_rupees', header: 'Cost Δ', render: (r) => fmt(r.cost_delta_rupees) },
    { key: 'settlement_delta_hours', header: 'Settle Δ (h)', render: (r) => Number(r.settlement_delta_hours).toFixed(1) },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const mixCols: Column<any>[] = [
    { key: 'mode', header: 'Mode', render: (r) => String(r.mode).toUpperCase() },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? '') },
    { key: 'total_monthly_volume_rupees', header: 'Volume', render: (r) => fmt(r.total_monthly_volume_rupees) },
    { key: 'total_cost_to_serve_rupees', header: 'Cost-to-serve', render: (r) => fmt(r.total_cost_to_serve_rupees) },
    { key: 'avg_settlement_hours', header: 'Avg settle (h)', render: (r) => Number(r.avg_settlement_hours).toFixed(1) },
    { key: 'avg_failure_rate_pct', header: 'Avg fail %', render: (r) => Number(r.avg_failure_rate_pct).toFixed(2) + '%' },
  ];

  const costCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'primary_mode', header: 'Mode', render: (r) => String(r.primary_mode).toUpperCase() },
    { key: 'monthly_volume_rupees', header: 'Volume', render: (r) => fmt(r.monthly_volume_rupees) },
    { key: 'cost_to_serve_rupees', header: 'Cost-to-serve', render: (r) => fmt(r.cost_to_serve_rupees) },
    { key: 'cost_pct', header: 'Cost %', render: (r) => Number(r.cost_pct).toFixed(2) + '%' },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'switch_reason', header: 'Reason', render: (r: any) => String(r.switch_reason ?? '') },
    { key: 'switch_count', header: 'Switches', render: (r: any) => String(r.switch_count ?? '') },
    { key: 'total_cost_delta_rupees', header: 'Total cost Δ', render: (r) => fmt(r.total_cost_delta_rupees) },
    { key: 'avg_settlement_delta_hours', header: 'Avg settle Δ (h)', render: (r) => Number(r.avg_settlement_delta_hours).toFixed(1) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'switched_at', header: 'When', render: (r) => new Date(r.switched_at).toLocaleDateString('en-IN') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'from_mode', header: 'From', render: (r) => String(r.from_mode).toUpperCase() },
    { key: 'to_mode', header: 'To', render: (r) => String(r.to_mode).toUpperCase() },
    { key: 'switch_reason', header: 'Reason', render: (r: any) => String(r.switch_reason ?? '') },
    { key: 'cost_delta_rupees', header: 'Cost Δ', render: (r) => fmt(r.cost_delta_rupees) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer payment-mode preference tracker</h1>
        <p className="text-sm text-gray-600">UPI vs NEFT vs card vs cash — switching log & cost-to-serve impact per hospital.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Hospitals</div><div className="text-lg font-semibold">{kpis.total_hospitals ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Monthly volume</div><div className="text-lg font-semibold">{fmt(kpis.total_monthly_volume_rupees ?? 0)}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Cost-to-serve</div><div className="text-lg font-semibold">{fmt(kpis.total_cost_to_serve_rupees ?? 0)}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">UPI share</div><div className="text-lg font-semibold">{Number(kpis.upi_share_pct ?? 0).toFixed(1)}%</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Switches 90d</div><div className="text-lg font-semibold">{kpis.switches_last_90d ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Avg settle (h)</div><div className="text-lg font-semibold">{Number(kpis.avg_settlement_hours ?? 0).toFixed(1)}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Mode mix</h2>
        <DataTable columns={mixCols} rows={mix} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Preferences by hospital</h2>
        <DataTable columns={prefCols} rows={prefs} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cost-to-serve ranking (cost % of volume, high first)</h2>
        <DataTable columns={costCols} rows={cost} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Switch reasons rollup</h2>
        <DataTable columns={reasonCols} rows={reasons} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent switches (180d)</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All switches log</h2>
        <DataTable columns={switchCols} rows={switches} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
