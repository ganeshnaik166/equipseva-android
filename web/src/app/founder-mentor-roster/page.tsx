import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMentorRosterPage() {
  const sb = await getSupabaseServerClient();

  const [mentorsRes, meetingsRes, topRes, staleRes] = await Promise.all([
    sb.rpc('list_mentors_r1718'),
    sb.rpc('list_meetings_r1718', { p_mentor_id: null }),
    sb.rpc('top_value_mentors_r1718', { p_limit: 10 }),
    sb.rpc('stale_mentor_relationships_r1718', { p_days_threshold: 60 }),
  ]);

  const mentors: any[] = Array.isArray(mentorsRes.data) ? (mentorsRes.data as any[]) : [];
  const meetings: any[] = Array.isArray(meetingsRes.data) ? (meetingsRes.data as any[]) : [];
  const top: any[] = Array.isArray(topRes.data) ? (topRes.data as any[]) : [];
  const stale: any[] = Array.isArray(staleRes.data) ? (staleRes.data as any[]) : [];

  const activeCount = mentors.filter((m) => m.status === 'active').length;
  const pausedCount = mentors.filter((m) => m.status === 'paused').length;
  const droppedCount = mentors.filter((m) => m.status === 'dropped').length;
  const totalMonthlyCash = mentors
    .filter((m) => m.status === 'active' && m.compensation_model === 'cash')
    .reduce((sum, m) => sum + Number(m.monthly_compensation_rupees || 0), 0);
  const meetingsWithAction = meetings.filter((m) => m.took_action).length;
  const actionRate = meetings.length > 0 ? Math.round((meetingsWithAction / meetings.length) * 100) : 0;

  const mentorColumns: Column<any>[] = [
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => <span className="font-medium">{r.mentor_name}</span> },
    { key: 'mentor_org', header: 'Org', render: (r: any) => r.mentor_org || '—' },
    {
      key: 'expertise_areas',
      header: 'Expertise',
      render: (r: any) => Array.isArray(r.expertise_areas) && r.expertise_areas.length > 0 ? r.expertise_areas.join(', ') : '—',
    },
    {
      key: 'compensation_model',
      header: 'Comp',
      render: (r: any) => (
        <span className={`px-2 py-0.5 rounded text-xs ${
          r.compensation_model === 'equity' ? 'bg-purple-100 text-purple-700'
          : r.compensation_model === 'cash' ? 'bg-amber-100 text-amber-700'
          : 'bg-green-100 text-green-700'
        }`}>
          {r.compensation_model}
        </span>
      ),
    },
    {
      key: 'monthly_compensation_rupees',
      header: 'Monthly',
      render: (r: any) => `₹${Number(r.monthly_compensation_rupees || 0).toLocaleString('en-IN')}`,
    },
    {
      key: 'value_rating',
      header: 'Value',
      render: (r: any) => r.value_rating == null ? '—' : `${r.value_rating}/10`,
    },
    {
      key: 'meetings_count',
      header: 'Meetings',
      render: (r: any) => String(r.meetings_count ?? 0),
    },
    {
      key: 'last_met_at',
      header: 'Last met',
      render: (r: any) => r.last_met_at ? new Date(r.last_met_at).toLocaleDateString('en-IN') : 'never',
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => (
        <span className={`px-2 py-0.5 rounded text-xs ${
          r.status === 'active' ? 'bg-green-100 text-green-700'
          : r.status === 'paused' ? 'bg-yellow-100 text-yellow-700'
          : 'bg-gray-200 text-gray-700'
        }`}>
          {r.status}
        </span>
      ),
    },
  ];

  const meetingColumns: Column<any>[] = [
    {
      key: 'meeting_date',
      header: 'Date',
      render: (r: any) => r.meeting_date ? new Date(r.meeting_date).toLocaleDateString('en-IN') : '—',
    },
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => <span className="font-medium">{r.mentor_name}</span> },
    { key: 'topic', header: 'Topic', render: (r: any) => r.topic || '—' },
    {
      key: 'key_insight',
      header: 'Key insight',
      render: (r: any) => (
        <span className="text-sm text-gray-700">
          {r.key_insight ? (r.key_insight.length > 80 ? r.key_insight.slice(0, 80) + '…' : r.key_insight) : '—'}
        </span>
      ),
    },
    {
      key: 'took_action',
      header: 'Acted?',
      render: (r: any) => (
        <span className={`px-2 py-0.5 rounded text-xs ${r.took_action ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
          {r.took_action ? 'yes' : 'no'}
        </span>
      ),
    },
    {
      key: 'outcome_md',
      header: 'Outcome',
      render: (r: any) => (
        <span className="text-sm text-gray-700">
          {r.outcome_md ? (r.outcome_md.length > 60 ? r.outcome_md.slice(0, 60) + '…' : r.outcome_md) : '—'}
        </span>
      ),
    },
  ];

  const topColumns: Column<any>[] = [
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => <span className="font-medium">{r.mentor_name}</span> },
    { key: 'mentor_org', header: 'Org', render: (r: any) => r.mentor_org || '—' },
    { key: 'value_rating', header: 'Value', render: (r: any) => r.value_rating == null ? '—' : `${r.value_rating}/10` },
    { key: 'compensation_model', header: 'Comp', render: (r: any) => r.compensation_model },
    {
      key: 'monthly_compensation_rupees',
      header: 'Monthly',
      render: (r: any) => `₹${Number(r.monthly_compensation_rupees || 0).toLocaleString('en-IN')}`,
    },
    { key: 'meetings_count', header: 'Meetings', render: (r: any) => String(r.meetings_count ?? 0) },
    {
      key: 'actions_taken_count',
      header: 'Acted on',
      render: (r: any) => {
        const total = Number(r.meetings_count ?? 0);
        const acted = Number(r.actions_taken_count ?? 0);
        const pct = total > 0 ? Math.round((acted / total) * 100) : 0;
        return `${acted}/${total} (${pct}%)`;
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => (
        <span className={`px-2 py-0.5 rounded text-xs ${
          r.status === 'active' ? 'bg-green-100 text-green-700'
          : r.status === 'paused' ? 'bg-yellow-100 text-yellow-700'
          : 'bg-gray-200 text-gray-700'
        }`}>
          {r.status}
        </span>
      ),
    },
  ];

  const staleColumns: Column<any>[] = [
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => <span className="font-medium">{r.mentor_name}</span> },
    { key: 'mentor_org', header: 'Org', render: (r: any) => r.mentor_org || '—' },
    {
      key: 'last_met_at',
      header: 'Last met',
      render: (r: any) => r.last_met_at ? new Date(r.last_met_at).toLocaleDateString('en-IN') : 'never',
    },
    {
      key: 'days_since_last_meeting',
      header: 'Days stale',
      render: (r: any) => {
        const d = r.days_since_last_meeting;
        if (d == null) return <span className="text-red-700 font-medium">never met</span>;
        const cls = d >= 90 ? 'text-red-700 font-medium' : d >= 60 ? 'text-amber-700' : 'text-gray-700';
        return <span className={cls}>{d}d</span>;
      },
    },
    { key: 'value_rating', header: 'Value', render: (r: any) => r.value_rating == null ? '—' : `${r.value_rating}/10` },
    {
      key: 'monthly_compensation_rupees',
      header: 'Monthly cost',
      render: (r: any) => `₹${Number(r.monthly_compensation_rupees || 0).toLocaleString('en-IN')}`,
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Founder Mentor Roster</h1>
        <p className="text-gray-600 text-sm mt-1">
          Active mentors & advisors, meeting cadence, and value extracted. Stale relationships (&gt;60 days)
          flagged for re-engagement or sunset.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="border rounded p-3 bg-green-50">
          <div className="text-xs uppercase text-gray-600">Active</div>
          <div className="text-2xl font-bold text-green-700">{activeCount}</div>
        </div>
        <div className="border rounded p-3 bg-yellow-50">
          <div className="text-xs uppercase text-gray-600">Paused</div>
          <div className="text-2xl font-bold text-yellow-700">{pausedCount}</div>
        </div>
        <div className="border rounded p-3 bg-gray-50">
          <div className="text-xs uppercase text-gray-600">Dropped</div>
          <div className="text-2xl font-bold text-gray-700">{droppedCount}</div>
        </div>
        <div className="border rounded p-3 bg-amber-50">
          <div className="text-xs uppercase text-gray-600">Monthly cash</div>
          <div className="text-2xl font-bold text-amber-700">₹{totalMonthlyCash.toLocaleString('en-IN')}</div>
        </div>
        <div className="border rounded p-3 bg-blue-50">
          <div className="text-xs uppercase text-gray-600">Action rate</div>
          <div className="text-2xl font-bold text-blue-700">{actionRate}%</div>
          <div className="text-xs text-gray-600">{meetingsWithAction}/{meetings.length} meetings</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All mentors</h2>
        <p className="text-sm text-gray-600 mb-3">
          Roster sorted by status (active first), then value rating. Value rating is founder's subjective 1-10
          score of insight quality.
        </p>
        <DataTable
          rows={mentors}
          columns={mentorColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top-value mentors</h2>
        <p className="text-sm text-gray-600 mb-3">
          Highest value_rating mentors with action-conversion rate. If action rate &lt; 30% on a high-value mentor,
          the bottleneck is founder execution, not mentor quality.
        </p>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale relationships (&gt;60 days)</h2>
        <p className="text-sm text-gray-600 mb-3">
          Active mentors not met in &gt;= 60 days. Re-engage or move to paused/dropped. Paying cash for a stale
          mentor is pure burn.
        </p>
        <DataTable
          rows={stale}
          columns={staleColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent meetings</h2>
        <p className="text-sm text-gray-600 mb-3">
          Last 200 meetings across all mentors. "Acted?" = founder followed through on action items.
        </p>
        <DataTable
          rows={meetings}
          columns={meetingColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
