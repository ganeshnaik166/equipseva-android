import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(n);
}
function fmtLakh(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + new Intl.NumberFormat('en-IN', { maximumFractionDigits: 1 }).format(n) + 'L';
}
function fmtDays(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return n.toFixed(1) + 'd';
}

export default async function FounderInvestorMegaListPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let mega: any[] = [];
  let funnel: any[] = [];
  let ladder: any[] = [];
  let stale: any[] = [];
  let byStage: any[] = [];
  let bySource: any[] = [];

  try { const r = await sb.rpc('rpc_founder_investor_kpis'); kpis = (r.data ?? [])[0] ?? null; } catch {}
  try { const r = await sb.rpc('rpc_founder_investor_mega_list'); mega = r.data ?? []; } catch {}
  try { const r = await sb.rpc('rpc_founder_investor_funnel'); funnel = r.data ?? []; } catch {}
  try { const r = await sb.rpc('rpc_founder_investor_action_ladder'); ladder = r.data ?? []; } catch {}
  try { const r = await sb.rpc('rpc_founder_investor_stale'); stale = r.data ?? []; } catch {}
  try { const r = await sb.rpc('rpc_founder_investor_by_stage'); byStage = r.data ?? []; } catch {}
  try { const r = await sb.rpc('rpc_founder_investor_by_source_round'); bySource = r.data ?? []; } catch {}

  const k: Kpi[] = [
    { label: 'Total investors',     value: fmtNum(kpis?.total_investors) },
    { label: 'Cold',                value: fmtNum(kpis?.cold_n) },
    { label: 'Warm',                value: fmtNum(kpis?.warm_n) },
    { label: 'Met',                 value: fmtNum(kpis?.met_n) },
    { label: 'DD',                  value: fmtNum(kpis?.dd_n) },
    { label: 'Term sheet',          value: fmtNum(kpis?.term_sheet_n) },
    { label: 'Passed',              value: fmtNum(kpis?.passed_n) },
    { label: 'Closed',              value: fmtNum(kpis?.closed_n) },
    { label: 'Ghosted',             value: fmtNum(kpis?.ghosted_n) },
    { label: 'Pipeline (max)',      value: fmtLakh(kpis?.total_pipeline_lakh) },
    { label: 'Closed amount',       value: fmtLakh(kpis?.closed_amount_lakh) },
    { label: 'Avg thesis fit',      value: kpis?.avg_thesis_fit ? Number(kpis.avg_thesis_fit).toFixed(0) : '—' },
    { label: 'Stale >30d',          value: fmtNum(kpis?.stale_30d) },
    { label: 'Open actions',        value: fmtNum(kpis?.open_actions) },
    { label: 'Due this week',       value: fmtNum(kpis?.due_this_week) },
    { label: 'Sources tracked',     value: fmtNum(bySource.length) },
  ];

  const megaCols: Column<any>[] = [
    { key: 'investor_name',    header: 'Investor',      render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm_name',        header: 'Firm',          render: (r: any) => r.firm_name ?? '—' },
    { key: 'fund_stage',       header: 'Stage',         render: (r: any) => r.fund_stage ?? '—' },
    { key: 'lifecycle_state',  header: 'State',         render: (r: any) => r.lifecycle_state ?? '—' },
    { key: 'cheque_max_lakh',  header: 'Max cheque',    render: (r: any) => fmtLakh(r.cheque_max_lakh) },
    { key: 'thesis_fit_0_100', header: 'Fit',           render: (r: any) => r.thesis_fit_0_100 ?? '—' },
    { key: 'partner_lead',     header: 'Partner',       render: (r: any) => r.partner_lead ?? '—' },
    { key: 'days_since_touch', header: 'Days idle',     render: (r: any) => fmtDays(r.days_since_touch) },
    { key: 'source_round',     header: 'Source round',  render: (r: any) => r.source_round ?? '—' },
    { key: 'open_actions',     header: 'Open actions',  render: (r: any) => r.open_actions ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'lifecycle_state',       header: 'State',          render: (r: any) => r.lifecycle_state ?? '—' },
    { key: 'n',                     header: 'Count',          render: (r: any) => fmtNum(r.n) },
    { key: 'total_cheque_max_lakh', header: 'Max cheque sum', render: (r: any) => fmtLakh(r.total_cheque_max_lakh) },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'investor_name',  header: 'Investor',  render: (r: any) => r.investor_name ?? '—' },
    { key: 'rung_order',     header: 'Rung',      render: (r: any) => r.rung_order ?? '—' },
    { key: 'action_text',    header: 'Action',    render: (r: any) => r.action_text ?? '—' },
    { key: 'due_at',         header: 'Due',       render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString('en-IN') : '—' },
    { key: 'days_until_due', header: 'Days left', render: (r: any) => fmtDays(r.days_until_due) },
    { key: 'blocker_note',   header: 'Blocker',   render: (r: any) => r.blocker_note ?? '—' },
  ];

  const staleCols: Column<any>[] = [
    { key: 'investor_name',    header: 'Investor',  render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm_name',        header: 'Firm',      render: (r: any) => r.firm_name ?? '—' },
    { key: 'lifecycle_state',  header: 'State',     render: (r: any) => r.lifecycle_state ?? '—' },
    { key: 'days_since_touch', header: 'Days idle', render: (r: any) => fmtDays(r.days_since_touch) },
    { key: 'partner_lead',     header: 'Partner',   render: (r: any) => r.partner_lead ?? '—' },
    { key: 'cheque_max_lakh',  header: 'Max cheque',render: (r: any) => fmtLakh(r.cheque_max_lakh) },
  ];

  const sourceCols: Column<any>[] = [
    { key: 'source_round',     header: 'Source round',  render: (r: any) => r.source_round ?? '—' },
    { key: 'n',                header: 'Investors',     render: (r: any) => fmtNum(r.n) },
    { key: 'closed_n',         header: 'Closed',        render: (r: any) => fmtNum(r.closed_n) },
    { key: 'total_closed_lakh',header: 'Closed sum',    render: (r: any) => fmtLakh(r.total_closed_lakh) },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Investor Mega-List · Full Lifecycle</h1>
        <p className="text-sm text-gray-500">
          Every investor across r1390/r1419/r1435/r1474/r1486/r1495/r1499 with funnel + action ladder · r1503
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {k.map((kpi) => (
          <div key={kpi.label} className="rounded-lg border border-gray-200 bg-white p-3">
            <div className="text-xs text-gray-500">{kpi.label}</div>
            <div className="text-xl font-semibold mt-1">{kpi.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Mega-list</h2>
        <DataTable columns={megaCols} rows={mega} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Funnel</h2>
        <DataTable columns={funnelCols} rows={funnel} rowKey={(r: any) => r.lifecycle_state} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action ladder · open rungs</h2>
        <DataTable columns={ladderCols} rows={ladder} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale {">"} 30d</h2>
        <DataTable columns={staleCols} rows={stale} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By source round</h2>
        <DataTable columns={sourceCols} rows={bySource} rowKey={(r: any) => r.source_round} />
      </section>
    </div>
  );
}
