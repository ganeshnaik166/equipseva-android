import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PipelineOverview = {
  role_family: string;
  stages: number;
  total_entered: number;
  total_passed: number;
  funnel_conversion_pct: number | null;
  bottlenecks: number;
};

type BottleneckStage = {
  role_family: string;
  stage_name: string;
  stage_order: number;
  candidates_entered: number;
  candidates_passed: number;
  median_days_in_stage: number;
  conversion_rate: number;
  owner: string;
  notes: string | null;
};

type StageConversion = {
  role_family: string;
  stage_name: string;
  stage_order: number;
  candidates_entered: number;
  candidates_passed: number;
  conversion_rate: number;
  median_days_in_stage: number;
};

type OfferAcceptance = {
  role_family: string;
  total_offers: number;
  accepted: number;
  declined: number;
  pending: number;
  acceptance_rate_pct: number | null;
  median_days_to_response: number | null;
};

type DeclineReason = {
  decline_reason: string;
  count: number;
  affected_role_families: number;
  avg_comp_gap_pct: number;
};

type CompOutlier = {
  candidate_code: string;
  role_family: string;
  level: string;
  total_comp_inr_lakhs: number;
  market_band_p50_inr_lakhs: number;
  comp_vs_market_pct: number;
  offer_status: string;
  decline_reason: string | null;
};

type SourceYield = {
  source_channel: string;
  total_offers: number;
  accepted: number;
  acceptance_rate_pct: number | null;
  avg_days_to_response: number | null;
};

