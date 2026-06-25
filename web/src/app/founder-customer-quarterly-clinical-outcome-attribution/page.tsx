import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_outcomes: number;
  strong_attributions: number;
  public_logo_refs: number;
  avg_delta_pct: number;
  avg_uptime_contribution_pct: number;
  open_followups: number;
};

type Outcome = {
  id: string;
  hospital_name: string;
  hospital_tier: string;
  quarter: string;
  equipment_category: string;
  equipment_model: string;
  clinical_outcome: string;
  outcome_metric_name: string;
  baseline_value: number;
  measured_value: number;
  delta_pct: number;
  uptime_contribution_pct: number;
  attribution_strength: string;
  evidence_type: string;
  follow_up_status: string;
};

type Rollup = {
  id: string;
  hospital_name: string;
  quarter: string;
  outcomes_measured: number;
  outcomes_improved: number;
  outcomes_attributed_strong: number;
  weighted_attribution_score: number;
  evidence_completeness_pct: number;
  reference_willingness: string;
  renewal_signal: string;
  next_qbr_date: string;
};

type Category = {
  equipment_category: string;
  outcomes_count: number;
  strong_count: number;
  avg_delta_pct: number;
  avg_uptime_pct: number;
};

type Quarter = {
  quarter: string;
  outcomes_count: number;
  strong_attribution_count: number;
  avg_delta_pct: number;
  hospitals_covered: number;
};

type Reference = {
  reference_willingness: string;
  hospital_count: number;
  avg_score: number;
  avg_evidence_completeness: number;
};

type Followup = {
  id: string;
  hospital_name: string;
  follow_up_action: string;
  follow_up_owner: string;
  follow_up_due_date: string;
  follow_up_status: string;
  days_until_due: number;
};

