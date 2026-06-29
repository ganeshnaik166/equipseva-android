import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type QuarterSummary = { quarter_label: string; total_bonus_rupees: number; paid_count: number; pending_count: number; clawback_count: number; avg_quality: number };
type TierRow = { referrer_tier: string; referrer_count: number; total_bonus_rupees: number; avg_quality: number; paid_share_pct: number };
type SpecialtyRow = { recruit_specialty: string; recruit_count: number; avg_bonus_rupees: number; avg_quality: number };
type ClawbackRow = { quarter_label: string; referrer_name: string; recruit_name: string; recruit_city: string; quality_score: number; bonus_rupees: number; bonus_status: string };
type FindingRow = { quarter_label: string; finding_category: string; severity: string; metric_value: number; threshold_value: number; status: string; owner: string; recommendation: string; due_date: string | null };
type SeverityRow = { severity: string; open_count: number; mitigated_count: number; closed_count: number; total_count: number };
type TopReferrerRow = { referrer_name: string; referrer_tier: string; recruit_count: number; total_bonus_rupees: number; avg_quality: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [qSummary, tier, specialty, clawback, findings, severity, topRef] = await Promise.all([
    supabase.rpc('rpc_r2989_quarterly_bonus_summary'),
    supabase.rpc('rpc_r2989_tier_leaderboard'),
    supabase.rpc('rpc_r2989_specialty_distribution'),
    supabase.rpc('rpc_r2989_clawback_risk_roster'),
    supabase.rpc('rpc_r2989_open_audit_findings'),
    supabase.rpc('rpc_r2989_severity_rollup'),
    supabase.rpc('rpc_r2989_top_referrers'),
  ]);

  const qRows: QuarterSummary[] = (qSummary.data ?? []) as QuarterSummary[];
  const tierRows: TierRow[] = (tier.data ?? []) as TierRow[];
  const specRows: SpecialtyRow[] = (specialty.data ?? []) as SpecialtyRow[];
  const clawRows: ClawbackRow[] = (clawback.data ?? []) as ClawbackRow[];
  const findRows: FindingRow[] = (findings.data ?? []) as FindingRow[];
  const sevRows: SeverityRow[] = (severity.data ?? []) as SeverityRow[];
  const topRows: TopReferrerRow[] = (topRef.data ?? []) as TopReferrerRow[];

  const qCols: Column<QuarterSummary>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r) => r.quarter_label },
    { key: 'total_bonus_rupees', header: 'Bonus (Rs)', render: (r) => String(r.total_bonus_rupees) },
    { key: 'paid_count', header: 'Paid', render: (r) => String(r.paid_count) },
    { key: 'pending_count', header: 'Pending', render: (r) => String(r.pending_count) },
    { key: 'clawback_count', header: 'Clawback', render: (r) => String(r.clawback_count) },
    { key: 'avg_quality', header: 'Avg Quality', render: (r) => String(r.avg_quality) },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'referrer_tier', header: 'Tier', render: (r) => r.referrer_tier },
    { key: 'referrer_count', header: 'Referrers', render: (r) => String(r.referrer_count) },
    { key: 'total_bonus_rupees', header: 'Bonus (Rs)', render: (r) => String(r.total_bonus_rupees) },
    { key: 'avg_quality', header: 'Avg Quality', render: (r) => String(r.avg_quality) },
    { key: 'paid_share_pct', header: 'Paid %', render: (r) => String(r.paid_share_pct) },
  ];

  const specCols: Column<SpecialtyRow>[] = [
    { key: 'recruit_specialty', header: 'Specialty', render: (r) => r.recruit_specialty },
    { key: 'recruit_count', header: 'Recruits', render: (r) => String(r.recruit_count) },
    { key: 'avg_bonus_rupees', header: 'Avg Bonus (Rs)', render: (r) => String(r.avg_bonus_rupees) },
    { key: 'avg_quality', header: 'Avg Quality', render: (r) => String(r.avg_quality) },
  ];

  const clawCols: Column<ClawbackRow>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r) => r.quarter_label },
    { key: 'referrer_name', header: 'Referrer', render: (r) => r.referrer_name },
    { key: 'recruit_name', header: 'Recruit', render: (r) => r.recruit_name },
    { key: 'recruit_city', header: 'City', render: (r) => r.recruit_city },
    { key: 'quality_score', header: 'Quality', render: (r) => String(r.quality_score) },
    { key: 'bonus_rupees', header: 'Bonus (Rs)', render: (r) => String(r.bonus_rupees) },
    { key: 'bonus_status', header: 'Status', render: (r) => r.bonus_status },
  ];

  const findCols: Column<FindingRow>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r) => r.quarter_label },
    { key: 'finding_category', header: 'Category', render: (r) => r.finding_category },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'metric_value', header: 'Metric', render: (r) => String(r.metric_value) },
    { key: 'threshold_value', header: 'Threshold', render: (r) => String(r.threshold_value) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'owner', header: 'Owner', render: (r) => r.owner },
    { key: 'recommendation', header: 'Recommendation', render: (r) => r.recommendation },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date ?? '-' },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'open_count', header: 'Open', render: (r) => String(r.open_count) },
    { key: 'mitigated_count', header: 'Mitigated', render: (r) => String(r.mitigated_count) },
    { key: 'closed_count', header: 'Closed', render: (r) => String(r.closed_count) },
    { key: 'total_count', header: 'Total', render: (r) => String(r.total_count) },
  ];

  const topCols: Column<TopReferrerRow>[] = [
    { key: 'referrer_name', header: 'Referrer', render: (r) => r.referrer_name },
    { key: 'referrer_tier', header: 'Tier', render: (r) => r.referrer_tier },
    { key: 'recruit_count', header: 'Recruits', render: (r) => String(r.recruit_count) },
    { key: 'total_bonus_rupees', header: 'Bonus (Rs)', render: (r) => String(r.total_bonus_rupees) },
    { key: 'avg_quality', header: 'Avg Quality', render: (r) => String(r.avg_quality) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Engineer-Recruiting Referral Bonus Performance Audit</h1>
        <p className="text-sm text-gray-600">Founder-only audit: bonus ROI, tier concentration & clawback risk across quarters.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Bonus Summary</h2>
        <DataTable rows={qRows} columns={qCols} emptyMessage="No quarters." rowKey={(r, i) => String((r as { quarter_label?: string }).quarter_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Leaderboard</h2>
        <DataTable rows={tierRows} columns={tierCols} emptyMessage="No tiers." rowKey={(r, i) => String((r as { referrer_tier?: string }).referrer_tier ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Specialty Distribution</h2>
        <DataTable rows={specRows} columns={specCols} emptyMessage="No specialties." rowKey={(r, i) => String((r as { recruit_specialty?: string }).recruit_specialty ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Clawback Risk Roster (quality &lt; 7 or status = clawback/rejected)</h2>
        <DataTable rows={clawRows} columns={clawCols} emptyMessage="No clawback risk." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Audit Findings</h2>
        <DataTable rows={findRows} columns={findCols} emptyMessage="No open findings." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity Rollup</h2>
        <DataTable rows={sevRows} columns={sevCols} emptyMessage="No severities." rowKey={(r, i) => String((r as { severity?: string }).severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Referrers</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No referrers." rowKey={(r, i) => String((r as { referrer_name?: string }).referrer_name ?? i)} />
      </section>
    </div>
  );
}
