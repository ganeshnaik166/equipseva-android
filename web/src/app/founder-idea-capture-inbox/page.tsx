import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type InboxRow = {
  id: string;
  idea_title: string;
  idea_body_md: string | null;
  source: string;
  captured_at: string;
  urgency: string;
  status: string;
  founder_decision_at: string | null;
};

type PromotionRow = {
  id: string;
  idea_id: string;
  idea_title: string;
  promoted_to: string;
  promoted_at: string;
  by_email: string | null;
  outcome: string | null;
};

type SummaryRow = {
  total_captured: number;
  inbox_count: number;
  triaged_count: number;
  promoted_count: number;
  parked_count: number;
  killed_count: number;
  kill_rate_pct: number;
  promote_rate_pct: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [inboxRes, promotionsRes, recentRes, summaryRes] = await Promise.all([
    sb.rpc('list_inbox_r1818'),
    sb.rpc('list_promotions_r1818'),
    sb.rpc('recent_promotions_r1818'),
    sb.rpc('kill_rate_summary_r1818'),
  ]);

  const inbox: InboxRow[] = (inboxRes.data as InboxRow[] | null) ?? [];
  const promotions: PromotionRow[] = (promotionsRes.data as PromotionRow[] | null) ?? [];
  const recent: PromotionRow[] = (recentRes.data as PromotionRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];

  const inboxCols: Column<InboxRow>[] = [
    { key: 'idea_title', header: 'Idea', render: (r: any) => r.idea_title },
    { key: 'source', header: 'Source', render: (r: any) => r.source },
    { key: 'urgency', header: 'Urgency', render: (r: any) => r.urgency },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
    { key: 'founder_decision_at', header: 'Decided', render: (r: any) => r.founder_decision_at ? new Date(r.founder_decision_at).toLocaleDateString() : '—' },
    { key: 'idea_body_md', header: 'Body', render: (r: any) => r.idea_body_md ? String(r.idea_body_md).slice(0, 80) : '—' },
  ];

  const promotionCols: Column<PromotionRow>[] = [
    { key: 'idea_title', header: 'Idea', render: (r: any) => r.idea_title },
    { key: 'promoted_to', header: 'Promoted to', render: (r: any) => r.promoted_to },
    { key: 'promoted_at', header: 'Promoted at', render: (r: any) => r.promoted_at ? new Date(r.promoted_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'total_captured', header: 'Total captured', render: (r: any) => r.total_captured },
    { key: 'inbox_count', header: 'Inbox', render: (r: any) => r.inbox_count },
    { key: 'triaged_count', header: 'Triaged', render: (r: any) => r.triaged_count },
    { key: 'promoted_count', header: 'Promoted', render: (r: any) => r.promoted_count },
    { key: 'parked_count', header: 'Parked', render: (r: any) => r.parked_count },
    { key: 'killed_count', header: 'Killed', render: (r: any) => r.killed_count },
    { key: 'kill_rate_pct', header: 'Kill rate %', render: (r: any) => r.kill_rate_pct },
    { key: 'promote_rate_pct', header: 'Promote rate %', render: (r: any) => r.promote_rate_pct },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Idea Capture Inbox</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Catch-all founder inbox for fleeting ideas. Triage to roadmap or kill. Track promotion outcomes and kill rate.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Kill / promote summary</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Healthy founder hygiene: kill rate &gt; promote rate. Ideas that sit in inbox &gt; 30 days should be parked or killed.
        </p>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Inbox ({inbox.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          All captured ideas, newest first. Statuses: inbox → triaged → promoted / parked / killed.
        </p>
        <DataTable
          rows={inbox}
          columns={inboxCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent promotions ({recent.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Promotions in the last 30 days.
        </p>
        <DataTable
          rows={recent}
          columns={promotionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All promotions ({promotions.length})</h2>
        <DataTable
          rows={promotions}
          columns={promotionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
