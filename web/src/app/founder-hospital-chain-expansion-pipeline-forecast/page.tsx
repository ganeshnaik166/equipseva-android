import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtLakh(n: number | null | undefined) {
  const v = Number(n ?? 0);
  if (v >= 100) return `Rs ${(v / 100).toFixed(2)} Cr`;
  return `Rs ${v.toFixed(1)} L`;
}

function fmtInt(n: number | null | undefined) {
  return Number(n ?? 0).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function stageBadge(stage: string) {
  const map: Record<string, string> = {
    rumor: 'bg-slate-100 text-slate-700',
    announced: 'bg-blue-100 text-blue-700',
    land_acquired: 'bg-cyan-100 text-cyan-700',
    construction: 'bg-amber-100 text-amber-700',
    equipping: 'bg-orange-100 text-orange-700',
    soft_launch: 'bg-lime-100 text-lime-700',
    operational: 'bg-emerald-100 text-emerald-700',
    cancelled: 'bg-rose-100 text-rose-700',
  };
  return map[stage] || 'bg-gray-100 text-gray-700';
}

function involvementBadge(plan: string) {
  const map: Record<string, string> = {
    cold: 'bg-slate-100 text-slate-600',
    intro_sent: 'bg-blue-100 text-blue-700',
    pilot_proposed: 'bg-indigo-100 text-indigo-700',
    quoted: 'bg-violet-100 text-violet-700',
    negotiating: 'bg-amber-100 text-amber-800',
    contracted: 'bg-emerald-100 text-emerald-700',
    onboarded: 'bg-green-200 text-green-800',
    lost: 'bg-rose-100 text-rose-700',
  };
  return map[plan] || 'bg-gray-100 text-gray-700';
}

export default async function ChainExpansionPipelineForecastPage() {
  const sb = await getSupabaseServerClient();

  const [overviewRes, sitesRes, chainsRes, calRes, funnelRes, overdueRes, activityRes] = await Promise.all([
    sb.rpc('r2299_chain_expansion_overview'),
    sb.rpc('r2299_list_pipeline_sites', { p_stage: null, p_involvement: null, p_limit: 100 }),
    sb.rpc('r2299_chain_rollup'),
    sb.rpc('r2299_quarterly_calendar'),
    sb.rpc('r2299_stage_funnel'),
    sb.rpc('r2299_overdue_actions'),
    sb.rpc('r2299_recent_activity', { p_limit: 30 }),
  ]);

  const o: any = (overviewRes.data && overviewRes.data[0]) || {};
  const sites: any[] = sitesRes.data || [];
  const chains: any[] = chainsRes.data || [];
  const cal: any[] = calRes.data || [];
  const funnel: any[] = funnelRes.data || [];
  const overdue: any[] = overdueRes.data || [];
  const activity: any[] = activityRes.data || [];

  const siteCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'site_name', header: 'Site', render: (r: any) => <span>{r.site_name}</span> },
    { key: 'city', header: 'City', render: (r: any) => <span className="text-sm">{r.city}, {r.state_code}</span> },
    { key: 'pipeline_stage', header: 'Stage', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${stageBadge(r.pipeline_stage)}`}>{r.pipeline_stage}</span>
    ) },
    { key: 'stage_confidence', header: 'Conf', render: (r: any) => <span className="text-sm">{r.stage_confidence}%</span> },
    { key: 'bed_count_planned', header: 'Beds', render: (r: any) => <span className="text-sm">{fmtInt(r.bed_count_planned)}</span> },
    { key: 'equipment_capex_inr_lakh', header: 'Equip Capex', render: (r: any) => <span className="text-sm">{fmtLakh(r.equipment_capex_inr_lakh)}</span> },
    { key: 'forecast_arr_lakh', header: 'Fcst ARR', render: (r: any) => <span className="text-sm font-mono">{fmtLakh(r.forecast_arr_lakh)}</span> },
    { key: 'weighted_arr_lakh', header: 'Wtd ARR', render: (r: any) => <span className="text-sm font-mono font-semibold">{fmtLakh(r.weighted_arr_lakh)}</span> },
    { key: 'involvement_plan', header: 'Our Plan', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs ${involvementBadge(r.involvement_plan)}`}>{r.involvement_plan}</span>
    ) },
    { key: 'expected_open_date', header: 'Opens', render: (r: any) => (
      <span className="text-sm" dangerouslySetInnerHTML={{ __html: fmtDate(r.expected_open_date) }} />
    ) },
    { key: 'days_to_open', header: 'Days', render: (r: any) => {
      if (r.days_to_open == null) return <span className="text-slate-400">—</span>;
      const d = Number(r.days_to_open);
      const cls = d < 0 ? 'text-rose-600' : d <= 90 ? 'text-amber-600 font-semibold' : 'text-slate-600';
      return <span className={`text-sm ${cls}`}>{d}</span>;
    } },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => <span className="font-semibold">{r.chain_name}</span> },
    { key: 'site_count', header: 'Sites', render: (r: any) => <span>{fmtInt(r.site_count)}</span> },
    { key: 'beds_pipeline', header: 'Beds', render: (r: any) => <span>{fmtInt(r.beds_pipeline)}</span> },
    { key: 'total_capex_lakh', header: 'Capex', render: (r: any) => <span className="text-sm">{fmtLakh(r.total_capex_lakh)}</span> },
    { key: 'forecast_arr_lakh', header: 'Fcst ARR', render: (r: any) => <span className="text-sm">{fmtLakh(r.forecast_arr_lakh)}</span> },
    { key: 'weighted_arr_lakh', header: 'Wtd ARR', render: (r: any) => <span className="text-sm font-mono font-bold text-emerald-700">{fmtLakh(r.weighted_arr_lakh)}</span> },
    { key: 'contracted_sites', header: 'Won', render: (r: any) => <span className="text-sm text-emerald-700">{fmtInt(r.contracted_sites)}</span> },
    { key: 'hottest_stage', header: 'Hot Stage', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs ${stageBadge(r.hottest_stage)}`}>{r.hottest_stage}</span>
    ) },
    { key: 'earliest_open', header: 'First Open', render: (r: any) => (
      <span className="text-sm" dangerouslySetInnerHTML={{ __html: fmtDate(r.earliest_open) }} />
    ) },
  ];

  const calCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => <span className="font-semibold">{r.quarter_label}</span> },
    { key: 'sites_opening', header: 'Sites', render: (r: any) => <span>{fmtInt(r.sites_opening)}</span> },
    { key: 'beds_opening', header: 'Beds', render: (r: any) => <span>{fmtInt(r.beds_opening)}</span> },
    { key: 'capex_lakh', header: 'Capex', render: (r: any) => <span className="text-sm">{fmtLakh(r.capex_lakh)}</span> },
    { key: 'forecast_arr_lakh', header: 'Fcst ARR/yr', render: (r: any) => <span className="text-sm">{fmtLakh(r.forecast_arr_lakh)}</span> },
    { key: 'weighted_arr_lakh', header: 'Wtd ARR/yr', render: (r: any) => <span className="text-sm font-mono font-bold text-emerald-700">{fmtLakh(r.weighted_arr_lakh)}</span> },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'pipeline_stage', header: 'Stage', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${stageBadge(r.pipeline_stage)}`}>{r.pipeline_stage}</span>
    ) },
    { key: 'site_count', header: 'Sites', render: (r: any) => <span className="font-mono">{fmtInt(r.site_count)}</span> },
    { key: 'avg_confidence', header: 'Avg Conf', render: (r: any) => <span className="text-sm">{Number(r.avg_confidence ?? 0).toFixed(0)}%</span> },
    { key: 'forecast_arr_lakh', header: 'Fcst ARR', render: (r: any) => <span className="text-sm">{fmtLakh(r.forecast_arr_lakh)}</span> },
    { key: 'weighted_arr_lakh', header: 'Wtd ARR', render: (r: any) => <span className="text-sm font-mono font-semibold">{fmtLakh(r.weighted_arr_lakh)}</span> },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'site_name', header: 'Site', render: (r: any) => <span className="text-sm">{r.site_name}</span> },
    { key: 'city', header: 'City', render: (r: any) => <span className="text-sm">{r.city}</span> },
    { key: 'involvement_plan', header: 'Plan', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs ${involvementBadge(r.involvement_plan)}`}>{r.involvement_plan}</span>
    ) },
    { key: 'next_action', header: 'Next Action', render: (r: any) => <span className="text-sm">{r.next_action || <span className="text-slate-400">—</span>}</span> },
    { key: 'next_action_due', header: 'Due', render: (r: any) => (
      <span className="text-sm text-rose-700" dangerouslySetInnerHTML={{ __html: fmtDate(r.next_action_due) }} />
    ) },
    { key: 'days_overdue', header: 'Days Late', render: (r: any) => (
      <span className="text-sm font-bold text-rose-700">{r.days_overdue}</span>
    ) },
    { key: 'weighted_arr_lakh', header: 'Wtd ARR @ Risk', render: (r: any) => <span className="text-sm font-mono">{fmtLakh(r.weighted_arr_lakh)}</span> },
  ];

  const actCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => <span className="text-xs text-slate-600">{new Date(r.occurred_at).toLocaleString('en-IN')}</span> },
    { key: 'chain_name', header: 'Chain / Site', render: (r: any) => <span className="text-sm"><span className="font-medium">{r.chain_name}</span> — {r.site_name}</span> },
    { key: 'activity_type', header: 'Type', render: (r: any) => <span className="text-xs px-2 py-0.5 rounded bg-slate-100">{r.activity_type}</span> },
    { key: 'summary', header: 'Summary', render: (r: any) => <span className="text-sm">{r.summary}</span> },
    { key: 'amount_inr_lakh', header: 'Amount', render: (r: any) => r.amount_inr_lakh ? <span className="text-sm font-mono">{fmtLakh(r.amount_inr_lakh)}</span> : <span className="text-slate-400">—</span> },
    { key: 'actor_email', header: 'By', render: (r: any) => <span className="text-xs text-slate-600">{r.actor_email}</span> },
  ];

  return (
    <main className="min-h-screen bg-slate-50 p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        <header className="space-y-1">
          <h1 className="text-2xl font-bold text-slate-900">Hospital Chain Expansion Pipeline</h1>
          <p className="text-sm text-slate-600">
            Track chains opening new sites & branches. Forecast revenue from each pipeline site & our involvement plan.
          </p>
        </header>

        <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-3">
          <div className="bg-white rounded-lg p-4 border border-slate-200">
            <div className="text-xs text-slate-500 uppercase tracking-wide">Active Sites</div>
            <div className="text-2xl font-bold text-slate-900 mt-1">{fmtInt(o.active_sites)}</div>
            <div className="text-xs text-slate-500 mt-0.5">{fmtInt(o.unique_chains)} chains</div>
          </div>
          <div className="bg-white rounded-lg p-4 border border-slate-200">
            <div className="text-xs text-slate-500 uppercase tracking-wide">Beds in Pipeline</div>
            <div className="text-2xl font-bold text-slate-900 mt-1">{fmtInt(o.beds_pipeline)}</div>
            <div className="text-xs text-slate-500 mt-0.5">across all stages</div>
          </div>
          <div className="bg-white rounded-lg p-4 border border-slate-200">
            <div className="text-xs text-slate-500 uppercase tracking-wide">Equip Capex</div>
            <div className="text-2xl font-bold text-slate-900 mt-1">{fmtLakh(o.total_capex_lakh)}</div>
            <div className="text-xs text-slate-500 mt-0.5">TAM @ stake</div>
          </div>
          <div className="bg-emerald-50 rounded-lg p-4 border border-emerald-200">
            <div className="text-xs text-emerald-700 uppercase tracking-wide">Weighted ARR</div>
            <div className="text-2xl font-bold text-emerald-900 mt-1">{fmtLakh(o.weighted_arr_lakh)}</div>
            <div className="text-xs text-emerald-700 mt-0.5">conf-weighted forecast</div>
          </div>
          <div className="bg-white rounded-lg p-4 border border-slate-200">
            <div className="text-xs text-slate-500 uppercase tracking-wide">Opening &lt;= 90d</div>
            <div className="text-2xl font-bold text-amber-600 mt-1">{fmtInt(o.opening_next_90d)}</div>
            <div className="text-xs text-slate-500 mt-0.5">{fmtInt(o.contracted_sites)} contracted · {fmtInt(o.overdue_actions)} overdue</div>
          </div>
        </section>

        <section className="bg-white rounded-lg border border-slate-200 p-5">
          <h2 className="text-lg font-semibold text-slate-900 mb-3">Stage Funnel</h2>
          <DataTable
            columns={funnelCols}
            rows={funnel}
            rowKey={(r: any, i: number) => String(r.pipeline_stage ?? i)}
          />
        </section>

        <section className="bg-white rounded-lg border border-slate-200 p-5">
          <h2 className="text-lg font-semibold text-slate-900 mb-1">Quarterly Opening Calendar</h2>
          <p className="text-xs text-slate-500 mb-3">Sites by expected open date — capex & recurring forecast per quarter</p>
          <DataTable
            columns={calCols}
            rows={cal}
            rowKey={(r: any, i: number) => String(r.quarter_start ?? i)}
          />
        </section>

        <section className="bg-white rounded-lg border border-slate-200 p-5">
          <h2 className="text-lg font-semibold text-slate-900 mb-1">Chain Rollup</h2>
          <p className="text-xs text-slate-500 mb-3">Top chains by weighted ARR — aggregated pipeline view</p>
          <DataTable
            columns={chainCols}
            rows={chains}
            rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
          />
        </section>

        {overdue.length > 0 && (
          <section className="bg-rose-50 rounded-lg border border-rose-200 p-5">
            <h2 className="text-lg font-semibold text-rose-900 mb-1">Overdue Actions</h2>
            <p className="text-xs text-rose-700 mb-3">Next-action dates past — weighted ARR at risk</p>
            <DataTable
              columns={overdueCols}
              rows={overdue}
              rowKey={(r: any, i: number) => String(r.id ?? i)}
            />
          </section>
        )}

        <section className="bg-white rounded-lg border border-slate-200 p-5">
          <h2 className="text-lg font-semibold text-slate-900 mb-1">All Pipeline Sites</h2>
          <p className="text-xs text-slate-500 mb-3">Sorted by expected open date — confidence-weighted ARR shown</p>
          <DataTable
            columns={siteCols}
            rows={sites}
            rowKey={(r: any, i: number) => String(r.id ?? i)}
          />
        </section>

        <section className="bg-white rounded-lg border border-slate-200 p-5">
          <h2 className="text-lg font-semibold text-slate-900 mb-3">Recent Activity</h2>
          <DataTable
            columns={actCols}
            rows={activity}
            rowKey={(r: any, i: number) => String(r.id ?? i)}
          />
        </section>
      </div>
    </main>
  );
}
