import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FeedbackRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  vendor_name: string | null;
  equipment_category: string | null;
  feedback_type: string | null;
  score: number | null;
  feedback_md: string | null;
  recorded_at: string | null;
  created_at: string | null;
};

type SummaryRow = {
  vendor_name: string | null;
  total_responses: number | null;
  avg_quality: number | null;
  avg_support: number | null;
  avg_manuals: number | null;
  recommended: boolean | null;
  recomputed_at: string | null;
};

type TopRow = {
  vendor_name: string | null;
  total_responses: number | null;
  avg_quality: number | null;
  avg_support: number | null;
  avg_manuals: number | null;
  recommended: boolean | null;
};

type DropRow = TopRow;

type RecentRow = {
  id: string;
  engineer_email: string | null;
  vendor_name: string | null;
  equipment_category: string | null;
  feedback_type: string | null;
  score: number | null;
  feedback_md: string | null;
  recorded_at: string | null;
};

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString();
  } catch {
    return s;
  }
}

function truncate(s: string | null | undefined, n = 80) {
  if (!s) return '-';
  return s.length > n ? s.slice(0, n) + '...' : s;
}

function fmtNum(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return String(n);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [feedbackRes, summaryRes, topRes, dropRes, recentRes] = await Promise.all([
    sb.rpc('list_feedback_r1868'),
    sb.rpc('list_summary_r1868'),
    sb.rpc('top_vendors_r1868'),
    sb.rpc('vendors_to_drop_r1868'),
    sb.rpc('recent_feedback_r1868'),
  ]);

  const feedback: FeedbackRow[] = (feedbackRes.data as FeedbackRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const drops: DropRow[] = (dropRes.data as DropRow[] | null) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[] | null) ?? [];

  const feedbackCols: Column<FeedbackRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '-' },
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? '-' },
    { key: 'category', header: 'Category', render: (r: any) => r.equipment_category ?? '-' },
    { key: 'type', header: 'Type', render: (r: any) => r.feedback_type ?? '-' },
    { key: 'score', header: 'Score', render: (r: any) => fmtNum(r.score) },
    { key: 'note', header: 'Note', render: (r: any) => truncate(r.feedback_md) },
    { key: 'recorded', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? '-' },
    { key: 'total', header: 'Responses', render: (r: any) => fmtNum(r.total_responses) },
    { key: 'quality', header: 'Avg Quality', render: (r: any) => fmtNum(r.avg_quality) },
    { key: 'support', header: 'Avg Support', render: (r: any) => fmtNum(r.avg_support) },
    { key: 'manuals', header: 'Avg Manuals', render: (r: any) => fmtNum(r.avg_manuals) },
    { key: 'rec', header: 'Recommended', render: (r: any) => (r.recommended ? 'yes' : 'no') },
    { key: 'recomp', header: 'Recomputed', render: (r: any) => fmtDate(r.recomputed_at) },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? '-' },
    { key: 'total', header: 'Responses', render: (r: any) => fmtNum(r.total_responses) },
    { key: 'quality', header: 'Avg Quality', render: (r: any) => fmtNum(r.avg_quality) },
    { key: 'support', header: 'Avg Support', render: (r: any) => fmtNum(r.avg_support) },
    { key: 'manuals', header: 'Avg Manuals', render: (r: any) => fmtNum(r.avg_manuals) },
  ];

  const dropCols: Column<DropRow>[] = [
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? '-' },
    { key: 'total', header: 'Responses', render: (r: any) => fmtNum(r.total_responses) },
    { key: 'quality', header: 'Avg Quality', render: (r: any) => fmtNum(r.avg_quality) },
    { key: 'support', header: 'Avg Support', render: (r: any) => fmtNum(r.avg_support) },
    { key: 'manuals', header: 'Avg Manuals', render: (r: any) => fmtNum(r.avg_manuals) },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? '-' },
    { key: 'category', header: 'Category', render: (r: any) => r.equipment_category ?? '-' },
    { key: 'type', header: 'Type', render: (r: any) => r.feedback_type ?? '-' },
    { key: 'score', header: 'Score', render: (r: any) => fmtNum(r.score) },
    { key: 'note', header: 'Note', render: (r: any) => truncate(r.feedback_md) },
    { key: 'recorded', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 px-4 py-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Equipment Vendor Feedback</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Field engineer feedback on equipment vendors — quality, support, manuals, pricing, delivery & training.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Vendor summary (rolling)</h2>
        <p className="text-xs text-[var(--color-muted)]">Recommended = average score &gt;= 3.5 across all feedback types.</p>
        <DataTable<SummaryRow>
          rows={summary}
          columns={summaryCols}
          rowKey={(r, i) => String(r.vendor_name ?? i)}
          emptyMessage="No vendor summary yet. Run refresh."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top vendors (recommended)</h2>
        <DataTable<TopRow>
          rows={top}
          columns={topCols}
          rowKey={(r, i) => String(r.vendor_name ?? i)}
          emptyMessage="No top vendors yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Vendors to drop (&lt; 3.5 avg, &gt;= 3 responses)</h2>
        <DataTable<DropRow>
          rows={drops}
          columns={dropCols}
          rowKey={(r, i) => String(r.vendor_name ?? i)}
          emptyMessage="No vendors flagged for drop."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent feedback (last 30 days)</h2>
        <DataTable<RecentRow>
          rows={recent}
          columns={recentCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No recent feedback."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All feedback (latest 200)</h2>
        <DataTable<FeedbackRow>
          rows={feedback}
          columns={feedbackCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No feedback logged yet."
        />
      </section>
    </main>
  );
}
