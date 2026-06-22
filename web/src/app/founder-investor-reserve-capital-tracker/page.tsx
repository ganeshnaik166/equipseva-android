import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ReserveRow = {
  id: string;
  investor_id: string;
  reserve_label: string;
  reserve_amount_rupees: number;
  drawdown_amount_rupees: number;
  remaining_rupees: number;
  status: string;
  captured_at: string;
};

type ExhaustedRow = {
  id: string;
  investor_id: string;
  reserve_label: string;
  reserve_amount_rupees: number;
  drawdown_amount_rupees: number;
  captured_at: string;
};

type RecentActionRow = {
  id: string;
  reserve_id: string;
  reserve_label: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  amount_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [reservesRes, exhaustedRes, recentRes] = await Promise.all([
    sb.rpc('list_reserves_r2105'),
    sb.rpc('exhausted_r2105'),
    sb.rpc('recent_actions_r2105'),
  ]);

  const reserves: ReserveRow[] = (reservesRes.data as ReserveRow[] | null) ?? [];
  const exhausted: ExhaustedRow[] = (exhaustedRes.data as ExhaustedRow[] | null) ?? [];
  const recent: RecentActionRow[] = (recentRes.data as RecentActionRow[] | null) ?? [];

  const totalCommitted = reserves.reduce((s, r) => s + (r.reserve_amount_rupees || 0), 0);
  const totalDrawn = reserves.reduce((s, r) => s + (r.drawdown_amount_rupees || 0), 0);
  const totalRemaining = totalCommitted - totalDrawn;

  const reserveCols: Column<ReserveRow>[] = [
    { key: 'reserve_label', header: 'Reserve', render: (r: any) => r.reserve_label ?? '-' },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'reserve_amount_rupees', header: 'Committed', render: (r: any) => fmtRupees(r.reserve_amount_rupees) },
    { key: 'drawdown_amount_rupees', header: 'Drawn', render: (r: any) => fmtRupees(r.drawdown_amount_rupees) },
    { key: 'remaining_rupees', header: 'Remaining', render: (r: any) => fmtRupees(r.remaining_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const exhaustedCols: Column<ExhaustedRow>[] = [
    { key: 'reserve_label', header: 'Reserve', render: (r: any) => r.reserve_label ?? '-' },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'reserve_amount_rupees', header: 'Committed', render: (r: any) => fmtRupees(r.reserve_amount_rupees) },
    { key: 'drawdown_amount_rupees', header: 'Drawn', render: (r: any) => fmtRupees(r.drawdown_amount_rupees) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const recentCols: Column<RecentActionRow>[] = [
    { key: 'reserve_label', header: 'Reserve', render: (r: any) => r.reserve_label ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => fmtDate(r.taken_at) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>
        Investor Reserve Capital Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track investor reserve capital commitments, drawdowns, and exhaustion events.
      </p>

      <section style={{ marginBottom: 24, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total committed</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(totalCommitted)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total drawn</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(totalDrawn)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total remaining</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(totalRemaining)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All reserves</h2>
        <DataTable
          rows={reserves}
          columns={reserveCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Exhausted reserves</h2>
        <DataTable
          rows={exhausted}
          columns={exhaustedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
