import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_quotes: number;
  won_count: number;
  lost_count: number;
  in_negotiation_count: number;
  win_rate_pct: number;
  avg_discount_pct: number;
  total_won_rupees: number;
};

type QuoteRow = {
  quote_ref: string;
  customer_name: string;
  customer_segment: string;
  ask_amount_rupees: number;
  quoted_amount_rupees: number;
  discount_pct: number;
  negotiation_rounds: number;
  outcome: string;
  loss_reason: string | null;
};

type LossRow = {
  loss_reason: string;
  lost_count: number;
  lost_value_rupees: number;
};

type SegmentRow = {
  customer_segment: string;
  quote_count: number;
  won_count: number;
  win_rate_pct: number;
  avg_discount_pct: number;
};

type TrendRow = {
  month_label: string;
  quotes_sent: number;
  quotes_won: number;
  win_rate_pct: number;
  total_won_rupees: number;
  avg_discount_pct: number;
  avg_negotiation_rounds: number;
};

type IntensityRow = {
  rounds_bucket: string;
  quote_count: number;
  won_count: number;
  win_rate_pct: number;
};

type AskCloseRow = {
  quote_ref: string;
  customer_name: string;
  ask_amount_rupees: number;
  closed_amount_rupees: number;
  drop_pct: number;
};

