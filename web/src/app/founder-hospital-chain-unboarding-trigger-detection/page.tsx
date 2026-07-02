import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainUnboardingTriggerDetectionPage() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, highRiskRes, signalsRes, breakdownRes, windowRes, pipelineRes, severityRes] = await Promise.all([
    supabase.rpc('r2327_dashboard_summary'),
    supabase.rpc('r2327_high_risk_chains'),
    supabase.rpc('r2327_recent_signals'),
    supabase.rpc('r2327_signal_type_breakdown'),
    supabase.rpc('r2327_churn_window_distribution'),
    supabase.rpc('r2327_intervention_pipeline'),
    supabase.rpc('r2327_severity_distribution'),
  ]);

  const summary = (summaryRes.data ?? [])[0] ?? null;
  const highRisk = highRiskRes.data ?? [];
  const signals = signalsRes.data ?? [];
  const breakdown = breakdownRes.data ?? [];
  const windowDist = windowRes.data ?? [];
  const pipeline = pipelineRes.data ?? [];
  const severity = severityRes.data ?? [];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '—' : '₹' + Number(n).toLocaleString('en-IN');
  const fmtPct = (n: number | null | undefined) =>
    n == null ? '—' : Number(n).toFixed(1) + '%';

  const highRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => String(r.chain_name ?? '') },
    { key: 'risk_score', header: 'Score', render: (r) => String(r.risk_score) },
    { key: 'risk_band', header: 'Band', render: (r: any) => String(r.risk_band ?? '') },
    { key: 'active_signal_count', header: 'Signals', render: (r: any) => String(r.active_signal_count ?? '') },
    { key: 'critical_signal_count', header: 'Critical', render: (r: any) => String(r.critical_signal_count ?? '') },
    { key: 'predicted_churn_window_days', header: 'Window (d)', render: (r) => r.predicted_churn_window_days ?? '—' },
    { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r) => fmtRupees(r.arr_at_risk_rupees) },
    { key: 'primary_trigger', header: 'Primary trigger', render: (r) => r.primary_trigger ?? '—' },
    { key: 'intervention_status', header: 'Intervention', render: (r: any) => String(r.intervention_status ?? '') },
  ];

  const signalCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => String(r.chain_name ?? '') },
    { key: 'signal_type', header: 'Signal', render: (r: any) => String(r.signal_type ?? '') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'days_before_potential_churn', header: 'Window (d)', render: (r: any) => String(r.days_before_potential_churn ?? '') },
    { key: 'delta_pct', header: 'Delta', render: (r) => fmtPct(r.delta_pct) },
    { key: 'baseline_value', header: 'Baseline', render: (r) => r.baseline_value ?? '—' },
    { key: 'signal_value_numeric', header: 'Current', render: (r) => r.signal_value_numeric ?? '—' },
    { key: 'detected_at', header: 'Detected', render: (r) => new Date(r.detected_at).toLocaleString('en-IN') },
    { key: 'acknowledged_at', header: 'Ack', render: (r) => (r.acknowledged_at ? 'yes' : 'no') },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'signal_type', header: 'Signal type', render: (r: any) => String(r.signal_type ?? '') },
    { key: 'occurrence_count', header: 'Total', render: (r: any) => String(r.occurrence_count ?? '') },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? '') },
    { key: 'high_count', header: 'High', render: (r: any) => String(r.high_count ?? '') },
    { key: 'avg_days_before_churn', header: 'Avg days before churn', render: (r: any) => String(r.avg_days_before_churn ?? '') },
    { key: 'chains_affected', header: 'Chains affected', render: (r: any) => String(r.chains_affected ?? '') },
  ];

  const windowCols: Column<any>[] = [
    { key: 'window_label', header: 'Window', render: (r: any) => String(r.window_label ?? '') },
    { key: 'signal_count', header: 'Signals', render: (r: any) => String(r.signal_count ?? '') },
    { key: 'unique_chains', header: 'Chains', render: (r: any) => String(r.unique_chains ?? '') },
    { key: 'critical_signals', header: 'Critical', render: (r: any) => String(r.critical_signals ?? '') },
    { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r) => fmtRupees(r.arr_at_risk_rupees) },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'intervention_status', header: 'Status', render: (r: any) => String(r.intervention_status ?? '') },
    { key: 'chain_count', header: 'Chains', render: (r: any) => String(r.chain_count ?? '') },
    { key: 'total_arr_at_risk_rupees', header: 'ARR at risk', render: (r) => fmtRupees(r.total_arr_at_risk_rupees) },
    { key: 'avg_risk_score', header: 'Avg score', render: (r: any) => String(r.avg_risk_score ?? '') },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'signal_count', header: 'Total', render: (r: any) => String(r.signal_count ?? '') },
    { key: 'acknowledged_count', header: 'Acked', render: (r: any) => String(r.acknowledged_count ?? '') },
    { key: 'unacknowledged_count', header: 'Open', render: (r: any) => String(r.unacknowledged_count ?? '') },
    { key: 'avg_delta_pct', header: 'Avg delta', render: (r) => fmtPct(r.avg_delta_pct) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Unboarding-Trigger Detection</h1>
        <p className="text-sm text-gray-600 mt-1">
          Signals predicting chain churn 30/60/90 days out. Catch leavers before they leave.
        </p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">Chains tracked</div>
            <div className="text-xl font-semibold">{summary.total_chains_tracked ?? 0}</div>
          </div>
          <div className="p-3 border rounded bg-red-50">
            <div className="text-xs text-gray-500">Red band</div>
            <div className="text-xl font-semibold">{summary.red_band_chains ?? 0}</div>
          </div>
          <div className="p-3 border rounded bg-orange-50">
            <div className="text-xs text-gray-500">Orange band</div>
            <div className="text-xl font-semibold">{summary.orange_band_chains ?? 0}</div>
          </div>
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">ARR at risk</div>
            <div className="text-xl font-semibold">{fmtRupees(summary.total_arr_at_risk_rupees)}</div>
          </div>
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">Critical open</div>
            <div className="text-xl font-semibold">{summary.critical_signals_open ?? 0}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">High-risk chains (orange & red)</h2>
        <DataTable
          rows={highRisk}
          columns={highRiskCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No high-risk chains right now."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent open signals</h2>
        <DataTable
          rows={signals}
          columns={signalCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No open signals."
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Signal-type breakdown</h2>
          <DataTable
            rows={breakdown}
            columns={breakdownCols}
            rowKey={(r: any) => r.signal_type}
            emptyMessage="No signals logged."
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Churn-window distribution</h2>
          <DataTable
            rows={windowDist}
            columns={windowCols}
            rowKey={(r: any) => r.window_label}
            emptyMessage="No window data."
          />
        </div>
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Intervention pipeline</h2>
          <DataTable
            rows={pipeline}
            columns={pipelineCols}
            rowKey={(r: any) => r.intervention_status}
            emptyMessage="No intervention data."
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Severity distribution</h2>
          <DataTable
            rows={severity}
            columns={severityCols}
            rowKey={(r: any) => r.severity}
            emptyMessage="No severity data."
          />
        </div>
      </section>
    </main>
  );
}
