import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorPerformanceReportsPage() {
  const sb = await getSupabaseServerClient();

  const [reportsRes, disputesRes, leaderboardRes, recentRes] = await Promise.all([
    sb.rpc('list_reports_r1749'),
    sb.rpc('list_disputes_r1749'),
    sb.rpc('irr_leaderboard_r1749'),
    sb.rpc('recent_reports_per_investor_r1749'),
  ]);

  const reports = (reportsRes.data ?? []) as any[];
  const disputes = (disputesRes.data ?? []) as any[];
  const leaderboard = (leaderboardRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const reportColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'report_period_start', header: 'Period Start', render: (r: any) => r.report_period_start ?? '—' },
    { key: 'report_period_end', header: 'Period End', render: (r: any) => r.report_period_end ?? '—' },
    { key: 'invested_rupees', header: 'Invested (Rs)', render: (r: any) => Number(r.invested_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'current_value_rupees', header: 'Current Value (Rs)', render: (r: any) => Number(r.current_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'distributions_received_rupees', header: 'Distributions (Rs)', render: (r: any) => Number(r.distributions_received_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'irr_pct', header: 'IRR %', render: (r: any) => `${Number(r.irr_pct ?? 0).toFixed(2)}%` },
    { key: 'moic', header: 'MOIC', render: (r: any) => `${Number(r.moic ?? 0).toFixed(2)}x` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '—' },
  ];

  const disputeColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'dispute_text', header: 'Dispute', render: (r: any) => r.dispute_text ?? '—' },
    { key: 'raised_at', header: 'Raised At', render: (r: any) => r.raised_at ? new Date(r.raised_at).toLocaleString('en-IN') : '—' },
    { key: 'raised_by_email', header: 'Raised By', render: (r: any) => r.raised_by_email ?? '—' },
    { key: 'resolution_at', header: 'Resolved At', render: (r: any) => r.resolution_at ? new Date(r.resolution_at).toLocaleString('en-IN') : 'OPEN' },
    { key: 'resolution_note', header: 'Resolution Note', render: (r: any) => r.resolution_note ?? '—' },
  ];

  const leaderboardColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'best_irr_pct', header: 'Best IRR %', render: (r: any) => `${Number(r.best_irr_pct ?? 0).toFixed(2)}%` },
    { key: 'best_moic', header: 'Best MOIC', render: (r: any) => `${Number(r.best_moic ?? 0).toFixed(2)}x` },
    { key: 'total_invested_rupees', header: 'Total Invested (Rs)', render: (r: any) => Number(r.total_invested_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'total_current_value_rupees', header: 'Total Current (Rs)', render: (r: any) => Number(r.total_current_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'report_count', header: 'Reports', render: (r: any) => r.report_count ?? 0 },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'latest_report_at', header: 'Latest Report', render: (r: any) => r.latest_report_at ? new Date(r.latest_report_at).toLocaleString('en-IN') : '—' },
    { key: 'latest_irr_pct', header: 'Latest IRR %', render: (r: any) => `${Number(r.latest_irr_pct ?? 0).toFixed(2)}%` },
    { key: 'latest_moic', header: 'Latest MOIC', render: (r: any) => `${Number(r.latest_moic ?? 0).toFixed(2)}x` },
    { key: 'latest_status', header: 'Status', render: (r: any) => r.latest_status ?? '—' },
    { key: 'total_reports', header: 'Total Reports', render: (r: any) => r.total_reports ?? 0 },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Performance Reports</h1>
        <p className="text-sm text-gray-600">Per-investor IRR & MOIC reports, dispute log, leaderboard.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Reports</h2>
        <DataTable
          rows={reports}
          columns={reportColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dispute Log</h2>
        <DataTable
          rows={disputes}
          columns={disputeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">IRR Leaderboard (top 50 by best IRR)</h2>
        <DataTable
          rows={leaderboard}
          columns={leaderboardColumns}
          rowKey={(r: any, i: number) => String(r.investor_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Reports Per Investor</h2>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.investor_email ?? i)}
        />
      </section>
    </div>
  );
}
