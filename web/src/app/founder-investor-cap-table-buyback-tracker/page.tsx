import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Buyback = {
  id: string;
  buyback_label: string;
  shares_bought_back: number;
  total_cost_rupees: number;
  buyback_date: string;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  buyback_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  shares_change: number;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [buybacksRes, recentBuybacksRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_buybacks_r2185'),
    sb.rpc('recent_buybacks_r2185', { p_limit: 25 }),
    sb.rpc('recent_actions_r2185', { p_limit: 25 }),
  ]);

  const buybacks: Buyback[] = (buybacksRes.data as Buyback[] | null) ?? [];
  const recentBuybacks: Buyback[] = (recentBuybacksRes.data as Buyback[] | null) ?? [];
  const recentActions: ActionRow[] = (recentActionsRes.data as ActionRow[] | null) ?? [];

  const totalShares = buybacks.reduce((acc, r) => acc + Number(r.shares_bought_back || 0), 0);
  const totalCost = buybacks.reduce((acc, r) => acc + Number(r.total_cost_rupees || 0), 0);
  const completedCount = buybacks.filter((r) => r.status === 'completed').length;

  const buybackColumns: Column<Buyback>[] = [
    { key: 'buyback_label', header: 'Label', render: (r: any) => String(r.buyback_label ?? '') },
    { key: 'shares_bought_back', header: 'Shares', render: (r: any) => Number(r.shares_bought_back ?? 0).toLocaleString('en-IN') },
    { key: 'total_cost_rupees', header: 'Cost (rupees)', render: (r: any) => Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'buyback_date', header: 'Date', render: (r: any) => String(r.buyback_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const recentBuybackColumns: Column<Buyback>[] = [
    { key: 'buyback_label', header: 'Label', render: (r: any) => String(r.buyback_label ?? '') },
    { key: 'shares_bought_back', header: 'Shares', render: (r: any) => Number(r.shares_bought_back ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'shares_change', header: 'Shares change', render: (r: any) => Number(r.shares_change ?? 0).toLocaleString('en-IN') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Cap Table Buyback Tracker</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Round r2185. Track announced, in-progress, and completed share buybacks plus the action log behind each one.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Total shares bought back</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalShares.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Total cost (rupees)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalCost.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Completed buybacks</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{completedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All buybacks</h2>
        <DataTable<Buyback>
          rows={buybacks}
          columns={buybackColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent buybacks</h2>
        <DataTable<Buyback>
          rows={recentBuybacks}
          columns={recentBuybackColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable<ActionRow>
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
