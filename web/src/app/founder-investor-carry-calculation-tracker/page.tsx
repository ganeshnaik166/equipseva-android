import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CalcRow = {
  id: string;
  investor_id: string;
  period_label: string;
  gross_returns_rupees: number;
  lp_returns_rupees: number;
  gp_carry_rupees: number;
  carry_rate_pct: number;
  status: string;
  calculated_at: string;
  paid_at: string | null;
};

type ActionRow = {
  id: string;
  calc_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  amount_rupees: number | null;
  notes_md: string | null;
};

type Totals = {
  total_paid_rupees: number;
  paid_count: number;
  draft_count: number;
  approved_count: number;
  disputed_count: number;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [calcsRes, actionsRes, totalsRes] = await Promise.all([
    sb.rpc('list_calcs_r1985', { p_limit: 100 }),
    sb.rpc('recent_actions_r1985', { p_limit: 50 }),
    sb.rpc('total_paid_r1985'),
  ]);

  const calcs: CalcRow[] = (calcsRes.data as CalcRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const totalsArr = (totalsRes.data as Totals[] | null) ?? [];
  const totals: Totals = totalsArr[0] ?? {
    total_paid_rupees: 0,
    paid_count: 0,
    draft_count: 0,
    approved_count: 0,
    disputed_count: 0,
  };

  const calcCols: Column<CalcRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '-') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '-').slice(0, 8) },
    { key: 'gross_returns_rupees', header: 'Gross', render: (r: any) => rupees(r.gross_returns_rupees) },
    { key: 'lp_returns_rupees', header: 'LP Returns', render: (r: any) => rupees(r.lp_returns_rupees) },
    { key: 'gp_carry_rupees', header: 'GP Carry', render: (r: any) => rupees(r.gp_carry_rupees) },
    { key: 'carry_rate_pct', header: 'Rate', render: (r: any) => String(r.carry_rate_pct ?? '-') + '%' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'calculated_at', header: 'Calculated', render: (r: any) => fmtDate(r.calculated_at) },
    { key: 'paid_at', header: 'Paid', render: (r: any) => fmtDate(r.paid_at) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '-') },
    { key: 'calc_id', header: 'Calc', render: (r: any) => String(r.calc_id ?? '-').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => rupees(r.amount_rupees) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '-') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Investor Carry Calculation Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track gross returns, LP returns, and GP carry across investor periods. Log approval, payment, and dispute actions for each calculation.
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Totals</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Total Paid Carry</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{rupees(totals.total_paid_rupees)}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Paid</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{totals.paid_count}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Draft</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{totals.draft_count}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Approved</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{totals.approved_count}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Disputed</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{totals.disputed_count}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Calculations</h2>
        <DataTable
          rows={calcs}
          columns={calcCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
