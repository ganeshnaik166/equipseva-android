import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = {
  drill_month: string;
  total_drills: number;
  completed_drills: number;
  failed_or_aborted: number;
  avg_activation_seconds: number | null;
  avg_response_seconds: number | null;
  pass_rate_pct: number | null;
};

type TierBreakdown = {
  hospital_tier: string;
  drill_count: number;
  avg_activation_seconds: number | null;
  best_grade_count: number;
  worst_grade_count: number;
};

type SlowestRow = {
  drill_code: string;
  hospital_name: string;
  drill_month: string;
  activation_latency_seconds: number | null;
  outcome_grade: string | null;
  responder_name: string | null;
};

type EngineerRow = {
  responder_name: string;
  drills_attended: number;
  avg_response_seconds: number | null;
  avg_activation_seconds: number | null;
  grade_a_count: number;
};

type EquipmentRow = {
  equipment_kind: string;
  total_activations: number;
  failures: number;
  partials: number;
  fail_rate_pct: number | null;
  avg_latency_seconds: number | null;
};

type SeverityRow = {
  drill_severity: string;
  grade_a: number;
  grade_b: number;
  grade_c: number;
  grade_d: number;
  grade_f: number;
  ungraded: number;
};

type MomRow = {
  hospital_name: string;
  may_avg_latency: number | null;
  june_avg_latency: number | null;
  delta_seconds: number | null;
  trend: string;
};

