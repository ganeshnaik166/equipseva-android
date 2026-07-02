import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Visit = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  hospital_id: string | null;
  hospital_name: string | null;
  visit_date: string | null;
  distance_km: number | null;
  travel_cost_rupees: number | null;
  reason: string | null;
  billable: boolean | null;
  billed_amount_rupees: number | null;
  status: string | null;
  created_at: string | null;
};

type Outcome = {
  id: string;
  visit_id: string | null;
  visit_date: string | null;
  engineer_email: string | null;
  outcome: string | null;
  follow_up_required: boolean | null;
  follow_up_at: string | null;
  founder_review: string | null;
  created_at: string | null;
};

type MonthlyRoi = {
  month_start: string | null;
  visits_count: number | null;
  total_travel_cost: number | null;
  total_billed: number | null;
  net_roi: number | null;
  completed_count: number | null;
  cancelled_count: number | null;
};

type FollowUp = {
  outcome_id: string;
  visit_id: string | null;
  engineer_email: string | null;
  hospital_name: string | null;
  follow_up_at: string | null;
  days_overdue: number | null;
  outcome: string | null;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [visitsRes, outcomesRes, roiRes, followUpRes] = await Promise.all([
    sb.rpc('list_offsite_visits_r1696'),
    sb.rpc('list_offsite_visit_outcomes_r1696'),
    sb.rpc('monthly_offsite_roi_summary_r1696'),
    sb.rpc('offsite_follow_up_due_r1696'),
  ]);

  const visits: Visit[] = (visitsRes.data as Visit[]) ?? [];
  const outcomes: Outcome[] = (outcomesRes.data as Outcome[]) ?? [];
  const roi: MonthlyRoi[] = (roiRes.data as MonthlyRoi[]) ?? [];
  const followUps: FollowUp[] = (followUpRes.data as FollowUp[]) ?? [];

  const totalVisits = visits.length;
  const completedVisits = visits.filter((v) => v.status === 'completed').length;
  const plannedVisits = visits.filter((v) => v.status === 'planned').length;
  const totalTravel = visits.reduce((s, v) => s + Number(v.travel_cost_rupees ?? 0), 0);
  const totalBilled = visits.reduce((s, v) => s + Number(v.billed_amount_rupees ?? 0), 0);
  const netRoi = totalBilled - totalTravel;

  const visitColumns: Column<Visit>[] = [
    { key: 'visit_date', header: 'Visit Date', render: (r: any) => r.visit_date ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'distance_km', header: 'Distance (km)', render: (r: any) => String(r.distance_km ?? 0) },
    { key: 'travel_cost_rupees', header: 'Travel Cost', render: (r: any) => rupees(r.travel_cost_rupees) },
    { key: 'billable', header: 'Billable', render: (r: any) => (r.billable ? 'Yes' : 'No') },
    { key: 'billed_amount_rupees', header: 'Billed', render: (r: any) => rupees(r.billed_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? '—' },
  ];

  const outcomeColumns: Column<Outcome>[] = [
    { key: 'visit_date', header: 'Visit Date', render: (r: any) => r.visit_date ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'follow_up_required', header: 'Follow-up', render: (r: any) => (r.follow_up_required ? 'Yes' : 'No') },
    { key: 'follow_up_at', header: 'Follow-up Date', render: (r: any) => r.follow_up_at ?? '—' },
    { key: 'founder_review', header: 'Founder Review', render: (r: any) => r.founder_review ?? '—' },
    { key: 'created_at', header: 'Recorded', render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleDateString('en-IN') : '—') },
  ];

  const roiColumns: Column<MonthlyRoi>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => (r.month_start ? String(r.month_start).slice(0, 7) : '—') },
    { key: 'visits_count', header: 'Visits', render: (r: any) => String(r.visits_count ?? 0) },
    { key: 'completed_count', header: 'Completed', render: (r: any) => String(r.completed_count ?? 0) },
    { key: 'cancelled_count', header: 'Cancelled', render: (r: any) => String(r.cancelled_count ?? 0) },
    { key: 'total_travel_cost', header: 'Travel Cost', render: (r: any) => rupees(r.total_travel_cost) },
    { key: 'total_billed', header: 'Billed', render: (r: any) => rupees(r.total_billed) },
    { key: 'net_roi', header: 'Net ROI', render: (r: any) => {
        const v = Number(r.net_roi ?? 0);
        const color = v >= 0 ? '#15803d' : '#b91c1c';
        return <span style={{ color, fontWeight: 600 }}>{rupees(v)}</span>;
      } },
  ];

  const followUpColumns: Column<FollowUp>[] = [
    { key: 'follow_up_at', header: 'Follow-up Date', render: (r: any) => r.follow_up_at ?? '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => {
        const d = Number(r.days_overdue ?? 0);
        const color = d > 0 ? '#b91c1c' : '#475569';
        return <span style={{ color, fontWeight: 600 }}>{d}</span>;
      } },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Engineer Off-Site Visits</h1>
        <p style={{ color: '#64748b', marginTop: 6 }}>
          Out-of-territory engineer dispatches with travel cost vs billed amount ROI tracking. Net ROI &gt;= 0 means visits paying for themselves.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <div style={{ padding: 16, border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase' }}>Total Visits</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{totalVisits}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase' }}>Completed</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: '#15803d' }}>{completedVisits}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase' }}>Planned</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: '#0369a1' }}>{plannedVisits}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase' }}>Total Travel</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{rupees(totalTravel)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase' }}>Total Billed</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{rupees(totalBilled)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase' }}>Net ROI</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: netRoi >= 0 ? '#15803d' : '#b91c1c' }}>{rupees(netRoi)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly ROI Summary</h2>
        <p style={{ color: '#64748b', fontSize: 13, marginBottom: 12 }}>
          Net ROI per month: billed amount minus travel cost. Positive = profitable dispatch (&gt;=0).
        </p>
        <DataTable rows={roi} columns={roiColumns} rowKey={(r: any, i: number) => String(r.month_start ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Follow-up Due (next 7 days & overdue)</h2>
        <p style={{ color: '#64748b', fontSize: 13, marginBottom: 12 }}>
          Outcomes with follow-up required. Days overdue &gt; 0 means missed window — escalate immediately.
        </p>
        <DataTable rows={followUps} columns={followUpColumns} rowKey={(r: any, i: number) => String(r.outcome_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Off-Site Visits</h2>
        <p style={{ color: '#64748b', fontSize: 13, marginBottom: 12 }}>
          Last 200 dispatches across all engineers. Travel cost &lt; billed amount = revenue positive.
        </p>
        <DataTable rows={visits} columns={visitColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Visit Outcomes</h2>
        <p style={{ color: '#64748b', fontSize: 13, marginBottom: 12 }}>
          Recorded outcomes per visit with founder review. Used to decide if follow-up dispatch is worth the travel cost.
        </p>
        <DataTable rows={outcomes} columns={outcomeColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
