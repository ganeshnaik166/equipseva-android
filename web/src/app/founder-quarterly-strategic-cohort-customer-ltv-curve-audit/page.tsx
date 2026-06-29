import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { cohort_quarter: string; cohort_label: string; segment: string; customers_acquired: number; ltv_q8_rupees: number; cac_rupees: number; ltv_cac_ratio: number; curve_shape: string; payback_months: number };
type Segment = { segment: string; cohorts: number; total_acquired: number; avg_payback: number; total_ltv_q8: number };
type ShapeMix = { curve_shape: string; cohort_count: number; healthy_count: number; at_risk_count: number };
type Decay = { cohort_label: string; segment: string; q1_retention: number; q4_retention: number; q8_retention: number };
type Finding = { cohort_label: string; finding_type: string; severity: string; observation: string; recommended_action: string; owner_role: string; status: string; expected_uplift_rupees: number };
type Severity = { severity: string; finding_count: number; open_count: number; total_uplift: number };
type Uplift = { cohort_label: string; segment: string; recommended_action: string; owner_role: string; status: string; expected_uplift_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ov, seg, shape, decay, log, sev, up] = await Promise.all([
    supabase.rpc('r2945_curve_overview'),
    supabase.rpc('r2945_segment_rollup'),
    supabase.rpc('r2945_curve_shape_mix'),
    supabase.rpc('r2945_retention_decay'),
    supabase.rpc('r2945_audit_findings_log'),
    supabase.rpc('r2945_severity_breakdown'),
    supabase.rpc('r2945_top_uplift_actions'),
  ]);

  const overview = (ov.data ?? []) as Overview[];
  const segments = (seg.data ?? []) as Segment[];
  const shapes = (shape.data ?? []) as ShapeMix[];
  const decays = (decay.data ?? []) as Decay[];
  const findings = (log.data ?? []) as Finding[];
  const severities = (sev.data ?? []) as Severity[];
  const uplifts = (up.data ?? []) as Uplift[];

  const overviewCols: Column<Overview>[] = [
    { key: 'cohort_quarter', header: 'Quarter', render: (r) => r.cohort_quarter },
    { key: 'cohort_label', header: 'Cohort', render: (r) => r.cohort_label },
    { key: 'segment', header: 'Segment', render: (r) => r.segment },
    { key: 'customers_acquired', header: 'Acquired', render: (r) => r.customers_acquired },
    { key: 'ltv_q8_rupees', header: 'LTV Q8 (₹)', render: (r) => r.ltv_q8_rupees.toLocaleString('en-IN') },
    { key: 'cac_rupees', header: 'CAC (₹)', render: (r) => r.cac_rupees.toLocaleString('en-IN') },
    { key: 'ltv_cac_ratio', header: 'LTV/CAC', render: (r) => `${r.ltv_cac_ratio}x` },
    { key: 'curve_shape', header: 'Shape', render: (r) => r.curve_shape },
    { key: 'payback_months', header: 'Payback (mo)', render: (r) => r.payback_months },
  ];

  const segCols: Column<Segment>[] = [
    { key: 'segment', header: 'Segment', render: (r) => r.segment },
    { key: 'cohorts', header: 'Cohorts', render: (r) => r.cohorts },
    { key: 'total_acquired', header: 'Total Acquired', render: (r) => r.total_acquired },
    { key: 'avg_payback', header: 'Avg Payback (mo)', render: (r) => r.avg_payback },
    { key: 'total_ltv_q8', header: 'Total LTV Q8 (₹)', render: (r) => r.total_ltv_q8.toLocaleString('en-IN') },
  ];

  const shapeCols: Column<ShapeMix>[] = [
    { key: 'curve_shape', header: 'Curve Shape', render: (r) => r.curve_shape },
    { key: 'cohort_count', header: 'Cohorts', render: (r) => r.cohort_count },
    { key: 'healthy_count', header: 'Healthy', render: (r) => r.healthy_count },
    { key: 'at_risk_count', header: 'At Risk', render: (r) => r.at_risk_count },
  ];

  const decayCols: Column<Decay>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r) => r.cohort_label },
    { key: 'segment', header: 'Segment', render: (r) => r.segment },
    { key: 'q1_retention', header: 'Q1 %', render: (r) => `${r.q1_retention}%` },
    { key: 'q4_retention', header: 'Q4 %', render: (r) => `${r.q4_retention}%` },
    { key: 'q8_retention', header: 'Q8 %', render: (r) => `${r.q8_retention}%` },
  ];

  const findingCols: Column<Finding>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r) => r.cohort_label },
    { key: 'finding_type', header: 'Type', render: (r) => r.finding_type },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'observation', header: 'Observation', render: (r) => r.observation },
    { key: 'recommended_action', header: 'Action', render: (r) => r.recommended_action },
    { key: 'owner_role', header: 'Owner', render: (r) => r.owner_role },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'expected_uplift_rupees', header: 'Uplift (₹)', render: (r) => r.expected_uplift_rupees.toLocaleString('en-IN') },
  ];

  const sevCols: Column<Severity>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'finding_count', header: 'Findings', render: (r) => r.finding_count },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
    { key: 'total_uplift', header: 'Total Uplift (₹)', render: (r) => r.total_uplift.toLocaleString('en-IN') },
  ];

  const upCols: Column<Uplift>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r) => r.cohort_label },
    { key: 'segment', header: 'Segment', render: (r) => r.segment },
    { key: 'recommended_action', header: 'Action', render: (r) => r.recommended_action },
    { key: 'owner_role', header: 'Owner', render: (r) => r.owner_role },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'expected_uplift_rupees', header: 'Uplift (₹)', render: (r) => r.expected_uplift_rupees.toLocaleString('en-IN') },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold">Quarterly Strategic Cohort & Customer LTV Curve Audit</h1>
        <p className="text-sm text-neutral-600">Round r2945 — founder console. LTV/CAC, retention decay, curve-shape mix & uplift actions across every quarterly cohort.</p>
      </header>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Cohort Curve Overview</h2>
        <DataTable rows={overview} columns={overviewCols} emptyMessage="No cohorts" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Segment Rollup</h2>
        <DataTable rows={segments} columns={segCols} emptyMessage="No segments" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Curve-Shape Mix</h2>
        <DataTable rows={shapes} columns={shapeCols} emptyMessage="No shapes" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Retention Decay (Q1 / Q4 / Q8)</h2>
        <DataTable rows={decays} columns={decayCols} emptyMessage="No decay data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Audit Findings Log</h2>
        <DataTable rows={findings} columns={findingCols} emptyMessage="No findings" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Severity Breakdown</h2>
        <DataTable rows={severities} columns={sevCols} emptyMessage="No severities" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Top Uplift Actions</h2>
        <DataTable rows={uplifts} columns={upCols} emptyMessage="No actions" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </main>
  );
}