type Renewal = {
  renewal_signal: string;
  hospital_count: number;
  avg_attribution_score: number;
  hospitals: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, outcomesRes, rollupRes, categoryRes, quarterRes, referenceRes, followupRes, renewalRes] = await Promise.all([
    supabase.rpc('founder_r2708_kpi_summary'),
    supabase.rpc('founder_r2708_outcomes'),
    supabase.rpc('founder_r2708_rollup'),
    supabase.rpc('founder_r2708_by_category'),
    supabase.rpc('founder_r2708_by_quarter'),
    supabase.rpc('founder_r2708_reference_readiness'),
    supabase.rpc('founder_r2708_followup_queue'),
    supabase.rpc('founder_r2708_renewal_signals'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_outcomes: 0,
    strong_attributions: 0,
    public_logo_refs: 0,
    avg_delta_pct: 0,
    avg_uptime_contribution_pct: 0,
    open_followups: 0,
  }) as Kpi;

  const outcomes: Outcome[] = (outcomesRes.data ?? []) as Outcome[];
  const rollup: Rollup[] = (rollupRes.data ?? []) as Rollup[];
  const categories: Category[] = (categoryRes.data ?? []) as Category[];
  const quarters: Quarter[] = (quarterRes.data ?? []) as Quarter[];
  const references: Reference[] = (referenceRes.data ?? []) as Reference[];
  const followups: Followup[] = (followupRes.data ?? []) as Followup[];
  const renewals: Renewal[] = (renewalRes.data ?? []) as Renewal[];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold tracking-tight">
          Customer quarterly clinical outcome attribution
        </h1>
        <p className="text-sm text-gray-600">
          Quarter-by-quarter ledger of measured clinical outcomes per hospital, weighted by our
          uptime contribution and grounded in evidence and follow-ups. Strong attribution
          unlocks named references and renewal expansion.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
        <KpiCard label="Outcomes tracked" value={String(kpi.total_outcomes)} />
        <KpiCard label="Strong attributions" value={String(kpi.strong_attributions)} />
        <KpiCard label="Public-logo refs" value={String(kpi.public_logo_refs)} />
        <KpiCard label="Avg |delta| %" value={`${Number(kpi.avg_delta_pct).toFixed(1)}%`} />
        <KpiCard label="Avg uptime contrib" value={`${Number(kpi.avg_uptime_contribution_pct).toFixed(1)}%`} />
        <KpiCard label="Open follow-ups" value={String(kpi.open_followups)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Outcomes ledger</h2>
        <p className="text-xs text-gray-500">
          Each row is one equipment-to-outcome attribution. Delta % is measured vs baseline;
          negative means a metric we wanted to reduce (e.g., scan cancellation rate dropped).
        </p>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: Outcome) => r.hospital_name },
            { key: 'quarter', header: 'Quarter', render: (r: Outcome) => r.quarter },
            { key: 'equipment_model', header: 'Equipment', render: (r: Outcome) => r.equipment_model },
            { key: 'clinical_outcome', header: 'Clinical outcome', render: (r: Outcome) => r.clinical_outcome },
            { key: 'outcome_metric_name', header: 'Metric', render: (r: Outcome) => r.outcome_metric_name },
            { key: 'baseline_value', header: 'Baseline', render: (r: Outcome) => Number(r.baseline_value).toFixed(2) },
            { key: 'measured_value', header: 'Measured', render: (r: Outcome) => Number(r.measured_value).toFixed(2) },
            { key: 'delta_pct', header: 'Delta %', render: (r: Outcome) => `${Number(r.delta_pct).toFixed(2)}%` },
            { key: 'uptime_contribution_pct', header: 'Uptime contrib %', render: (r: Outcome) => `${Number(r.uptime_contribution_pct).toFixed(1)}%` },
            { key: 'attribution_strength', header: 'Attribution', render: (r: Outcome) => r.attribution_strength },
            { key: 'evidence_type', header: 'Evidence', render: (r: Outcome) => r.evidence_type },
            { key: 'follow_up_status', header: 'Follow-up', render: (r: Outcome) => r.follow_up_status },
          ]}
          emptyMessage="No outcomes recorded yet"
          rowKey={(r: Outcome, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Per-hospital quarterly rollup</h2>
        <p className="text-xs text-gray-500">
          Weighted attribution score blends outcomes improved, strong attributions, and evidence
          completeness. Score &gt;= 85 typically unlocks public-logo reference rights.
        </p>
        <DataTable
          rows={rollup}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: Rollup) => r.hospital_name },
            { key: 'quarter', header: 'Quarter', render: (r: Rollup) => r.quarter },
            { key: 'outcomes_measured', header: 'Measured', render: (r: Rollup) => String(r.outcomes_measured) },
            { key: 'outcomes_improved', header: 'Improved', render: (r: Rollup) => String(r.outcomes_improved) },
            { key: 'outcomes_attributed_strong', header: 'Strong', render: (r: Rollup) => String(r.outcomes_attributed_strong) },
            { key: 'weighted_attribution_score', header: 'Score', render: (r: Rollup) => Number(r.weighted_attribution_score).toFixed(1) },
            { key: 'evidence_completeness_pct', header: 'Evidence %', render: (r: Rollup) => `${Number(r.evidence_completeness_pct).toFixed(1)}%` },
            { key: 'reference_willingness', header: 'Reference', render: (r: Rollup) => r.reference_willingness },
            { key: 'renewal_signal', header: 'Renewal', render: (r: Rollup) => r.renewal_signal },
            { key: 'next_qbr_date', header: 'Next QBR', render: (r: Rollup) => r.next_qbr_date },
          ]}
          emptyMessage="No rollups computed yet"
          rowKey={(r: Rollup, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-semibold">By equipment category</h2>
          <DataTable
            rows={categories}
            columns={[
              { key: 'equipment_category', header: 'Category', render: (r: Category) => r.equipment_category },
              { key: 'outcomes_count', header: 'Outcomes', render: (r: Category) => String(r.outcomes_count) },
              { key: 'strong_count', header: 'Strong', render: (r: Category) => String(r.strong_count) },
              { key: 'avg_delta_pct', header: 'Avg delta %', render: (r: Category) => `${Number(r.avg_delta_pct).toFixed(1)}%` },
              { key: 'avg_uptime_pct', header: 'Avg uptime %', render: (r: Category) => `${Number(r.avg_uptime_pct).toFixed(1)}%` },
            ]}
            emptyMessage="No category data"
            rowKey={(r: Category, i: number) => String(r.equipment_category ?? i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-semibold">By quarter</h2>
          <DataTable
            rows={quarters}
            columns={[
              { key: 'quarter', header: 'Quarter', render: (r: Quarter) => r.quarter },
              { key: 'outcomes_count', header: 'Outcomes', render: (r: Quarter) => String(r.outcomes_count) },
              { key: 'strong_attribution_count', header: 'Strong', render: (r: Quarter) => String(r.strong_attribution_count) },
              { key: 'avg_delta_pct', header: 'Avg delta %', render: (r: Quarter) => `${Number(r.avg_delta_pct).toFixed(1)}%` },
              { key: 'hospitals_covered', header: 'Hospitals', render: (r: Quarter) => String(r.hospitals_covered) },
            ]}
            emptyMessage="No quarter data"
            rowKey={(r: Quarter, i: number) => String(r.quarter ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Reference readiness</h2>
        <p className="text-xs text-gray-500">
          What fraction of the customer base is willing to be quoted publicly. Public-logo and
          named-quote tiers are the fuel for sales and investor decks.
        </p>
        <DataTable
          rows={references}
          columns={[
            { key: 'reference_willingness', header: 'Willingness', render: (r: Reference) => r.reference_willingness },
            { key: 'hospital_count', header: 'Hospitals', render: (r: Reference) => String(r.hospital_count) },
            { key: 'avg_score', header: 'Avg score', render: (r: Reference) => Number(r.avg_score).toFixed(1) },
            { key: 'avg_evidence_completeness', header: 'Avg evidence %', render: (r: Reference) => `${Number(r.avg_evidence_completeness).toFixed(1)}%` },
          ]}
          emptyMessage="No reference data"
          rowKey={(r: Reference, i: number) => String(r.reference_willingness ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Follow-up queue</h2>
        <p className="text-xs text-gray-500">
          Open work items per outcome. Negative days-until-due means overdue.
        </p>
        <DataTable
          rows={followups}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: Followup) => r.hospital_name },
            { key: 'follow_up_action', header: 'Action', render: (r: Followup) => r.follow_up_action },
            { key: 'follow_up_owner', header: 'Owner', render: (r: Followup) => r.follow_up_owner },
            { key: 'follow_up_due_date', header: 'Due', render: (r: Followup) => r.follow_up_due_date },
            { key: 'days_until_due', header: 'Days', render: (r: Followup) => String(r.days_until_due) },
            { key: 'follow_up_status', header: 'Status', render: (r: Followup) => r.follow_up_status },
          ]}
          emptyMessage="No open follow-ups"
          rowKey={(r: Followup, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Renewal signals</h2>
        <p className="text-xs text-gray-500">
          Pipeline view of which accounts are strong-yes vs at-risk going into renewal QBRs.
        </p>
        <DataTable
          rows={renewals}
          columns={[
            { key: 'renewal_signal', header: 'Signal', render: (r: Renewal) => r.renewal_signal },
            { key: 'hospital_count', header: 'Hospitals', render: (r: Renewal) => String(r.hospital_count) },
            { key: 'avg_attribution_score', header: 'Avg score', render: (r: Renewal) => Number(r.avg_attribution_score).toFixed(1) },
            { key: 'hospitals', header: 'Accounts', render: (r: Renewal) => r.hospitals },
          ]}
          emptyMessage="No renewal data"
          rowKey={(r: Renewal, i: number) => String(r.renewal_signal ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
