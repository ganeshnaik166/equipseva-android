import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Kpi = {
  active_vip_count: number;
  tier_a_plus_count: number;
  strategic_count: number;
  total_acv_rupees: number;
  avg_acv_rupees: number;
  founder_calls_30d: number;
  exec_reviews_90d: number;
  nps_surveys_90d: number;
  avg_nps_90d: number;
  promoters_90d: number;
  detractors_90d: number;
  passives_90d: number;
  missed_founder_call_count: number;
  missed_exec_review_count: number;
  missed_nps_count: number;
  at_risk_account_count: number;
};

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpiRes, accountsRes, missedRes, recentRes, npsRes, tierRes, riskRes] = await Promise.all([
    supabase.rpc('founder_vip_concierge_kpis'),
    supabase.rpc('founder_vip_concierge_accounts'),
    supabase.rpc('founder_vip_concierge_missed_touches'),
    supabase.rpc('founder_vip_concierge_recent_touchpoints'),
    supabase.rpc('founder_vip_concierge_nps_trend'),
    supabase.rpc('founder_vip_concierge_tier_mix'),
    supabase.rpc('founder_vip_concierge_at_risk'),
  ]);

  const k: Kpi = (kpiRes.data?.[0] ?? {
    active_vip_count: 0, tier_a_plus_count: 0, strategic_count: 0,
    total_acv_rupees: 0, avg_acv_rupees: 0,
    founder_calls_30d: 0, exec_reviews_90d: 0, nps_surveys_90d: 0,
    avg_nps_90d: 0, promoters_90d: 0, detractors_90d: 0, passives_90d: 0,
    missed_founder_call_count: 0, missed_exec_review_count: 0, missed_nps_count: 0,
    at_risk_account_count: 0,
  }) as Kpi;

  const surveys = k.promoters_90d + k.passives_90d + k.detractors_90d;
  const npsIndex = surveys > 0
    ? Math.round(((k.promoters_90d - k.detractors_90d) / surveys) * 1000) / 10
    : 0;

  const cards: { label: string; value: string; sub?: string }[] = [
    { label: 'Active VIP accounts', value: String(k.active_vip_count) },
    { label: 'Tier A+ accounts', value: String(k.tier_a_plus_count) },
    { label: 'Strategic accounts', value: String(k.strategic_count) },
    { label: 'Total ACV', value: formatRupees(k.total_acv_rupees) },
    { label: 'Avg ACV', value: formatRupees(k.avg_acv_rupees) },
    { label: 'Founder calls 30d', value: String(k.founder_calls_30d) },
    { label: 'Exec reviews 90d', value: String(k.exec_reviews_90d) },
    { label: 'NPS surveys 90d', value: String(k.nps_surveys_90d) },
    { label: 'Avg NPS 90d', value: k.avg_nps_90d ? String(k.avg_nps_90d) : '0' },
    { label: 'NPS index', value: String(npsIndex) },
    { label: 'Promoters 90d', value: String(k.promoters_90d) },
    { label: 'Detractors 90d', value: String(k.detractors_90d) },
    { label: 'Missed founder calls', value: String(k.missed_founder_call_count) },
    { label: 'Missed exec reviews', value: String(k.missed_exec_review_count) },
    { label: 'Missed NPS surveys', value: String(k.missed_nps_count) },
    { label: 'At-risk accounts', value: String(k.at_risk_account_count) },
  ];

  return (
    <div className="p-4 md:p-6 space-y-6">
      <header className="space-y-1">
        <div className="text-xs uppercase tracking-wider text-neutral-500">r1450 · Revenue</div>
        <h1 className="text-2xl md:text-3xl font-semibold">VIP customer concierge tracker</h1>
        <p className="text-sm text-neutral-600 max-w-3xl">
          Tier-A hospital chains get white-glove SLAs. Track founder calls, executive reviews, and NPS surveys against cadence. Anything older than the configured cadence is flagged as a missed touch.
        </p>
      </header>

      <section>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {cards.map((c) => (
            <div key={c.label} className="rounded-xl border border-neutral-200 bg-white p-3">
              <div className="text-[11px] uppercase tracking-wide text-neutral-500">{c.label}</div>
              <div className="mt-1 text-xl font-semibold tabular-nums">{c.value}</div>
              {c.sub ? <div className="text-xs text-neutral-500 mt-0.5">{c.sub}</div> : null}
            </div>
          ))}
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">VIP account roster</h2>
        <p className="text-xs text-neutral-500">Health column: at_risk {"<"} overdue {"<"} healthy {"<"} promoter.</p>
        <DataTable
          rows={accountsRes.data ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'c1', header: 'Account', render: (r: any) => r.organization_name },
            { key: 'c2', header: 'Tier', render: (r: any) => r.tier },
            { key: 'c3', header: 'ACV', render: (r: any) => formatRupees(r.annual_contract_value_rupees ?? 0) },
            { key: 'c4', header: 'Owner', render: (r: any) => r.assigned_founder ?? '—' },
            { key: 'c5', header: 'Call cadence (d)', render: (r: any) => r.founder_call_cadence_days },
            { key: 'c6', header: 'Last call', render: (r: any) => r.last_founder_call ? new Date(r.last_founder_call).toLocaleDateString() : '—' },
            { key: 'c7', header: 'Call overdue (d)', render: (r: any) => r.founder_call_overdue_days ?? 0 },
            { key: 'c8', header: 'Last review', render: (r: any) => r.last_exec_review ? new Date(r.last_exec_review).toLocaleDateString() : '—' },
            { key: 'c9', header: 'Last NPS', render: (r: any) => r.last_nps_score ?? '—' },
            { key: 'c10', header: 'Health', render: (r: any) => r.health },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Missed touches</h2>
        <p className="text-xs text-neutral-500">Cadence breached. Sorted by days overdue then ACV.</p>
        <DataTable
          rows={missedRes.data ?? []}
          rowKey={(r: any) => `${r.id}-${r.touchpoint_kind}`}
          columns={[
            { key: 'c11', header: 'Account', render: (r: any) => r.organization_name },
            { key: 'c12', header: 'Tier', render: (r: any) => r.tier },
            { key: 'c13', header: 'Kind', render: (r: any) => r.touchpoint_kind },
            { key: 'c14', header: 'Cadence (d)', render: (r: any) => r.cadence_days },
            { key: 'c15', header: 'Last touch', render: (r: any) => r.last_touch ? new Date(r.last_touch).toLocaleDateString() : 'never' },
            { key: 'c16', header: 'Days overdue', render: (r: any) => r.days_overdue },
            { key: 'c17', header: 'ACV', render: (r: any) => formatRupees(r.acv_rupees ?? 0) },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">At-risk accounts</h2>
        <p className="text-xs text-neutral-500">NPS detractor or manually flagged concern/at_risk on last touchpoint.</p>
        <DataTable
          rows={riskRes.data ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'c18', header: 'Account', render: (r: any) => r.organization_name },
            { key: 'c19', header: 'Tier', render: (r: any) => r.tier },
            { key: 'c20', header: 'ACV', render: (r: any) => formatRupees(r.acv_rupees ?? 0) },
            { key: 'c21', header: 'Last NPS', render: (r: any) => r.last_nps_score ?? '—' },
            { key: 'c22', header: 'Last outcome', render: (r: any) => r.last_outcome ?? '—' },
            { key: 'c23', header: 'Reason', render: (r: any) => r.reason },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent touchpoints</h2>
        <p className="text-xs text-neutral-500">Last 60 logged touchpoints across all VIP accounts.</p>
        <DataTable
          rows={recentRes.data ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'c24', header: 'When', render: (r: any) => new Date(r.occurred_at).toLocaleString() },
            { key: 'c25', header: 'Account', render: (r: any) => r.organization_name },
            { key: 'c26', header: 'Tier', render: (r: any) => r.tier },
            { key: 'c27', header: 'Kind', render: (r: any) => r.touchpoint_kind },
            { key: 'c28', header: 'NPS', render: (r: any) => r.nps_score ?? '—' },
            { key: 'c29', header: 'Minutes', render: (r: any) => r.duration_minutes ?? '—' },
            { key: 'c30', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
            { key: 'c31', header: 'By', render: (r: any) => r.recorded_by ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">NPS trend by month</h2>
        <p className="text-xs text-neutral-500">12-month rolling. NPS index = % promoters minus % detractors.</p>
        <DataTable
          rows={npsRes.data ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'c32', header: 'Month', render: (r: any) => r.month_label },
            { key: 'c33', header: 'Surveys', render: (r: any) => r.survey_count },
            { key: 'c34', header: 'Avg NPS', render: (r: any) => r.avg_nps ?? '—' },
            { key: 'c35', header: 'Promoters', render: (r: any) => r.promoters },
            { key: 'c36', header: 'Passives', render: (r: any) => r.passives },
            { key: 'c37', header: 'Detractors', render: (r: any) => r.detractors },
            { key: 'c38', header: 'NPS index', render: (r: any) => r.nps_index ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Touch mix by tier</h2>
        <DataTable
          rows={tierRes.data ?? []}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'c39', header: 'Tier', render: (r: any) => r.tier },
            { key: 'c40', header: 'Active accounts', render: (r: any) => r.active_accounts },
            { key: 'c41', header: 'ACV', render: (r: any) => formatRupees(r.acv_rupees ?? 0) },
            { key: 'c42', header: 'Founder calls 90d', render: (r: any) => r.founder_calls_90d },
            { key: 'c43', header: 'Exec reviews 90d', render: (r: any) => r.exec_reviews_90d },
            { key: 'c44', header: 'NPS surveys 90d', render: (r: any) => r.nps_surveys_90d },
            { key: 'c45', header: 'Avg NPS 90d', render: (r: any) => r.avg_nps_90d ?? '—' },
          ]}
        />
      </section>
    </div>
  );
}
