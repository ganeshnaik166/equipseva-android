import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Prediction = {
  id: string;
  customer_email: string | null;
  customer_segment: string;
  customer_tier: string;
  amc_contract_value_rupees: number;
  model_version: string;
  predicted_renewal_probability: number;
  predicted_outcome: string;
  confidence_score: number;
  prediction_date: string;
  renewal_due_date: string;
  actual_outcome: string | null;
  prediction_correct: boolean | null;
};

type SegmentAccuracy = {
  customer_segment: string;
  total_predictions: number;
  resolved_predictions: number;
  correct_predictions: number;
  accuracy_pct: number | null;
  avg_predicted_prob: number | null;
  renewal_rate_pct: number | null;
};

type ModelAccuracy = {
  model_version: string;
  total_predictions: number;
  resolved_predictions: number;
  accuracy_pct: number | null;
  avg_confidence: number | null;
  earliest_prediction: string | null;
  latest_prediction: string | null;
};

type Refinement = {
  id: string;
  model_version: string;
  previous_version: string | null;
  refinement_type: string;
  refinement_summary: string;
  trigger_reason: string;
  prior_accuracy_pct: number | null;
  new_accuracy_pct: number | null;
  accuracy_delta: number | null;
  training_sample_size: number;
  refined_by_email: string;
  deployed_at: string;
};

