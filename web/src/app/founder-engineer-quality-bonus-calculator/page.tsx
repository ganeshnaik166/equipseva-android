import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [bonusesRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_bonuses_r2192'),
    sb.rpc('top_bonuses_r2192'),
    sb.rpc('recent_actions_r2192'),
  ]);

  const bonuses: any[] = Array.isArray(bonusesRes.data) ? bonusesRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalAmount = bonuses.reduce((s, r) => s + Number(r?.bonus_amount_rupees ?? 0), 0);
  const paidCount = bonuses.filter((r) => r?.status === 'paid').length;
  const disputedCount = bonuses.filter((r) => r?.status === 'disputed').length;

  const bonusCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r?.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r?.engineer_user_id ?? '').slice(0, 8) },
    { key: 'quality_score', header: 'Score', render: (r: any) => String(r?.quality_score ?? 0) },
    { key: 'bonus_multiplier', header: 'Mult', render: (r: any) => String(r?.bonus_multiplier ?? '1.000') },
    { key: 'bonus_amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r?.bonus_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r?.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r?.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '') },
  ];

  const topCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r?.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r?.engineer_user_id ?? '').slice(0, 8) },
    { key: 'quality_score', header: 'Score', render: (r: any) => String(r?.quality_score ?? 0) },
    { key: 'bonus_amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r?.bonus_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r?.status ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => (r?.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r?.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r?.by_email ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => (r?.amount_rupees == null ? '' : `Rs ${Number(r.amount_rupees).toLocaleString('en-IN')}`) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r?.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Quality Bonus Calculator</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>Calculate quality-based bonuses for engineers. Founder-only console (r2192).</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total bonuses</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{bonuses.length}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total amount</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>Rs {totalAmount.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Paid</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{paidCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Disputed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{disputedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All bonuses</h2>
        <DataTable rows={bonuses} columns={bonusCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top 25 by amount</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>
    </main>
  );
}
