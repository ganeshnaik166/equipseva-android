import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';
import type { ReactNode } from 'react';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-3">
      <div className="text-[11px] uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-slate-900">{value}</div>
    </div>
  );
}

export default async function FounderEngineerCareerLadderPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  await supabase.rpc('log_founder_rung_view');

  const [defRes, kpiRes, curRes, distRes, gapRes, promoRes, assessRes] = await Promise.all([
    supabase.rpc('founder_career_ladder_definition'),
    supabase.rpc('founder_career_ladder_kpis'),
    supabase.rpc('founder_career_ladder_engineer_current'),
    supabase.rpc('founder_career_ladder_distribution'),
    supabase.rpc('founder_career_ladder_gap_analysis'),
    supabase.rpc('founder_career_ladder_recent_promotions'),
    supabase.rpc('founder_career_ladder_recent_assessments'),
  ]);

  const defs = (defRes.data ?? []) as any[];
  const kpi = ((kpiRes.data ?? [])[0] ?? {}) as any;
  const current = (curRes.data ?? []) as any[];
  const distribution = (distRes.data ?? []) as any[];
  const gaps = (gapRes.data ?? []) as any[];
  const promotions = (promoRes.data ?? []) as any[];
  const assessments = (assessRes.data ?? []) as any[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4">
      <header>
        <h1 className="text-2xl font-semibold text-slate-900">Engineer Career Ladder</h1>
        <p className="text-sm text-slate-600">
          T0 {"→"} T6 progression rungs, current placement, and readiness gap analysis. Founder-only.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total engineers" value={kpi.total_engineers ?? 0} />
        <Kpi label="T0 trainees" value={kpi.t0_count ?? 0} />
        <Kpi label="T1 junior" value={kpi.t1_count ?? 0} />
        <Kpi label="T2 field" value={kpi.t2_count ?? 0} />
        <Kpi label="T3 senior" value={kpi.t3_count ?? 0} />
        <Kpi label="T4 specialist" value={kpi.t4_count ?? 0} />
        <Kpi label="T5 principal" value={kpi.t5_count ?? 0} />
        <Kpi label="T6 master" value={kpi.t6_count ?? 0} />
        <Kpi label="Avg readiness %" value={Number(kpi.avg_readiness ?? 0).toFixed(1)} />
        <Kpi label="Ready for promotion" value={kpi.ready_for_promotion ?? 0} />
        <Kpi label="Promotions 30d" value={kpi.promotions_30d ?? 0} />
        <Kpi label="Monthly payroll" value={formatRupees(Number(kpi.total_payroll_rupees ?? 0))} />
        <Kpi label="Pending assessments" value={kpi.pending_assessments ?? 0} />
        <Kpi label="Certified engineers" value={kpi.certified_engineers ?? 0} />
        <Kpi label="Avg rating (all)" value={Number(kpi.avg_rating_all ?? 0).toFixed(2)} />
        <Kpi label="Median rung order" value={Number(kpi.median_rung_order ?? 0).toFixed(1)} />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-800">Ladder definition (T0 {"→"} T6)</h2>
        <DataTable
          rows={defs}
          rowKey={(r: any) => r.rung_code}
          columns={[
            { key: 'rung_code', header: 'Rung', render: (r: any) => <span className="font-mono">{r.rung_code}</span> },
            { key: 'rung_name', header: 'Name', render: (r: any) => r.rung_name },
            { key: 'min_completed_jobs', header: 'Min jobs', render: (r: any) => r.min_completed_jobs },
            { key: 'min_avg_rating', header: 'Min rating', render: (r: any) => Number(r.min_avg_rating ?? 0).toFixed(2) },
            { key: 'min_amc_attached', header: 'Min AMC', render: (r: any) => r.min_amc_attached },
            { key: 'min_certifications', header: 'Min certs', render: (r: any) => r.min_certifications },
            { key: 'base_monthly_stipend_rupees', header: 'Stipend', render: (r: any) => formatRupees(Number(r.base_monthly_stipend_rupees ?? 0)) },
            { key: 'per_job_bonus_rupees', header: 'Per-job bonus', render: (r: any) => formatRupees(Number(r.per_job_bonus_rupees ?? 0)) },
            { key: 'description', header: 'Description', render: (r: any) => <span className="text-slate-600">{r.description}</span> },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-800">Rung distribution</h2>
        <DataTable
          rows={distribution}
          rowKey={(r: any) => r.rung_code}
          columns={[
            { key: 'rung_code', header: 'Rung', render: (r: any) => <span className="font-mono">{r.rung_code}</span> },
            { key: 'rung_name', header: 'Name', render: (r: any) => r.rung_name },
            { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
            { key: 'pct_share', header: 'Share %', render: (r: any) => `${Number(r.pct_share ?? 0).toFixed(1)}%` },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-800">Current placement (top 500)</h2>
        <DataTable
          rows={current}
          rowKey={(r: any) => r.engineer_id}
          columns={[
            { key: 'display_name', header: 'Engineer', render: (r: any) => r.display_name },
            { key: 'current_rung', header: 'Rung', render: (r: any) => <span className="font-mono">{r.current_rung}</span> },
            { key: 'completed_jobs', header: 'Jobs done', render: (r: any) => r.completed_jobs },
            { key: 'avg_rating', header: 'Avg rating', render: (r: any) => Number(r.avg_rating ?? 0).toFixed(2) },
            { key: 'amc_attached', header: 'AMC active', render: (r: any) => r.amc_attached },
            { key: 'city', header: 'City', render: (r: any) => r.city },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-800">Gap analysis — readiness for next rung</h2>
        <DataTable
          rows={gaps}
          rowKey={(r: any) => r.engineer_id}
          columns={[
            { key: 'display_name', header: 'Engineer', render: (r: any) => r.display_name },
            { key: 'current_rung', header: 'Current', render: (r: any) => <span className="font-mono">{r.current_rung}</span> },
            { key: 'next_rung', header: 'Next', render: (r: any) => <span className="font-mono">{r.next_rung}</span> },
            { key: 'jobs_done', header: 'Jobs done', render: (r: any) => r.jobs_done },
            { key: 'jobs_required', header: 'Jobs req', render: (r: any) => r.jobs_required },
            { key: 'jobs_gap', header: 'Jobs gap', render: (r: any) => r.jobs_gap },
            { key: 'avg_rating', header: 'Rating', render: (r: any) => Number(r.avg_rating ?? 0).toFixed(2) },
            { key: 'rating_required', header: 'Rating req', render: (r: any) => Number(r.rating_required ?? 0).toFixed(2) },
            { key: 'readiness_pct', header: 'Readiness %', render: (r: any) => `${Number(r.readiness_pct ?? 0).toFixed(1)}%` },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-800">Recent assessments</h2>
        <DataTable
          rows={assessments}
          rowKey={(r: any) => r.assessment_id}
          columns={[
            { key: 'engineer_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_id ?? '').slice(0, 8)}</span> },
            { key: 'current_rung', header: 'Current', render: (r: any) => r.current_rung },
            { key: 'target_rung', header: 'Target', render: (r: any) => r.target_rung },
            { key: 'readiness_pct', header: 'Readiness %', render: (r: any) => `${Number(r.readiness_pct ?? 0).toFixed(1)}%` },
            { key: 'assessed_at', header: 'Assessed', render: (r: any) => new Date(r.assessed_at).toLocaleString() },
            { key: 'notes', header: 'Notes', render: (r: any) => <span className="text-slate-600">{r.notes ?? '—'}</span> },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-800">Recent promotions (50)</h2>
        <DataTable
          rows={promotions}
          rowKey={(r: any) => r.event_id}
          columns={[
            { key: 'engineer_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_id ?? '').slice(0, 8)}</span> },
            { key: 'from_rung', header: 'From', render: (r: any) => r.from_rung },
            { key: 'to_rung', header: 'To', render: (r: any) => r.to_rung },
            { key: 'promoted_at', header: 'Promoted at', render: (r: any) => new Date(r.promoted_at).toLocaleString() },
          ]}
        />
      </section>
    </div>
  );
}