type ActiveRow = {
  quote_ref: string;
  customer_name: string;
  quoted_amount_rupees: number;
  negotiation_rounds: number;
  days_open: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + n.toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, recentRes, lossRes, segRes, trendRes, intensityRes, askCloseRes, activeRes] = await Promise.all([
    supabase.rpc('funnel_kpis_r2728'),
    supabase.rpc('funnel_recent_quotes_r2728'),
    supabase.rpc('funnel_loss_reasons_r2728'),
    supabase.rpc('funnel_segment_breakdown_r2728'),
    supabase.rpc('funnel_monthly_trend_r2728'),
    supabase.rpc('funnel_negotiation_intensity_r2728'),
    supabase.rpc('funnel_ask_vs_close_r2728'),
    supabase.rpc('funnel_active_negotiations_r2728'),
  ]);

  const kpi: KpiRow | null = (kpiRes.data && kpiRes.data[0]) || null;
  const recent: QuoteRow[] = recentRes.data || [];
  const loss: LossRow[] = lossRes.data || [];
  const segments: SegmentRow[] = segRes.data || [];
  const trend: TrendRow[] = trendRes.data || [];
  const intensity: IntensityRow[] = intensityRes.data || [];
  const askClose: AskCloseRow[] = askCloseRes.data || [];
  const active: ActiveRow[] = activeRes.data || [];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer Monthly Quote Conversion Funnel
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Quote → ask → discount → negotiate → close. Track loss reasons & outcomes across segments.
      </p>

      {/* KPI cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Quotes</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpi?.total_quotes ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#f0fdf4' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Won</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#16a34a' }}>{kpi?.won_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Lost</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#dc2626' }}>{kpi?.lost_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fefce8' }}>
          <div style={{ fontSize: 12, color: '#666' }}>In Negotiation</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#ca8a04' }}>{kpi?.in_negotiation_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Win Rate</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtPct(kpi?.win_rate_pct)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Discount</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtPct(kpi?.avg_discount_pct)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Won Value</div>
          <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtRupees(kpi?.total_won_rupees)}</div>
        </div>
      </div>

      {/* Monthly Trend */}
      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Funnel Trend</h2>
        <DataTable
          rows={trend}
          columns={[
            { key: 'month_label', header: 'Month', render: (r: TrendRow) => r.month_label },
            { key: 'quotes_sent', header: 'Sent', render: (r: TrendRow) => r.quotes_sent },
            { key: 'quotes_won', header: 'Won', render: (r: TrendRow) => r.quotes_won },
            { key: 'win_rate_pct', header: 'Win Rate', render: (r: TrendRow) => fmtPct(r.win_rate_pct) },
            { key: 'total_won_rupees', header: 'Won Value', render: (r: TrendRow) => fmtRupees(r.total_won_rupees) },
            { key: 'avg_discount_pct', header: 'Avg Discount', render: (r: TrendRow) => fmtPct(r.avg_discount_pct) },
            { key: 'avg_negotiation_rounds', header: 'Avg Rounds', render: (r: TrendRow) => Number(r.avg_negotiation_rounds).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TrendRow, i: number) => String(r.month_label ?? i)}
        />
      </section>

      {/* Segment Breakdown */}
      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Segment Breakdown</h2>
        <DataTable
          rows={segments}
          columns={[
            { key: 'customer_segment', header: 'Segment', render: (r: SegmentRow) => r.customer_segment },
            { key: 'quote_count', header: 'Quotes', render: (r: SegmentRow) => r.quote_count },
            { key: 'won_count', header: 'Won', render: (r: SegmentRow) => r.won_count },
            { key: 'win_rate_pct', header: 'Win Rate', render: (r: SegmentRow) => fmtPct(r.win_rate_pct) },
            { key: 'avg_discount_pct', header: 'Avg Discount', render: (r: SegmentRow) => fmtPct(r.avg_discount_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SegmentRow, i: number) => String(r.customer_segment ?? i)}
        />
      </section>

      {/* Loss Reasons */}
      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Loss Reasons</h2>
        <DataTable
          rows={loss}
          columns={[
            { key: 'loss_reason', header: 'Reason', render: (r: LossRow) => r.loss_reason },
            { key: 'lost_count', header: 'Count', render: (r: LossRow) => r.lost_count },
            { key: 'lost_value_rupees', header: 'Lost Value', render: (r: LossRow) => fmtRupees(r.lost_value_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: LossRow, i: number) => String(r.loss_reason ?? i)}
        />
      </section>

      {/* Negotiation Intensity */}
      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Negotiation Intensity (rounds vs win rate)</h2>
        <DataTable
          rows={intensity}
          columns={[
            { key: 'rounds_bucket', header: 'Rounds', render: (r: IntensityRow) => r.rounds_bucket },
            { key: 'quote_count', header: 'Quotes', render: (r: IntensityRow) => r.quote_count },
            { key: 'won_count', header: 'Won', render: (r: IntensityRow) => r.won_count },
            { key: 'win_rate_pct', header: 'Win Rate', render: (r: IntensityRow) => fmtPct(r.win_rate_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: IntensityRow, i: number) => String(r.rounds_bucket ?? i)}
        />
      </section>

      {/* Ask vs Close */}
      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Ask vs Close (won deals)</h2>
        <DataTable
          rows={askClose}
          columns={[
            { key: 'quote_ref', header: 'Quote', render: (r: AskCloseRow) => r.quote_ref },
            { key: 'customer_name', header: 'Customer', render: (r: AskCloseRow) => r.customer_name },
            { key: 'ask_amount_rupees', header: 'Ask', render: (r: AskCloseRow) => fmtRupees(r.ask_amount_rupees) },
            { key: 'closed_amount_rupees', header: 'Closed', render: (r: AskCloseRow) => fmtRupees(r.closed_amount_rupees) },
            { key: 'drop_pct', header: 'Drop', render: (r: AskCloseRow) => fmtPct(r.drop_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: AskCloseRow, i: number) => String(r.quote_ref ?? i)}
        />
      </section>

      {/* Active Negotiations */}
      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active Negotiations</h2>
        <DataTable
          rows={active}
          columns={[
            { key: 'quote_ref', header: 'Quote', render: (r: ActiveRow) => r.quote_ref },
            { key: 'customer_name', header: 'Customer', render: (r: ActiveRow) => r.customer_name },
            { key: 'quoted_amount_rupees', header: 'Quoted', render: (r: ActiveRow) => fmtRupees(r.quoted_amount_rupees) },
            { key: 'negotiation_rounds', header: 'Rounds', render: (r: ActiveRow) => r.negotiation_rounds },
            { key: 'days_open', header: 'Days Open', render: (r: ActiveRow) => r.days_open },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActiveRow, i: number) => String(r.quote_ref ?? i)}
        />
      </section>

      {/* Recent Quotes */}
      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Quotes</h2>
        <DataTable
          rows={recent}
          columns={[
            { key: 'quote_ref', header: 'Quote', render: (r: QuoteRow) => r.quote_ref },
            { key: 'customer_name', header: 'Customer', render: (r: QuoteRow) => r.customer_name },
            { key: 'customer_segment', header: 'Segment', render: (r: QuoteRow) => r.customer_segment },
            { key: 'ask_amount_rupees', header: 'Ask', render: (r: QuoteRow) => fmtRupees(r.ask_amount_rupees) },
            { key: 'quoted_amount_rupees', header: 'Quoted', render: (r: QuoteRow) => fmtRupees(r.quoted_amount_rupees) },
            { key: 'discount_pct', header: 'Discount', render: (r: QuoteRow) => fmtPct(r.discount_pct) },
            { key: 'negotiation_rounds', header: 'Rounds', render: (r: QuoteRow) => r.negotiation_rounds },
            { key: 'outcome', header: 'Outcome', render: (r: QuoteRow) => r.outcome },
            { key: 'loss_reason', header: 'Loss Reason', render: (r: QuoteRow) => r.loss_reason ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuoteRow, i: number) => String(r.quote_ref ?? i)}
        />
      </section>
    </div>
  );
}
