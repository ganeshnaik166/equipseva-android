import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PlanRow = {
  id: string;
  plan_label: string;
  total_authorized_shares: number;
  total_issued_shares: number;
  status: string;
  last_amended_at: string | null;
  captured_at: string;
};

type ActionRow = {
  id: string;
  plan_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  shares_change: number;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const plansRes = await sb.rpc('list_plans_r2169');
  const activeRes = await sb.rpc('active_plans_r2169');
  const recentRes = await sb.rpc('recent_actions_r2169', { p_limit: 50 });

  const plans: PlanRow[] = (plansRes.data as PlanRow[] | null) ?? [];
  const active: PlanRow[] = (activeRes.data as PlanRow[] | null) ?? [];
  const recent: ActionRow[] = (recentRes.data as ActionRow[] | null) ?? [];

  const planCols: Column<PlanRow>[] = [
    { key: 'plan_label', header: 'Plan', render: (r: any) => r.plan_label },
    { key: 'total_authorized_shares', header: 'Authorized', render: (r: any) => String(r.total_authorized_shares ?? 0) },
    { key: 'total_issued_shares', header: 'Issued', render: (r: any) => String(r.total_issued_shares ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_amended_at', header: 'Last Amended', render: (r: any) => r.last_amended_at ? new Date(r.last_amended_at).toLocaleString() : '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'shares_change', header: 'Shares Change', render: (r: any) => String(r.shares_change ?? 0) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
    { key: 'plan_id', header: 'Plan ID', render: (r: any) => String(r.plan_id).slice(0, 8) },
  ];

  return (
    <div style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Investor Cap Table Stock Plan Tracker</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Track stock plan amendments across the cap table — authorized vs issued, status, and amendment history.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Active Plans ({active.length})</h2>
        <DataTable rows={active} columns={planCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All Plans ({plans.length})</h2>
        <DataTable rows={plans} columns={planCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Actions ({recent.length})</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
