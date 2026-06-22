import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type EarningRow = {
  id: string;
  engineer_user_id: string;
  period_label: string;
  base_payout_rupees: number;
  bonus_payout_rupees: number;
  total_earnings_rupees: number;
  ytd_total_rupees: number;
  status: string;
  captured_at: string;
};

type TopEarner = {
  engineer_user_id: string;
  total_rupees: number;
  ytd_rupees: number;
  entries: number;
};

type ActionRow = {
  id: string;
  earning_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const earningsRes = await sb.rpc('list_earnings_r2036');
  const topRes = await sb.rpc('top_earners_r2036');
  const actionsRes = await sb.rpc('recent_actions_r2036');

  const earnings: EarningRow[] = (earningsRes.data as EarningRow[]) ?? [];
  const top: TopEarner[] = (topRes.data as TopEarner[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const earningCols: Column<EarningRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'base_payout_rupees', header: 'Base', render: (r: any) => `Rs ${Number(r.base_payout_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'bonus_payout_rupees', header: 'Bonus', render: (r: any) => `Rs ${Number(r.bonus_payout_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_earnings_rupees', header: 'Total', render: (r: any) => `Rs ${Number(r.total_earnings_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'ytd_total_rupees', header: 'YTD', render: (r: any) => `Rs ${Number(r.ytd_total_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '' },
  ];

  const topCols: Column<TopEarner>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_rupees', header: 'Total', render: (r: any) => `Rs ${Number(r.total_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'ytd_rupees', header: 'YTD Max', render: (r: any) => `Rs ${Number(r.ytd_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'entries', header: 'Entries', render: (r: any) => String(r.entries ?? 0) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'earning_id', header: 'Earning', render: (r: any) => String(r.earning_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Earning Trajectory</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track engineer earning patterns. Spot rising stars, flag declining trajectories, celebrate spikes.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Earning Periods</h2>
        <DataTable
          rows={earnings}
          columns={earningCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Earners (rolled up)</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Founder Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
