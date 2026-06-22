import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [prefs, active, recent] = await Promise.all([
    sb.rpc('list_preferences_r2189'),
    sb.rpc('active_preferences_r2189'),
    sb.rpc('recent_actions_r2189', { p_limit: 50 }),
  ]);

  const prefRows: any[] = (prefs.data as any[]) ?? [];
  const activeRows: any[] = (active.data as any[]) ?? [];
  const recentRows: any[] = (recent.data as any[]) ?? [];

  const prefCols: Column<any>[] = [
    { key: 'share_class_label', header: 'Share Class', render: (r: any) => String(r.share_class_label ?? '') },
    { key: 'preference_rate_pct', header: 'Rate %', render: (r: any) => String(r.preference_rate_pct ?? '') },
    { key: 'accrual_method', header: 'Accrual', render: (r: any) => String(r.accrual_method ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'share_class_label', header: 'Share Class', render: (r: any) => String(r.share_class_label ?? '') },
    { key: 'preference_rate_pct', header: 'Rate %', render: (r: any) => String(r.preference_rate_pct ?? '') },
    { key: 'accrual_method', header: 'Accrual', render: (r: any) => String(r.accrual_method ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'share_class_label', header: 'Share Class', render: (r: any) => String(r.share_class_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => r.amount_rupees != null ? String(r.amount_rupees) : '' },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1>Investor Cap Table Dividend Preference</h1>
      <p>Track dividend preferences across share classes. Founder-only console (r2189).</p>

      <section style={{ marginTop: 24 }}>
        <h2>All Preferences</h2>
        <DataTable rows={prefRows} columns={prefCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Active Preferences</h2>
        <DataTable rows={activeRows} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Recent Actions</h2>
        <DataTable rows={recentRows} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
