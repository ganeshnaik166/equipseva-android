import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type AttendanceRow = { quarter_label: string; scheduled_count: number; attended_count: number; no_show_count: number; attendance_pct: number | null; avg_rating: number | null };
type TopAdvisorRow = { advisor_name: string; advisor_firm: string; sessions_attended: number; avg_rating: number | null; total_duration_minutes: number };
type PipelineRow = { status: string; item_count: number; total_impact_rupees: number; p0_count: number; p1_count: number };
type OverdueRow = { action_title: string; action_owner: string; priority: string; status: string; due_date: string | null; days_overdue: number; impact_estimate_rupees: number | null };
type ExpertiseRow = { advisor_expertise: string; advisor_count: number; sessions_attended: number; avg_rating: number | null; follow_ups_open: number };
type UpcomingRow = { advisor_name: string; advisor_firm: string; advisor_expertise: string; scheduled_at: string; days_until: number; meeting_format: string };
type OwnerImpactRow = { action_owner: string; total_items: number; done_items: number; open_items: number; total_impact_rupees: number; realized_impact_rupees: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [att, top, pipe, overdue, exp, upc, owner] = await Promise.all([
    sb.rpc('r3081_quarterly_attendance_summary'),
    sb.rpc('r3081_top_rated_advisors'),
    sb.rpc('r3081_action_pipeline_by_status'),
    sb.rpc('r3081_overdue_action_items'),
    sb.rpc('r3081_expertise_coverage'),
    sb.rpc('r3081_upcoming_sessions'),
    sb.rpc('r3081_impact_by_owner'),
  ]);

  const attRows = (att.data ?? []) as AttendanceRow[];
  const topRows = (top.data ?? []) as TopAdvisorRow[];
  const pipeRows = (pipe.data ?? []) as PipelineRow[];
  const overdueRows = (overdue.data ?? []) as OverdueRow[];
  const expRows = (exp.data ?? []) as ExpertiseRow[];
  const upcRows = (upc.data ?? []) as UpcomingRow[];
  const ownerRows = (owner.data ?? []) as OwnerImpactRow[];

  const attCols: Column<AttendanceRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Scheduled', accessor: (r) => r.scheduled_count },
    { header: 'Attended', accessor: (r) => r.attended_count },
    { header: 'No-show', accessor: (r) => r.no_show_count },
    { header: 'Attend %', accessor: (r) => r.attendance_pct ?? '—' },
    { header: 'Avg rating', accessor: (r) => r.avg_rating ?? '—' },
  ];

  const topCols: Column<TopAdvisorRow>[] = [
    { header: 'Advisor', accessor: (r) => r.advisor_name },
    { header: 'Firm', accessor: (r) => r.advisor_firm },
    { header: 'Sessions', accessor: (r) => r.sessions_attended },
    { header: 'Avg rating', accessor: (r) => r.avg_rating ?? '—' },
    { header: 'Total minutes', accessor: (r) => r.total_duration_minutes },
  ];

  const pipeCols: Column<PipelineRow>[] = [
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Items', accessor: (r) => r.item_count },
    { header: 'Impact (₹)', accessor: (r) => r.total_impact_rupees.toLocaleString('en-IN') },
    { header: 'P0', accessor: (r) => r.p0_count },
    { header: 'P1', accessor: (r) => r.p1_count },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { header: 'Action', accessor: (r) => r.action_title },
    { header: 'Owner', accessor: (r) => r.action_owner },
    { header: 'Priority', accessor: (r) => r.priority },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Due', accessor: (r) => r.due_date ?? '—' },
    { header: 'Days overdue', accessor: (r) => r.days_overdue },
    { header: 'Impact (₹)', accessor: (r) => r.impact_estimate_rupees?.toLocaleString('en-IN') ?? '—' },
  ];

  const expCols: Column<ExpertiseRow>[] = [
    { header: 'Expertise', accessor: (r) => r.advisor_expertise },
    { header: 'Advisors', accessor: (r) => r.advisor_count },
    { header: 'Sessions', accessor: (r) => r.sessions_attended },
    { header: 'Avg rating', accessor: (r) => r.avg_rating ?? '—' },
    { header: 'Follow-ups open', accessor: (r) => r.follow_ups_open },
  ];

  const upcCols: Column<UpcomingRow>[] = [
    { header: 'Advisor', accessor: (r) => r.advisor_name },
    { header: 'Firm', accessor: (r) => r.advisor_firm },
    { header: 'Expertise', accessor: (r) => r.advisor_expertise },
    { header: 'When', accessor: (r) => new Date(r.scheduled_at).toLocaleString('en-IN') },
    { header: 'Days until', accessor: (r) => r.days_until },
    { header: 'Format', accessor: (r) => r.meeting_format },
  ];

  const ownerCols: Column<OwnerImpactRow>[] = [
    { header: 'Owner', accessor: (r) => r.action_owner },
    { header: 'Total', accessor: (r) => r.total_items },
    { header: 'Done', accessor: (r) => r.done_items },
    { header: 'Open', accessor: (r) => r.open_items },
    { header: 'Total impact (₹)', accessor: (r) => r.total_impact_rupees.toLocaleString('en-IN') },
    { header: 'Realized (₹)', accessor: (r) => r.realized_impact_rupees.toLocaleString('en-IN') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Quarterly Strategic Engineer-Founder External Board-of-Advisors Office-Hour Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Round r3081 — founder-only view tracking advisor office-hour sessions & downstream action items.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Quarterly attendance summary</h2>
        <DataTable rows={attRows} columns={attCols} emptyMessage="No quarters yet" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top-rated advisors</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No rated advisors" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Action pipeline by status</h2>
        <DataTable rows={pipeRows} columns={pipeCols} emptyMessage="No action items" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Overdue action items</h2>
        <DataTable rows={overdueRows} columns={overdueCols} emptyMessage="No overdue items — all green" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Expertise coverage</h2>
        <DataTable rows={expRows} columns={expCols} emptyMessage="No expertise tracked" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Upcoming sessions (next 90 days)</h2>
        <DataTable rows={upcRows} columns={upcCols} emptyMessage="No upcoming sessions" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Impact by owner</h2>
        <DataTable rows={ownerRows} columns={ownerCols} emptyMessage="No owners assigned" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </main>
  );
}
