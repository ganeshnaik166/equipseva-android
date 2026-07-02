import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInr(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return new Intl.NumberFormat('en-IN').format(v);
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = {};
  let campaigns: any[] = [];
  let touches: any[] = [];
  let byKind: any[] = [];
  let churnReasons: any[] = [];
  let funnel: any[] = [];
  let stale: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_winback_overview');
    overview = (r.data && r.data[0]) || {};
  } catch { overview = {}; }
  try {
    const r = await sb.rpc('rpc_founder_winback_campaigns_list');
    campaigns = r.data || [];
  } catch { campaigns = []; }
  try {
    const r = await sb.rpc('rpc_founder_winback_touchpoints_recent');
    touches = r.data || [];
  } catch { touches = []; }
  try {
    const r = await sb.rpc('rpc_founder_winback_by_touch_kind');
    byKind = r.data || [];
  } catch { byKind = []; }
  try {
    const r = await sb.rpc('rpc_founder_winback_churn_reasons');
    churnReasons = r.data || [];
  } catch { churnReasons = []; }
  try {
    const r = await sb.rpc('rpc_founder_winback_funnel');
    funnel = r.data || [];
  } catch { funnel = []; }
  try {
    const r = await sb.rpc('rpc_founder_winback_stale_campaigns');
    stale = r.data || [];
  } catch { stale = []; }

  const kpis: Kpi[] = [
    { label: 'Total campaigns', value: String(overview.total_campaigns ?? 0) },
    { label: 'Open', value: String(overview.open_campaigns ?? 0) },
    { label: 'In progress', value: String(overview.in_progress_campaigns ?? 0) },
    { label: 'Won', value: String(overview.won_campaigns ?? 0) },
    { label: 'Lost', value: String(overview.lost_campaigns ?? 0) },
    { label: 'Paused', value: String(overview.paused_campaigns ?? 0) },
    { label: 'Total touches', value: String(overview.total_touches ?? 0) },
    { label: 'Positive touches', value: String(overview.positive_touches ?? 0) },
    { label: 'Conversion rate', value: `${overview.conversion_rate_pct ?? 0}%` },
    { label: 'Pipeline ARR', value: `₹${fmtInr(overview.pipeline_arr_rupees)}` },
    { label: 'Recovered ARR', value: `₹${fmtInr(overview.recovered_arr_rupees)}` },
    { label: 'Avg touches per win', value: String(Number(overview.avg_touches_per_win ?? 0).toFixed(1)) },
    { label: 'Stale campaigns', value: String(stale.length) },
    { label: 'Touch kinds tracked', value: String(byKind.length) },
    { label: 'Churn reasons', value: String(churnReasons.length) },
    { label: 'Funnel stages', value: String(funnel.length) },
  ];

  const campaignCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'campaign_status', header: 'Status', render: (r: any) => r.campaign_status ?? "—" },
    { key: 'churn_reason', header: 'Churn reason', render: (r: any) => r.churn_reason ?? "—" },
    { key: 'last_contract_arr_rupees', header: 'ARR at risk', render: (r: any) => `₹${fmtInr(r.last_contract_arr_rupees)}` },
    { key: 'special_offer_pct', header: 'Offer %', render: (r: any) => `${r.special_offer_pct ?? 0}%` },
    { key: 'pitch_feature', header: 'Pitch', render: (r: any) => r.pitch_feature ?? "—" },
    { key: 'touches_count', header: 'Touches', render: (r: any) => String(r.touches_count ?? 0) },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => r.last_touch_at ? new Date(r.last_touch_at).toLocaleString() : "—" },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleDateString() : "—" },
  ];

  const touchCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind ?? "—" },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? "—" },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary ?? "—" },
    { key: 'performed_by_email', header: 'By', render: (r: any) => r.performed_by_email ?? "—" },
    { key: 'occurred_at', header: 'When', render: (r: any) => r.occurred_at ? new Date(r.occurred_at).toLocaleString() : "—" },
    { key: 'next_step_at', header: 'Next step', render: (r: any) => r.next_step_at ? new Date(r.next_step_at).toLocaleString() : "—" },
  ];

  const kindCols: Column<any>[] = [
    { key: 'touch_kind', header: 'Touch kind', render: (r: any) => r.touch_kind ?? "—" },
    { key: 'total_touches', header: 'Total', render: (r: any) => String(r.total_touches ?? 0) },
    { key: 'positive_touches', header: 'Positive', render: (r: any) => String(r.positive_touches ?? 0) },
    { key: 'conversion_pct', header: 'Conversion %', render: (r: any) => `${r.conversion_pct ?? 0}%` },
  ];

  const churnCols: Column<any>[] = [
    { key: 'churn_reason', header: 'Churn reason', render: (r: any) => r.churn_reason ?? "—" },
    { key: 'campaigns_count', header: 'Campaigns', render: (r: any) => String(r.campaigns_count ?? 0) },
    { key: 'won_count', header: 'Won', render: (r: any) => String(r.won_count ?? 0) },
    { key: 'lost_count', header: 'Lost', render: (r: any) => String(r.lost_count ?? 0) },
    { key: 'conversion_pct', header: 'Conv %', render: (r: any) => `${r.conversion_pct ?? 0}%` },
    { key: 'total_arr_at_risk', header: 'ARR at risk', render: (r: any) => `₹${fmtInr(r.total_arr_at_risk)}` },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? "—" },
    { key: 'hospitals_count', header: 'Hospitals', render: (r: any) => String(r.hospitals_count ?? 0) },
    { key: 'arr_rupees', header: 'ARR', render: (r: any) => `₹${fmtInr(r.arr_rupees)}` },
  ];

  const staleCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'campaign_status', header: 'Status', render: (r: any) => r.campaign_status ?? "—" },
    { key: 'days_since_touch', header: 'Days since touch', render: (r: any) => Number(r.days_since_touch ?? 0).toFixed(1) },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => r.last_touch_at ? new Date(r.last_touch_at).toLocaleString() : "—" },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleDateString() : "—" },
    { key: 'last_contract_arr_rupees', header: 'ARR at risk', render: (r: any) => `₹${fmtInr(r.last_contract_arr_rupees)}` },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Winback Campaign</h1>
        <p className="text-sm text-gray-500 mt-1">
          Churned hospitals to multi-touch winback. Founder call, special offer, new feature pitch. Per-hospital touchpoint log with conversion rate.
        </p>
      </header>

      <section>
        <h2 className="text-sm font-medium text-gray-700 mb-3">Overview</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {kpis.map((k) => (
            <div key={k.label} className="rounded-lg border bg-white p-4">
              <div className="text-xs text-gray-500">{k.label}</div>
              <div className="text-lg font-semibold mt-1">{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-medium text-gray-700 mb-3">Campaigns</h2>
        <DataTable columns={campaignCols} rows={campaigns} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-sm font-medium text-gray-700 mb-3">Recent touchpoints</h2>
        <DataTable columns={touchCols} rows={touches} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-sm font-medium text-gray-700 mb-3">By touch kind</h2>
        <DataTable columns={kindCols} rows={byKind} rowKey={(r: any) => r.touch_kind} />
      </section>

      <section>
        <h2 className="text-sm font-medium text-gray-700 mb-3">Churn reasons</h2>
        <DataTable columns={churnCols} rows={churnReasons} rowKey={(r: any) => r.churn_reason} />
      </section>

      <section>
        <h2 className="text-sm font-medium text-gray-700 mb-3">Winback funnel</h2>
        <DataTable columns={funnelCols} rows={funnel} rowKey={(r: any) => r.stage} />
      </section>

      <section>
        <h2 className="text-sm font-medium text-gray-700 mb-3">Stale campaigns</h2>
        <DataTable columns={staleCols} rows={stale} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
