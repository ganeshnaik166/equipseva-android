import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderStrategyDocVersioningPage() {
  const supabase = await getSupabaseServerClient();

  const [docsRes, reviewsRes, lockedRes, pendingRes, historyRes, signoffRes, decisionsRes] = await Promise.all([
    supabase.rpc('list_docs_r2485'),
    supabase.rpc('list_stakeholder_reviews_r2485'),
    supabase.rpc('latest_locked_docs_r2485'),
    supabase.rpc('pending_reviews_focus_r2485'),
    supabase.rpc('version_history_r2485'),
    supabase.rpc('signoff_status_summary_r2485'),
    supabase.rpc('top_changed_decisions_r2485'),
  ]);

  const docs = (docsRes.data ?? []) as any[];
  const reviews = (reviewsRes.data ?? []) as any[];
  const locked = (lockedRes.data ?? []) as any[];
  const pending = (pendingRes.data ?? []) as any[];
  const history = (historyRes.data ?? []) as any[];
  const signoff = (signoffRes.data ?? []) as any[];
  const decisions = (decisionsRes.data ?? []) as any[];

  const docCols: Column<any>[] = [
    { key: 'doc_title', header: 'Doc', render: (r: any) => r.doc_title },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'prior_version_label', header: 'Prior', render: (r: any) => r.prior_version_label ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => r.drafted_at ? new Date(r.drafted_at).toLocaleDateString() : '—' },
    { key: 'locked_at', header: 'Locked', render: (r: any) => r.locked_at ? new Date(r.locked_at).toLocaleDateString() : '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'delta_summary_md', header: 'Delta', render: (r: any) => r.delta_summary_md ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'doc_title', header: 'Doc', render: (r: any) => r.doc_title },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email },
    { key: 'signoff_status', header: 'Signoff', render: (r: any) => r.signoff_status },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => r.reviewed_at ? new Date(r.reviewed_at).toLocaleDateString() : '—' },
    { key: 'follow_up_required', header: 'Follow-up', render: (r: any) => r.follow_up_required ? 'yes' : 'no' },
    { key: 'follow_up_at', header: 'Follow-up Date', render: (r: any) => r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : '—' },
    { key: 'feedback_md', header: 'Feedback', render: (r: any) => r.feedback_md ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const lockedCols: Column<any>[] = [
    { key: 'doc_title', header: 'Doc', render: (r: any) => r.doc_title },
    { key: 'version_label', header: 'Locked Version', render: (r: any) => r.version_label },
    { key: 'locked_at', header: 'Locked At', render: (r: any) => r.locked_at ? new Date(r.locked_at).toLocaleDateString() : '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'days_since_lock', header: 'Days Since Lock', render: (r: any) => `${r.days_since_lock}d` },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'doc_title', header: 'Doc', render: (r: any) => r.doc_title },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email },
    { key: 'status', header: 'Doc Status', render: (r: any) => r.status },
    { key: 'days_pending', header: 'Days Pending', render: (r: any) => `${r.days_pending}d` },
  ];

  const historyCols: Column<any>[] = [
    { key: 'doc_title', header: 'Doc', render: (r: any) => r.doc_title },
    { key: 'version_count', header: 'Versions', render: (r: any) => String(r.version_count) },
    { key: 'latest_version', header: 'Latest', render: (r: any) => r.latest_version },
    { key: 'latest_status', header: 'Latest Status', render: (r: any) => r.latest_status },
    { key: 'first_drafted_at', header: 'First Draft', render: (r: any) => r.first_drafted_at ? new Date(r.first_drafted_at).toLocaleDateString() : '—' },
    { key: 'latest_locked_at', header: 'Last Locked', render: (r: any) => r.latest_locked_at ? new Date(r.latest_locked_at).toLocaleDateString() : '—' },
  ];

  const signoffCols: Column<any>[] = [
    { key: 'signoff_status', header: 'Signoff Status', render: (r: any) => r.signoff_status },
    { key: 'review_count', header: 'Reviews', render: (r: any) => String(r.review_count) },
    { key: 'follow_ups_required', header: 'Follow-ups', render: (r: any) => String(r.follow_ups_required) },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'doc_title', header: 'Doc', render: (r: any) => r.doc_title },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'decisions_changed_md', header: 'Decisions Changed', render: (r: any) => r.decisions_changed_md ?? '—' },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => r.drafted_at ? new Date(r.drafted_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder > Strategy Doc Versioning</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Strategy doc & version & delta from last & decisions changed & stakeholder review & locked-in.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Strategy Docs & Versions</h2>
        <DataTable
          rows={docs}
          columns={docCols}
          emptyMessage="No strategy docs yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Stakeholder Reviews</h2>
        <DataTable
          rows={reviews}
          columns={reviewCols}
          emptyMessage="No stakeholder reviews logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Latest Locked Docs</h2>
        <DataTable
          rows={locked}
          columns={lockedCols}
          emptyMessage="No locked docs yet."
          rowKey={(r: any, i: number) => String(r.doc_title ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pending Reviews => Founder Focus</h2>
        <DataTable
          rows={pending}
          columns={pendingCols}
          emptyMessage="No pending reviews — all caught up."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Version History per Doc</h2>
        <DataTable
          rows={history}
          columns={historyCols}
          emptyMessage="No version history."
          rowKey={(r: any, i: number) => String(r.doc_title ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Signoff Status Summary</h2>
        <DataTable
          rows={signoff}
          columns={signoffCols}
          emptyMessage="No signoff data."
          rowKey={(r: any, i: number) => String(r.signoff_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Changed Decisions Across Versions</h2>
        <DataTable
          rows={decisions}
          columns={decisionCols}
          emptyMessage="No decision changes recorded."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>
    </main>
  );
}