type PendingOffer = {
  candidate_code: string;
  role_family: string;
  level: string;
  offer_date: string;
  days_outstanding: number;
  total_comp_inr_lakhs: number;
  source_channel: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    bottlenecksRes,
    stageRes,
    offerRes,
    declineRes,
    outlierRes,
    sourceRes,
    pendingRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2929_pipeline_overview'),
    supabase.rpc('founder_r2929_bottleneck_stages'),
    supabase.rpc('founder_r2929_stage_conversion_detail'),
    supabase.rpc('founder_r2929_offer_acceptance_rate'),
    supabase.rpc('founder_r2929_decline_reason_breakdown'),
    supabase.rpc('founder_r2929_comp_vs_market_outliers'),
    supabase.rpc('founder_r2929_source_channel_yield'),
    supabase.rpc('founder_r2929_pending_offers_followup'),
  ]);

  const overview = (overviewRes.data ?? []) as PipelineOverview[];
  const bottlenecks = (bottlenecksRes.data ?? []) as BottleneckStage[];
  const stages = (stageRes.data ?? []) as StageConversion[];
  const offers = (offerRes.data ?? []) as OfferAcceptance[];
  const declines = (declineRes.data ?? []) as DeclineReason[];
  const outliers = (outlierRes.data ?? []) as CompOutlier[];
  const sources = (sourceRes.data ?? []) as SourceYield[];
  const pending = (pendingRes.data ?? []) as PendingOffer[];

  const overviewCols: Column<PipelineOverview>[] = [
    { key: 'role_family', header: 'Role Family', render: (r) => r.role_family },
    { key: 'stages', header: 'Stages', render: (r) => r.stages },
    { key: 'total_entered', header: 'Entered', render: (r) => r.total_entered },
    { key: 'total_passed', header: 'Passed', render: (r) => r.total_passed },
    { key: 'funnel_conversion_pct', header: 'Funnel %', render: (r) => r.funnel_conversion_pct ?? '—' },
    { key: 'bottlenecks', header: 'Bottlenecks', render: (r) => r.bottlenecks },
  ];

  const bottleneckCols: Column<BottleneckStage>[] = [
    { key: 'role_family', header: 'Role', render: (r) => r.role_family },
    { key: 'stage_name', header: 'Stage', render: (r) => r.stage_name },
    { key: 'stage_order', header: '#', render: (r) => r.stage_order },
    { key: 'candidates_entered', header: 'In', render: (r) => r.candidates_entered },
    { key: 'candidates_passed', header: 'Out', render: (r) => r.candidates_passed },
    { key: 'median_days_in_stage', header: 'Median Days', render: (r) => r.median_days_in_stage },
    { key: 'conversion_rate', header: 'Conv %', render: (r) => r.conversion_rate },
    { key: 'owner', header: 'Owner', render: (r) => r.owner },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const stageCols: Column<StageConversion>[] = [
    { key: 'role_family', header: 'Role', render: (r) => r.role_family },
    { key: 'stage_order', header: '#', render: (r) => r.stage_order },
    { key: 'stage_name', header: 'Stage', render: (r) => r.stage_name },
    { key: 'candidates_entered', header: 'Entered', render: (r) => r.candidates_entered },
    { key: 'candidates_passed', header: 'Passed', render: (r) => r.candidates_passed },
    { key: 'conversion_rate', header: 'Conv %', render: (r) => r.conversion_rate },
    { key: 'median_days_in_stage', header: 'Median Days', render: (r) => r.median_days_in_stage },
  ];

  const offerCols: Column<OfferAcceptance>[] = [
    { key: 'role_family', header: 'Role Family', render: (r) => r.role_family },
    { key: 'total_offers', header: 'Offers', render: (r) => r.total_offers },
    { key: 'accepted', header: 'Accepted', render: (r) => r.accepted },
    { key: 'declined', header: 'Declined', render: (r) => r.declined },
    { key: 'pending', header: 'Pending', render: (r) => r.pending },
    { key: 'acceptance_rate_pct', header: 'Accept %', render: (r) => r.acceptance_rate_pct ?? '—' },
    { key: 'median_days_to_response', header: 'Median Days', render: (r) => r.median_days_to_response ?? '—' },
  ];

  const declineCols: Column<DeclineReason>[] = [
    { key: 'decline_reason', header: 'Reason', render: (r) => r.decline_reason },
    { key: 'count', header: 'Count', render: (r) => r.count },
    { key: 'affected_role_families', header: 'Roles Affected', render: (r) => r.affected_role_families },
    { key: 'avg_comp_gap_pct', header: 'Avg Comp Gap %', render: (r) => r.avg_comp_gap_pct },
  ];

  const outlierCols: Column<CompOutlier>[] = [
    { key: 'candidate_code', header: 'Candidate', render: (r) => r.candidate_code },
    { key: 'role_family', header: 'Role', render: (r) => r.role_family },
    { key: 'level', header: 'Level', render: (r) => r.level },
    { key: 'total_comp_inr_lakhs', header: 'Comp (L)', render: (r) => r.total_comp_inr_lakhs },
    { key: 'market_band_p50_inr_lakhs', header: 'Market P50 (L)', render: (r) => r.market_band_p50_inr_lakhs },
    { key: 'comp_vs_market_pct', header: 'vs Market %', render: (r) => r.comp_vs_market_pct },
    { key: 'offer_status', header: 'Status', render: (r) => r.offer_status },
    { key: 'decline_reason', header: 'Decline Reason', render: (r) => r.decline_reason ?? '—' },
  ];

  const sourceCols: Column<SourceYield>[] = [
    { key: 'source_channel', header: 'Channel', render: (r) => r.source_channel },
    { key: 'total_offers', header: 'Offers', render: (r) => r.total_offers },
    { key: 'accepted', header: 'Accepted', render: (r) => r.accepted },
    { key: 'acceptance_rate_pct', header: 'Accept %', render: (r) => r.acceptance_rate_pct ?? '—' },
    { key: 'avg_days_to_response', header: 'Avg Days', render: (r) => r.avg_days_to_response ?? '—' },
  ];

  const pendingCols: Column<PendingOffer>[] = [
    { key: 'candidate_code', header: 'Candidate', render: (r) => r.candidate_code },
    { key: 'role_family', header: 'Role', render: (r) => r.role_family },
    { key: 'level', header: 'Level', render: (r) => r.level },
    { key: 'offer_date', header: 'Offer Date', render: (r) => r.offer_date },
    { key: 'days_outstanding', header: 'Days Outstanding', render: (r) => r.days_outstanding },
    { key: 'total_comp_inr_lakhs', header: 'Comp (L)', render: (r) => r.total_comp_inr_lakhs },
    { key: 'source_channel', header: 'Channel', render: (r) => r.source_channel },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Monthly Strategic 90-Day Hiring Pipeline & Offer Acceptance Audit</h1>
        <p className="text-sm text-gray-600">
          Round r2929 — founder console — pipeline funnel, offer accept rate, decline reasons, comp-vs-market.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Pipeline Overview by Role Family</h2>
        <DataTable
          rows={overview}
          columns={overviewCols}
          emptyMessage="No pipeline data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Bottleneck Stages (median days &gt;= 7 or conv &lt;= 50%)</h2>
        <DataTable
          rows={bottlenecks}
          columns={bottleneckCols}
          emptyMessage="No bottlenecks flagged."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Stage-by-Stage Conversion Detail</h2>
        <DataTable
          rows={stages}
          columns={stageCols}
          emptyMessage="No stages."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Offer Acceptance Rate by Role</h2>
        <DataTable
          rows={offers}
          columns={offerCols}
          emptyMessage="No offers."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Decline Reason Breakdown</h2>
        <DataTable
          rows={declines}
          columns={declineCols}
          emptyMessage="No declines logged."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Comp vs Market Outliers (&lt; 95% or &gt; 105%)</h2>
        <DataTable
          rows={outliers}
          columns={outlierCols}
          emptyMessage="No comp outliers."
          rowKey={(r, i) => String(r.candidate_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Source Channel Yield</h2>
        <DataTable
          rows={sources}
          columns={sourceCols}
          emptyMessage="No source data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Pending Offers — Follow-up Queue</h2>
        <DataTable
          rows={pending}
          columns={pendingCols}
          emptyMessage="No pending offers."
          rowKey={(r, i) => String(r.candidate_code ?? i)}
        />
      </section>
    </div>
  );
}
