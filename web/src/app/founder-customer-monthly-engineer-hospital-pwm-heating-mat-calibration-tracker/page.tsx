import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Monthly = { month_label: string; total_runs: number; passes: number; marginals: number; fails: number; avg_drift: number };
type Engineer = { engineer_name: string; runs: number; passes: number; fails: number; avg_drift: number; critical_count: number };
type Hospital = { hospital_name: string; hospital_city: string; runs: number; fails: number; marginals: number; worst_drift: number };
type Model = { mat_model: string; runs: number; fails: number; fail_rate_pct: number; avg_ripple: number };
type Critical = { hospital_name: string; engineer_name: string; mat_model: string; serial_no: string; measured_temp_c: number; temp_drift_c: number; ripple_mv: number; calibration_result: string };
type Action = { action_kind: string; total: number; resolved: number; pending: number; failed: number; partial: number };
type Rerun = { hospital_name: string; hospital_city: string; engineer_name: string; mat_model: string; serial_no: string; temp_drift_c: number; severity: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [monthly, engineer, hospital, model, critical, action, rerun] = await Promise.all([
    supabase.rpc('rpc_r3052_monthly_overview'),
    supabase.rpc('rpc_r3052_engineer_scorecard'),
    supabase.rpc('rpc_r3052_hospital_heatmap'),
    supabase.rpc('rpc_r3052_mat_model_quality'),
    supabase.rpc('rpc_r3052_critical_runs'),
    supabase.rpc('rpc_r3052_action_pipeline'),
    supabase.rpc('rpc_r3052_rerun_backlog'),
  ]);

  const monthlyCols: Column<Monthly>[] = [
    { header: 'Month', accessor: (r) => r.month_label },
    { header: 'Total', accessor: (r) => r.total_runs },
    { header: 'Pass', accessor: (r) => r.passes },
    { header: 'Marginal', accessor: (r) => r.marginals },
    { header: 'Fail', accessor: (r) => r.fails },
    { header: 'Avg Drift °C', accessor: (r) => r.avg_drift },
  ];
  const engineerCols: Column<Engineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Runs', accessor: (r) => r.runs },
    { header: 'Pass', accessor: (r) => r.passes },
    { header: 'Fail', accessor: (r) => r.fails },
    { header: 'Avg Drift', accessor: (r) => r.avg_drift },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];
  const hospitalCols: Column<Hospital>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Runs', accessor: (r) => r.runs },
    { header: 'Fail', accessor: (r) => r.fails },
    { header: 'Marginal', accessor: (r) => r.marginals },
    { header: 'Worst Drift', accessor: (r) => r.worst_drift },
  ];
  const modelCols: Column<Model>[] = [
    { header: 'Mat Model', accessor: (r) => r.mat_model },
    { header: 'Runs', accessor: (r) => r.runs },
    { header: 'Fail', accessor: (r) => r.fails },
    { header: 'Fail %', accessor: (r) => r.fail_rate_pct },
    { header: 'Avg Ripple mV', accessor: (r) => r.avg_ripple },
  ];
  const criticalCols: Column<Critical>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Model', accessor: (r) => r.mat_model },
    { header: 'Serial', accessor: (r) => r.serial_no },
    { header: 'Measured °C', accessor: (r) => r.measured_temp_c },
    { header: 'Drift', accessor: (r) => r.temp_drift_c },
    { header: 'Ripple mV', accessor: (r) => r.ripple_mv },
    { header: 'Result', accessor: (r) => r.calibration_result },
  ];
  const actionCols: Column<Action>[] = [
    { header: 'Action', accessor: (r) => r.action_kind },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Resolved', accessor: (r) => r.resolved },
    { header: 'Pending', accessor: (r) => r.pending },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Partial', accessor: (r) => r.partial },
  ];
  const rerunCols: Column<Rerun>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Model', accessor: (r) => r.mat_model },
    { header: 'Serial', accessor: (r) => r.serial_no },
    { header: 'Drift', accessor: (r) => r.temp_drift_c },
    { header: 'Severity', accessor: (r) => r.severity },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>PWM Heating-Mat Calibration Tracker — r3052</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Customer &amp; monthly engineer-hospital pulse-width-modulation calibration — drift &gt;= 1.0°C flags warn, &gt;= 2.0°C flags critical.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly overview</h2>
        <DataTable<Monthly>
          rows={(monthly.data ?? []) as Monthly[]}
          columns={monthlyCols}
          emptyMessage="No monthly data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer scorecard</h2>
        <DataTable<Engineer>
          rows={(engineer.data ?? []) as Engineer[]}
          columns={engineerCols}
          emptyMessage="No engineer data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Hospital heatmap</h2>
        <DataTable<Hospital>
          rows={(hospital.data ?? []) as Hospital[]}
          columns={hospitalCols}
          emptyMessage="No hospital data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Mat-model quality</h2>
        <DataTable<Model>
          rows={(model.data ?? []) as Model[]}
          columns={modelCols}
          emptyMessage="No model data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Critical & warn runs</h2>
        <DataTable<Critical>
          rows={(critical.data ?? []) as Critical[]}
          columns={criticalCols}
          emptyMessage="No critical runs"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Action pipeline</h2>
        <DataTable<Action>
          rows={(action.data ?? []) as Action[]}
          columns={actionCols}
          emptyMessage="No actions"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Rerun backlog</h2>
        <DataTable<Rerun>
          rows={(rerun.data ?? []) as Rerun[]}
          columns={rerunCols}
          emptyMessage="No rerun backlog"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
