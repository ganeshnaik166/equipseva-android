import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerAttritionRiskRadarPage() {
  const supabase = await getSupabaseServerClient();

  const [signalsRes, plansRes, topRiskRes, distRes, sideRes, trendRes, outcomeRes] = await Promise.all([
    supabase.rpc('list_signals_r2482'),
    supabase.rpc('list_retention_plans_r2482'),
    supabase.rpc('top_risk_engineers_r2482'),
    supabase.rpc('risk_distribution_r2482'),
    supabase.rpc('side_opportunity_breakdown_r2482'),
    supabase.rpc('monthly_flight_risk_trend_r2482'),
    supabase.rpc('plan_outcome_summary_r2482'),
  ]);

  const signals = (signalsRes.data ?? []) as any[];
  const plans = (plansRes.data ?? []) as any[];
  const topRisk = (topRiskRes.data ?? []) as any[];
  const dist = (distRes.data ?? []) as any[];
  const side = (sideRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const outcome = (outcomeRes.data ?? []) as any[];

  const signalCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'tenure_months', header: 'Tenure (mo)', render: (r: any) => r.tenure_months },
    { key: 'current_comp_rupees', header: 'Comp ₹', render: (r: any) => Number(r.current_comp_rupees).toLocaleString('en-IN') },
    { key: 'market_comp_gap_pct', header: 'Gap %', render: (r: any) => `${r.market_comp_gap_pct}%` },
    { key: 'satisfaction_score', header: 'Sat /10', render: (r: any) => r.satisfaction_score },
    { key: 'side_opportunity_kind', header: 'Side signal', render: (r: any) => r.side_opportunity_kind },
    { key: 'flight_risk_score', header: 'Risk', render: (r: any) => r.flight_risk_score },
    { key: 'top_risk', header: 'Top risk', render: (r: any) => r.top_risk },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_assessed_at', header: 'Assessed', render: (r: any) => new Date(r.last_assessed_at).toLocaleDateString() },
  ];

  const planCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'plan_kind', header: 'Plan kind', render: (r: any) => r.plan_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'action_due_at', header: 'Due', render: (r: any) => new Date(r.action_due_at).toLocaleDateString() },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'closed_at', header: 'Closed', render: (r: any) => r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topRiskCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'flight_risk_score', header: 'Risk', render: (r: any) => r.flight_risk_score },
    { key: 'top_risk', header: 'Top risk', render: (r: any) => r.top_risk },
    { key: 'tenure_months', header: 'Tenure (mo)', render: (r: any) => r.tenure_months },
    { key: 'market_comp_gap_pct', header: 'Gap %', render: (r: any) => `${r.market_comp_gap_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const distCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
  ];

  const sideCols: Column<any>[] = [
    { key: 'side_opportunity_kind', header: 'Side signal', render: (r: any) => r.side_opportunity_kind },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'avg_flight_risk', header: 'Avg risk', render: (r: any) => r.avg_flight_risk },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString() },
    { key: 'assessments', header: 'Assessments', render: (r: any) => r.assessments },
    { key: 'avg_risk', header: 'Avg risk', render: (r: any) => r.avg_risk },
    { key: 'high_risk_count', header: 'High risk', render: (r: any) => r.high_risk_count },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'plan_count', header: 'Plans', render: (r: any) => r.plan_count },
    { key: 'avg_days_to_close', header: 'Avg days', render: (r: any) => r.avg_days_to_close },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Attrition Risk Radar</h1>
        <p className="text-sm text-gray-600">Per-engineer flight risk & retention plan execution.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top risk engineers (&gt;=60)</h2>
        <DataTable
          rows={topRisk}
          columns={topRiskCols}
          emptyMessage="No high-risk engineers."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All attrition signals</h2>
        <DataTable
          rows={signals}
          columns={signalCols}
          emptyMessage="No signals."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Retention plans</h2>
        <DataTable
          rows={plans}
          columns={planCols}
          emptyMessage="No plans."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Risk distribution</h2>
        <DataTable
          rows={dist}
          columns={distCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Side opportunity breakdown</h2>
        <DataTable
          rows={side}
          columns={sideCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.side_opportunity_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly flight risk trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Plan outcome summary</h2>
        <DataTable
          rows={outcome}
          columns={outcomeCols}
          emptyMessage="No outcomes."
          rowKey={(r: any, i: number) => String(r.outcome ?? i)}
        />
      </section>
    </div>
  );
}
