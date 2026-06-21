import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type DealRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  deal_value_rupees: number;
  expected_close_date: string | null;
  actual_close_date: string | null;
  outcome: string;
  primary_reason: string;
  secondary_reason: string | null;
  competitor_count: number;
  created_at: string;
};

type CompetitorRow = {
  id: string;
  deal_id: string;
  competitor_name: string;
  competitor_offer_summary: string | null;
  our_advantage: string | null;
  their_advantage: string | null;
  outcome: string;
  created_at: string;
};

type ReasonRow = {
  primary_reason: string;
  outcome: string;
  deal_count: number;
  total_value_rupees: number;
};

type WinRateRow = {
  total_deals: number;
  won_deals: number;
  lost_deals: number;
  withdrawn_deals: number;
  win_rate_pct: number;
  won_value_rupees: number;
  lost_value_rupees: number;
  avg_won_value_rupees: number;
};

type TopCompetitorRow = {
  competitor_name: string;
  encounter_count: number;
  won_against: number;
  lost_to: number;
  deal_value_at_stake_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (!n) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [dealsRes, competitorsRes, reasonsRes, winRateRes, topCompRes] = await Promise.all([
    sb.rpc('list_deals_r1774'),
    sb.rpc('list_competitors_r1774'),
    sb.rpc('reason_distribution_r1774'),
    sb.rpc('win_rate_summary_r1774'),
    sb.rpc('top_competitors_r1774'),
  ]);

  const deals: DealRow[] = (dealsRes.data as DealRow[] | null) ?? [];
  const competitors: CompetitorRow[] = (competitorsRes.data as CompetitorRow[] | null) ?? [];
  const reasons: ReasonRow[] = (reasonsRes.data as ReasonRow[] | null) ?? [];
  const winRateArr: WinRateRow[] = (winRateRes.data as WinRateRow[] | null) ?? [];
  const winRate: WinRateRow = winRateArr[0] ?? {
    total_deals: 0,
    won_deals: 0,
    lost_deals: 0,
    withdrawn_deals: 0,
    win_rate_pct: 0,
    won_value_rupees: 0,
    lost_value_rupees: 0,
    avg_won_value_rupees: 0,
  };
  const topComp: TopCompetitorRow[] = (topCompRes.data as TopCompetitorRow[] | null) ?? [];

  const dealCols: Column<DealRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? String(r.hospital_user_id).slice(0, 8) },
    { key: 'deal_value_rupees', header: 'Value (Rs)', render: (r: any) => fmtRupees(r.deal_value_rupees) },
    { key: 'expected_close_date', header: 'Expected close', render: (r: any) => r.expected_close_date ?? '-' },
    { key: 'actual_close_date', header: 'Actual close', render: (r: any) => r.actual_close_date ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'primary_reason', header: 'Primary reason', render: (r: any) => r.primary_reason },
    { key: 'secondary_reason', header: 'Secondary', render: (r: any) => r.secondary_reason ?? '-' },
    { key: 'competitor_count', header: 'Competitors', render: (r: any) => r.competitor_count },
  ];

  const competitorCols: Column<CompetitorRow>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'competitor_offer_summary', header: 'Their offer', render: (r: any) => r.competitor_offer_summary ?? '-' },
    { key: 'our_advantage', header: 'Our edge', render: (r: any) => r.our_advantage ?? '-' },
    { key: 'their_advantage', header: 'Their edge', render: (r: any) => r.their_advantage ?? '-' },
    { key: 'deal_id', header: 'Deal', render: (r: any) => String(r.deal_id).slice(0, 8) },
  ];

  const reasonCols: Column<ReasonRow>[] = [
    { key: 'primary_reason', header: 'Primary reason', render: (r: any) => r.primary_reason },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'deal_count', header: 'Deals', render: (r: any) => r.deal_count },
    { key: 'total_value_rupees', header: 'Total value (Rs)', render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  const topCompCols: Column<TopCompetitorRow>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name },
    { key: 'encounter_count', header: 'Encounters', render: (r: any) => r.encounter_count },
    { key: 'won_against', header: 'Won against', render: (r: any) => r.won_against },
    { key: 'lost_to', header: 'Lost to', render: (r: any) => r.lost_to },
    { key: 'deal_value_at_stake_rupees', header: 'Value at stake (Rs)', render: (r: any) => fmtRupees(r.deal_value_at_stake_rupees) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Win-Loss Analysis</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Every closed deal logged with primary reason and competitor context. Win rate counts won vs (won + lost); withdrawn deals excluded from rate.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Headline metrics</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total deals</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{winRate.total_deals}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Win rate</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{winRate.win_rate_pct}%</div>
            <div style={{ fontSize: 11, color: '#888' }}>{winRate.won_deals} won · {winRate.lost_deals} lost · {winRate.withdrawn_deals} withdrew</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Won value (Rs)</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(winRate.won_value_rupees)}</div>
            <div style={{ fontSize: 11, color: '#888' }}>avg {fmtRupees(winRate.avg_won_value_rupees)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Lost value (Rs)</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(winRate.lost_value_rupees)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All deals ({deals.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Every closed deal with outcome & primary reason. Sorted by most recent close date.
        </p>
        <DataTable
          rows={deals}
          columns={dealCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Reason distribution ({reasons.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Group by primary_reason × outcome. Surfaces patterns: e.g. how many deals lost on price vs feature gap.
        </p>
        <DataTable
          rows={reasons}
          columns={reasonCols}
          rowKey={(r: any, i: number) => String(r.primary_reason + '|' + r.outcome + '|' + i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top competitors ({topComp.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Competitors encountered across deals. "Lost to" counts only deals where outcome = lost & primary_reason = competitor_chosen.
        </p>
        <DataTable
          rows={topComp}
          columns={topCompCols}
          rowKey={(r: any, i: number) => String(r.competitor_name + '|' + i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Competitor log ({competitors.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Per-deal competitor entries with their offer, our edge, and their edge.
        </p>
        <DataTable
          rows={competitors}
          columns={competitorCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
