import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s ?? '—'; }
}

function fmtMonth(s: string | null | undefined): string {
  if (!s) return '—';
  try {
    const d = new Date(s);
    return d.toLocaleString('en-IN', { month: 'long', year: 'numeric' });
  } catch { return s ?? '—'; }
}

export default async function FounderAllHandsPrepPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let meetings: any[] = [];
  let questions: any[] = [];
  let categories: any[] = [];
  let ships: any[] = [];

  try {
    const r = await sb.rpc('founder_all_hands_kpis');
    kpis = (r.data as any) ?? {};
  } catch {
    kpis = {};
  }
  try {
    const r = await sb.rpc('founder_all_hands_list_meetings');
    meetings = (r.data as any[]) ?? [];
  } catch {
    meetings = [];
  }
  try {
    const r = await sb.rpc('founder_all_hands_recent_questions');
    questions = (r.data as any[]) ?? [];
  } catch {
    questions = [];
  }
  try {
    const r = await sb.rpc('founder_all_hands_category_breakdown');
    categories = (r.data as any[]) ?? [];
  } catch {
    categories = [];
  }
  try {
    const r = await sb.rpc('founder_all_hands_ships_this_month');
    ships = (r.data as any[]) ?? [];
  } catch {
    ships = [];
  }

  const cards: Kpi[] = [
    { label: 'Total Meetings', value: (kpis.total_meetings ?? 0) as number },
    { label: 'Completed', value: (kpis.completed_meetings ?? 0) as number },
    { label: 'Planned', value: (kpis.planned_meetings ?? 0) as number },
    { label: 'In Progress', value: (kpis.in_progress_meetings ?? 0) as number },
    { label: 'This Month', value: (kpis.this_month_meetings ?? 0) as number },
    { label: 'Prev Month', value: (kpis.prev_month_meetings ?? 0) as number },
    { label: 'Total Attendees', value: (kpis.total_attendees ?? 0) as number },
    { label: 'Avg Attendees', value: (kpis.avg_attendees_per_meeting ?? 0) as number },
    { label: 'Total Q&A', value: (kpis.total_questions ?? 0) as number },
    { label: 'Answered Q', value: (kpis.answered_q ?? 0) as number },
    { label: 'Open Q', value: (kpis.open_q ?? 0) as number },
    { label: 'Q (30d)', value: (kpis.q_30d ?? 0) as number },
    { label: 'Categories', value: (kpis.distinct_categories ?? 0) as number },
    { label: 'Ships (30d)', value: (kpis.ships_30d ?? 0) as number },
    { label: 'Next Meeting', value: fmtDate(kpis.next_meeting_at) },
    { label: 'Last Meeting', value: fmtDate(kpis.last_meeting_at) },
  ];

  const meetingCols: Column<any>[] = [
    { key: 'meeting_month', header: 'Month', render: (r: any) => fmtMonth(r.meeting_month) },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'scheduled_at', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_at) },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => r.attendee_count ?? 0 },
    { key: 'question_count', header: 'Questions', render: (r: any) => r.question_count ?? 0 },
    { key: 'has_slides', header: 'Slides', render: (r: any) => (r.has_slides ? 'yes' : 'no') },
    { key: 'has_recap', header: 'Recap', render: (r: any) => (r.has_recap ? 'yes' : 'no') },
  ];

  const questionCols: Column<any>[] = [
    { key: 'created_at', header: 'Asked', render: (r: any) => fmtDate(r.created_at) },
    { key: 'meeting_title', header: 'Meeting', render: (r: any) => r.meeting_title ?? '—' },
    { key: 'asker_email', header: 'Asker', render: (r: any) => r.asker_email ?? '—' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'question_text', header: 'Question', render: (r: any) => r.question_text ?? '—' },
    { key: 'upvotes', header: 'Upvotes', render: (r: any) => r.upvotes ?? 0 },
    { key: 'is_answered', header: 'Answered', render: (r: any) => (r.is_answered ? 'yes' : 'no') },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'total_q', header: 'Total Q', render: (r: any) => r.total_q ?? 0 },
    { key: 'answered_q', header: 'Answered', render: (r: any) => r.answered_q ?? 0 },
    { key: 'open_q', header: 'Open', render: (r: any) => r.open_q ?? 0 },
    { key: 'avg_upvotes', header: 'Avg Upvotes', render: (r: any) => r.avg_upvotes ?? 0 },
  ];

  const shipCols: Column<any>[] = [
    { key: 'op_name', header: 'Operation', render: (r: any) => r.op_name ?? '—' },
    { key: 'ship_count', header: 'Ships', render: (r: any) => r.ship_count ?? 0 },
    { key: 'last_ship_at', header: 'Last Ship', render: (r: any) => fmtDate(r.last_ship_at) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder Monthly All-Hands Prep</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Monthly all-hands meeting agenda, slides, Q&A log and attendance. Founder reviews what shipped and asks team for input.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 12 }}>
        {cards.map((k, i) => (
          <div key={i} style={{ padding: 12, border: '1px solid #e5e5e5', borderRadius: 8, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Meetings (last 50)</h2>
        <DataTable<any> rows={meetings} columns={meetingCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Questions</h2>
        <DataTable<any> rows={questions} columns={questionCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Q&A Category Breakdown</h2>
        <DataTable<any> rows={categories} columns={categoryCols} rowKey={(r: any) => r.category} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Ships This Month (for review)</h2>
        <DataTable<any> rows={ships} columns={shipCols} rowKey={(r: any) => r.op_name} />
      </section>
    </div>
  );
}
