import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderOfficeHoursSchedulePage() {
  const sb = await getSupabaseServerClient();

  const [slotsRes, feedbackRes, attendeesRes, themesRes] = await Promise.all([
    sb.rpc('list_office_hours_slots_r1766'),
    sb.rpc('list_office_hours_feedback_r1766'),
    sb.rpc('office_hours_attendee_summary_r1766'),
    sb.rpc('office_hours_top_themes_r1766'),
  ]);

  const slots = (slotsRes.data ?? []) as any[];
  const feedback = (feedbackRes.data ?? []) as any[];
  const attendees = (attendeesRes.data ?? []) as any[];
  const themes = (themesRes.data ?? []) as any[];

  const slotCols: Column<any>[] = [
    { key: 'slot_date', header: 'Date', render: (r: any) => String(r.slot_date ?? '') },
    { key: 'slot_start', header: 'Start', render: (r: any) => String(r.slot_start ?? '') },
    { key: 'slot_end', header: 'End', render: (r: any) => String(r.slot_end ?? '') },
    { key: 'theme', header: 'Theme', render: (r: any) => String(r.theme ?? '') },
    { key: 'max_attendees', header: 'Max', render: (r: any) => String(r.max_attendees ?? 0) },
    { key: 'booked_count', header: 'Booked', render: (r: any) => String(r.booked_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ? String(r.notes) : '—' },
  ];

  const feedbackCols: Column<any>[] = [
    { key: 'slot_date', header: 'Slot Date', render: (r: any) => String(r.slot_date ?? '') },
    { key: 'theme', header: 'Theme', render: (r: any) => String(r.theme ?? '') },
    { key: 'attendee_email', header: 'Attendee', render: (r: any) => String(r.attendee_email ?? '') },
    { key: 'helpful_rating', header: 'Rating (1-10)', render: (r: any) => String(r.helpful_rating ?? '') },
    { key: 'what_helped', header: 'What Helped', render: (r: any) => r.what_helped ? String(r.what_helped) : '—' },
    { key: 'what_would_improve', header: 'Improve', render: (r: any) => r.what_would_improve ? String(r.what_would_improve) : '—' },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => r.submitted_at ? new Date(r.submitted_at).toLocaleString() : '' },
  ];

  const attendeeCols: Column<any>[] = [
    { key: 'attendee_email', header: 'Attendee', render: (r: any) => String(r.attendee_email ?? '') },
    { key: 'sessions_attended', header: 'Sessions', render: (r: any) => String(r.sessions_attended ?? 0) },
    { key: 'avg_helpful_rating', header: 'Avg Rating', render: (r: any) => r.avg_helpful_rating != null ? String(r.avg_helpful_rating) : '—' },
    { key: 'last_attended', header: 'Last Attended', render: (r: any) => r.last_attended ? new Date(r.last_attended).toLocaleString() : '' },
  ];

  const themeCols: Column<any>[] = [
    { key: 'theme', header: 'Theme', render: (r: any) => String(r.theme ?? '') },
    { key: 'slots_total', header: 'Slots Total', render: (r: any) => String(r.slots_total ?? 0) },
    { key: 'slots_completed', header: 'Completed', render: (r: any) => String(r.slots_completed ?? 0) },
    { key: 'feedback_count', header: 'Feedback', render: (r: any) => String(r.feedback_count ?? 0) },
    { key: 'avg_rating', header: 'Avg Rating', render: (r: any) => r.avg_rating != null ? String(r.avg_rating) : '—' },
  ];

  const totalSlots = slots.length;
  const openSlots = slots.filter((s) => s.status === 'open').length;
  const completedSlots = slots.filter((s) => s.status === 'completed').length;
  const avgRating = feedback.length
    ? (feedback.reduce((sum, f) => sum + Number(f.helpful_rating || 0), 0) / feedback.length).toFixed(2)
    : '—';

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>Founder Office Hours Schedule</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Open office hours founder offers to engineers and hospitals. Track slots, bookings, and attendee feedback.
        Slots flagged when feedback rating &lt;=4 or attendance &lt;50% of max.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Slots</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalSlots}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Open Slots</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{openSlots}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Completed</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{completedSlots}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Avg Helpful Rating</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{avgRating}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Scheduled Slots</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          All office hours slots with bookings. Status open/full/cancelled/completed.
        </p>
        <DataTable rows={slots} columns={slotCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Attendee Feedback</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Post-session feedback. Ratings &lt;=4 flagged for follow-up; &gt;=8 considered highly helpful.
        </p>
        <DataTable rows={feedback} columns={feedbackCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Attendees</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Repeat attendees by sessions attended. Helps identify engaged engineers/hospitals (&gt;=3 sessions = power user).
        </p>
        <DataTable rows={attendees} columns={attendeeCols} rowKey={(r, i) => String(r.attendee_email ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Theme Performance</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Aggregate by theme. Themes with avg rating &lt;5 need redesign; &gt;=8 are working well.
        </p>
        <DataTable rows={themes} columns={themeCols} rowKey={(r, i) => String(r.theme ?? i)} />
      </section>
    </main>
  );
}
