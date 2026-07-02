import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [updatesRes, summaryRes] = await Promise.all([
    sb.rpc('list_updates_r1713'),
    sb.rpc('latest_update_summary_r1713'),
  ]);

  const updates: any[] = Array.isArray(updatesRes.data) ? updatesRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) && summaryRes.data.length > 0 ? summaryRes.data[0] : null;

  let reviewers: any[] = [];
  if (updates.length > 0) {
    const firstId = updates[0].id;
    const revRes = await sb.rpc('list_reviewers_r1713', { p_update_id: firstId });
    reviewers = Array.isArray(revRes.data) ? revRes.data : [];
  }

  const updateCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono text-xs">{r.quarter}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span> },
    { key: 'drafter_email', header: 'Drafter', render: (r: any) => <span className="text-xs">{r.drafter_email ?? '-'}</span> },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => <span className="text-xs">{r.drafted_at ? new Date(r.drafted_at).toLocaleString() : '-'}</span> },
    { key: 'reviewer_count', header: 'Reviewers', render: (r: any) => <span className="text-xs">{r.reviewer_count ?? 0}</span> },
    { key: 'approve_count', header: 'Approved', render: (r: any) => <span className="text-xs text-green-700">{r.approve_count ?? 0}</span> },
    { key: 'request_changes_count', header: 'Changes', render: (r: any) => <span className="text-xs text-amber-700">{r.request_changes_count ?? 0}</span> },
    { key: 'approved_by_email', header: 'Approved By', render: (r: any) => <span className="text-xs">{r.approved_by_email ?? '-'}</span> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => <span className="text-xs">{r.sent_at ? new Date(r.sent_at).toLocaleString() : '-'}</span> },
  ];

  const reviewerCols: Column<any>[] = [
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => <span className="text-xs">{r.reviewer_email}</span> },
    { key: 'decision', header: 'Decision', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.decision}</span> },
    { key: 'comment_md', header: 'Comment', render: (r: any) => <span className="text-xs">{r.comment_md ?? '-'}</span> },
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span className="text-xs">{r.decided_at ? new Date(r.decided_at).toLocaleString() : '-'}</span> },
    { key: 'created_at', header: 'Logged', render: (r: any) => <span className="text-xs">{r.created_at ? new Date(r.created_at).toLocaleString() : '-'}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Investor Quarterly Update Approvals</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Track quarterly investor letter drafts through review, approval, and send. Workflow: draft → under_review → approved → sent.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Pipeline Summary</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Total</div>
            <div className="mt-1 text-xl font-semibold">{summary?.total_updates ?? 0}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Draft</div>
            <div className="mt-1 text-xl font-semibold">{summary?.draft_count ?? 0}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Under Review</div>
            <div className="mt-1 text-xl font-semibold">{summary?.under_review_count ?? 0}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Approved</div>
            <div className="mt-1 text-xl font-semibold text-green-700">{summary?.approved_count ?? 0}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Sent</div>
            <div className="mt-1 text-xl font-semibold text-blue-700">{summary?.sent_count ?? 0}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Archived</div>
            <div className="mt-1 text-xl font-semibold text-[var(--color-muted)]">{summary?.archived_count ?? 0}</div>
          </div>
        </div>
        {summary?.latest_quarter ? (
          <div className="rounded border border-[var(--color-border)] bg-white p-3 text-sm">
            <span className="text-[var(--color-muted)]">Latest quarter:</span>{' '}
            <span className="font-mono text-xs">{summary.latest_quarter}</span>{' '}
            <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{summary.latest_status}</span>{' '}
            {summary.latest_drafted_at ? (
              <span className="text-xs text-[var(--color-muted)]">
                drafted {new Date(summary.latest_drafted_at).toLocaleString()}
              </span>
            ) : null}{' '}
            {summary.latest_sent_at ? (
              <span className="text-xs text-[var(--color-muted)]">
                · sent {new Date(summary.latest_sent_at).toLocaleString()}
              </span>
            ) : null}
          </div>
        ) : null}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Quarterly Updates</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Most recent 200 drafts. Approve only after &gt;= 1 approve decision and 0 outstanding request_changes.
        </p>
        <DataTable
          rows={updates}
          columns={updateCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No quarterly updates drafted yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Reviewer Decisions (latest update)</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Decisions on the most recent update. Status auto-moves draft → under_review when first decision is recorded.
        </p>
        <DataTable
          rows={reviewers}
          columns={reviewerCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No reviewer decisions logged yet."
        />
      </section>
    </main>
  );
}
