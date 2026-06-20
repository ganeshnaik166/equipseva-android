import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtSec(v: any): string {
  const n = Number(v);
  if (!isFinite(n)) return '—';
  if (n < 60) return `${n.toFixed(0)}s`;
  if (n < 3600) return `${(n / 60).toFixed(1)}m`;
  return `${(n / 3600).toFixed(2)}h`;
}

function fmtPct(v: any): string {
  const n = Number(v);
  if (!isFinite(n)) return '—';
  return `${n.toFixed(1)}%`;
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let hero: any[] = [];
  let dropout: any[] = [];
  let breakdown: any[] = [];
  let targets: any[] = [];
  let recent: any[] = [];

  try {
    const r = await sb.rpc('founder_code_red_response_overview');
    overview = (r.data ?? [])[0] ?? null;
  } catch {}
  try {
    const r = await sb.rpc('founder_code_red_hero_board', { p_limit: 20 });
    hero = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_code_red_dropout_board', { p_limit: 20 });
    dropout = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_code_red_per_engineer_breakdown', { p_limit: 50 });
    breakdown = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_code_red_sla_targets');
    targets = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_code_red_recent_metrics', { p_limit: 50 });
    recent = r.data ?? [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Total metrics', value: String(overview?.total_metrics ?? '—') },
    { label: 'Engineers tracked', value: String(overview?.engineers_with_metrics ?? '—') },
    { label: 'Median first-resp', value: fmtSec(overview?.median_first_response_seconds) },
    { label: 'Median on-site', value: fmtSec(overview?.median_on_site_seconds) },
    { label: 'Median resolve', value: fmtSec(overview?.median_resolve_seconds) },
    { label: 'First-resp SLA hit', value: fmtPct(overview?.first_response_sla_pct) },
    { label: 'On-site SLA hit', value: fmtPct(overview?.on_site_sla_pct) },
    { label: 'Resolve SLA hit', value: fmtPct(overview?.resolve_sla_pct) },
    { label: 'Dropouts', value: String(overview?.dropout_count ?? '—') },
    { label: 'Hero board size', value: String(hero.length) },
    { label: 'Dropout board size', value: String(dropout.length) },
    { label: 'Engineer rows', value: String(breakdown.length) },
    { label: 'SLA tiers', value: String(targets.length) },
    { label: 'Recent metrics', value: String(recent.length) },
    { label: 'View', value: 'Code Red perf' },
    { label: 'Round', value: 'r1517' },
  ];

  const heroCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'total_responses', header: 'Responses', render: (r: any) => String(r.total_responses ?? '—') },
    { key: 'median_first_response_seconds', header: 'Median first-resp', render: (r: any) => fmtSec(r.median_first_response_seconds) },
    { key: 'sla_hit_pct', header: 'SLA hit %', render: (r: any) => fmtPct(r.sla_hit_pct) },
  ];

  const dropoutCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'dropout_count', header: 'Dropouts', render: (r: any) => String(r.dropout_count ?? '—') },
    { key: 'last_drop_at', header: 'Last drop', render: (r: any) => r.last_drop_at ? new Date(r.last_drop_at).toLocaleString() : '—' },
    { key: 'last_reason', header: 'Reason', render: (r: any) => r.last_reason ?? '—' },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'cached_highest_tier', header: 'Tier', render: (r: any) => r.cached_highest_tier ?? '—' },
    { key: 'total_responses', header: 'Responses', render: (r: any) => String(r.total_responses ?? '—') },
    { key: 'median_first_response_seconds', header: 'First-resp', render: (r: any) => fmtSec(r.median_first_response_seconds) },
    { key: 'median_on_site_seconds', header: 'On-site', render: (r: any) => fmtSec(r.median_on_site_seconds) },
    { key: 'median_resolve_seconds', header: 'Resolve', render: (r: any) => fmtSec(r.median_resolve_seconds) },
    { key: 'dropout_count', header: 'Drops', render: (r: any) => String(r.dropout_count ?? '—') },
  ];

  const targetCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'first_response_target_seconds', header: 'First-resp tgt', render: (r: any) => fmtSec(r.first_response_target_seconds) },
    { key: 'on_site_target_seconds', header: 'On-site tgt', render: (r: any) => fmtSec(r.on_site_target_seconds) },
    { key: 'resolve_target_seconds', header: 'Resolve tgt', render: (r: any) => fmtSec(r.resolve_target_seconds) },
    { key: 'updated_at', header: 'Updated', render: (r: any) => r.updated_at ? new Date(r.updated_at).toLocaleString() : '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'first_response_seconds', header: 'First-resp', render: (r: any) => fmtSec(r.first_response_seconds) },
    { key: 'on_site_seconds', header: 'On-site', render: (r: any) => fmtSec(r.on_site_seconds) },
    { key: 'resolve_seconds', header: 'Resolve', render: (r: any) => fmtSec(r.resolve_seconds) },
    { key: 'hit_first_response_sla', header: 'Hit SLA', render: (r: any) => r.hit_first_response_sla ? 'yes' : 'no' },
    { key: 'dropped', header: 'Drop', render: (r: any) => r.dropped ? 'yes' : 'no' },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Engineer Code Red Response Performance</h1>
        <p className="text-sm text-gray-600">Per-engineer emergency SLAs {">"} hero board, dropout board, severity targets.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((k, i) => (
          <div key={i} className="rounded border p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hero board {"<"} fastest responders {">"}</h2>
        <DataTable columns={heroCols} rows={hero} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dropout board</h2>
        <DataTable columns={dropoutCols} rows={dropout} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-engineer breakdown</h2>
        <DataTable columns={breakdownCols} rows={breakdown} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">SLA targets by severity</h2>
        <DataTable columns={targetCols} rows={targets} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent metrics</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
