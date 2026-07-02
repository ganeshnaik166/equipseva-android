import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AuditRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  audit_date: string | null;
  audit_score: number | null;
  audit_category: string | null;
  status: string | null;
  captured_at: string | null;
};

type FailedRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  audit_date: string | null;
  audit_score: number | null;
  audit_category: string | null;
  status: string | null;
};

type ActionRow = {
  id: string;
  audit_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return '';
  try { return new Date(s).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }); } catch { return s; }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, failedRes, actionsRes] = await Promise.all([
    sb.rpc('list_audits_r2044', { p_limit: 100 }),
    sb.rpc('failed_audits_r2044', { p_limit: 50 }),
    sb.rpc('recent_actions_r2044', { p_limit: 50 }),
  ]);

  const audits: AuditRow[] = (auditsRes.data as AuditRow[]) ?? [];
  const failed: FailedRow[] = (failedRes.data as FailedRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const totalAudits = audits.length;
  const passedCount = audits.filter((a) => a.status === 'passed').length;
  const failedCount = failed.length;
  const avgScore = totalAudits > 0
    ? Math.round(audits.reduce((s, a) => s + (a.audit_score ?? 0), 0) / totalAudits)
    : 0;

  const auditCols: Column<AuditRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'audit_date', header: 'Audit Date', render: (r: any) => r.audit_date ?? '' },
    { key: 'audit_category', header: 'Category', render: (r: any) => r.audit_category ?? '' },
    { key: 'audit_score', header: 'Score', render: (r: any) => String(r.audit_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const failedCols: Column<FailedRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'audit_date', header: 'Date', render: (r: any) => r.audit_date ?? '' },
    { key: 'audit_category', header: 'Category', render: (r: any) => r.audit_category ?? '' },
    { key: 'audit_score', header: 'Score', render: (r: any) => String(r.audit_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'audit_id', header: 'Audit', render: (r: any) => String(r.audit_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Quality Audit Tracker</h1>
        <p className="text-sm text-gray-600">
          Track quality audit results per engineer across work quality, safety, customer handling, documentation, and cleanup.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total audits</div>
          <div className="text-xl font-semibold">{totalAudits}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Passed</div>
          <div className="text-xl font-semibold">{passedCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Needs attention</div>
          <div className="text-xl font-semibold">{failedCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Average score</div>
          <div className="text-xl font-semibold">{avgScore}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent audits</h2>
        <DataTable
          rows={audits}
          columns={auditCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Failed and escalated</h2>
        <p className="text-sm text-gray-600">Audits flagged as needs improvement, failed, or escalated.</p>
        <DataTable
          rows={failed}
          columns={failedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent actions</h2>
        <p className="text-sm text-gray-600">Coaching, retraining, recognition, and escalation actions taken.</p>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
