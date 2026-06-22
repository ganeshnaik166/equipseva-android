import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Deal = {
  id: string;
  investor_id: string | null;
  deal_label: string | null;
  round_label: string | null;
  target_close_date: string | null;
  amount_committed_rupees: number | null;
  status: string | null;
  closed_at: string | null;
  captured_at: string | null;
};

type ActiveDeal = {
  id: string;
  deal_label: string | null;
  round_label: string | null;
  target_close_date: string | null;
  amount_committed_rupees: number | null;
  status: string | null;
  captured_at: string | null;
};

type Action = {
  id: string;
  deal_id: string;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  amount_rupees: number | null;
  notes_md: string | null;
};

function fmtDate(v: string | null) {
  if (!v) return '';
  try { return new Date(v).toLocaleString('en-IN'); } catch { return v; }
}

function fmtRupees(n: number | null) {
  if (n === null || n === undefined) return '';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [allDealsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_deals_r2085'),
    sb.rpc('active_deals_r2085'),
    sb.rpc('recent_actions_r2085'),
  ]);

  const allDeals: Deal[] = (allDealsRes.data as Deal[]) || [];
  const active: ActiveDeal[] = (activeRes.data as ActiveDeal[]) || [];
  const recent: Action[] = (recentRes.data as Action[]) || [];

  const dealColumns: Column<Deal>[] = [
    { key: 'deal_label', header: 'Deal', render: (r: any) => r.deal_label || '' },
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label || '' },
    { key: 'target_close_date', header: 'Target Close', render: (r: any) => r.target_close_date || '' },
    { key: 'amount_committed_rupees', header: 'Committed', render: (r: any) => fmtRupees(r.amount_committed_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '' },
    { key: 'closed_at', header: 'Closed At', render: (r: any) => fmtDate(r.closed_at) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const activeColumns: Column<ActiveDeal>[] = [
    { key: 'deal_label', header: 'Deal', render: (r: any) => r.deal_label || '' },
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label || '' },
    { key: 'target_close_date', header: 'Target Close', render: (r: any) => r.target_close_date || '' },
    { key: 'amount_committed_rupees', header: 'Committed', render: (r: any) => fmtRupees(r.amount_committed_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const actionColumns: Column<Action>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type || '' },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md || '' },
    { key: 'deal_id', header: 'Deal Id', render: (r: any) => r.deal_id || '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Investor Deal Closing Pipeline</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Track deals moving toward close. Founder only. Round r2085.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active Deals</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Deals currently in motion, ordered by target close date.</p>
        <DataTable
          rows={active}
          columns={activeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Deals</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Every deal logged, latest captured first.</p>
        <DataTable
          rows={allDeals}
          columns={dealColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Term sheets, legal drafts, wires received, closes and losses.</p>
        <DataTable
          rows={recent}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
