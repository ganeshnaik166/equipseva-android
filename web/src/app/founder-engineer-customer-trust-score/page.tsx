import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [trustsRes, atRiskRes, recentRes] = await Promise.all([
    sb.rpc('list_trusts_r2072'),
    sb.rpc('at_risk_r2072'),
    sb.rpc('recent_actions_r2072'),
  ]);

  const trusts: any[] = Array.isArray(trustsRes.data) ? (trustsRes.data as any[]) : [];
  const atRisk: any[] = Array.isArray(atRiskRes.data) ? (atRiskRes.data as any[]) : [];
  const recent: any[] = Array.isArray(recentRes.data) ? (recentRes.data as any[]) : [];

  const trustCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'trust_score', header: 'Score', render: (r: any) => String(r.trust_score ?? '') },
    { key: 'total_interactions', header: 'Total', render: (r: any) => String(r.total_interactions ?? '') },
    { key: 'positive_interactions', header: 'Positive', render: (r: any) => String(r.positive_interactions ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'trust_score', header: 'Score', render: (r: any) => String(r.trust_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'trust_id', header: 'Trust', render: (r: any) => String(r.trust_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Customer Trust Score</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Trust score per engineer and customer pair. Track interactions, status, and recovery actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Trust Records</h2>
        <DataTable rows={trusts} columns={trustCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>At Risk Pairs</h2>
        <p style={{ color: '#777', fontSize: 13, marginBottom: 8 }}>
          Pairs with status concerning or at risk. Lowest score first.
        </p>
        <DataTable rows={atRisk} columns={atRiskCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
