import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function bpsToPct(bps: number | null | undefined): string {
  const v = Number(bps ?? 0) / 100;
  return v.toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summary, byChain, byKind, closing, buckets, events, stages, topDeals] = await Promise.all([
    supabase.rpc('founder_hcfp_r2787_pipeline_summary'),
    supabase.rpc('founder_hcfp_r2787_deals_by_chain'),
    supabase.rpc('founder_hcfp_r2787_deals_by_financing_kind'),
    supabase.rpc('founder_hcfp_r2787_closing_window'),
    supabase.rpc('founder_hcfp_r2787_renew_probability_buckets'),
    supabase.rpc('founder_hcfp_r2787_recent_events', { p_limit: 25 }),
    supabase.rpc('founder_hcfp_r2787_stage_breakdown'),
    supabase.rpc('founder_hcfp_r2787_top_deals', { p_limit: 10 }),
  ]);

  const s = (summary.data && summary.data[0]) || {
    total_deals: 0,
    total_ticket_rupees: 0,
    weighted_revenue_rupees: 0,
    avg_renew_prob_bps: 0,
    funded_deals: 0,
    pipeline_deals: 0,
  };

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>
          Hospital Chain Quarterly Equipment Financing Pulse
        </h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Chain × deal × financing kind × terms × close × revenue × renew probability
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <KpiCard label="Total Deals" value={String(s.total_deals)} />
        <KpiCard label="Total Ticket" value={rupees(s.total_ticket_rupees)} />
        <KpiCard label="Weighted Revenue" value={rupees(s.weighted_revenue_rupees)} />
        <KpiCard label="Avg Renew Prob" value={bpsToPct(s.avg_renew_prob_bps)} />
        <KpiCard label="Funded Deals" value={String(s.funded_deals)} />
        <KpiCard label="In Pipeline" value={String(s.pipeline_deals)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Deals by Chain</h2>
        <DataTable
          rows={byChain.data ?? []}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'deal_count', header: 'Deals', render: (r: any) => String(r.deal_count) },
            { key: 'total_ticket_rupees', header: 'Total Ticket', render: (r: any) => rupees(r.total_ticket_rupees) },
            { key: 'total_quarterly_revenue_rupees', header: 'Quarterly Revenue', render: (r: any) => rupees(r.total_quarterly_revenue_rupees) },
            { key: 'avg_renew_bps', header: 'Avg Renew', render: (r: any) => bpsToPct(r.avg_renew_bps) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Deals by Financing Kind</h2>
        <DataTable
          rows={byKind.data ?? []}
          columns={[
            { key: 'financing_kind', header: 'Kind', render: (r: any) => r.financing_kind },
            { key: 'deal_count', header: 'Deals', render: (r: any) => String(r.deal_count) },
            { key: 'total_ticket_rupees', header: 'Total Ticket', render: (r: any) => rupees(r.total_ticket_rupees) },
            { key: 'avg_term_months', header: 'Avg Term (mo)', render: (r: any) => Number(r.avg_term_months ?? 0).toFixed(1) },
            { key: 'avg_interest_bps', header: 'Avg Rate', render: (r: any) => bpsToPct(r.avg_interest_bps) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.financing_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Closing Window</h2>
        <DataTable
          rows={closing.data ?? []}
          columns={[
            { key: 'deal_code', header: 'Deal', render: (r: any) => r.deal_code },
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'expected_close_date', header: 'Expected Close', render: (r: any) => String(r.expected_close_date ?? '') },
            { key: 'days_to_close', header: 'Days', render: (r: any) => String(r.days_to_close) },
            { key: 'ticket_size_rupees', header: 'Ticket', render: (r: any) => rupees(r.ticket_size_rupees) },
            { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
          ]}
          emptyMessage="No deals in window"
          rowKey={(r: any, i: number) => String(r.deal_code ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Renew Probability Buckets</h2>
        <DataTable
          rows={buckets.data ?? []}
          columns={[
            { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
            { key: 'deal_count', header: 'Deals', render: (r: any) => String(r.deal_count) },
            { key: 'expected_revenue_rupees', header: 'Expected Revenue', render: (r: any) => rupees(r.expected_revenue_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Stage Breakdown</h2>
        <DataTable
          rows={stages.data ?? []}
          columns={[
            { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
            { key: 'deal_count', header: 'Deals', render: (r: any) => String(r.deal_count) },
            { key: 'total_ticket_rupees', header: 'Total Ticket', render: (r: any) => rupees(r.total_ticket_rupees) },
            { key: 'expected_revenue_rupees', header: 'Expected Revenue', render: (r: any) => rupees(r.expected_revenue_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.stage ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Deals</h2>
        <DataTable
          rows={topDeals.data ?? []}
          columns={[
            { key: 'deal_code', header: 'Deal', render: (r: any) => r.deal_code },
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'equipment_category', header: 'Equipment', render: (r: any) => r.equipment_category },
            { key: 'financing_kind', header: 'Kind', render: (r: any) => r.financing_kind },
            { key: 'ticket_size_rupees', header: 'Ticket', render: (r: any) => rupees(r.ticket_size_rupees) },
            { key: 'term_months', header: 'Term', render: (r: any) => String(r.term_months) + ' mo' },
            { key: 'interest_rate_bps', header: 'Rate', render: (r: any) => bpsToPct(r.interest_rate_bps) },
            { key: 'quarterly_revenue_rupees', header: 'Qtr Rev', render: (r: any) => rupees(r.quarterly_revenue_rupees) },
            { key: 'renew_probability_bps', header: 'Renew', render: (r: any) => bpsToPct(r.renew_probability_bps) },
            { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
            { key: 'expected_close_date', header: 'Close', render: (r: any) => String(r.expected_close_date ?? '') },
          ]}
          emptyMessage="No deals"
          rowKey={(r: any, i: number) => String(r.deal_code ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Pulse Events</h2>
        <DataTable
          rows={events.data ?? []}
          columns={[
            { key: 'event_at', header: 'When', render: (r: any) => new Date(r.event_at).toLocaleString('en-IN') },
            { key: 'deal_code', header: 'Deal', render: (r: any) => r.deal_code },
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'event_kind', header: 'Event', render: (r: any) => r.event_kind },
            { key: 'delta_rupees', header: 'Delta', render: (r: any) => rupees(r.delta_rupees) },
            { key: 'note', header: 'Note', render: (r: any) => r.note ?? '' },
          ]}
          emptyMessage="No events"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}
