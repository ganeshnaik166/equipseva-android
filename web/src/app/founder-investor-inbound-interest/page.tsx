import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return v.toLocaleString('en-IN');
}

function fmtRupees(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return '₹' + v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return v.toFixed(1) + '%';
}

function fmtDate(d: any): string {
  if (!d) return "—";
  try {
    return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  } catch {
    return "—";
  }
}

export default async function FounderInvestorInboundInterestPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  let kpis: any = null;
  let queue: any[] = [];
  let backlog: any[] = [];
  let ladder: any[] = [];
  let channels: any[] = [];
  let overdue: any[] = [];
  let warm: any[] = [];

  try {
    const r = await supabase.rpc('founder_investor_inbound_kpis');
    kpis = (r.data && r.data[0]) ?? null;
  } catch { kpis = null; }

  try {
    const r = await supabase.rpc('founder_investor_inbound_queue', { p_limit: 100 });
    queue = r.data ?? [];
  } catch { queue = []; }

  try {
    const r = await supabase.rpc('founder_investor_triage_backlog');
    backlog = r.data ?? [];
  } catch { backlog = []; }

  try {
    const r = await supabase.rpc('founder_investor_ladder_breakdown');
    ladder = r.data ?? [];
  } catch { ladder = []; }

  try {
    const r = await supabase.rpc('founder_investor_channel_rank');
    channels = r.data ?? [];
  } catch { channels = []; }

  try {
    const r = await supabase.rpc('founder_investor_overdue_actions');
    overdue = r.data ?? [];
  } catch { overdue = []; }

  try {
    const r = await supabase.rpc('founder_investor_top_warm_leads', { p_limit: 25 });
    warm = r.data ?? [];
  } catch { warm = []; }

  const kpiCards: Kpi[] = [
    { label: 'Total inbound', value: fmtNum(kpis?.total_inbound) },
    { label: 'New unreviewed', value: fmtNum(kpis?.new_unreviewed) },
    { label: 'Reviewing', value: fmtNum(kpis?.reviewing) },
    { label: 'Warm', value: fmtNum(kpis?.warm_count) },
    { label: 'Cold', value: fmtNum(kpis?.cold_count) },
    { label: 'Pass', value: fmtNum(kpis?.pass_count) },
    { label: 'Ghosted', value: fmtNum(kpis?.ghosted_count) },
    { label: 'Intro meetings', value: fmtNum(kpis?.intro_meetings) },
    { label: 'Partner meetings', value: fmtNum(kpis?.partner_meetings) },
    { label: 'DD in progress', value: fmtNum(kpis?.dd_count) },
    { label: 'Term sheets', value: fmtNum(kpis?.term_sheet_count) },
    { label: 'Closed', value: fmtNum(kpis?.closed_count) },
    { label: 'Inbound last 7d', value: fmtNum(kpis?.inbound_last_7d) },
    { label: 'Inbound last 30d', value: fmtNum(kpis?.inbound_last_30d) },
    { label: 'Avg triage score', value: kpis?.avg_triage_score !== null && kpis?.avg_triage_score !== undefined ? String(kpis.avg_triage_score) : "—" },
    { label: 'Top source', value: kpis?.top_source ?? "—" },
  ];

  const queueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? "—" },
    { key: 'source_display', header: 'Source', render: (r: any) => r.source_display ?? "—" },
    { key: 'reached_out_at', header: 'Reached out', render: (r: any) => fmtDate(r.reached_out_at) },
    { key: 'triage_status', header: 'Status', render: (r: any) => r.triage_status ?? "—" },
    { key: 'triage_score', header: 'Score', render: (r: any) => r.triage_score !== null && r.triage_score !== undefined ? String(r.triage_score) : "—" },
    { key: 'ladder_stage', header: 'Stage', render: (r: any) => r.ladder_stage ?? "—" },
    { key: 'founder_priority', header: 'P', render: (r: any) => r.founder_priority !== null && r.founder_priority !== undefined ? String(r.founder_priority) : "—" },
    { key: 'days_since_inbound', header: 'Days', render: (r: any) => r.days_since_inbound !== null && r.days_since_inbound !== undefined ? String(r.days_since_inbound) : "—" },
  ];

  const backlogCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? "—" },
    { key: 'source_display', header: 'Source', render: (r: any) => r.source_display ?? "—" },
    { key: 'days_waiting', header: 'Days waiting', render: (r: any) => r.days_waiting !== null && r.days_waiting !== undefined ? String(r.days_waiting) : "—" },
    { key: 'founder_priority', header: 'Priority', render: (r: any) => r.founder_priority !== null && r.founder_priority !== undefined ? String(r.founder_priority) : "—" },
    { key: 'contact_email', header: 'Email', render: (r: any) => r.contact_email ?? "—" },
    { key: 'contact_handle', header: 'Handle', render: (r: any) => r.contact_handle ?? "—" },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? "—" },
    { key: 'stage_count', header: 'Count', render: (r: any) => fmtNum(r.stage_count) },
    { key: 'pct_of_total', header: '% of total', render: (r: any) => fmtPct(r.pct_of_total) },
    { key: 'avg_days_in_stage', header: 'Avg days', render: (r: any) => r.avg_days_in_stage !== null && r.avg_days_in_stage !== undefined ? String(r.avg_days_in_stage) : "—" },
  ];

  const channelCols: Column<any>[] = [
    { key: 'source_display', header: 'Channel', render: (r: any) => r.source_display ?? "—" },
    { key: 'inbound_count', header: 'Inbound', render: (r: any) => fmtNum(r.inbound_count) },
    { key: 'warm_count', header: 'Warm', render: (r: any) => fmtNum(r.warm_count) },
    { key: 'intro_count', header: 'Intros', render: (r: any) => fmtNum(r.intro_count) },
    { key: 'partner_count', header: 'Partner mtgs', render: (r: any) => fmtNum(r.partner_count) },
    { key: 'term_sheet_count', header: 'Term sheets', render: (r: any) => fmtNum(r.term_sheet_count) },
    { key: 'warm_pct', header: 'Warm %', render: (r: any) => fmtPct(r.warm_pct) },
    { key: 'intro_pct', header: 'Intro %', render: (r: any) => fmtPct(r.intro_pct) },
    { key: 'avg_triage_score', header: 'Avg score', render: (r: any) => r.avg_triage_score !== null && r.avg_triage_score !== undefined ? String(r.avg_triage_score) : "—" },
  ];

  const warmCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? "—" },
    { key: 'source_display', header: 'Source', render: (r: any) => r.source_display ?? "—" },
    { key: 'triage_score', header: 'Score', render: (r: any) => r.triage_score !== null && r.triage_score !== undefined ? String(r.triage_score) : "—" },
    { key: 'ladder_stage', header: 'Stage', render: (r: any) => r.ladder_stage ?? "—" },
    { key: 'check_size_max_rupees', header: 'Check max', render: (r: any) => fmtRupees(r.check_size_max_rupees) },
    { key: 'thesis_snippet', header: 'Thesis', render: (r: any) => r.thesis_snippet ?? "—" },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => fmtDate(r.last_touch_at) },
  ];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Investor inbound-interest log</h1>
        <p className="text-sm text-gray-600 mt-1">Capture every investor that reaches out. Triage, ladder, channel rank.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpiCards.map((k) => (
          <div key={k.label} className="rounded border bg-white p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Inbound queue (recent)</h2>
        <DataTable rowKey={(r: any) => r.id} columns={queueCols} rows={queue} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Triage backlog</h2>
        <DataTable rowKey={(r: any) => r.id} columns={backlogCols} rows={backlog} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Meeting-conversion ladder</h2>
        <DataTable rowKey={(r: any) => r.stage} columns={ladderCols} rows={ladder} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-source channel rank</h2>
        <DataTable rowKey={(r: any) => r.source_display} columns={channelCols} rows={channels} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top warm leads</h2>
        <DataTable rowKey={(r: any) => r.id} columns={warmCols} rows={warm} />
      </section>

      {overdue.length > 0 && (
        <section className="rounded border border-amber-300 bg-amber-50 p-4">
          <h2 className="text-lg font-semibold mb-2 text-amber-900">Overdue next-actions ({overdue.length})</h2>
          <ul className="text-sm text-amber-900 space-y-1">
            {overdue.slice(0, 10).map((o: any) => (
              <li key={o.id}>
                {o.investor_name} ({o.firm_name ?? "—"}) — {o.next_action ?? "—"} · {o.days_overdue ?? "—"} days overdue · stage {o.ladder_stage ?? "—"}
              </li>
            ))}
          </ul>
        </section>
      )}
    </main>
  );
}
