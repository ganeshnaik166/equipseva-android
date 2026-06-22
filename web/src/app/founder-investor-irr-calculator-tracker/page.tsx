import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CalcRow = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  period_label: string;
  invested_rupees: number;
  current_value_rupees: number;
  irr_pct: number;
  status: string;
  calculated_at: string | null;
  approved_at: string | null;
  created_at: string;
};

type TopRow = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  period_label: string;
  irr_pct: number;
  status: string;
  calculated_at: string | null;
};

type ActionRow = {
  id: string;
  calc_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(2) + ' pct';
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '-';
  return new Date(d).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [calcsRes, topRes, actionsRes] = await Promise.all([
    sb.rpc('list_irr_calcs_r2037'),
    sb.rpc('top_irrs_r2037'),
    sb.rpc('recent_irr_actions_r2037'),
  ]);

  const calcs: CalcRow[] = (calcsRes.data as CalcRow[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const totalInvested = calcs.reduce((s, r) => s + (r.invested_rupees || 0), 0);
  const totalCurrent = calcs.reduce((s, r) => s + (r.current_value_rupees || 0), 0);
  const approvedCount = calcs.filter((r) => r.status === 'approved' || r.status === 'sent').length;
  const disputedCount = calcs.filter((r) => r.status === 'disputed').length;

  const calcCols: Column<CalcRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label },
    { key: 'invested_rupees', header: 'Invested', render: (r: any) => fmtRupees(r.invested_rupees) },
    { key: 'current_value_rupees', header: 'Current value', render: (r: any) => fmtRupees(r.current_value_rupees) },
    { key: 'irr_pct', header: 'IRR', render: (r: any) => fmtPct(r.irr_pct) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'calculated_at', header: 'Calculated', render: (r: any) => fmtDate(r.calculated_at) },
    { key: 'approved_at', header: 'Approved', render: (r: any) => fmtDate(r.approved_at) },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label },
    { key: 'irr_pct', header: 'IRR', render: (r: any) => fmtPct(r.irr_pct) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'calculated_at', header: 'Calculated', render: (r: any) => fmtDate(r.calculated_at) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'calc_id', header: 'Calc ref', render: (r: any) => String(r.calc_id).slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Investor IRR Calculator Tracker</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track IRR calculations across investors. Draft, approve, send, and reconcile disputes.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Portfolio summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 14 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total calcs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{calcs.length}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 14 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total invested</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(totalInvested)}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 14 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total current value</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(totalCurrent)}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 14 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Approved or sent</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{approvedCount}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 14 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Disputed</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: disputedCount > 0 ? '#c0392b' : '#222' }}>{disputedCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>All IRR calculations</h2>
        <DataTable rows={calcs} columns={calcCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Top IRRs</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
