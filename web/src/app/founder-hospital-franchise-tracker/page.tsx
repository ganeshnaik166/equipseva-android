import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (!isFinite(v)) return '-';
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN');
}

export default async function FounderHospitalFranchiseTrackerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let prospects: any[] = [];
  let queue: any[] = [];
  let funnel: any[] = [];
  let events: any[] = [];

  try {
    const k = await sb.rpc('founder_franchise_tracker_kpis');
    kpis = (k.data as any) ?? {};
  } catch { kpis = {}; }

  try {
    const p = await sb.rpc('founder_franchise_prospects_list');
    prospects = (p.data as any[]) ?? [];
  } catch { prospects = []; }

  try {
    const q = await sb.rpc('founder_franchise_go_no_go_queue');
    queue = (q.data as any[]) ?? [];
  } catch { queue = []; }

  try {
    const f = await sb.rpc('founder_franchise_stage_funnel');
    funnel = (f.data as any[]) ?? [];
  } catch { funnel = []; }

  try {
    const e = await sb.rpc('founder_franchise_stage_events_recent');
    events = (e.data as any[]) ?? [];
  } catch { events = []; }

  try {
    await sb.rpc('log_founder_franchise_view', { p_op: 'page_view' });
  } catch { /* swallow */ }

  const cards: Kpi[] = [
    { label: 'Total Prospects', value: fmtInt(kpis.total) },
    { label: 'Leads', value: fmtInt(kpis.leads) },
    { label: 'Qualified', value: fmtInt(kpis.qualified) },
    { label: 'Term Sheet', value: fmtInt(kpis.term_sheet) },
    { label: 'Due Diligence', value: fmtInt(kpis.due_diligence) },
    { label: 'Contract Sent', value: fmtInt(kpis.contract_sent) },
    { label: 'Signed', value: fmtInt(kpis.signed) },
    { label: 'Live', value: fmtInt(kpis.live) },
    { label: 'Stalled', value: fmtInt(kpis.stalled) },
    { label: 'Rejected', value: fmtInt(kpis.rejected) },
    { label: 'Founder GO', value: fmtInt(kpis.go_count) },
    { label: 'Founder NO-GO', value: fmtInt(kpis.no_go_count) },
    { label: 'Pending Decision', value: fmtInt(kpis.pending_count) },
    { label: 'Booked Monthly Rev', value: fmtRupees(kpis.booked_monthly_rupees) },
    { label: 'Pipeline Monthly Rev', value: fmtRupees(kpis.pipeline_monthly_rupees) },
    { label: 'Overdue Next Steps', value: fmtInt(kpis.overdue_next_steps) },
  ];

  const prospectsCols: Column<any>[] = [
    { key: 'prospect_name', header: 'Prospect', render: (r: any) => r.prospect_name ?? '-' },
    { key: 'city', header: 'City', render: (r: any) => (r.city ?? '-') + ' / ' + (r.state_code ?? '-') },
    { key: 'agreement_stage', header: 'Stage', render: (r: any) => r.agreement_stage ?? '-' },
    { key: 'founder_decision', header: 'Decision', render: (r: any) => r.founder_decision ?? '-' },
    { key: 'monthly_revenue_projection_rupees', header: 'Monthly Rev', render: (r: any) => fmtRupees(r.monthly_revenue_projection_rupees) },
    { key: 'one_time_setup_rupees', header: 'Setup', render: (r: any) => fmtRupees(r.one_time_setup_rupees) },
    { key: 'expected_amc_count', header: 'AMCs', render: (r: any) => fmtInt(r.expected_amc_count) },
    { key: 'expected_repair_jobs_monthly', header: 'Jobs/mo', render: (r: any) => fmtInt(r.expected_repair_jobs_monthly) },
    { key: 'risk_score', header: 'Risk', render: (r: any) => fmtInt(r.risk_score) },
    { key: 'next_step_due_date', header: 'Next Due', render: (r: any) => r.next_step_due_date ?? '-' },
  ];

  const queueCols: Column<any>[] = [
    { key: 'prospect_name', header: 'Prospect', render: (r: any) => r.prospect_name ?? '-' },
    { key: 'agreement_stage', header: 'Stage', render: (r: any) => r.agreement_stage ?? '-' },
    { key: 'monthly_revenue_projection_rupees', header: 'Monthly Rev', render: (r: any) => fmtRupees(r.monthly_revenue_projection_rupees) },
    { key: 'risk_score', header: 'Risk', render: (r: any) => fmtInt(r.risk_score) },
    { key: 'next_step', header: 'Next Step', render: (r: any) => r.next_step ?? '-' },
    { key: 'next_step_due_date', header: 'Due', render: (r: any) => r.next_step_due_date ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'agreement_stage', header: 'Stage', render: (r: any) => r.agreement_stage ?? '-' },
    { key: 'prospect_count', header: 'Prospects', render: (r: any) => fmtInt(r.prospect_count) },
    { key: 'projected_monthly_rupees', header: 'Projected Monthly', render: (r: any) => fmtRupees(r.projected_monthly_rupees) },
  ];

  const eventsCols: Column<any>[] = [
    { key: 'prospect_name', header: 'Prospect', render: (r: any) => r.prospect_name ?? '-' },
    { key: 'from_stage', header: 'From', render: (r: any) => r.from_stage ?? '-' },
    { key: 'to_stage', header: 'To', render: (r: any) => r.to_stage ?? '-' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '-' },
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '-' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Franchise Tracker</h1>
        <p className="text-sm text-gray-500">r1616 — concrete franchise prospect ledger: stage, projection, founder go/no-go.</p>
      </header>

      <section className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded border border-gray-200 bg-white p-3">
            <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
            <div className="mt-1 text-lg font-semibold text-gray-900">{c.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Go / No-Go Queue</h2>
        <DataTable columns={queueCols} rows={queue} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Stage Funnel</h2>
        <DataTable columns={funnelCols} rows={funnel} rowKey={(r: any) => r.agreement_stage} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Prospects</h2>
        <DataTable columns={prospectsCols} rows={prospects} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Stage Events</h2>
        <DataTable columns={eventsCols} rows={events} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
