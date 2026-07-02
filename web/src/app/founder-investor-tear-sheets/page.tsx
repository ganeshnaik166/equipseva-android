import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (!n || n <= 0) return "₹0";
  if (n >= 10000000) return `₹${(n/10000000).toFixed(2)}Cr`;
  if (n >= 100000) return `₹${(n/100000).toFixed(2)}L`;
  return `₹${n.toLocaleString('en-IN')}`;
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return "—"; }
}

export default async function FounderInvestorTearSheetsPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = {};
  let sheets: any[] = [];
  let stale: any[] = [];
  let gaps: any[] = [];
  let recent: any[] = [];
  let refreshResult: any = {};

  try {
    const r = await sb.rpc('rpc_founder_investor_refresh_all');
    refreshResult = r.data ?? {};
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_investor_tear_sheets_summary');
    summary = r.data ?? {};
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_investor_tear_sheets_list');
    sheets = (r.data as any[]) ?? [];
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_investor_stale_touches');
    stale = (r.data as any[]) ?? [];
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_investor_narrative_gaps');
    gaps = (r.data as any[]) ?? [];
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_investor_recent_interactions');
    recent = (r.data as any[]) ?? [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Total Investors', value: String(summary.total_investors ?? 0) },
    { label: 'Soft Commits', value: fmtRupees(summary.total_soft_commit_rupees) },
    { label: 'Pipeline Check Size', value: fmtRupees(summary.total_check_size_rupees) },
    { label: 'Avg Conviction', value: `${summary.avg_conviction ?? 0}/100` },
    { label: 'Cold', value: String(summary.cold ?? 0) },
    { label: 'Warm', value: String(summary.warm ?? 0) },
    { label: 'Meeting', value: String(summary.meeting ?? 0) },
    { label: 'Soft Commit', value: String(summary.soft_commit ?? 0) },
    { label: 'Term Sheet', value: String(summary.term_sheet ?? 0) },
    { label: 'Passed', value: String(summary.passed ?? 0) },
    { label: 'Closed', value: String(summary.closed ?? 0) },
    { label: 'Fresh (7d)', value: String(summary.fresh_7d ?? 0) },
    { label: 'Stale (30d+)', value: String(summary.stale_30d ?? 0) },
    { label: 'Next Touch Due', value: String(summary.next_touch_due ?? 0) },
    { label: 'Avg Beats Covered', value: String(summary.avg_beats_covered ?? 0) },
    { label: 'Total Interactions', value: String(summary.total_interactions ?? 0) },
  ];

  const sheetCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? "—" },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? "—" },
    { key: 'check_size_rupees', header: 'Check', render: (r: any) => fmtRupees(r.check_size_rupees) },
    { key: 'soft_commit_rupees', header: 'Soft Commit', render: (r: any) => fmtRupees(r.soft_commit_rupees) },
    { key: 'conviction_score', header: 'Conviction', render: (r: any) => `${r.conviction_score ?? 0}/100` },
    { key: 'total_interactions', header: 'Touches', render: (r: any) => String(r.total_interactions ?? 0) },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'last_touch_channel', header: 'Channel', render: (r: any) => r.last_touch_channel ?? "—" },
    { key: 'beats', header: 'Beats', render: (r: any) => String((r.narrative_beats_covered ?? []).length) },
  ];

  const staleCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? "—" },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? "—" },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'days_since_touch', header: 'Days Stale', render: (r: any) => String(r.days_since_touch ?? 0) },
    { key: 'conviction_score', header: 'Conviction', render: (r: any) => `${r.conviction_score ?? 0}/100` },
  ];

  const gapsCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? "—" },
    { key: 'beats_covered', header: 'Beats Covered', render: (r: any) => String(r.beats_covered ?? 0) },
    { key: 'missing_beats', header: 'Missing Beats', render: (r: any) => (r.missing_beats ?? []).join(', ') || "—" },
  ];

  const recentCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'interaction_at', header: 'When', render: (r: any) => fmtDate(r.interaction_at) },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? "—" },
    { key: 'direction', header: 'Dir', render: (r: any) => r.direction ?? "—" },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary ?? "—" },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? "—" },
  ];

  return (
    <main className="p-6 space-y-6">
      <header className="flex items-baseline justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Investor Tear Sheets</h1>
          <p className="text-sm text-gray-600">One-page summary per investor — interactions, soft-commits, last-touch, narrative coverage. Auto-refreshed on open.</p>
        </div>
        <div className="text-xs text-gray-500">Refreshed {refreshResult.updated ?? 0} sheets</div>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded border bg-white p-3">
            <div className="text-xs uppercase text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Tear Sheets ({sheets.length})</h2>
        <DataTable columns={sheetCols} rows={sheets} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale Touches ({stale.length})</h2>
        <DataTable columns={staleCols} rows={stale} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Narrative Gaps ({gaps.length})</h2>
        <DataTable columns={gapsCols} rows={gaps} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Interactions ({recent.length})</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