type QueueRow = {
  drill_code: string;
  hospital_name: string;
  hospital_tier: string;
  drill_scheduled_at: string;
  drill_status: string;
  drill_severity: string;
  responder_name: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthly, tier, slow, eng, equip, sev, mom, queue] = await Promise.all([
    supabase.rpc('r3088_monthly_summary'),
    supabase.rpc('r3088_hospital_tier_breakdown'),
    supabase.rpc('r3088_slowest_activations'),
    supabase.rpc('r3088_engineer_leaderboard'),
    supabase.rpc('r3088_equipment_failure_pareto'),
    supabase.rpc('r3088_severity_grade_matrix'),
    supabase.rpc('r3088_hospital_mom_delta'),
    supabase.rpc('r3088_open_drill_queue'),
  ]);

  const monthlyRows: MonthlySummary[] = (monthly.data ?? []) as MonthlySummary[];
  const tierRows: TierBreakdown[] = (tier.data ?? []) as TierBreakdown[];
  const slowRows: SlowestRow[] = (slow.data ?? []) as SlowestRow[];
  const engRows: EngineerRow[] = (eng.data ?? []) as EngineerRow[];
  const equipRows: EquipmentRow[] = (equip.data ?? []) as EquipmentRow[];
  const sevRows: SeverityRow[] = (sev.data ?? []) as SeverityRow[];
  const momRows: MomRow[] = (mom.data ?? []) as MomRow[];
  const queueRows: QueueRow[] = (queue.data ?? []) as QueueRow[];

  const monthlyCols: Column<MonthlySummary>[] = [
    { header: 'Month', accessor: (r) => r.drill_month },
    { header: 'Total', accessor: (r) => r.total_drills },
    { header: 'Completed', accessor: (r) => r.completed_drills },
    { header: 'Failed/Aborted', accessor: (r) => r.failed_or_aborted },
    { header: 'Avg Activation (s)', accessor: (r) => r.avg_activation_seconds ?? '—' },
    { header: 'Avg Response (s)', accessor: (r) => r.avg_response_seconds ?? '—' },
    { header: 'Pass Rate %', accessor: (r) => r.pass_rate_pct ?? '—' },
  ];

  const tierCols: Column<TierBreakdown>[] = [
    { header: 'Hospital Tier', accessor: (r) => r.hospital_tier },
    { header: 'Drills', accessor: (r) => r.drill_count },
    { header: 'Avg Activation (s)', accessor: (r) => r.avg_activation_seconds ?? '—' },
    { header: 'Grade A', accessor: (r) => r.best_grade_count },
    { header: 'Grade D/F', accessor: (r) => r.worst_grade_count },
  ];

  const slowCols: Column<SlowestRow>[] = [
    { header: 'Drill', accessor: (r) => r.drill_code },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Month', accessor: (r) => r.drill_month },
    { header: 'Latency (s)', accessor: (r) => r.activation_latency_seconds ?? '—' },
    { header: 'Grade', accessor: (r) => r.outcome_grade ?? '—' },
    { header: 'Responder', accessor: (r) => r.responder_name ?? '—' },
  ];

  const engCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.responder_name },
    { header: 'Drills', accessor: (r) => r.drills_attended },
    { header: 'Avg Response (s)', accessor: (r) => r.avg_response_seconds ?? '—' },
    { header: 'Avg Activation (s)', accessor: (r) => r.avg_activation_seconds ?? '—' },
    { header: 'Grade A Count', accessor: (r) => r.grade_a_count },
  ];

  const equipCols: Column<EquipmentRow>[] = [
    { header: 'Equipment', accessor: (r) => r.equipment_kind },
    { header: 'Activations', accessor: (r) => r.total_activations },
    { header: 'Failures', accessor: (r) => r.failures },
    { header: 'Partials', accessor: (r) => r.partials },
    { header: 'Fail Rate %', accessor: (r) => r.fail_rate_pct ?? '—' },
    { header: 'Avg Latency (s)', accessor: (r) => r.avg_latency_seconds ?? '—' },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.drill_severity },
    { header: 'A', accessor: (r) => r.grade_a },
    { header: 'B', accessor: (r) => r.grade_b },
    { header: 'C', accessor: (r) => r.grade_c },
    { header: 'D', accessor: (r) => r.grade_d },
    { header: 'F', accessor: (r) => r.grade_f },
    { header: 'Ungraded', accessor: (r) => r.ungraded },
  ];

  const momCols: Column<MomRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'May Avg (s)', accessor: (r) => r.may_avg_latency ?? '—' },
    { header: 'June Avg (s)', accessor: (r) => r.june_avg_latency ?? '—' },
    { header: 'Delta (s)', accessor: (r) => r.delta_seconds ?? '—' },
    { header: 'Trend', accessor: (r) => r.trend },
  ];

  const queueCols: Column<QueueRow>[] = [
    { header: 'Drill', accessor: (r) => r.drill_code },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Tier', accessor: (r) => r.hospital_tier },
    { header: 'Scheduled', accessor: (r) => new Date(r.drill_scheduled_at).toLocaleString() },
    { header: 'Status', accessor: (r) => r.drill_status },
    { header: 'Severity', accessor: (r) => r.drill_severity },
    { header: 'Responder', accessor: (r) => r.responder_name ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Engineer Hospital Code-Blue Drill Activation Latency Tracker</h1>
        <p className="text-sm text-gray-600">Round 3088 — founder console — activation latency & drill outcomes</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Summary</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No drills recorded."
          rowKey={(r, i) => String((r as { drill_month?: string }).drill_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital Tier Breakdown</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier data."
          rowKey={(r, i) => String((r as { hospital_tier?: string }).hospital_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Slowest Activations (top 10)</h2>
        <DataTable
          rows={slowRows}
          columns={slowCols}
          emptyMessage="No slow drills."
          rowKey={(r, i) => String((r as { drill_code?: string }).drill_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineers tracked."
          rowKey={(r, i) => String((r as { responder_name?: string }).responder_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Equipment Failure Pareto</h2>
        <DataTable
          rows={equipRows}
          columns={equipCols}
          emptyMessage="No equipment activations."
          rowKey={(r, i) => String((r as { equipment_kind?: string }).equipment_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity x Grade Matrix</h2>
        <DataTable
          rows={sevRows}
          columns={sevCols}
          emptyMessage="No severity data."
          rowKey={(r, i) => String((r as { drill_severity?: string }).drill_severity ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital Month-over-Month Delta</h2>
        <DataTable
          rows={momRows}
          columns={momCols}
          emptyMessage="No M-o-M data."
          rowKey={(r, i) => String((r as { hospital_name?: string }).hospital_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Drill Queue (Scheduled & In-Progress)</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No open drills."
          rowKey={(r, i) => String((r as { drill_code?: string }).drill_code ?? i)}
        />
      </section>
    </div>
  );
}
