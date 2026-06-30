import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusSummary = {
  total_customers: number;
  total_arr_inr_lakh: number;
  total_outstanding_inr_lakh: number;
  weighted_avg_dso: number;
  top1_share_pct: number;
  top3_share_pct: number;
  customers_distressed: number;
  covenant_breaches: number;
};

type HotlistRow = {
  customer_name: string;
  segment: string;
  arr_share_pct: number;
  outstanding_inr_lakh: number;
  solvency: string;
  covenant: string;
  runway_impact_days: number;
  risk_score: number;
};

type SegmentRow = {
  segment: string;
  customer_count: number;
  total_arr_inr_lakh: number;
  avg_dso_days: number;
  outstanding_inr_lakh: number;
  share_pct: number;
};

type PaymentRow = {
  payment_behaviour: string;
  customer_count: number;
  total_outstanding_inr_lakh: number;
  avg_dso_days: number;
};

type ActionRow = {
  customer_name: string;
  action_type: string;
  priority: string;
  owner_role: string;
  status: string;
  bankruptcy_drill_outcome: string;
  target_close_at: string;
  expected_replace_inr_lakh: number;
  blocker_note: string | null;
};

type ScoreRow = {
  customer_name: string;
  arr_share_pct: number;
  runway_impact_days: number;
  worst_outcome: string | null;
  open_actions: number;
  blocked_actions: number;
  diversification_status: string;
};

type HeatmapRow = {
  public_solvency_signal: string;
  covenant_flag: string;
  customer_count: number;
  arr_at_risk_inr_lakh: number;
};

