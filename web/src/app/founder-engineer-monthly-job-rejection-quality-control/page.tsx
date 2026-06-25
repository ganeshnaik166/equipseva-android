import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { total_rejections: number; valid_rejections: number; override_count: number; policy_adjusts: number; avoided_est: number };
type ByReason = { rejection_reason: string; total: number; valid_count: number; invalid_count: number; override_count: number };
type ByEngineer = { engineer_code: string; engineer_name: string; total: number; valid_pct: number | null; override_pct: number | null };
type Invalid = { job_code: string; engineer_name: string; rejection_reason: string; outcome: string; override_actor: string | null; rejected_at: string };
type OverrideOutcome = { outcome: string; total: number };
type Policy = { policy_area: string; prior_threshold: string; new_threshold: string; trigger_reason: string; rejections_avoided_est: number; approved_by: string; effective_at: string };
type Flagged = { job_code: string; engineer_name: string; rejection_reason: string; policy_adjust_note: string | null; rejected_at: string };
type Recent = { job_code: string; engineer_name: string; rejection_reason: string; reason_valid: boolean; override_applied: boolean; outcome: string; rejected_at: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiR, reasonR, engR, invalidR, overrideR, policyR, flaggedR, recentR] = await Promise.all([
    supabase.rpc('founder_r2786_rejection_kpis'),
    supabase.rpc('founder_r2786_rejections_by_reason'),
    supabase.rpc('founder_r2786_rejections_by_engineer'),
    supabase.rpc('founder_r2786_invalid_rejection_list'),
    supabase.rpc('founder_r2786_override_outcomes'),
    supabase.rpc('founder_r2786_policy_adjusts'),
    supabase.rpc('founder_r2786_flagged_for_review'),
    supabase.rpc('founder_r2786_recent_rejections'),
  ]);

  const kpi: Kpi = (kpiR.data?.[0] as Kpi) ?? { total_rejections: 0, valid_rejections: 0, override_count: 0, policy_adjusts: 0, avoided_est: 0 };
  const byReason: ByReason[] = (reasonR.data as ByReason[]) ?? [];
  const byEngineer: ByEngineer[] = (engR.data as ByEngineer[]) ?? [];
  const invalids: Invalid[] = (invalidR.data as Invalid[]) ?? [];
  const overrides: OverrideOutcome[] = (overrideR.data as OverrideOutcome[]) ?? [];
  const policies: Policy[] = (policyR.data as Policy[]) ?? [];
  const flagged: Flagged[] = (flaggedR.data as Flagged[]) ?? [];
  const recent: Recent[] = (recentR.data as Recent[]) ?? [];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-8">
      <header>
        <h1 className="text-3xl font-bold">Engineer Monthly Job Rejection Quality Control</h1>
        <p className="text-gray-600 mt-2">Audit engineer rejections: reason validity, override outcomes, and triggered policy adjustments.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <KpiCard label="Total Rejections" value={kpi.total_rejections} />
        <KpiCard label="Valid Rejections" value={kpi.valid_rejections} />
        <KpiCard label="Overrides Applied" value={kpi.override_count} />
        <KpiCard label="Policy Adjusts" value={kpi.policy_adjusts} />
        <KpiCard label="Avoided (est)" value={kpi.avoided_est} />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Rejections by Reason</h2>
        <DataTable
          rows={byReason}
          columns={[
            { key: 'rejection_reason', header: 'Reason', render: (r: ByReason) => r.rejection_reason },
            { key: 'total', header: 'Total', render: (r: ByReason) => r.total },
            { key: 'valid_count', header: 'Valid', render: (r: ByReason) => r.valid_count },
            { key: 'invalid_count', header: 'Invalid', render: (r: ByReason) => r.invalid_count },
            { key: 'override_count', header: 'Overrides', render: (r: ByReason) => r.override_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByReason, i: number) => String(r.rejection_reason ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Rejections by Engineer</h2>
        <DataTable
          rows={byEngineer}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: ByEngineer) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: ByEngineer) => r.engineer_name },
            { key: 'total', header: 'Total', render: (r: ByEngineer) => r.total },
            { key: 'valid_pct', header: 'Valid %', render: (r: ByEngineer) => r.valid_pct ?? '—' },
            { key: 'override_pct', header: 'Override %', render: (r: ByEngineer) => r.override_pct ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByEngineer, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Invalid Rejections (review required)</h2>
        <DataTable
          rows={invalids}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: Invalid) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Invalid) => r.engineer_name },
            { key: 'rejection_reason', header: 'Reason', render: (r: Invalid) => r.rejection_reason },
            { key: 'outcome', header: 'Outcome', render: (r: Invalid) => r.outcome },
            { key: 'override_actor', header: 'Override By', render: (r: Invalid) => r.override_actor ?? '—' },
            { key: 'rejected_at', header: 'When', render: (r: Invalid) => new Date(r.rejected_at).toLocaleString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: Invalid, i: number) => String(r.job_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Override Outcomes</h2>
        <DataTable
          rows={overrides}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OverrideOutcome) => r.outcome },
            { key: 'total', header: 'Total', render: (r: OverrideOutcome) => r.total },
          ]}
          emptyMessage="No data"
          rowKey={(r: OverrideOutcome, i: number) => String(r.outcome ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Policy Adjustments Log</h2>
        <DataTable
          rows={policies}
          columns={[
            { key: 'policy_area', header: 'Area', render: (r: Policy) => r.policy_area },
            { key: 'prior_threshold', header: 'Prior', render: (r: Policy) => r.prior_threshold },
            { key: 'new_threshold', header: 'New', render: (r: Policy) => r.new_threshold },
            { key: 'trigger_reason', header: 'Trigger', render: (r: Policy) => r.trigger_reason },
            { key: 'rejections_avoided_est', header: 'Avoided', render: (r: Policy) => r.rejections_avoided_est },
            { key: 'approved_by', header: 'Approved By', render: (r: Policy) => r.approved_by },
            { key: 'effective_at', header: 'Effective', render: (r: Policy) => new Date(r.effective_at).toLocaleDateString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: Policy, i: number) => String(r.policy_area + r.effective_at ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Flagged for Policy Review</h2>
        <DataTable
          rows={flagged}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: Flagged) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Flagged) => r.engineer_name },
            { key: 'rejection_reason', header: 'Reason', render: (r: Flagged) => r.rejection_reason },
            { key: 'policy_adjust_note', header: 'Note', render: (r: Flagged) => r.policy_adjust_note ?? '—' },
            { key: 'rejected_at', header: 'When', render: (r: Flagged) => new Date(r.rejected_at).toLocaleString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: Flagged, i: number) => String(r.job_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Recent Rejections</h2>
        <DataTable
          rows={recent}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: Recent) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Recent) => r.engineer_name },
            { key: 'rejection_reason', header: 'Reason', render: (r: Recent) => r.rejection_reason },
            { key: 'reason_valid', header: 'Valid', render: (r: Recent) => (r.reason_valid ? 'yes' : 'no') },
            { key: 'override_applied', header: 'Override', render: (r: Recent) => (r.override_applied ? 'yes' : 'no') },
            { key: 'outcome', header: 'Outcome', render: (r: Recent) => r.outcome },
            { key: 'rejected_at', header: 'When', render: (r: Recent) => new Date(r.rejected_at).toLocaleString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: Recent, i: number) => String(r.job_code ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-lg border bg-white p-4">
      <div className="text-sm text-gray-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}
