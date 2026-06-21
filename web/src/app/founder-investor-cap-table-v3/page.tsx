import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(Math.round(n));
}
function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  if (n >= 10000000) return '₹' + (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return '₹' + (n / 100000).toFixed(2) + ' L';
  return '₹' + new Intl.NumberFormat('en-IN').format(Math.round(n));
}
function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(3) + '%';
}
function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default async function FounderInvestorCapTableV3Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpiRow: any = {};
  let eventsRows: any[] = [];
  let tableRows: any[] = [];
  let waterfallRows: any[] = [];
  let esopRows: any[] = [];
  let secondaryRows: any[] = [];

  try {
    const { data } = await sb.rpc('rpc_founder_cap_v3_kpis');
    kpiRow = Array.isArray(data) && data.length > 0 ? data[0] : {};
  } catch { kpiRow = {}; }
  try {
    const { data } = await sb.rpc('rpc_founder_cap_v3_events_list');
    eventsRows = Array.isArray(data) ? data : [];
  } catch { eventsRows = []; }
  try {
    const { data } = await sb.rpc('rpc_founder_cap_v3_current_table');
    tableRows = Array.isArray(data) ? data : [];
  } catch { tableRows = []; }
  try {
    const { data } = await sb.rpc('rpc_founder_cap_v3_dilution_waterfall');
    waterfallRows = Array.isArray(data) ? data : [];
  } catch { waterfallRows = []; }
  try {
    const { data } = await sb.rpc('rpc_founder_cap_v3_esop_history');
    esopRows = Array.isArray(data) ? data : [];
  } catch { esopRows = []; }
  try {
    const { data } = await sb.rpc('rpc_founder_cap_v3_secondary_log');
    secondaryRows = Array.isArray(data) ? data : [];
  } catch { secondaryRows = []; }

  const kpis: Kpi[] = [
    { label: 'Total events', value: fmtInt(kpiRow.total_events) },
    { label: 'Priced rounds', value: fmtInt(kpiRow.priced_rounds) },
    { label: 'SAFE conversions', value: fmtInt(kpiRow.safe_conversions) },
    { label: 'ESOP refreshes', value: fmtInt(kpiRow.esop_refreshes) },
    { label: 'Secondary sales', value: fmtInt(kpiRow.secondary_sales) },
    { label: 'Buybacks', value: fmtInt(kpiRow.buybacks) },
    { label: 'Option grants', value: fmtInt(kpiRow.option_grants) },
    { label: 'Option exercises', value: fmtInt(kpiRow.option_exercises) },
    { label: 'Total primary raised', value: fmtRupees(kpiRow.total_new_money_rupees) },
    { label: 'Total secondary value', value: fmtRupees(kpiRow.total_secondary_rupees) },
    { label: 'Latest post-money', value: fmtRupees(kpiRow.latest_post_money_rupees) },
    { label: 'Shares outstanding', value: fmtInt(kpiRow.total_shares_outstanding) },
    { label: 'Shareholders', value: fmtInt(kpiRow.total_shareholders) },
    { label: 'Founders %', value: fmtPct(kpiRow.founders_pct) },
    { label: 'ESOP pool %', value: fmtPct(kpiRow.esop_pool_pct) },
    { label: 'Last event', value: fmtDate(kpiRow.last_event_at) },
  ];

  const eventsCols: Column<any>[] = [
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
    { key: 'event_code', header: 'Code', render: (r: any) => r.event_code ?? '—' },
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind ?? '—' },
    { key: 'pre_money_valuation_rupees', header: 'Pre-money', render: (r: any) => fmtRupees(r.pre_money_valuation_rupees) },
    { key: 'post_money_valuation_rupees', header: 'Post-money', render: (r: any) => fmtRupees(r.post_money_valuation_rupees) },
    { key: 'new_money_rupees', header: 'New money', render: (r: any) => fmtRupees(r.new_money_rupees) },
    { key: 'price_per_share_rupees', header: 'PPS', render: (r: any) => r.price_per_share_rupees ? '₹' + Number(r.price_per_share_rupees).toFixed(4) : '—' },
    { key: 'shares_issued', header: 'Shares issued', render: (r: any) => fmtInt(r.shares_issued) },
    { key: 'esop_pool_target_pct', header: 'ESOP target', render: (r: any) => fmtPct(r.esop_pool_target_pct) },
    { key: 'holdings_count', header: 'Holdings', render: (r: any) => fmtInt(r.holdings_count) },
  ];

  const tableCols: Column<any>[] = [
    { key: 'shareholder_name', header: 'Shareholder', render: (r: any) => r.shareholder_name ?? '—' },
    { key: 'shareholder_kind', header: 'Kind', render: (r: any) => r.shareholder_kind ?? '—' },
    { key: 'share_class', header: 'Class', render: (r: any) => r.share_class ?? '—' },
    { key: 'shares_after', header: 'Shares', render: (r: any) => fmtInt(r.shares_after) },
    { key: 'pct_after', header: '% holding', render: (r: any) => fmtPct(r.pct_after) },
    { key: 'cash_in_rupees', header: 'Cash in', render: (r: any) => fmtRupees(r.cash_in_rupees) },
    { key: 'cash_out_rupees', header: 'Cash out', render: (r: any) => fmtRupees(r.cash_out_rupees) },
  ];

  const waterfallCols: Column<any>[] = [
    { key: 'shareholder_name', header: 'Shareholder', render: (r: any) => r.shareholder_name ?? '—' },
    { key: 'shareholder_kind', header: 'Kind', render: (r: any) => r.shareholder_kind ?? '—' },
    { key: 'pct_at_first', header: '% at entry', render: (r: any) => fmtPct(r.pct_at_first) },
    { key: 'pct_now', header: '% now', render: (r: any) => fmtPct(r.pct_now) },
    { key: 'total_dilution_pct', header: 'Dilution', render: (r: any) => fmtPct(r.total_dilution_pct) },
    { key: 'cumulative_cash_in_rupees', header: 'Cum. cash in', render: (r: any) => fmtRupees(r.cumulative_cash_in_rupees) },
    { key: 'cumulative_cash_out_rupees', header: 'Cum. cash out', render: (r: any) => fmtRupees(r.cumulative_cash_out_rupees) },
    { key: 'events_touched', header: 'Events', render: (r: any) => fmtInt(r.events_touched) },
  ];

  const esopCols: Column<any>[] = [
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
    { key: 'event_code', header: 'Event', render: (r: any) => r.event_code ?? '—' },
    { key: 'target_pct', header: 'Target %', render: (r: any) => fmtPct(r.target_pct) },
    { key: 'pool_shares_after', header: 'Pool shares', render: (r: any) => fmtInt(r.pool_shares_after) },
    { key: 'pool_pct_after', header: 'Pool %', render: (r: any) => fmtPct(r.pool_pct_after) },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '—' },
  ];

  const secondaryCols: Column<any>[] = [
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
    { key: 'event_code', header: 'Event', render: (r: any) => r.event_code ?? '—' },
    { key: 'seller_name', header: 'Seller', render: (r: any) => r.seller_name ?? '—' },
    { key: 'shares_sold', header: 'Shares sold', render: (r: any) => fmtInt(r.shares_sold) },
    { key: 'price_per_share_rupees', header: 'PPS', render: (r: any) => r.price_per_share_rupees ? '₹' + Number(r.price_per_share_rupees).toFixed(4) : '—' },
    { key: 'cash_out_rupees', header: 'Cash out', render: (r: any) => fmtRupees(r.cash_out_rupees) },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Investor cap table v3 — post-money</h1>
        <p className="text-sm text-gray-600">Priced rounds, SAFE conversions, ESOP refreshes, secondary sales, and per-shareholder dilution waterfall.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded border p-3 bg-white">
            <div className="text-xs uppercase text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cap-table events</h2>
        <DataTable rows={eventsRows} columns={eventsCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Current cap table</h2>
        <DataTable rows={tableRows} columns={tableCols} rowKey={(r: any) => r.shareholder_name + '|' + r.share_class} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dilution waterfall</h2>
        <DataTable rows={waterfallRows} columns={waterfallCols} rowKey={(r: any) => r.shareholder_name} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">ESOP pool history</h2>
        <DataTable rows={esopRows} columns={esopCols} rowKey={(r: any) => r.event_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Secondary sale log</h2>
        <DataTable rows={secondaryRows} columns={secondaryCols} rowKey={(r: any) => r.event_id + '|' + r.seller_name} />
      </section>
    </main>
  );
}
