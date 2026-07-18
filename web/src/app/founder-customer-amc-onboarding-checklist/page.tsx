import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerAmcOnboardingChecklistPage() {
  const supabase = await getSupabaseServerClient();

  const [steps, signoffs, stuck, kindSummary, topHospitals, weekDue, trend] = await Promise.all([
    supabase.rpc('list_steps_r2460'),
    supabase.rpc('list_signoffs_r2460'),
    supabase.rpc('stuck_steps_r2460'),
    supabase.rpc('step_kind_summary_r2460'),
    supabase.rpc('top_hospitals_by_handover_r2460'),
    supabase.rpc('this_week_due_steps_r2460'),
    supabase.rpc('monthly_onboarding_trend_r2460'),
  ]);

  const stepsRows: any[] = steps.data ?? [];
  const signoffsRows: any[] = signoffs.data ?? [];
  const stuckRows: any[] = stuck.data ?? [];
  const kindRows: any[] = kindSummary.data ?? [];
  const topRows: any[] = topHospitals.data ?? [];
  const weekRows: any[] = weekDue.data ?? [];
  const trendRows: any[] = trend.data ?? [];

  const stepsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'step_kind', header: 'Step', render: (r: any) => r.step_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'days_elapsed', header: 'Days', render: (r: any) => String(r.days_elapsed ?? 0) },
    { key: 'reminder_count', header: 'Reminders', render: (r: any) => String(r.reminder_count ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'blocker_notes', header: 'Blocker', render: (r: any) => r.blocker_notes ?? '—' },
  ];

  const signoffsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'signoff_by_email', header: 'Signed By', render: (r: any) => r.signoff_by_email },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => String(r.equipment_count ?? 0) },
    { key: 'gst_invoice_issued', header: 'GST Invoice', render: (r: any) => r.gst_invoice_issued ? 'Yes' : 'No' },
    { key: 'satisfaction_score', header: 'CSAT', render: (r: any) => r.satisfaction_score != null ? String(r.satisfaction_score) : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'founder_review_required', header: 'Founder Review', render: (r: any) => r.founder_review_required ? 'Required' : '—' },
  ];

  const stuckCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'step_kind', header: 'Step', render: (r: any) => r.step_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'days_elapsed', header: 'Days', render: (r: any) => String(r.days_elapsed ?? 0) },
    { key: 'reminder_count', header: 'Reminders', render: (r: any) => String(r.reminder_count ?? 0) },
    { key: 'blocker_notes', header: 'Blocker', render: (r: any) => r.blocker_notes ?? '—' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'step_kind', header: 'Step Kind', render: (r: any) => r.step_kind },
    { key: 'total_steps', header: 'Total', render: (r: any) => String(r.total_steps ?? 0) },
    { key: 'done_steps', header: 'Done', render: (r: any) => String(r.done_steps ?? 0) },
    { key: 'blocked_steps', header: 'Blocked', render: (r: any) => String(r.blocked_steps ?? 0) },
    { key: 'avg_days_elapsed', header: 'Avg Days', render: (r: any) => String(r.avg_days_elapsed ?? 0) },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'handover_count', header: 'Handovers', render: (r: any) => String(r.handover_count ?? 0) },
    { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: any) => r.avg_satisfaction != null ? String(r.avg_satisfaction) : '—' },
    { key: 'total_equipment', header: 'Equipment', render: (r: any) => String(r.total_equipment ?? 0) },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => String(r.escalated_count ?? 0) },
  ];

  const weekCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'step_kind', header: 'Step', render: (r: any) => r.step_kind },
    { key: 'planned_at', header: 'Planned', render: (r: any) => r.planned_at ? new Date(r.planned_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'days_elapsed', header: 'Days', render: (r: any) => String(r.days_elapsed ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'steps_planned', header: 'Planned', render: (r: any) => String(r.steps_planned ?? 0) },
    { key: 'steps_done', header: 'Done', render: (r: any) => String(r.steps_done ?? 0) },
    { key: 'steps_blocked', header: 'Blocked', render: (r: any) => String(r.steps_blocked ?? 0) },
    { key: 'handovers_complete', header: 'Handovers', render: (r: any) => String(r.handovers_complete ?? 0) },
  ];

  return (
    <div className="space-y-8 p-6">
      <div>
        <h1 className="text-2xl font-bold">Customer AMC Onboarding Checklist</h1>
        <p className="text-sm text-gray-600 mt-1">
          Hospital &gt; onboarding step &gt; status &gt; days &gt; auto reminders &gt; handover signoff (r2460)
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Step Kind Summary</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No step kinds yet"
          rowKey={(r: any, i: number) => String(r.step_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stuck Steps (&gt;= 3 days)</h2>
        <DataTable
          rows={stuckRows}
          columns={stuckCols}
          emptyMessage="No stuck steps"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Due This Week</h2>
        <DataTable
          rows={weekRows}
          columns={weekCols}
          emptyMessage="Nothing due this week"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Hospitals by Handover</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No handovers yet"
          rowKey={(r: any, i: number) => String(r.hospital_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Onboarding Steps</h2>
        <DataTable
          rows={stepsRows}
          columns={stepsCols}
          emptyMessage="No steps yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Handover Signoffs</h2>
        <DataTable
          rows={signoffsRows}
          columns={signoffsCols}
          emptyMessage="No signoffs yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Onboarding Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </div>
  );
}
