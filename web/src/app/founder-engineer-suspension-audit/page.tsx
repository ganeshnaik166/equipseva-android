import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let recent: any[] = [];
  let breaches: any[] = [];
  let mix: any[] = [];
  let reviews: any[] = [];

  try {
    const r = await sb.rpc('founder_suspension_audit_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch { kpis = {}; }
  try {
    const r = await sb.rpc('founder_suspension_audit_recent');
    recent = r.data || [];
  } catch { recent = []; }
  try {
    const r = await sb.rpc('founder_suspension_audit_sla_breaches');
    breaches = r.data || [];
  } catch { breaches = []; }
  try {
    const r = await sb.rpc('founder_suspension_audit_category_mix');
    mix = r.data || [];
  } catch { mix = []; }
  try {
    const r = await sb.rpc('founder_suspension_audit_reviews_recent');
    reviews = r.data || [];
  } catch { reviews = []; }

  const cards: Kpi[] = [
    { label: 'Total Suspensions', value: kpis.total_suspensions ?? '—' },
    { label: 'Open', value: kpis.open_count ?? '—' },
    { label: 'Founder Approved', value: kpis.approved_count ?? '—' },
    { label: 'Reinstated', value: kpis.reinstated_count ?? '—' },
    { label: 'Permanent', value: kpis.permanent_count ?? '—' },
    { label: 'Archived', value: kpis.archived_count ?? '—' },
    { label: 'SLA Breached', value: kpis.sla_breached_count ?? '—' },
    { label: 'Avg Review Hours', value: kpis.avg_review_hours ?? '—' },
    { label: 'Fraud', value: kpis.fraud_count ?? '—' },
    { label: 'Quality', value: kpis.quality_count ?? '—' },
    { label: 'Safety', value: kpis.safety_count ?? '—' },
    { label: 'No-Show', value: kpis.no_show_count ?? '—' },
    { label: 'Complaint', value: kpis.complaint_count ?? '—' },
    { label: 'Evidence Attached', value: kpis.evidence_attached_count ?? '—' },
    { label: 'L30D New', value: kpis.l30d_new ?? '—' },
    { label: 'Pending Approval', value: kpis.pending_founder_approval ?? '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'reason_category', header: 'Category', render: (r: any) => r.reason_category ?? '—' },
    { key: 'reason', header: 'Reason', render: (r: any) => (r.reason ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'founder_approved', header: 'Approved', render: (r: any) => (r.founder_approved ? 'yes' : 'no') },
    { key: 'evidence_count', header: 'Evidence', render: (r: any) => r.evidence_count ?? 0 },
    { key: 'days_open', header: 'Days Open', render: (r: any) => r.days_open ?? '—' },
    { key: 'created_at', header: 'Opened', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '—' },
  ];

  const breachCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'reason_category', header: 'Category', render: (r: any) => r.reason_category ?? '—' },
    { key: 'hours_overdue', header: 'Hours Overdue', render: (r: any) => r.hours_overdue ?? '—' },
    { key: 'sla_review_due_at', header: 'SLA Due', render: (r: any) => r.sla_review_due_at ? new Date(r.sla_review_due_at).toLocaleString() : '—' },
  ];

  const mixCols: Column<any>[] = [
    { key: 'reason_category', header: 'Category', render: (r: any) => r.reason_category ?? '—' },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt ?? 0 },
    { key: 'reinstated', header: 'Reinstated', render: (r: any) => r.reinstated ?? 0 },
    { key: 'permanent', header: 'Permanent', render: (r: any) => r.permanent ?? 0 },
    { key: 'avg_days_open', header: 'Avg Days Open', render: (r: any) => r.avg_days_open ?? '—' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email ?? '—' },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '—' },
    { key: 'decision_notes', header: 'Notes', render: (r: any) => r.decision_notes ?? '—' },
    { key: 'reviewed_at', header: 'When', render: (r: any) => r.reviewed_at ? new Date(r.reviewed_at).toLocaleString() : '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Engineer Suspension Audit Trail</h1>
        <p className="text-sm text-gray-500">r1574 — log reason, evidence, founder approval, reinstatement path, SLA review, 90-day archive.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((k) => (
          <div key={k.label} className="border rounded p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{String(k.value)}</div>
          </div>
        ))}
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent Suspensions</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">SLA Breaches</h2>
        <DataTable columns={breachCols} rows={breaches} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Category Mix</h2>
        <DataTable columns={mixCols} rows={mix} rowKey={(r: any) => r.reason_category} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent Reviews</h2>
        <DataTable columns={reviewCols} rows={reviews} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