type Summary = {
  total_predictions: number;
  pending_outcome: number;
  resolved_outcome: number;
  overall_accuracy_pct: number | null;
  avg_predicted_prob: number | null;
  total_amc_value_at_risk: number;
  high_confidence_correct_pct: number | null;
  active_model_version: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [predRes, segRes, modelRes, refineRes, summaryRes] = await Promise.all([
    supabase.rpc('list_renewal_predictions_r2332'),
    supabase.rpc('accuracy_by_segment_r2332'),
    supabase.rpc('accuracy_by_model_version_r2332'),
    supabase.rpc('list_refinement_log_r2332'),
    supabase.rpc('summary_renewal_accuracy_r2332'),
  ]);

  const predictions = (predRes.data ?? []) as Prediction[];
  const segments = (segRes.data ?? []) as SegmentAccuracy[];
  const models = (modelRes.data ?? []) as ModelAccuracy[];
  const refinements = (refineRes.data ?? []) as Refinement[];
  const summary = (summaryRes.data?.[0] ?? null) as Summary | null;

  const predCols: Column<Prediction>[] = [
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? '—' },
    { key: 'customer_segment', header: 'Segment', render: (r) => r.customer_segment },
    { key: 'customer_tier', header: 'Tier', render: (r) => r.customer_tier },
    { key: 'amc_contract_value_rupees', header: 'AMC Value (₹)', render: (r) => r.amc_contract_value_rupees.toLocaleString('en-IN') },
    { key: 'model_version', header: 'Model', render: (r) => r.model_version },
    { key: 'predicted_renewal_probability', header: 'Predicted %', render: (r) => (r.predicted_renewal_probability * 100).toFixed(1) + '%' },
    { key: 'predicted_outcome', header: 'Predicted', render: (r) => r.predicted_outcome },
    { key: 'confidence_score', header: 'Confidence', render: (r) => (r.confidence_score * 100).toFixed(0) + '%' },
    { key: 'renewal_due_date', header: 'Due Date', render: (r) => r.renewal_due_date },
    { key: 'actual_outcome', header: 'Actual', render: (r) => r.actual_outcome ?? 'pending' },
    { key: 'prediction_correct', header: 'Correct?', render: (r) => r.prediction_correct === null ? '—' : r.prediction_correct ? 'Yes' : 'No' },
  ];

  const segCols: Column<SegmentAccuracy>[] = [
    { key: 'customer_segment', header: 'Segment', render: (r) => r.customer_segment },
    { key: 'total_predictions', header: 'Total', render: (r) => r.total_predictions },
    { key: 'resolved_predictions', header: 'Resolved', render: (r) => r.resolved_predictions },
    { key: 'correct_predictions', header: 'Correct', render: (r) => r.correct_predictions },
    { key: 'accuracy_pct', header: 'Accuracy %', render: (r) => r.accuracy_pct === null ? '—' : r.accuracy_pct + '%' },
    { key: 'avg_predicted_prob', header: 'Avg Predicted', render: (r) => r.avg_predicted_prob === null ? '—' : (r.avg_predicted_prob * 100).toFixed(1) + '%' },
    { key: 'renewal_rate_pct', header: 'Renewal Rate', render: (r) => r.renewal_rate_pct === null ? '—' : r.renewal_rate_pct + '%' },
  ];

  const modelCols: Column<ModelAccuracy>[] = [
    { key: 'model_version', header: 'Version', render: (r) => r.model_version },
    { key: 'total_predictions', header: 'Total', render: (r) => r.total_predictions },
    { key: 'resolved_predictions', header: 'Resolved', render: (r) => r.resolved_predictions },
    { key: 'accuracy_pct', header: 'Accuracy %', render: (r) => r.accuracy_pct === null ? '—' : r.accuracy_pct + '%' },
    { key: 'avg_confidence', header: 'Avg Confidence', render: (r) => r.avg_confidence === null ? '—' : (r.avg_confidence * 100).toFixed(0) + '%' },
    { key: 'earliest_prediction', header: 'First Used', render: (r) => r.earliest_prediction ?? '—' },
    { key: 'latest_prediction', header: 'Last Used', render: (r) => r.latest_prediction ?? '—' },
  ];

  const refineCols: Column<Refinement>[] = [
    { key: 'deployed_at', header: 'Deployed', render: (r) => new Date(r.deployed_at).toLocaleDateString('en-IN') },
    { key: 'model_version', header: 'Version', render: (r) => r.model_version },
    { key: 'previous_version', header: 'From', render: (r) => r.previous_version ?? '—' },
    { key: 'refinement_type', header: 'Type', render: (r) => r.refinement_type },
    { key: 'trigger_reason', header: 'Trigger', render: (r) => r.trigger_reason },
    { key: 'refinement_summary', header: 'Summary', render: (r) => r.refinement_summary },
    { key: 'prior_accuracy_pct', header: 'Prior %', render: (r) => r.prior_accuracy_pct === null ? '—' : r.prior_accuracy_pct + '%' },
    { key: 'new_accuracy_pct', header: 'New %', render: (r) => r.new_accuracy_pct === null ? '—' : r.new_accuracy_pct + '%' },
    { key: 'accuracy_delta', header: 'Δ', render: (r) => r.accuracy_delta === null ? '—' : (r.accuracy_delta >= 0 ? '+' : '') + r.accuracy_delta + '%' },
    { key: 'training_sample_size', header: 'Samples', render: (r) => r.training_sample_size.toLocaleString('en-IN') },
    { key: 'refined_by_email', header: 'By', render: (r) => r.refined_by_email },
  ];

  return (
    <main className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Customer Renewal Prediction Model Accuracy</h1>
        <p className="text-sm text-gray-600 mt-1">Predicted renewal % vs actual outcome, accuracy by segment & model, refinement log.</p>
      </div>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Total Predictions</div>
            <div className="text-2xl font-semibold">{summary.total_predictions}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Overall Accuracy</div>
            <div className="text-2xl font-semibold">{summary.overall_accuracy_pct === null ? '—' : summary.overall_accuracy_pct + '%'}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">High-Confidence Accuracy</div>
            <div className="text-2xl font-semibold">{summary.high_confidence_correct_pct === null ? '—' : summary.high_confidence_correct_pct + '%'}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">AMC Value At Risk</div>
            <div className="text-2xl font-semibold">₹{summary.total_amc_value_at_risk.toLocaleString('en-IN')}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Pending Outcomes</div>
            <div className="text-2xl font-semibold">{summary.pending_outcome}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Resolved Outcomes</div>
            <div className="text-2xl font-semibold">{summary.resolved_outcome}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Avg Predicted Prob</div>
            <div className="text-2xl font-semibold">{summary.avg_predicted_prob === null ? '—' : (summary.avg_predicted_prob * 100).toFixed(1) + '%'}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Active Model</div>
            <div className="text-lg font-semibold">{summary.active_model_version ?? '—'}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Accuracy by Customer Segment</h2>
        <DataTable<SegmentAccuracy>
          rows={segments}
          columns={segCols}
          rowKey={(r) => r.customer_segment}
          emptyMessage="No segment data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Accuracy by Model Version</h2>
        <DataTable<ModelAccuracy>
          rows={models}
          columns={modelCols}
          rowKey={(r) => r.model_version}
          emptyMessage="No model versions logged."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Predictions vs Actual Outcomes</h2>
        <DataTable<Prediction>
          rows={predictions}
          columns={predCols}
          rowKey={(r) => r.id}
          emptyMessage="No predictions recorded."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Model Refinement Log</h2>
        <DataTable<Refinement>
          rows={refinements}
          columns={refineCols}
          rowKey={(r) => r.id}
          emptyMessage="No refinements logged."
        />
      </section>
    </main>
  );
}