import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderStrategicBetsPortfolioPage() {
  const supabase = await getSupabaseServerClient();

  const [
    betsRes,
    evidenceRes,
    breakdownRes,
    topRevenueRes,
    recentEvidenceRes,
    overdueRes,
    weeklyRes,
  ] = await Promise.all([
    supabase.rpc('list_bets_r2433'),
    supabase.rpc('list_evidence_r2433'),
    supabase.rpc('status_breakdown_r2433'),
    supabase.rpc('top_revenue_bets_r2433'),
    supabase.rpc('recent_evidence_r2433'),
    supabase.rpc('overdue_reviews_r2433'),
    supabase.rpc('weekly_confidence_change_r2433'),
  ]);

  const bets = (betsRes.data ?? []) as any[];
  const evidence = (evidenceRes.data ?? []) as any[];
  const breakdown = (breakdownRes.data ?? []) as any[];
  const topRevenue = (topRevenueRes.data ?? []) as any[];
  const recentEvidence = (recentEvidenceRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const weekly = (weeklyRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '—' : '₹' + Number(n).toLocaleString('en-IN');
  const fmtDate = (d: string | null | undefined) =>
    d ? new Date(d).toLocaleString('en-IN') : '—';

  const betCols: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => r.bet_name },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'confidence_pct', header: 'Confidence', render: (r: any) => r.confidence_pct + '%' },
    { key: 'revenue_impact_rupees', header: 'Revenue Impact', render: (r: any) => fmtRupees(r.revenue_impact_rupees) },
    { key: 'time_to_evidence_days', header: 'Time to Evidence', render: (r: any) => r.time_to_evidence_days + ' days' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'next_review_at', header: 'Next Review', render: (r: any) => fmtDate(r.next_review_at) },
    { key: 'kill_threshold', header: 'Kill Threshold', render: (r: any) => r.kill_threshold ?? '—' },
  ];

  const evidenceCols: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => r.bet_name },
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'evidence_kind', header: 'Kind', render: (r: any) => r.evidence_kind },
    { key: 'evidence_md', header: 'Evidence', render: (r: any) => r.evidence_md },
    { key: 'confidence_delta_pct', header: 'Delta', render: (r: any) => (r.confidence_delta_pct > 0 ? '+' : '') + r.confidence_delta_pct + '%' },
    { key: 'decision_impact', header: 'Decision Impact', render: (r: any) => r.decision_impact ?? '—' },
    { key: 'source_link', header: 'Source', render: (r: any) => r.source_link ?? '—' },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'bet_count', header: 'Bets', render: (r: any) => r.bet_count },
    { key: 'total_revenue_rupees', header: 'Total Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'avg_confidence_pct', header: 'Avg Confidence', render: (r: any) => (r.avg_confidence_pct ?? 0) + '%' },
  ];

  const topRevenueCols: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => r.bet_name },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'confidence_pct', header: 'Confidence', render: (r: any) => r.confidence_pct + '%' },
    { key: 'revenue_impact_rupees', header: 'Revenue Impact', render: (r: any) => fmtRupees(r.revenue_impact_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const recentEvidenceCols: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => r.bet_name },
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'evidence_kind', header: 'Kind', render: (r: any) => r.evidence_kind },
    { key: 'evidence_md', header: 'Evidence', render: (r: any) => r.evidence_md },
    { key: 'confidence_delta_pct', header: 'Delta', render: (r: any) => (r.confidence_delta_pct > 0 ? '+' : '') + r.confidence_delta_pct + '%' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => r.bet_name },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'next_review_at', header: 'Next Review', render: (r: any) => fmtDate(r.next_review_at) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => r.days_overdue },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => r.bet_name },
    { key: 'net_delta_pct', header: 'Net Delta (7d)', render: (r: any) => (Number(r.net_delta_pct) > 0 ? '+' : '') + r.net_delta_pct + '%' },
    { key: 'supporting_count', header: 'Supporting', render: (r: any) => r.supporting_count },
    { key: 'refuting_count', header: 'Refuting', render: (r: any) => r.refuting_count },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>Founder Strategic Bets Portfolio</h1>
      <p style={{ color: '#666', marginBottom: '2rem' }}>
        Bet × thesis × hypothesis × evidence × proceed / pivot / kill × confidence × revenue impact.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', marginBottom: '0.75rem' }}>Status breakdown</h2>
        <DataTable
          rows={breakdown}
          columns={breakdownCols}
          emptyMessage="No bets yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', marginBottom: '0.75rem' }}>Top revenue bets</h2>
        <DataTable
          rows={topRevenue}
          columns={topRevenueCols}
          emptyMessage="No active bets."
          rowKey={(r: any, i: number) => String(r.bet_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', marginBottom: '0.75rem' }}>Weekly confidence change</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No evidence in the last 7 days."
          rowKey={(r: any, i: number) => String(r.bet_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', marginBottom: '0.75rem' }}>Overdue reviews</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue bet reviews."
          rowKey={(r: any, i: number) => String(r.bet_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', marginBottom: '0.75rem' }}>All bets</h2>
        <DataTable
          rows={bets}
          columns={betCols}
          emptyMessage="No bets in portfolio."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', marginBottom: '0.75rem' }}>Recent evidence (30d)</h2>
        <DataTable
          rows={recentEvidence}
          columns={recentEvidenceCols}
          emptyMessage="No evidence logged in the last 30 days."
          rowKey={(r: any, i: number) => String(r.bet_name + r.observed_at)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', marginBottom: '0.75rem' }}>All evidence log</h2>
        <DataTable
          rows={evidence}
          columns={evidenceCols}
          emptyMessage="No evidence logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
