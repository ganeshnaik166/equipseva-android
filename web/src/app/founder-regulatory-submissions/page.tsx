import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

type Kpis = {
  total_submissions?: number;
  active_licenses?: number;
  pending_review?: number;
  draft?: number;
  rejected?: number;
  expired?: number;
  expiring_30d?: number;
  expiring_90d?: number;
  overdue?: number;
  due_7d?: number;
  cdsco_count?: number;
  state_dc_count?: number;
  udyam_count?: number;
  gst_count?: number;
  msme_count?: number;
  total_filing_fee_rupees?: number;
};

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-neutral-800 bg-neutral-950 p-3">
      <div className="text-xs uppercase tracking-wide text-neutral-400">{label}</div>
      <div className="mt-1 text-xl font-semibold text-neutral-100">{value}</div>
    </div>
  );
}

export default async function FounderRegulatorySubmissionsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, expiringRes, overdueRes, ladderRes, byAuthRes, eventsRes, activeRes] = await Promise.all([
    supabase.rpc('founder_regsub_kpis'),
    supabase.rpc('founder_regsub_expiring_soon'),
    supabase.rpc('founder_regsub_overdue_filings'),
    supabase.rpc('founder_regsub_approval_ladder'),
    supabase.rpc('founder_regsub_by_authority'),
    supabase.rpc('founder_regsub_recent_events', { p_limit: 30 }),
    supabase.rpc('founder_regsub_active_licenses'),
  ]);

  const k: Kpis = (kpisRes.data as Kpis) || {};
  const expiring = (expiringRes.data as any[]) || [];
  const overdue = (overdueRes.data as any[]) || [];
  const ladder = (ladderRes.data as any[]) || [];
  const byAuth = (byAuthRes.data as any[]) || [];
  const events = (eventsRes.data as any[]) || [];
  const active = (activeRes.data as any[]) || [];

  return (
    <div className="min-h-screen bg-neutral-950 px-4 py-6 text-neutral-100">
      <div className="mx-auto max-w-7xl">
        <header className="mb-6">
          <div className="text-xs uppercase tracking-widest text-neutral-500">Compliance / r1458</div>
          <h1 className="mt-1 text-2xl font-semibold">Regulatory submissions tracker</h1>
          <p className="mt-1 text-sm text-neutral-400">
            CDSCO, state drug control, Udyam, GST, MSME filings — due dates, approval ladder, expiring license alerts.
          </p>
        </header>

        <section className="mb-8">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-300">Overview</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <Kpi label="Total submissions" value={k.total_submissions ?? 0} />
            <Kpi label="Active licenses" value={k.active_licenses ?? 0} />
            <Kpi label="Pending review" value={k.pending_review ?? 0} />
            <Kpi label="Draft" value={k.draft ?? 0} />
            <Kpi label="Rejected" value={k.rejected ?? 0} />
            <Kpi label="Expired" value={k.expired ?? 0} />
            <Kpi label="Expiring in 30d" value={k.expiring_30d ?? 0} />
            <Kpi label="Expiring in 90d" value={k.expiring_90d ?? 0} />
            <Kpi label="Overdue filings" value={k.overdue ?? 0} />
            <Kpi label="Due in 7d" value={k.due_7d ?? 0} />
            <Kpi label="CDSCO filings" value={k.cdsco_count ?? 0} />
            <Kpi label="State drug control" value={k.state_dc_count ?? 0} />
            <Kpi label="Udyam filings" value={k.udyam_count ?? 0} />
            <Kpi label="GST filings" value={k.gst_count ?? 0} />
            <Kpi label="MSME filings" value={k.msme_count ?? 0} />
            <Kpi label="Total filing fees" value={formatRupees(k.total_filing_fee_rupees ?? 0)} />
          </div>
        </section>

        <section className="mb-8">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-300">Expiring soon (next 120 days)</h2>
          <DataTable
            rows={expiring}
            rowKey={(r: any) => r.id}
            columns={[
              { key: 'authority', header: 'Authority', render: (r: any) => <span className="uppercase">{r.authority}</span> },
              { key: 'title', header: 'Title', render: (r: any) => r.title },
              { key: 'reference_number', header: 'Reference', render: (r: any) => r.reference_number || '—' },
              { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
              { key: 'days_until', header: 'Days left', render: (r: any) => <span className={r.days_until <= 30 ? 'text-amber-400' : 'text-neutral-200'}>{r.days_until}</span> },
              { key: 'status', header: 'Status', render: (r: any) => r.status },
            ]}
          />
        </section>

        <section className="mb-8">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-300">Overdue filings</h2>
          <DataTable
            rows={overdue}
            rowKey={(r: any) => r.id}
            columns={[
              { key: 'authority', header: 'Authority', render: (r: any) => <span className="uppercase">{r.authority}</span> },
              { key: 'title', header: 'Title', render: (r: any) => r.title },
              { key: 'reference_number', header: 'Reference', render: (r: any) => r.reference_number || '—' },
              { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '—' },
              { key: 'days_overdue', header: 'Days overdue', render: (r: any) => <span className="text-red-400">{r.days_overdue}</span> },
              { key: 'status', header: 'Status', render: (r: any) => r.status },
            ]}
          />
        </section>

        <section className="mb-8">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-300">Approval ladder (in review)</h2>
          <DataTable
            rows={ladder}
            rowKey={(r: any) => r.id}
            columns={[
              { key: 'authority', header: 'Authority', render: (r: any) => <span className="uppercase">{r.authority}</span> },
              { key: 'title', header: 'Title', render: (r: any) => r.title },
              { key: 'approval_stage', header: 'Current stage', render: (r: any) => r.approval_stage || '—' },
              { key: 'progress', header: 'Progress', render: (r: any) => `${r.approval_stages_done ?? 0} / ${r.approval_stages_total ?? 1}` },
              { key: 'status', header: 'Status', render: (r: any) => r.status },
              { key: 'submitted_at', header: 'Submitted', render: (r: any) => r.submitted_at ? new Date(r.submitted_at).toLocaleDateString() : '—' },
            ]}
          />
        </section>

        <section className="mb-8">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-300">By authority</h2>
          <DataTable
            rows={byAuth}
            rowKey={(r: any) => r.authority}
            columns={[
              { key: 'authority', header: 'Authority', render: (r: any) => <span className="uppercase">{r.authority}</span> },
              { key: 'total', header: 'Total', render: (r: any) => r.total },
              { key: 'approved', header: 'Approved', render: (r: any) => <span className="text-emerald-400">{r.approved}</span> },
              { key: 'pending', header: 'Pending', render: (r: any) => <span className="text-amber-400">{r.pending}</span> },
              { key: 'rejected', header: 'Rejected', render: (r: any) => <span className="text-red-400">{r.rejected}</span> },
              { key: 'total_fee_rupees', header: 'Total fees', render: (r: any) => formatRupees(Number(r.total_fee_rupees ?? 0)) },
            ]}
          />
        </section>

        <section className="mb-8">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-300">Active licenses</h2>
          <DataTable
            rows={active}
            rowKey={(r: any) => r.id}
            columns={[
              { key: 'authority', header: 'Authority', render: (r: any) => <span className="uppercase">{r.authority}</span> },
              { key: 'title', header: 'Title', render: (r: any) => r.title },
              { key: 'reference_number', header: 'Reference', render: (r: any) => r.reference_number || '—' },
              { key: 'state_code', header: 'State', render: (r: any) => r.state_code || '—' },
              { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
              { key: 'status', header: 'Status', render: (r: any) => r.status },
            ]}
          />
        </section>

        <section className="mb-8">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-300">Recent activity</h2>
          <DataTable
            rows={events}
            rowKey={(r: any) => r.id}
            columns={[
              { key: 'occurred_at', header: 'When', render: (r: any) => new Date(r.occurred_at).toLocaleString() },
              { key: 'authority', header: 'Authority', render: (r: any) => <span className="uppercase">{r.authority}</span> },
              { key: 'title', header: 'Title', render: (r: any) => r.title },
              { key: 'event_type', header: 'Event', render: (r: any) => r.event_type },
              { key: 'note', header: 'Note', render: (r: any) => r.note || '—' },
            ]}
          />
        </section>
      </div>
    </div>
  );
}
