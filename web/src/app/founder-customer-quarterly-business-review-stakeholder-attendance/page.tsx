import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerQbrStakeholderAttendancePage() {
  const supabase = await getSupabaseServerClient();

  const [
    attendanceRes,
    commitmentsRes,
    highInfluenceRes,
    engagementRes,
    completionRes,
    topQbrsRes,
    roleSummaryRes,
  ] = await Promise.all([
    supabase.rpc('list_attendance_r2532'),
    supabase.rpc('list_followup_commitments_r2532'),
    supabase.rpc('high_influence_attendees_r2532'),
    supabase.rpc('engagement_distribution_r2532'),
    supabase.rpc('commitment_completion_rate_r2532'),
    supabase.rpc('top_attended_qbrs_r2532'),
    supabase.rpc('role_attendance_summary_r2532'),
  ]);

  const attendance = (attendanceRes.data ?? []) as any[];
  const commitments = (commitmentsRes.data ?? []) as any[];
  const highInfluence = (highInfluenceRes.data ?? []) as any[];
  const engagement = (engagementRes.data ?? []) as any[];
  const completion = (completionRes.data ?? []) as any[];
  const topQbrs = (topQbrsRes.data ?? []) as any[];
  const roleSummary = (roleSummaryRes.data ?? []) as any[];

  const fmtDate = (s: string | null) => (s ? new Date(s).toLocaleDateString() : '—');
  const fmtDateTime = (s: string | null) => (s ? new Date(s).toLocaleString() : '—');

  const attendanceColumns: Column<any>[] = [
    { key: 'qbr_quarter', header: 'Quarter', render: (r: any) => r.qbr_quarter },
    { key: 'held_on', header: 'Held On', render: (r: any) => fmtDate(r.held_on) },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'stakeholder_name', header: 'Stakeholder', render: (r: any) => r.stakeholder_name },
    { key: 'stakeholder_role', header: 'Role', render: (r: any) => r.stakeholder_role },
    { key: 'attended', header: 'Attended', render: (r: any) => (r.attended ? 'Yes' : 'No') },
    { key: 'influence_score', header: 'Influence', render: (r: any) => `${r.influence_score}/100` },
    { key: 'engagement_level', header: 'Engagement', render: (r: any) => r.engagement_level },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const commitmentColumns: Column<any>[] = [
    { key: 'qbr_quarter', header: 'Quarter', render: (r: any) => r.qbr_quarter },
    { key: 'stakeholder_name', header: 'Stakeholder', render: (r: any) => r.stakeholder_name },
    { key: 'commitment_text', header: 'Commitment', render: (r: any) => r.commitment_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDateTime(r.closed_at) },
  ];

  const highInfluenceColumns: Column<any>[] = [
    { key: 'qbr_quarter', header: 'Quarter', render: (r: any) => r.qbr_quarter },
    { key: 'held_on', header: 'Held On', render: (r: any) => fmtDate(r.held_on) },
    { key: 'stakeholder_name', header: 'Stakeholder', render: (r: any) => r.stakeholder_name },
    { key: 'stakeholder_role', header: 'Role', render: (r: any) => r.stakeholder_role },
    { key: 'influence_score', header: 'Influence', render: (r: any) => `${r.influence_score}/100` },
    { key: 'attended', header: 'Attended', render: (r: any) => (r.attended ? 'Yes' : 'No') },
    { key: 'engagement_level', header: 'Engagement', render: (r: any) => r.engagement_level },
  ];

  const engagementColumns: Column<any>[] = [
    { key: 'engagement_level', header: 'Engagement Level', render: (r: any) => r.engagement_level },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => String(r.attendee_count) },
    { key: 'avg_influence', header: 'Avg Influence', render: (r: any) => Number(r.avg_influence).toFixed(1) },
    { key: 'attended_count', header: 'Showed Up', render: (r: any) => String(r.attended_count) },
  ];

  const completionColumns: Column<any>[] = [
    { key: 'total_commitments', header: 'Total', render: (r: any) => String(r.total_commitments) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count) },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => String(r.in_progress_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => String(r.dropped_count) },
    { key: 'positive_outcome_count', header: 'Positive', render: (r: any) => String(r.positive_outcome_count) },
    { key: 'negative_outcome_count', header: 'Negative', render: (r: any) => String(r.negative_outcome_count) },
    { key: 'completion_rate_pct', header: 'Completion %', render: (r: any) => `${Number(r.completion_rate_pct).toFixed(1)}%` },
  ];

  const topQbrsColumns: Column<any>[] = [
    { key: 'qbr_quarter', header: 'Quarter', render: (r: any) => r.qbr_quarter },
    { key: 'held_on', header: 'Held On', render: (r: any) => fmtDate(r.held_on) },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'invited_count', header: 'Invited', render: (r: any) => String(r.invited_count) },
    { key: 'attended_count', header: 'Attended', render: (r: any) => String(r.attended_count) },
    { key: 'attendance_rate_pct', header: 'Attendance %', render: (r: any) => `${Number(r.attendance_rate_pct).toFixed(1)}%` },
    { key: 'avg_influence', header: 'Avg Influence', render: (r: any) => Number(r.avg_influence).toFixed(1) },
  ];

  const roleSummaryColumns: Column<any>[] = [
    { key: 'stakeholder_role', header: 'Role', render: (r: any) => r.stakeholder_role },
    { key: 'invited_count', header: 'Invited', render: (r: any) => String(r.invited_count) },
    { key: 'attended_count', header: 'Attended', render: (r: any) => String(r.attended_count) },
    { key: 'attendance_rate_pct', header: 'Attendance %', render: (r: any) => `${Number(r.attendance_rate_pct).toFixed(1)}%` },
    { key: 'avg_influence', header: 'Avg Influence', render: (r: any) => Number(r.avg_influence).toFixed(1) },
    { key: 'highly_engaged_count', header: 'Highly Engaged', render: (r: any) => String(r.highly_engaged_count) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer QBR — Stakeholder Attendance</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track who attended each quarterly business review, their influence & engagement, and follow-up commitment delivery.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Commitment Completion Snapshot</h2>
        <DataTable
          rows={completion}
          columns={completionColumns}
          emptyMessage="No commitments tracked yet."
          rowKey={(_r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engagement Distribution</h2>
        <DataTable
          rows={engagement}
          columns={engagementColumns}
          emptyMessage="No engagement data."
          rowKey={(r: any, i: number) => String(r.engagement_level ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top QBRs by Attendance</h2>
        <DataTable
          rows={topQbrs}
          columns={topQbrsColumns}
          emptyMessage="No QBRs logged."
          rowKey={(r: any, i: number) => String(`${r.qbr_quarter}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Role Attendance Summary</h2>
        <DataTable
          rows={roleSummary}
          columns={roleSummaryColumns}
          emptyMessage="No role data."
          rowKey={(r: any, i: number) => String(r.stakeholder_role ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">High-Influence Attendees (&gt;=70)</h2>
        <DataTable
          rows={highInfluence}
          columns={highInfluenceColumns}
          emptyMessage="No high-influence stakeholders tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Attendance Records</h2>
        <DataTable
          rows={attendance}
          columns={attendanceColumns}
          emptyMessage="No attendance records."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-Up Commitments</h2>
        <DataTable
          rows={commitments}
          columns={commitmentColumns}
          emptyMessage="No commitments tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
