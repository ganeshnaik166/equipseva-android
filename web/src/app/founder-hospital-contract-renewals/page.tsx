import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-3">
      <div className="text-[11px] uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-slate-900">{value}</div>
    </div>
  );
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, queueRes, ladderRes, postmortemRes, silentRes, lossRes, rungRes] = await Promise.all([
    sb.rpc('founder_renewal_kpis'),
    sb.rpc('founder_renewal_queue'),
    sb.rpc('founder_renewal_action_ladder'),
    sb.rpc('founder_renewal_postmortem_log'),
    sb.rpc('founder_renewal_silent_contracts'),
    sb.rpc('founder_renewal_loss_reasons'),
    sb.rpc('founder_renewal_rung_distribution'),
  ]);

  const k = (kpisRes.data?.[0] ?? {}) as any;
  const queue = (queueRes.data ?? []) as any[];
  const ladder = (ladderRes.data ?? []) as any[];
  const postmortems = (postmortemRes.data ?? []) as any[];
  const silent = (silentRes.data ?? []) as any[];
  const lossReasons = (lossRes.data ?? []) as any[];
  const rungs = (rungRes.data ?? []) as any[];

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 space-y-6">
      <header>
        <div className="text-xs uppercase tracking-wider text-slate-500">Revenue · r1462</div>
        <h1 className="text-2xl font-semibold text-slate-900">Hospital Contract Renewals Queue</h1>
        <p className="text-sm text-slate-600 mt-1">All AMC contracts due in the next 90 days, with renewal-likelihood, founder action ladder, and lost-renewal post-mortems.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Due 90d" value={k.contracts_due_90d ?? 0} />
        <Kpi label="Due 30d" value={k.contracts_due_30d ?? 0} />
        <Kpi label="Due 7d" value={k.contracts_due_7d ?? 0} />
        <Kpi label="Overdue" value={k.contracts_overdue ?? 0} />
        <Kpi label="ARR at risk" value={formatRupees(k.arr_at_risk_rupees ?? 0)} />
        <Kpi label="ARR due 30d" value={formatRupees(k.arr_due_30d_rupees ?? 0)} />
        <Kpi label="High likelihood" value={k.high_likelihood_count ?? 0} />
        <Kpi label="Med likelihood" value={k.med_likelihood_count ?? 0} />
        <Kpi label="Low likelihood" value={k.low_likelihood_count ?? 0} />
        <Kpi label="Actions 30d" value={k.actions_logged_30d ?? 0} />
        <Kpi label="Postmortems 30d" value={k.postmortems_30d ?? 0} />
        <Kpi label="Preventable losses 30d" value={k.preventable_losses_30d ?? 0} />
        <Kpi label="Avg likelihood %" value={String(k.avg_likelihood_pct ?? 0)} />
        <Kpi label="At-risk orgs" value={k.total_at_risk_orgs ?? 0} />
        <Kpi label="Silent orgs" value={k.silent_orgs_count ?? 0} />
        <Kpi label="Escalations pending" value={k.escalations_pending ?? 0} />
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-2">Renewal queue (next 90 days)</h2>
        <DataTable
          rows={queue}
          rowKey={(r: any) => r.contract_id}
          columns={[
            { key: 'org', header: 'Organization', render: (r: any) => <span className="font-medium">{r.org_name}</span> },
            { key: 'city', header: 'City', render: (r: any) => r.org_city ?? '—' },
            { key: 'tier', header: 'Tier', render: (r: any) => r.amc_tier ?? '—' },
            { key: 'end_date', header: 'Expires', render: (r: any) => r.end_date },
            { key: 'days', header: 'Days left', render: (r: any) => r.days_to_expiry },
            { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
            { key: 'arr', header: 'Annual value', render: (r: any) => formatRupees(r.annual_value_rupees) },
            { key: 'likelihood', header: 'Likelihood %', render: (r: any) => `${r.likelihood_pct}%` },
            { key: 'last_rung', header: 'Last rung', render: (r: any) => r.last_action_rung ?? 'none' },
            { key: 'last_outcome', header: 'Last outcome', render: (r: any) => r.last_action_outcome ?? '—' },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-2">Silent contracts (no founder action yet)</h2>
        <DataTable
          rows={silent}
          rowKey={(r: any) => r.contract_id}
          columns={[
            { key: 'org', header: 'Organization', render: (r: any) => r.org_name },
            { key: 'city', header: 'City', render: (r: any) => r.org_city ?? '—' },
            { key: 'end_date', header: 'Expires', render: (r: any) => r.end_date },
            { key: 'days', header: 'Days left', render: (r: any) => r.days_to_expiry },
            { key: 'arr', header: 'Annual value', render: (r: any) => formatRupees(r.annual_value_rupees) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-2">Action ladder (recent 100)</h2>
        <DataTable
          rows={ladder}
          rowKey={(r: any) => r.action_id}
          columns={[
            { key: 'org', header: 'Organization', render: (r: any) => r.org_name },
            { key: 'rung', header: 'Rung', render: (r: any) => r.rung },
            { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? 'pending' },
            { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
            { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-2">Lost-renewal post-mortems</h2>
        <DataTable
          rows={postmortems}
          rowKey={(r: any) => r.postmortem_id}
          columns={[
            { key: 'org', header: 'Organization', render: (r: any) => r.org_name },
            { key: 'reason', header: 'Reason', render: (r: any) => r.loss_reason },
            { key: 'competitor', header: 'Competitor', render: (r: any) => r.competitor_name ?? '—' },
            { key: 'gap', header: 'Price gap', render: (r: any) => r.price_gap_rupees != null ? formatRupees(r.price_gap_rupees) : '—' },
            { key: 'preventable', header: 'Preventable', render: (r: any) => r.preventable ? 'yes' : 'no' },
            { key: 'lessons', header: 'Lessons', render: (r: any) => r.lessons_learned ?? '—' },
            { key: 'when', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleDateString() },
          ]}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold text-slate-900 mb-2">Loss-reason rollup</h2>
          <DataTable
            rows={lossReasons}
            rowKey={(r: any) => r.loss_reason}
            columns={[
              { key: 'reason', header: 'Reason', render: (r: any) => r.loss_reason },
              { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
              { key: 'preventable', header: 'Preventable', render: (r: any) => r.preventable_cnt },
              { key: 'arr', header: 'ARR lost', render: (r: any) => formatRupees(r.total_arr_lost_rupees) },
            ]}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold text-slate-900 mb-2">Rung distribution (90d)</h2>
          <DataTable
            rows={rungs}
            rowKey={(r: any) => r.rung}
            columns={[
              { key: 'rung', header: 'Rung', render: (r: any) => r.rung },
              { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
              { key: 'promised', header: 'Promised', render: (r: any) => r.promised_cnt },
              { key: 'silent', header: 'Silent', render: (r: any) => r.silent_cnt },
            ]}
          />
        </div>
      </section>

      <p className="text-xs text-slate-500">Founder-only. Likelihood is heuristic: 60 base, +25 if last outcome promised_renew, -30 if will_not_renew or silent, clamped 5..95.</p>
    </div>
  );
}
