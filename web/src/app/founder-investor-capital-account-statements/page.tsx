import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type StatementRow = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  statement_quarter: string;
  opening_balance_rupees: number;
  contributions_rupees: number;
  distributions_rupees: number;
  gains_losses_rupees: number;
  closing_balance_rupees: number;
  status: string;
  generated_at: string;
};

type DisputeRow = {
  id: string;
  statement_id: string;
  investor_email: string | null;
  statement_quarter: string;
  dispute_text: string;
  raised_at: string;
  raised_by_email: string | null;
  resolution_at: string | null;
  resolution_note: string | null;
};

type LatestBalanceRow = {
  investor_id: string;
  investor_email: string | null;
  latest_quarter: string;
  closing_balance_rupees: number;
  generated_at: string;
};

type TopGrowthRow = {
  investor_id: string;
  investor_email: string | null;
  total_gains_rupees: number;
  statement_count: number;
};

function fmtRupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [stmtsRes, dispsRes, latestRes, topRes] = await Promise.all([
    sb.rpc('r1877_list_statements'),
    sb.rpc('r1877_list_disputes'),
    sb.rpc('r1877_latest_balance'),
    sb.rpc('r1877_top_growth'),
  ]);

  const statements: StatementRow[] = (stmtsRes.data as StatementRow[]) ?? [];
  const disputes: DisputeRow[] = (dispsRes.data as DisputeRow[]) ?? [];
  const latest: LatestBalanceRow[] = (latestRes.data as LatestBalanceRow[]) ?? [];
  const topGrowth: TopGrowthRow[] = (topRes.data as TopGrowthRow[]) ?? [];

  const totalAUM = latest.reduce((acc, r) => acc + Number(r.closing_balance_rupees || 0), 0);
  const openDisputes = disputes.filter((d) => !d.resolution_at).length;

  const stmtCols: Column<StatementRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) },
    { key: 'statement_quarter', header: 'Quarter', render: (r: any) => r.statement_quarter },
    { key: 'opening_balance_rupees', header: 'Opening', render: (r: any) => fmtRupees(r.opening_balance_rupees) },
    { key: 'contributions_rupees', header: 'Contrib', render: (r: any) => fmtRupees(r.contributions_rupees) },
    { key: 'distributions_rupees', header: 'Distrib', render: (r: any) => fmtRupees(r.distributions_rupees) },
    { key: 'gains_losses_rupees', header: 'Gains/Losses', render: (r: any) => fmtRupees(r.gains_losses_rupees) },
    { key: 'closing_balance_rupees', header: 'Closing', render: (r: any) => fmtRupees(r.closing_balance_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'generated_at', header: 'Generated', render: (r: any) => fmtDate(r.generated_at) },
  ];

  const dispCols: Column<DisputeRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '-' },
    { key: 'statement_quarter', header: 'Quarter', render: (r: any) => r.statement_quarter },
    { key: 'dispute_text', header: 'Dispute', render: (r: any) => (r.dispute_text ?? '').slice(0, 80) },
    { key: 'raised_by_email', header: 'Raised By', render: (r: any) => r.raised_by_email ?? '-' },
    { key: 'raised_at', header: 'Raised At', render: (r: any) => fmtDate(r.raised_at) },
    { key: 'resolution_at', header: 'Resolved', render: (r: any) => (r.resolution_at ? fmtDate(r.resolution_at) : 'open') },
    { key: 'resolution_note', header: 'Note', render: (r: any) => (r.resolution_note ?? '-').slice(0, 80) },
  ];

  const latestCols: Column<LatestBalanceRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) },
    { key: 'latest_quarter', header: 'Latest Quarter', render: (r: any) => r.latest_quarter },
    { key: 'closing_balance_rupees', header: 'Closing Balance', render: (r: any) => fmtRupees(r.closing_balance_rupees) },
    { key: 'generated_at', header: 'Generated', render: (r: any) => fmtDate(r.generated_at) },
  ];

  const growthCols: Column<TopGrowthRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) },
    { key: 'total_gains_rupees', header: 'Total Gains', render: (r: any) => fmtRupees(r.total_gains_rupees) },
    { key: 'statement_count', header: 'Statements', render: (r: any) => r.statement_count },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Capital Account Statements</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Quarterly capital account statements per investor — opening → contributions & distributions → gains/losses → closing balance.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Statements (recent)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{statements.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total AUM (latest)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalAUM)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Open Disputes</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: openDisputes > 0 ? '#dc2626' : '#16a34a' }}>{openDisputes}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Investors Tracked</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{latest.length}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Latest Balance Per Investor</h2>
        <DataTable
          rows={latest}
          columns={latestCols}
          rowKey={(r: any, i: number) => String(r.investor_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Growth (Cumulative Gains)</h2>
        <DataTable
          rows={topGrowth}
          columns={growthCols}
          rowKey={(r: any, i: number) => String(r.investor_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Statements</h2>
        <DataTable
          rows={statements}
          columns={stmtCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Dispute Log</h2>
        <DataTable
          rows={disputes}
          columns={dispCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
