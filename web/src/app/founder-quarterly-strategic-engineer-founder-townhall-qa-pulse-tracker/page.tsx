import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Session = { id: string; quarter: string; fiscal_year: number; held_on: string; attendee_count: number; questions_submitted: number; questions_answered: number; avg_satisfaction: number; nps_score: number; status: string };
type Category = { category: string; total_questions: number; total_upvotes: number; answered_count: number; avg_upvotes: number };
type TopQ = { id: string; engineer_name: string; category: string; question: string; upvotes: number; answered: boolean; priority: string };
type Unans = { id: string; engineer_name: string; category: string; question: string; upvotes: number; priority: string };
type Follow = { id: string; engineer_name: string; category: string; question: string; founder_response: string | null; priority: string };
type Nps = { quarter: string; fiscal_year: number; attendee_count: number; avg_satisfaction: number; nps_score: number };
type Prio = { priority: string; total: number; answered: number; pct_answered: number };
type Eng = { engineer_name: string; questions_asked: number; total_upvotes: number; answered_count: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [s, c, t, u, f, n, p, e] = await Promise.all([
    sb.rpc('townhall_r2981_sessions_overview'),
    sb.rpc('townhall_r2981_category_breakdown'),
    sb.rpc('townhall_r2981_top_upvoted'),
    sb.rpc('townhall_r2981_unanswered_queue'),
    sb.rpc('townhall_r2981_follow_ups'),
    sb.rpc('townhall_r2981_nps_trend'),
    sb.rpc('townhall_r2981_priority_dist'),
    sb.rpc('townhall_r2981_engineer_participation'),
  ]);

  const sessions = (s.data ?? []) as Session[];
  const cats = (c.data ?? []) as Category[];
  const top = (t.data ?? []) as TopQ[];
  const unans = (u.data ?? []) as Unans[];
  const follows = (f.data ?? []) as Follow[];
  const nps = (n.data ?? []) as Nps[];
  const prio = (p.data ?? []) as Prio[];
  const engs = (e.data ?? []) as Eng[];

  const sessionsCols: Column<Session>[] = [
    { header: 'Quarter', accessor: (r) => `${r.quarter.toUpperCase()} FY${r.fiscal_year}` },
    { header: 'Held On', accessor: (r) => new Date(r.held_on).toLocaleDateString() },
    { header: 'Attendees', accessor: (r) => r.attendee_count },
    { header: 'Q Submitted', accessor: (r) => r.questions_submitted },
    { header: 'Q Answered', accessor: (r) => r.questions_answered },
    { header: 'CSAT', accessor: (r) => r.avg_satisfaction.toFixed(2) },
    { header: 'NPS', accessor: (r) => r.nps_score },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const catsCols: Column<Category>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Total Questions', accessor: (r) => r.total_questions },
    { header: 'Total Upvotes', accessor: (r) => r.total_upvotes },
    { header: 'Answered', accessor: (r) => r.answered_count },
    { header: 'Avg Upvotes', accessor: (r) => r.avg_upvotes },
  ];

  const topCols: Column<TopQ>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Question', accessor: (r) => r.question },
    { header: 'Upvotes', accessor: (r) => r.upvotes },
    { header: 'Answered', accessor: (r) => (r.answered ? 'Yes' : 'No') },
    { header: 'Priority', accessor: (r) => r.priority },
  ];

  const unansCols: Column<Unans>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Question', accessor: (r) => r.question },
    { header: 'Upvotes', accessor: (r) => r.upvotes },
    { header: 'Priority', accessor: (r) => r.priority },
  ];

  const followCols: Column<Follow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Question', accessor: (r) => r.question },
    { header: 'Response', accessor: (r) => r.founder_response ?? '—' },
    { header: 'Priority', accessor: (r) => r.priority },
  ];

  const npsCols: Column<Nps>[] = [
    { header: 'Quarter', accessor: (r) => `${r.quarter.toUpperCase()} FY${r.fiscal_year}` },
    { header: 'Attendees', accessor: (r) => r.attendee_count },
    { header: 'CSAT', accessor: (r) => r.avg_satisfaction.toFixed(2) },
    { header: 'NPS', accessor: (r) => r.nps_score },
  ];

  const prioCols: Column<Prio>[] = [
    { header: 'Priority', accessor: (r) => r.priority },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Answered', accessor: (r) => r.answered },
    { header: '% Answered', accessor: (r) => `${r.pct_answered}%` },
  ];

  const engCols: Column<Eng>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Questions Asked', accessor: (r) => r.questions_asked },
    { header: 'Total Upvotes', accessor: (r) => r.total_upvotes },
    { header: 'Answered', accessor: (r) => r.answered_count },
  ];

  return (
    <div style={{ padding: 24, display: 'grid', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 28, fontWeight: 700 }}>Quarterly Strategic Engineer-Founder Townhall Q&amp;A Pulse Tracker</h1>
        <p style={{ color: '#555', marginTop: 8 }}>Round r2981 — measure engineer voice, prioritize follow-ups, watch CSAT &amp; NPS trend &gt;= target across quarters.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Sessions Overview</h2>
        <DataTable rows={sessions} columns={sessionsCols} emptyMessage="No sessions" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Category Breakdown</h2>
        <DataTable rows={cats} columns={catsCols} emptyMessage="No categories" rowKey={(r, i) => String(r.category ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Upvoted Questions</h2>
        <DataTable rows={top} columns={topCols} emptyMessage="No questions" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Unanswered Queue</h2>
        <DataTable rows={unans} columns={unansCols} emptyMessage="All caught up" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Follow-ups Required</h2>
        <DataTable rows={follows} columns={followCols} emptyMessage="No follow-ups" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>CSAT & NPS Trend</h2>
        <DataTable rows={nps} columns={npsCols} emptyMessage="No trend data" rowKey={(r, i) => String(`${r.fiscal_year}-${r.quarter}-${i}`)} />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Priority Distribution</h2>
        <DataTable rows={prio} columns={prioCols} emptyMessage="No priority data" rowKey={(r, i) => String(r.priority ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Engineer Participation</h2>
        <DataTable rows={engs} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>
    </div>
  );
}
