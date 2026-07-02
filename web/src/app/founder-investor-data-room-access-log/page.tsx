import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Kpi = { label: string; value: string };

function n(v: any): string {
  if (v === null || v === undefined) return '0';
  const num = typeof v === 'number' ? v : Number(v);
  if (Number.isNaN(num)) return String(v);
  return num.toLocaleString('en-IN');
}

function fmtTime(v: any): string {
  if (!v) return '—';
  try { return new Date(v).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }); }
  catch { return String(v); }
}

function fmtDwell(sec: any): string {
  const s = Number(sec) || 0;
  if (s < 60) return s + 's';
  const m = Math.floor(s / 60);
  const rs = s % 60;
  return m + 'm ' + rs + 's';
}

function tempBadge(t: any): string {
  const v = String(t || '').toLowerCase();
  if (v === 'hot')  return 'bg-rose-100 text-rose-700';
  if (v === 'warm') return 'bg-amber-100 text-amber-700';
  return 'bg-slate-200 text-slate-700';
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, recentRes, heatRes, docsRes, coldRes, histRes] = await Promise.all([
    sb.rpc('founder_dr_access_kpis'),
    sb.rpc('founder_dr_recent_access', { p_limit: 100 }),
    sb.rpc('founder_dr_investor_heatmap'),
    sb.rpc('founder_dr_doc_popularity'),
    sb.rpc('founder_dr_cold_investors'),
    sb.rpc('founder_dr_cold_action_history', { p_limit: 50 }),
  ]);

  try { await sb.rpc('log_founder_dr_access_view'); } catch {}

  const k: any = kpisRes.data ?? {};
  const recent: any[] = recentRes.data ?? [];
  const heat: any[] = heatRes.data ?? [];
  const docs: any[] = docsRes.data ?? [];
  const cold: any[] = coldRes.data ?? [];
  const hist: any[] = histRes.data ?? [];

  const kpis: Kpi[] = [
    { label: 'Total events',         value: n(k.total_events) },
    { label: 'Events 24h',           value: n(k.events_24h) },
    { label: 'Events 7d',            value: n(k.events_7d) },
    { label: 'Events 30d',           value: n(k.events_30d) },
    { label: 'Unique investors',     value: n(k.unique_investors) },
    { label: 'Unique firms',         value: n(k.unique_firms) },
    { label: 'Unique docs',          value: n(k.unique_docs) },
    { label: 'Unique tokens',        value: n(k.unique_tokens) },
    { label: 'Avg dwell (sec)',      value: n(k.avg_dwell_seconds) },
    { label: 'Total dwell (min)',    value: n(k.total_dwell_minutes) },
    { label: 'Repeat visitors',      value: n(k.repeat_visitors) },
    { label: 'Whales (5+ visits)',   value: n(k.whales_5plus) },
    { label: 'Cold investors',       value: n(k.cold_investors) },
    { label: 'Hot investors (7d)',   value: n(k.hot_investors_7d) },
    { label: 'Cold actions total',   value: n(k.cold_actions_total) },
    { label: 'Cold actions pending', value: n(k.cold_actions_pending) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'accessed_at',    header: 'When',     render: (r: any) => fmtTime(r.accessed_at) },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'investor_firm',  header: 'Firm',     render: (r: any) => r.investor_firm ?? '—' },
    { key: 'doc_title',      header: 'Doc',      render: (r: any) => r.doc_title ?? r.doc_slug ?? '—' },
    { key: 'dwell_seconds',  header: 'Dwell',    render: (r: any) => fmtDwell(r.dwell_seconds) },
    { key: 'share_token',    header: 'Token',    render: (r: any) => (r.share_token ? String(r.share_token).slice(0, 10) + '…' : '—') },
  ];

  const heatCols: Column<any>[] = [
    { key: 'investor_email',      header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'investor_firm',       header: 'Firm',     render: (r: any) => r.investor_firm ?? '—' },
    { key: 'visits',              header: 'Visits',   render: (r: any) => n(r.visits) },
    { key: 'unique_docs',         header: 'Docs',     render: (r: any) => n(r.unique_docs) },
    { key: 'total_dwell_seconds', header: 'Dwell',    render: (r: any) => fmtDwell(r.total_dwell_seconds) },
    { key: 'last_seen',           header: 'Last seen',render: (r: any) => fmtTime(r.last_seen) },
    { key: 'days_since_last',     header: 'Days ago', render: (r: any) => (r.days_since_last ?? '—') },
    { key: 'temperature',         header: 'Temp',     render: (r: any) => (
      <span className={'inline-flex px-2 py-0.5 rounded text-xs font-medium ' + tempBadge(r.temperature)}>
        {String(r.temperature ?? '—')}
      </span>
    ) },
  ];

  const docCols: Column<any>[] = [
    { key: 'doc_title',         header: 'Doc',        render: (r: any) => r.doc_title ?? r.doc_slug ?? '—' },
    { key: 'total_views',       header: 'Views',      render: (r: any) => n(r.total_views) },
    { key: 'unique_viewers',    header: 'Viewers',    render: (r: any) => n(r.unique_viewers) },
    { key: 'avg_dwell_seconds', header: 'Avg dwell',  render: (r: any) => fmtDwell(r.avg_dwell_seconds) },
    { key: 'last_viewed',       header: 'Last viewed',render: (r: any) => fmtTime(r.last_viewed) },
  ];

  const coldCols: Column<any>[] = [
    { key: 'investor_email',   header: 'Investor',     render: (r: any) => r.investor_email ?? '—' },
    { key: 'investor_firm',    header: 'Firm',         render: (r: any) => r.investor_firm ?? '—' },
    { key: 'last_seen',        header: 'Last seen',    render: (r: any) => fmtTime(r.last_seen) },
    { key: 'days_since_last',  header: 'Days cold',    render: (r: any) => (r.days_since_last ?? '—') },
    { key: 'visits',           header: 'Visits',       render: (r: any) => n(r.visits) },
    { key: 'suggested_step',   header: 'Next action',  render: (r: any) => (
      <span className="inline-flex px-2 py-0.5 rounded text-xs font-medium bg-indigo-100 text-indigo-700">
        {String(r.suggested_step ?? '—')}
      </span>
    ) },
  ];

  const histCols: Column<any>[] = [
    { key: 'taken_at',       header: 'When',     render: (r: any) => fmtTime(r.taken_at) },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'investor_firm',  header: 'Firm',     render: (r: any) => r.investor_firm ?? '—' },
    { key: 'ladder_step',    header: 'Step',     render: (r: any) => r.ladder_step ?? '—' },
    { key: 'outcome',        header: 'Outcome',  render: (r: any) => r.outcome ?? 'pending' },
    { key: 'notes',          header: 'Notes',    render: (r: any) => r.notes ?? '—' },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Investor Data-Room Access Log</h1>
        <p className="text-sm text-slate-600">
          Every investor data-room hit with per-investor heat map and a founder action ladder for cold investors.
        </p>
      </header>

      <section aria-label="KPIs" className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((kpi: Kpi) => (
          <div key={kpi.label} className="rounded-lg border border-slate-200 bg-white p-3">
            <div className="text-xs text-slate-500">{kpi.label}</div>
            <div className="text-lg font-semibold text-slate-900 mt-1">{kpi.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent access events</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Per-investor heat map</h2>
        <DataTable columns={heatCols} rows={heat} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Document popularity</h2>
        <DataTable columns={docCols} rows={docs} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Cold investors — action ladder</h2>
        <DataTable columns={coldCols} rows={cold} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Cold action history</h2>
        <DataTable columns={histCols} rows={hist} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
