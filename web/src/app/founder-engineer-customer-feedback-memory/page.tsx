import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FeedbackRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  hospital_id: string | null;
  hospital_name: string | null;
  feedback_text_md: string | null;
  feedback_category: string | null;
  sentiment: string | null;
  captured_at: string | null;
  status: string | null;
};

type NegativeRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  feedback_category: string | null;
  sentiment: string | null;
  feedback_text_md: string | null;
  captured_at: string | null;
  status: string | null;
};

type ActionRow = {
  id: string;
  feedback_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [feedbackRes, negativeRes, actionsRes] = await Promise.all([
    sb.rpc('list_feedback_r1988'),
    sb.rpc('negative_feedback_r1988'),
    sb.rpc('recent_actions_r1988'),
  ]);

  const feedback: FeedbackRow[] = (feedbackRes.data as FeedbackRow[]) ?? [];
  const negative: NegativeRow[] = (negativeRes.data as NegativeRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const feedbackCols: Column<FeedbackRow>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '' },
    { key: 'feedback_category', header: 'Category', render: (r: any) => r.feedback_category ?? '' },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'feedback_text_md', header: 'Feedback', render: (r: any) => (r.feedback_text_md ?? '').slice(0, 140) },
  ];

  const negativeCols: Column<NegativeRow>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'feedback_category', header: 'Category', render: (r: any) => r.feedback_category ?? '' },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'feedback_text_md', header: 'Feedback', render: (r: any) => (r.feedback_text_md ?? '').slice(0, 200) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'feedback_id', header: 'Feedback', render: (r: any) => r.feedback_id ?? '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ?? '').slice(0, 140) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Customer-Feedback Memory</h1>
        <p className="text-sm text-gray-600">
          Persistent record of customer feedback per engineer and follow-up actions taken.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All Feedback (latest 200)</h2>
        <DataTable rows={feedback} columns={feedbackCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Negative or Very Negative Feedback</h2>
        <p className="text-xs text-gray-500">Items flagged for coaching or escalation review.</p>
        <DataTable rows={negative} columns={negativeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
