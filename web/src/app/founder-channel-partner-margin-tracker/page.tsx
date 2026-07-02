import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type RosterRow = {
  partner_code: string;
  partner_name: string;
  partner_type: string;
  region: string;
  tier_rank: string;
  arr_inr_lakhs: number;
  parts_orders_q: number;
  oem_rebate_pct: number;
  margin_pct: number;
  payment_terms_days: number;
  dispute_count_q: number;
  exclusivity_clause: boolean;
  primary_oem_brand: string;
};

type TierRow = {
  tier_rank: string;
  partner_count: number;
  total_arr_lakhs: number;
  avg_margin_pct: number;
  total_disputes: number;
};

type RegionRow = {
  region: string;
  partner_count: number;
  total_arr_lakhs: number;
  total_parts_orders: number;
  avg_rebate_pct: number;
  avg_terms_days: number;
};

type OemRow = {
  primary_oem_brand: string;
  partner_count: number;
  total_arr_lakhs: number;
  avg_rebate_pct: number;
  exclusivity_count: number;
};

type DisputeRow = {
  partner_code: string;
  partner_name: string;
  tier_rank: string;
  dispute_count_q: number;
  margin_pct: number;
  payment_terms_days: number;
  founder_action: string;
};

type EventRow = {
  partner_code: string;
  partner_name: string;
  event_type: string;
  event_outcome: string;
  margin_delta_pct: number;
  arr_impact_inr_lakhs: number;
  occurred_on: string;
  founder_attention: boolean;
  notes: string | null;
};

type OutcomeRow = {
  event_outcome: string;
  event_count: number;
  total_margin_delta: number;
  total_arr_impact: number;
  founder_attention_count: number;
};

type AttentionRow = {
  partner_code: string;
  partner_name: string;
  tier_rank: string;
  event_type: string;
  event_outcome: string;
  occurred_on: string;
  followup_due: string | null;
  arr_impact_inr_lakhs: number;
  notes: string | null;
};

type ScoreRow = {
  partner_code: string;
  partner_name: string;
  tier_rank: string;
  margin_pct: number;
  arr_inr_lakhs: number;
  oem_rebate_pct: number;
  composite_score: number;
};

export default async function FounderChannelPartnerMarginTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    rosterRes,
    tierRes,
    regionRes,
    oemRes,
    disputeRes,
    eventRes,
    outcomeRes,
    attentionRes,
    scoreRes,
  ] = await Promise.all([
    supabase.rpc('fn_r3115_partner_roster_snapshot'),
    supabase.rpc('fn_r3115_tier_distribution'),
    supabase.rpc('fn_r3115_regional_rollup'),
    supabase.rpc('fn_r3115_oem_brand_concentration'),
    supabase.rpc('fn_r3115_dispute_heatmap'),
    supabase.rpc('fn_r3115_engagement_event_log'),
    supabase.rpc('fn_r3115_event_outcome_rollup'),
    supabase.rpc('fn_r3115_founder_attention_queue'),
    supabase.rpc('fn_r3115_margin_scoreboard'),
  ]);

  const roster: RosterRow[] = (rosterRes.data as RosterRow[]) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const regions: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const oems: OemRow[] = (oemRes.data as OemRow[]) ?? [];
  const disputes: DisputeRow[] = (disputeRes.data as DisputeRow[]) ?? [];
  const events: EventRow[] = (eventRes.data as EventRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const attention: AttentionRow[] = (attentionRes.data as AttentionRow[]) ?? [];
  const scores: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];

  const rosterCols: Column<RosterRow>[] = [
    { key: 'partner_code', header: 'Code' },
    { key: 'partner_name', header: 'Partner' },
    { key: 'partner_type', header: 'Type' },
    { key: 'region', header: 'Region' },
    { key: 'tier_rank', header: 'Tier' },
    { key: 'arr_inr_lakhs', header: 'ARR (Lakhs)', render: (r) => `Rs ${Number(r.arr_inr_lakhs).toFixed(2)}L` },
    { key: 'parts_orders_q', header: 'Parts Orders Q' },
    { key: 'oem_rebate_pct', header: 'OEM Rebate %' },
    { key: 'margin_pct', header: 'Margin %' },
    { key: 'payment_terms_days', header: 'Terms (d)' },
    { key: 'dispute_count_q', header: 'Disputes Q' },
    { key: 'exclusivity_clause', header: 'Exclusive', render: (r) => (r.exclusivity_clause ? 'Yes' : 'No') },
    { key: 'primary_oem_brand', header: 'OEM Brand' },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'tier_rank', header: 'Tier' },
    { key: 'partner_count', header: 'Partners' },
    { key: 'total_arr_lakhs', header: 'Total ARR (L)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'total_disputes', header: 'Total Disputes' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'partner_count', header: 'Partners' },
    { key: 'total_arr_lakhs', header: 'Total ARR (L)' },
    { key: 'total_parts_orders', header: 'Parts Orders' },
    { key: 'avg_rebate_pct', header: 'Avg Rebate %' },
    { key: 'avg_terms_days', header: 'Avg Terms (d)' },
  ];

  const oemCols: Column<OemRow>[] = [
    { key: 'primary_oem_brand', header: 'OEM Brand' },
    { key: 'partner_count', header: 'Partners' },
    { key: 'total_arr_lakhs', header: 'Total ARR (L)' },
    { key: 'avg_rebate_pct', header: 'Avg Rebate %' },
    { key: 'exclusivity_count', header: 'Exclusivity Count' },
  ];

  const disputeCols: Column<DisputeRow>[] = [
    { key: 'partner_code', header: 'Code' },
    { key: 'partner_name', header: 'Partner' },
    { key: 'tier_rank', header: 'Tier' },
    { key: 'dispute_count_q', header: 'Disputes Q' },
    { key: 'margin_pct', header: 'Margin %' },
    { key: 'payment_terms_days', header: 'Terms (d)' },
    { key: 'founder_action', header: 'Founder Action' },
  ];

  const eventCols: Column<EventRow>[] = [
    { key: 'partner_code', header: 'Code' },
    { key: 'partner_name', header: 'Partner' },
    { key: 'event_type', header: 'Event' },
    { key: 'event_outcome', header: 'Outcome' },
    { key: 'margin_delta_pct', header: 'Margin Δ %' },
    { key: 'arr_impact_inr_lakhs', header: 'ARR Δ (L)' },
    { key: 'occurred_on', header: 'Date' },
    { key: 'founder_attention', header: 'Founder?', render: (r) => (r.founder_attention ? 'Yes' : 'No') },
    { key: 'notes', header: 'Notes' },
  ];

  const outcomeCols: Column<OutcomeRow>[] = [
    { key: 'event_outcome', header: 'Outcome' },
    { key: 'event_count', header: 'Events' },
    { key: 'total_margin_delta', header: 'Total Margin Δ' },
    { key: 'total_arr_impact', header: 'Total ARR Δ (L)' },
    { key: 'founder_attention_count', header: 'Founder Attn' },
  ];

  const attentionCols: Column<AttentionRow>[] = [
    { key: 'partner_code', header: 'Code' },
    { key: 'partner_name', header: 'Partner' },
    { key: 'tier_rank', header: 'Tier' },
    { key: 'event_type', header: 'Event' },
    { key: 'event_outcome', header: 'Outcome' },
    { key: 'occurred_on', header: 'Date' },
    { key: 'followup_due', header: 'Followup Due' },
    { key: 'arr_impact_inr_lakhs', header: 'ARR Δ (L)' },
    { key: 'notes', header: 'Notes' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'partner_code', header: 'Code' },
    { key: 'partner_name', header: 'Partner' },
    { key: 'tier_rank', header: 'Tier' },
    { key: 'margin_pct', header: 'Margin %' },
    { key: 'arr_inr_lakhs', header: 'ARR (L)' },
    { key: 'oem_rebate_pct', header: 'Rebate %' },
    { key: 'composite_score', header: 'Composite' },
  ];

  return (
    <main className="max-w-7xl mx-auto p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Channel Partner / Distributor Engagement Margin Tracker</h1>
        <p className="text-sm text-gray-600">
          Quarterly strategic rollup: partner ARR, parts orders, OEM rebate, payment terms, disputes & tier rank.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Partner Roster</h2>
        <DataTable
          rows={roster}
          columns={rosterCols}
          emptyMessage="No channel partners on roster."
          rowKey={(r, i) => String((r as RosterRow).partner_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Tier Distribution</h2>
        <DataTable
          rows={tiers}
          columns={tierCols}
          emptyMessage="No tier rollup."
          rowKey={(r, i) => String((r as TierRow).tier_rank ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Regional Rollup</h2>
        <DataTable
          rows={regions}
          columns={regionCols}
          emptyMessage="No regional data."
          rowKey={(r, i) => String((r as RegionRow).region ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">OEM Brand Concentration</h2>
        <DataTable
          rows={oems}
          columns={oemCols}
          emptyMessage="No OEM concentration data."
          rowKey={(r, i) => String((r as OemRow).primary_oem_brand ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Dispute Heatmap (dispute_count_q &gt;= 1)</h2>
        <DataTable
          rows={disputes}
          columns={disputeCols}
          emptyMessage="No active disputes."
          rowKey={(r, i) => String((r as DisputeRow).partner_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Engagement Event Log</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          emptyMessage="No engagement events."
          rowKey={(r, i) => `${(r as EventRow).partner_code}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Outcome Rollup</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcome rollup."
          rowKey={(r, i) => String((r as OutcomeRow).event_outcome ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Founder Attention Queue</h2>
        <DataTable
          rows={attention}
          columns={attentionCols}
          emptyMessage="Founder queue clear."
          rowKey={(r, i) => `${(r as AttentionRow).partner_code}-att-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Margin Composite Scoreboard</h2>
        <DataTable
          rows={scores}
          columns={scoreCols}
          emptyMessage="No score data."
          rowKey={(r, i) => String((r as ScoreRow).partner_code ?? i)}
        />
      </section>
    </main>
  );
}
