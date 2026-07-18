import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerLoyaltyEventAttendancePage() {
  const supabase = await getSupabaseServerClient();

  const [
    attendanceRes,
    followupsRes,
    topArrRes,
    eventKindRes,
    bondDistRes,
    monthlyRes,
    noShowRes,
  ] = await Promise.all([
    supabase.rpc('list_attendance_r2560'),
    supabase.rpc('list_followups_r2560'),
    supabase.rpc('top_arr_uplift_customers_r2560'),
    supabase.rpc('event_kind_breakdown_r2560'),
    supabase.rpc('bond_strength_distribution_r2560'),
    supabase.rpc('monthly_attendance_trend_r2560'),
    supabase.rpc('no_show_focus_r2560'),
  ]);

  const attendance = (attendanceRes.data ?? []) as any[];
  const followups = (followupsRes.data ?? []) as any[];
  const topArr = (topArrRes.data ?? []) as any[];
  const eventKind = (eventKindRes.data ?? []) as any[];
  const bondDist = (bondDistRes.data ?? []) as any[];
  const monthly = (monthlyRes.data ?? []) as any[];
  const noShow = (noShowRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '-');
  const fmtMonth = (v: any) =>
    v ? new Date(v).toLocaleDateString(undefined, { year: 'numeric', month: 'short' }) : '-';
  const fmtRupees = (v: any) =>
    v == null ? '-' : '₹' + Number(v).toLocaleString('en-IN');
  const yesNo = (v: any) => (v ? 'Yes' : 'No');

  const attendanceCols: Column<any>[] = [
    { key: 'event_at', header: 'Event Date', render: (r: any) => fmtDate(r.event_at) },
    { key: 'event_label', header: 'Event', render: (r: any) => r.event_label },
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'invited', header: 'Invited', render: (r: any) => yesNo(r.invited) },
    { key: 'attended', header: 'Attended', render: (r: any) => yesNo(r.attended) },
    { key: 'engagement_score', header: 'Engagement', render: (r: any) => `${r.engagement_score}/100` },
    { key: 'bond_strength_kind', header: 'Bond', render: (r: any) => r.bond_strength_kind },
    { key: 'arr_uplift_estimate_rupees', header: 'ARR Uplift', render: (r: any) => fmtRupees(r.arr_uplift_estimate_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const followupCols: Column<any>[] = [
    { key: 'followup_at', header: 'Date', render: (r: any) => fmtDate(r.followup_at) },
    { key: 'event_label', header: 'Event', render: (r: any) => r.event_label ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'followup_kind', header: 'Kind', render: (r: any) => r.followup_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topArrCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'events_attended', header: 'Events Attended', render: (r: any) => r.events_attended },
    { key: 'total_arr_uplift_rupees', header: 'Total ARR Uplift', render: (r: any) => fmtRupees(r.total_arr_uplift_rupees) },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => r.avg_engagement ?? '-' },
    { key: 'best_bond', header: 'Best Bond', render: (r: any) => r.best_bond ?? '-' },
  ];

  const eventKindCols: Column<any>[] = [
    { key: 'event_kind', header: 'Event Kind', render: (r: any) => r.event_kind },
    { key: 'events_count', header: 'Events', render: (r: any) => r.events_count },
    { key: 'attended_count', header: 'Attended', render: (r: any) => r.attended_count },
    { key: 'total_arr_uplift_rupees', header: 'ARR Uplift', render: (r: any) => fmtRupees(r.total_arr_uplift_rupees) },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => r.avg_engagement ?? '-' },
  ];

  const bondCols: Column<any>[] = [
    { key: 'bond_strength_kind', header: 'Bond', render: (r: any) => r.bond_strength_kind },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => r.hospital_count },
    { key: 'total_arr_uplift_rupees', header: 'ARR Uplift', render: (r: any) => fmtRupees(r.total_arr_uplift_rupees) },
    { key: 'pct_of_attended', header: '% of Attended', render: (r: any) => `${r.pct_of_attended ?? 0}%` },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'events_count', header: 'Events', render: (r: any) => r.events_count },
    { key: 'attended_count', header: 'Attended', render: (r: any) => r.attended_count },
    { key: 'no_show_count', header: 'No-shows', render: (r: any) => r.no_show_count },
    { key: 'total_arr_uplift_rupees', header: 'ARR Uplift', render: (r: any) => fmtRupees(r.total_arr_uplift_rupees) },
  ];

  const noShowCols: Column<any>[] = [
    { key: 'event_at', header: 'Event Date', render: (r: any) => fmtDate(r.event_at) },
    { key: 'event_label', header: 'Event', render: (r: any) => r.event_label },
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'bond_strength_kind', header: 'Bond', render: (r: any) => r.bond_strength_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const rowKey = (r: any, i: number) => String(r.id ?? i);
  const rowKeyComposite = (r: any, i: number) => String(r.hospital_user_id ?? r.event_kind ?? r.bond_strength_kind ?? r.month_start ?? i);

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>
        Customer Loyalty & Event Attendance
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track customer event invitations, attendance, engagement & ARR uplift from bond-strengthening
        moments =&gt; identify champions, salvage no-shows.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Event Attendance Roster</h2>
        <DataTable
          rows={attendance}
          columns={attendanceCols}
          emptyMessage="No event attendance yet."
          rowKey={rowKey}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top ARR Uplift Customers</h2>
        <DataTable
          rows={topArr}
          columns={topArrCols}
          emptyMessage="No ARR uplift data yet."
          rowKey={rowKeyComposite}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Event Kind Breakdown</h2>
        <DataTable
          rows={eventKind}
          columns={eventKindCols}
          emptyMessage="No event kinds yet."
          rowKey={rowKeyComposite}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Bond Strength Distribution</h2>
        <DataTable
          rows={bondDist}
          columns={bondCols}
          emptyMessage="No bond distribution data yet."
          rowKey={rowKeyComposite}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Attendance Trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly trend data yet."
          rowKey={rowKeyComposite}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>No-Show Focus List</h2>
        <DataTable
          rows={noShow}
          columns={noShowCols}
          emptyMessage="No no-shows > great attendance!"
          rowKey={rowKey}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Bond Follow-ups</h2>
        <DataTable
          rows={followups}
          columns={followupCols}
          emptyMessage="No follow-ups logged yet."
          rowKey={rowKey}
        />
      </section>
    </main>
  );
}
