import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalServiceTierPricingPage() {
  const sb = await getSupabaseServerClient();

  const [tiersRes, actionsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_tiers_r2079'),
    sb.rpc('list_actions_r2079'),
    sb.rpc('active_tiers_r2079'),
    sb.rpc('recent_actions_r2079'),
  ]);

  const tiers: any[] = Array.isArray(tiersRes.data) ? tiersRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const activeTiers: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recentActions: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const tierColumns: Column<any>[] = [
    { key: 'tier_label', header: 'Tier', render: (r: any) => String(r.tier_label ?? '') },
    { key: 'base_monthly_price_rupees', header: 'Monthly Price', render: (r: any) => `Rs ${Number(r.base_monthly_price_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'included_jobs_per_month', header: 'Jobs Included', render: (r: any) => String(r.included_jobs_per_month ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'tier_id', header: 'Tier', render: (r: any) => String(r.tier_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'price_change_rupees', header: 'Price Change', render: (r: any) => r.price_change_rupees != null ? `Rs ${Number(r.price_change_rupees).toLocaleString('en-IN')}` : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Service Tier Pricing</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Manage hospital service tier pricing. Tiers include basic, standard, premium, enterprise, and custom.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Tiers ({activeTiers.length})</h2>
        <DataTable rows={activeTiers} columns={tierColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Tiers ({tiers.length})</h2>
        <DataTable rows={tiers} columns={tierColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions ({recentActions.length})</h2>
        <DataTable rows={recentActions} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Actions ({actions.length})</h2>
        <DataTable rows={actions} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
