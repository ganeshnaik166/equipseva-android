import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [pulses, actions, atRisk, statusDist, trend, attendance, kindBreakdown] = await Promise.all([
    supabase.rpc('list_wellness_r2598'),
    supabase.rpc('list_planning_actions_r2598'),
    supabase.rpc('top_at_risk_engineers_r2598'),
    supabase.rpc('status_distribution_r2598'),
    supabase.rpc('monthly_pulse_trend_r2598'),
    supabase.rpc('planning_attendance_rate_r2598'),
    supabase.rpc('action_kind_breakdown_r2598'),
  ]);

  const pulseRows = (pulses.data ?? []) as any[];
  const actionRows = (actions.data ?? []) as any[];
  const atRiskRows = (atRisk.data ?? []) as any[];
  const statusRows = (statusDist.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const attendanceRow = ((attendance.data ?? []) as any[])[0] ?? null;
  const kindRows = (kindBreakdown.data ?? []) as any[];

  const pulseCols: Column<any>[] = [
    { key: 'pulse_at', header: 'Pulse At', render: (r: any) => r.pulse_at ? new Date(r.pulse_at).toLocaleString() : '' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'emergency_fund_months', header: 'Emergency (mo)', render: (r: any) => String(r.emergency_fund_months ?? '') },
    { key: 'savings_rate_pct', header: 'Savings %', render: (r: any) => String(r.savings_rate_pct ?? '') },
    { key: 'debt_burden_pct', header: 'Debt %', render: (r: any) => String(r.debt_burden_pct ?? '') },
    { key: 'financial_stress_score', header: 'Stress', render: (r: any) => String(r.financial_stress_score ?? '') },
    { key: 'planning_session_attended', header: 'Session', render: (r: any) => r.planning_session_attended ? 'Yes' : 'No' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'Action At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '' },
    { key: 'action_kind', header: 'Kind', render: (r: any) => String(r.action_kind ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'pulse_at', header: 'Pulse At', render: (r: any) => r.pulse_at ? new Date(r.pulse_at).toLocaleString() : '' },
    { key: 'financial_stress_score', header: 'Stress', render: (r: any) => String(r.financial_stress_score ?? '') },
    { key: 'emergency_fund_months', header: 'Emergency (mo)', render: (r: any) => String(r.emergency_fund_months ?? '') },
    { key: 'debt_burden_pct', header: 'Debt %', render: (r: any) => String(r.debt_burden_pct ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'pulse_count', header: 'Pulses', render: (r: any) => String(r.pulse_count ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '' },
    { key: 'pulse_count', header: 'Pulses', render: (r: any) => String(r.pulse_count ?? '') },
    { key: 'avg_stress', header: 'Avg Stress', render: (r: any) => String(r.avg_stress ?? '') },
    { key: 'avg_emergency_fund', header: 'Avg Emergency', render: (r: any) => String(r.avg_emergency_fund ?? '') },
    { key: 'avg_debt_burden', header: 'Avg Debt %', render: (r: any) => String(r.avg_debt_burden ?? '') },
  ];

  const kindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Kind', render: (r: any) => String(r.action_kind ?? '') },
    { key: 'total_actions', header: 'Total', render: (r: any) => String(r.total_actions ?? '') },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count ?? '') },
    { key: 'positive_pct', header: 'Positive %', render: (r: any) => String(r.positive_pct ?? '') },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer Personal Financial Wellness Pulse</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Round r2598 — engineer financial health pulses, planning actions & at-risk view.
      </p>

      {attendanceRow ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 24 }}>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ color: '#6b7280', fontSize: 12 }}>Total Pulses</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{String(attendanceRow.total_pulses ?? 0)}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ color: '#6b7280', fontSize: 12 }}>Attended Planning</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{String(attendanceRow.attended_count ?? 0)}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ color: '#6b7280', fontSize: 12 }}>Attendance %</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{String(attendanceRow.attendance_pct ?? 0)}</div>
          </div>
        </div>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top At-Risk Engineers</h2>
        <DataTable
          rows={atRiskRows}
          columns={atRiskCols}
          emptyMessage="No at-risk engineers."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Status Distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Monthly Pulse Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Action Kind Breakdown</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No action breakdown."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Pulses</h2>
        <DataTable
          rows={pulseRows}
          columns={pulseCols}
          emptyMessage="No pulses recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Planning Actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No planning actions recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