type RenewalRow = {
  customer_name: string;
  segment: string;
  arr_share_pct: number;
  contract_renewal_at: string;
  days_to_renewal: number;
  diversification_status: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    summaryRes,
    hotlistRes,
    segmentRes,
    paymentRes,
    actionRes,
    scoreRes,
    heatmapRes,
    renewalRes,
  ] = await Promise.all([
    supabase.rpc('rpc_r3097_status_summary'),
    supabase.rpc('rpc_r3097_customer_hotlist'),
    supabase.rpc('rpc_r3097_segment_breakdown'),
    supabase.rpc('rpc_r3097_payment_behaviour'),
    supabase.rpc('rpc_r3097_action_queue'),
    supabase.rpc('rpc_r3097_drill_scorecard'),
    supabase.rpc('rpc_r3097_solvency_heatmap'),
    supabase.rpc('rpc_r3097_renewal_calendar'),
  ]);

  const summary = (summaryRes.data?.[0] ?? null) as StatusSummary | null;
  const hotlist = (hotlistRes.data ?? []) as HotlistRow[];
  const segments = (segmentRes.data ?? []) as SegmentRow[];
  const payments = (paymentRes.data ?? []) as PaymentRow[];
  const actions = (actionRes.data ?? []) as ActionRow[];
  const scorecard = (scoreRes.data ?? []) as ScoreRow[];
  const heatmap = (heatmapRes.data ?? []) as HeatmapRow[];
  const renewals = (renewalRes.data ?? []) as RenewalRow[];

  const hotlistColumns: Column<HotlistRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'segment', header: 'Segment' },
    { key: 'arr_share_pct', header: 'ARR Share %' },
    { key: 'outstanding_inr_lakh', header: 'Outstanding (lakh)' },
    { key: 'solvency', header: 'Solvency' },
    { key: 'covenant', header: 'Covenant' },
    { key: 'runway_impact_days', header: 'Runway Impact (days)' },
    { key: 'risk_score', header: 'Risk Score' },
  ];

  const segmentColumns: Column<SegmentRow>[] = [
    { key: 'segment', header: 'Segment' },
    { key: 'customer_count', header: 'Customers' },
    { key: 'total_arr_inr_lakh', header: 'ARR (lakh)' },
    { key: 'avg_dso_days', header: 'Avg DSO (days)' },
    { key: 'outstanding_inr_lakh', header: 'Outstanding (lakh)' },
    { key: 'share_pct', header: 'Share %' },
  ];

  const paymentColumns: Column<PaymentRow>[] = [
    { key: 'payment_behaviour', header: 'Payment Behaviour' },
    { key: 'customer_count', header: 'Customers' },
    { key: 'total_outstanding_inr_lakh', header: 'Outstanding (lakh)' },
    { key: 'avg_dso_days', header: 'Avg DSO (days)' },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'action_type', header: 'Action' },
    { key: 'priority', header: 'Priority' },
    { key: 'owner_role', header: 'Owner' },
    { key: 'status', header: 'Status' },
    { key: 'bankruptcy_drill_outcome', header: 'Drill Outcome' },
    { key: 'target_close_at', header: 'Target Close' },
    { key: 'expected_replace_inr_lakh', header: 'Replace ARR (lakh)' },
    { key: 'blocker_note', header: 'Blocker' },
  ];

  const scoreColumns: Column<ScoreRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'arr_share_pct', header: 'ARR Share %' },
    { key: 'runway_impact_days', header: 'Runway Impact (days)' },
    { key: 'worst_outcome', header: 'Worst Drill Outcome' },
    { key: 'open_actions', header: 'Open Actions' },
    { key: 'blocked_actions', header: 'Blocked' },
    { key: 'diversification_status', header: 'Diversification' },
  ];

  const heatmapColumns: Column<HeatmapRow>[] = [
    { key: 'public_solvency_signal', header: 'Solvency Signal' },
    { key: 'covenant_flag', header: 'Covenant Flag' },
    { key: 'customer_count', header: 'Customers' },
    { key: 'arr_at_risk_inr_lakh', header: 'ARR at Risk (lakh)' },
  ];

  const renewalColumns: Column<RenewalRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'segment', header: 'Segment' },
    { key: 'arr_share_pct', header: 'ARR Share %' },
    { key: 'contract_renewal_at', header: 'Renewal Date' },
    { key: 'days_to_renewal', header: 'Days to Renewal' },
    { key: 'diversification_status', header: 'Diversification' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">
          Customer Concentration & Bankruptcy-Risk Drill (r3097)
        </h1>
        <p className="text-sm text-gray-600">
          Quarterly founder drill. Tracks top-5 customer ARR share, payment
          behaviour, public solvency signals, covenant flags, and the
          diversification action queue. Goal =&gt; no single customer &gt;= 25%
          of ARR; survive a forced loss of #1.
        </p>
      </header>

      {summary ? (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Stat label="Customers tracked" value={summary.total_customers} />
          <Stat label="Total ARR (lakh)" value={summary.total_arr_inr_lakh} />
          <Stat
            label="Outstanding (lakh)"
            value={summary.total_outstanding_inr_lakh}
          />
          <Stat label="Weighted DSO (days)" value={summary.weighted_avg_dso} />
          <Stat label="Top-1 ARR Share %" value={summary.top1_share_pct} />
          <Stat label="Top-3 ARR Share %" value={summary.top3_share_pct} />
          <Stat
            label="Distressed customers"
            value={summary.customers_distressed}
          />
          <Stat label="Covenant breaches" value={summary.covenant_breaches} />
        </section>
      ) : null}

      <Section title="Customer Hotlist (risk-ranked)">
        <DataTable
          rows={hotlist}
          columns={hotlistColumns}
          emptyMessage="No customers in concentration drill."
          rowKey={(r, i) => String((r as HotlistRow).customer_name ?? i)}
        />
      </Section>

      <Section title="Segment Breakdown">
        <DataTable
          rows={segments}
          columns={segmentColumns}
          emptyMessage="No segment data."
          rowKey={(r, i) => String((r as SegmentRow).segment ?? i)}
        />
      </Section>

      <Section title="Payment Behaviour Rollup">
        <DataTable
          rows={payments}
          columns={paymentColumns}
          emptyMessage="No payment data."
          rowKey={(r, i) => String((r as PaymentRow).payment_behaviour ?? i)}
        />
      </Section>

      <Section title="Diversification Action Queue">
        <DataTable
          rows={actions}
          columns={actionColumns}
          emptyMessage="No queued diversification actions."
          rowKey={(_r, i) => String(i)}
        />
      </Section>

      <Section title="Bankruptcy Drill Scorecard">
        <DataTable
          rows={scorecard}
          columns={scoreColumns}
          emptyMessage="No scorecard rows."
          rowKey={(r, i) => String((r as ScoreRow).customer_name ?? i)}
        />
      </Section>

      <Section title="Solvency / Covenant Heatmap">
        <DataTable
          rows={heatmap}
          columns={heatmapColumns}
          emptyMessage="No heatmap rows."
          rowKey={(_r, i) => String(i)}
        />
      </Section>

      <Section title="Renewal Calendar">
        <DataTable
          rows={renewals}
          columns={renewalColumns}
          emptyMessage="No upcoming renewals."
          rowKey={(r, i) => String((r as RenewalRow).customer_name ?? i)}
        />
      </Section>
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="space-y-2">
      <h2 className="text-lg font-medium">{title}</h2>
      {children}
    </section>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded border border-gray-200 p-3">
      <div className="text-xs uppercase tracking-wide text-gray-500">
        {label}
      </div>
      <div className="text-xl font-semibold">{String(value)}</div>
    </div>
  );
}
