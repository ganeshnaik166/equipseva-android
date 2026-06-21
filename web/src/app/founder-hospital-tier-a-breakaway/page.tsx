import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Math.round(Number(n)).toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Math.round(Number(n)).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0.0%';
  return Number(n).toFixed(1) + '%';
}

function fmtNum(n: number | null | undefined, digits = 2): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toFixed(digits);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  const d = new Date(s);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function FounderHospitalTierABreakawayPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let topCands: any[] = [];
  let recentActions: any[] = [];
  let noAction: any[] = [];
  let actionMix: any[] = [];

  try {
    const r = await sb.rpc('founder_breakaway_kpis_v2');
    if (!r.error && Array.isArray(r.data) && r.data.length > 0) kpis = r.data[0];
  } catch {}

  try {
    const r = await sb.rpc('founder_breakaway_top_candidates_v2', { p_limit: 50 });
    if (!r.error && Array.isArray(r.data)) topCands = r.data;
  } catch {}

  try {
    const r = await sb.rpc('founder_breakaway_recent_actions_v2', { p_limit: 50 });
    if (!r.error && Array.isArray(r.data)) recentActions = r.data;
  } catch {}

  try {
    const r = await sb.rpc('founder_breakaway_no_action_v2', { p_limit: 50 });
    if (!r.error && Array.isArray(r.data)) noAction = r.data;
  } catch {}

  try {
    const r = await sb.rpc('founder_breakaway_action_mix_v2');
    if (!r.error && Array.isArray(r.data)) actionMix = r.data;
  } catch {}

  const k = kpis ?? {};
  const cards: Kpi[] = [
    { label: 'Total candidates', value: fmtInt(k.total_candidates) },
    { label: 'High-score (≥70)', value: fmtInt(k.high_score_candidates) },
    { label: 'Trailing 30d revenue', value: fmtRupees(k.total_trailing_revenue_rupees) },
    { label: 'Prior 30d revenue', value: fmtRupees(k.total_prior_revenue_rupees) },
    { label: 'Avg growth %', value: fmtPct(k.avg_growth_pct) },
    { label: 'Avg NPS delta', value: fmtNum(k.avg_nps_delta) },
    { label: 'NPS rising', value: fmtInt(k.candidates_with_nps_rise) },
    { label: 'Revenue doubled', value: fmtInt(k.candidates_revenue_doubled) },
    { label: 'Active AMCs (sum)', value: fmtInt(k.active_amc_total) },
    { label: 'Actions logged 30d', value: fmtInt(k.actions_logged_30d) },
    { label: 'Founder calls 30d', value: fmtInt(k.founder_calls_30d) },
    { label: 'Upgrades offered 30d', value: fmtInt(k.upgrades_offered_30d) },
    { label: 'Site visits 30d', value: fmtInt(k.site_visits_30d) },
    { label: 'No-action candidates', value: fmtInt(k.candidates_no_action) },
    { label: 'Oldest pending (days)', value: fmtInt(k.oldest_pending_days) },
    { label: 'Newest snapshot', value: fmtDate(k.newest_snapshot_at) },
  ];

  const candCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'hospital_state', header: 'State', render: (r: any) => String(r.hospital_state ?? '—') },
    { key: 'current_tier', header: 'Tier', render: (r: any) => String(r.current_tier ?? '—') },
    { key: 'breakaway_score', header: 'Score', render: (r: any) => fmtNum(r.breakaway_score) },
    { key: 'revenue_growth_pct', header: 'Growth', render: (r: any) => fmtPct(r.revenue_growth_pct) },
    { key: 'trailing_30d_revenue_rupees', header: 'Rev 30d', render: (r: any) => fmtRupees(r.trailing_30d_revenue_rupees) },
    { key: 'prior_30d_revenue_rupees', header: 'Prior 30d', render: (r: any) => fmtRupees(r.prior_30d_revenue_rupees) },
    { key: 'nps_delta', header: 'NPS Δ', render: (r: any) => fmtNum(r.nps_delta) },
    { key: 'job_count_30d', header: 'Jobs', render: (r: any) => fmtInt(r.job_count_30d) },
    { key: 'active_amc_count', header: 'AMCs', render: (r: any) => fmtInt(r.active_amc_count) },
    { key: 'recommendation', header: 'Recommendation', render: (r: any) => String(r.recommendation ?? '—') },
    { key: 'snapshot_at', header: 'Snapshot', render: (r: any) => fmtDate(r.snapshot_at) },
  ];

  const actCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'action_kind', header: 'Action', render: (r: any) => String(r.action_kind ?? '—') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '—') },
    { key: 'scheduled_for', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_for) },
    { key: 'completed_at', header: 'Completed', render: (r: any) => fmtDate(r.completed_at) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '—') },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const noActCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'hospital_state', header: 'State', render: (r: any) => String(r.hospital_state ?? '—') },
    { key: 'breakaway_score', header: 'Score', render: (r: any) => fmtNum(r.breakaway_score) },
    { key: 'revenue_growth_pct', header: 'Growth', render: (r: any) => fmtPct(r.revenue_growth_pct) },
    { key: 'days_since_snapshot', header: 'Days waiting', render: (r: any) => fmtInt(r.days_since_snapshot) },
    { key: 'snapshot_at', header: 'Snapshot', render: (r: any) => fmtDate(r.snapshot_at) },
  ];

  const mixCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action', render: (r: any) => String(r.action_kind ?? '—') },
    { key: 'action_count', header: 'Count', render: (r: any) => fmtInt(r.action_count) },
    { key: 'with_outcome', header: 'With outcome', render: (r: any) => fmtInt(r.with_outcome) },
    { key: 'scheduled_pending', header: 'Pending', render: (r: any) => fmtInt(r.scheduled_pending) },
    { key: 'last_at', header: 'Last at', render: (r: any) => fmtDate(r.last_at) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Tier-A Breakaway List</h1>
        <p className="text-sm text-gray-600 mt-1">
          B-tier hospitals showing tier-A indicators (revenue growth, NPS rise). Founder personal-attention list before competitors poach.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-4 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="border rounded-lg p-3 bg-white">
            <div className="text-xs text-gray-500">{c.label}</div>
            <div className="text-lg font-semibold mt-1">{c.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top breakaway candidates</h2>
        <DataTable
          rows={topCands}
          columns={candCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">No action yet (priority follow-ups)</h2>
        <DataTable
          rows={noAction}
          columns={noActCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent founder actions</h2>
        <DataTable
          rows={recentActions}
          columns={actCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action mix</h2>
        <DataTable
          rows={actionMix}
          columns={mixCols}
          rowKey={(r: any) => r.action_kind}
        />
      </section>
    </div>
  );
}
