import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyTeamCoachingInvestmentPage() {
  const supabase = await getSupabaseServerClient();

  const [
    coachingRes,
    outcomesRes,
    topRoiRes,
    kindDistRes,
    successionRes,
    weeklyTrendRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_coaching_r2605'),
    supabase.rpc('list_succession_outcomes_r2605'),
    supabase.rpc('top_roi_coaching_r2605'),
    supabase.rpc('kind_distribution_r2605'),
    supabase.rpc('succession_readiness_summary_r2605'),
    supabase.rpc('weekly_investment_trend_r2605'),
    supabase.rpc('founder_pulse_summary_r2605'),
  ]);

  const coaching: any[] = coachingRes.data ?? [];
  const outcomes: any[] = outcomesRes.data ?? [];
  const topRoi: any[] = topRoiRes.data ?? [];
  const kindDist: any[] = kindDistRes.data ?? [];
  const succession: any[] = successionRes.data ?? [];
  const weeklyTrend: any[] = weeklyTrendRes.data ?? [];
  const pulse: any = (pulseRes.data ?? [])[0] ?? {};

  const fmtRupees = (n: number | null | undefined) => {
    if (n == null) return '-';
    return '₹' + Number(n).toLocaleString('en-IN');
  };

  const coachingCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ?? '-' },
    { key: 'team_member_email', header: 'Team Member', render: (r: any) => r.team_member_email ?? '-' },
    { key: 'coaching_kind', header: 'Kind', render: (r: any) => r.coaching_kind ?? '-' },
    { key: 'hours_invested', header: 'Hours', render: (r: any) => Number(r.hours_invested ?? 0).toFixed(2) },
    { key: 'roi_estimate_rupees', header: 'ROI', render: (r: any) => fmtRupees(r.roi_estimate_rupees) },
    { key: 'succession_readiness_pct', header: 'Succession %', render: (r: any) => (r.succession_readiness_pct ?? 0) + '%' },
    { key: 'delegation_lift_pct', header: 'Delegation Lift', render: (r: any) => Number(r.delegation_lift_pct ?? 0).toFixed(2) + '%' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => r.observed_at ? new Date(r.observed_at).toLocaleString() : '-' },
    { key: 'team_member_email', header: 'Team Member', render: (r: any) => r.team_member_email ?? '-' },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind ?? '-' },
    { key: 'evidence_md', header: 'Evidence', render: (r: any) => r.evidence_md ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topRoiCols: Column<any>[] = [
    { key: 'team_member_email', header: 'Team Member', render: (r: any) => r.team_member_email ?? '-' },
    { key: 'total_hours', header: 'Hours', render: (r: any) => Number(r.total_hours ?? 0).toFixed(2) },
    { key: 'total_roi_rupees', header: 'Total ROI', render: (r: any) => fmtRupees(r.total_roi_rupees) },
    { key: 'roi_per_hour', header: 'ROI / Hour', render: (r: any) => fmtRupees(r.roi_per_hour) },
    { key: 'avg_succession_pct', header: 'Avg Succession %', render: (r: any) => Number(r.avg_succession_pct ?? 0).toFixed(2) + '%' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'coaching_kind', header: 'Kind', render: (r: any) => r.coaching_kind ?? '-' },
    { key: 'session_count', header: 'Sessions', render: (r: any) => r.session_count ?? 0 },
    { key: 'total_hours', header: 'Hours', render: (r: any) => Number(r.total_hours ?? 0).toFixed(2) },
    { key: 'total_roi_rupees', header: 'ROI', render: (r: any) => fmtRupees(r.total_roi_rupees) },
  ];

  const successionCols: Column<any>[] = [
    { key: 'team_member_email', header: 'Team Member', render: (r: any) => r.team_member_email ?? '-' },
    { key: 'latest_readiness_pct', header: 'Readiness %', render: (r: any) => (r.latest_readiness_pct ?? 0) + '%' },
    { key: 'latest_delegation_lift_pct', header: 'Delegation Lift', render: (r: any) => Number(r.latest_delegation_lift_pct ?? 0).toFixed(2) + '%' },
    { key: 'promotion_ready_count', header: 'Promotion Ready', render: (r: any) => r.promotion_ready_count ?? 0 },
    { key: 'delegation_unlocked_count', header: 'Delegation Unlocked', render: (r: any) => r.delegation_unlocked_count ?? 0 },
    { key: 'no_change_count', header: 'No Change', render: (r: any) => r.no_change_count ?? 0 },
    { key: 'regressed_count', header: 'Regressed', render: (r: any) => r.regressed_count ?? 0 },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ?? '-' },
    { key: 'session_count', header: 'Sessions', render: (r: any) => r.session_count ?? 0 },
    { key: 'total_hours', header: 'Hours', render: (r: any) => Number(r.total_hours ?? 0).toFixed(2) },
    { key: 'total_roi_rupees', header: 'ROI', render: (r: any) => fmtRupees(r.total_roi_rupees) },
    { key: 'avg_succession_pct', header: 'Avg Succession %', render: (r: any) => Number(r.avg_succession_pct ?? 0).toFixed(2) + '%' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Founder Weekly Team Coaching Investment
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track weekly hours invested coaching team members & the ROI in succession readiness & delegation lift.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Founder Pulse</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <PulseCard label="Total Sessions" value={String(pulse.total_sessions ?? 0)} />
          <PulseCard label="Total Hours" value={Number(pulse.total_hours ?? 0).toFixed(2)} />
          <PulseCard label="Total ROI" value={fmtRupees(pulse.total_roi_rupees)} />
          <PulseCard label="Team Members" value={String(pulse.unique_team_members ?? 0)} />
          <PulseCard label="Avg Succession %" value={Number(pulse.avg_succession_pct ?? 0).toFixed(2) + '%'} />
          <PulseCard label="Avg Delegation Lift" value={Number(pulse.avg_delegation_lift_pct ?? 0).toFixed(2) + '%'} />
          <PulseCard label="Promotion Ready" value={String(pulse.promotion_ready_outcomes ?? 0)} />
          <PulseCard label="Delegation Unlocked" value={String(pulse.delegation_unlocked_outcomes ?? 0)} />
          <PulseCard label="Planned" value={String(pulse.planned_sessions ?? 0)} />
          <PulseCard label="Done" value={String(pulse.done_sessions ?? 0)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top ROI by Team Member</h2>
        <DataTable
          rows={topRoi}
          columns={topRoiCols}
          emptyMessage="No coaching ROI yet"
          rowKey={(r: any, i: number) => String(r.team_member_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Succession Readiness Summary</h2>
        <DataTable
          rows={succession}
          columns={successionCols}
          emptyMessage="No succession data yet"
          rowKey={(r: any, i: number) => String(r.team_member_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Coaching Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindCols}
          emptyMessage="No coaching kinds logged yet"
          rowKey={(r: any, i: number) => String(r.coaching_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Weekly Investment Trend</h2>
        <DataTable
          rows={weeklyTrend}
          columns={trendCols}
          emptyMessage="No weekly trend data yet"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Coaching Sessions</h2>
        <DataTable
          rows={coaching}
          columns={coachingCols}
          emptyMessage="No coaching sessions logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Succession Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No succession outcomes logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function PulseCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ padding: 16, borderRadius: 12, border: '1px solid #e5e7eb', background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, color: '#111' }}>{value}</div>
    </div>
  );
}