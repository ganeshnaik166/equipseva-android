import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [renewalsRes, highRes, recentRes] = await Promise.all([
    sb.rpc('list_renewals_r2115'),
    sb.rpc('high_likelihood_r2115'),
    sb.rpc('recent_actions_r2115'),
  ]);

  const renewals: any[] = Array.isArray(renewalsRes.data) ? renewalsRes.data : [];
  const high: any[] = Array.isArray(highRes.data) ? highRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const renewalCols: Column<any>[] = [
    { key: 'contract_label', header: 'Contract', render: (r: any) => String(r.contract_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'current_value_rupees', header: 'Current', render: (r: any) => `Rs ${Number(r.current_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'renewal_value_rupees', header: 'Renewal', render: (r: any) => `Rs ${Number(r.renewal_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'renewal_likelihood_pct', header: 'Likelihood', render: (r: any) => `${Number(r.renewal_likelihood_pct ?? 0)} pct` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const highCols: Column<any>[] = [
    { key: 'contract_label', header: 'Contract', render: (r: any) => String(r.contract_label ?? '') },
    { key: 'renewal_value_rupees', header: 'Renewal value', render: (r: any) => `Rs ${Number(r.renewal_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'renewal_likelihood_pct', header: 'Likelihood', render: (r: any) => `${Number(r.renewal_likelihood_pct ?? 0)} pct` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'value_change_rupees', header: 'Value change', render: (r: any) => `Rs ${Number(r.value_change_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'renewal_id', header: 'Renewal', render: (r: any) => String(r.renewal_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Service Contract Renewals v2
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Deeper renewal tracking with quote, negotiation, and outcome logging.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All renewals (latest 200)
        </h2>
        <DataTable
          rows={renewals}
          columns={renewalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          High likelihood (70 pct and above, still open)
        </h2>
        <DataTable
          rows={high}
          columns={highCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent actions (last 100)
        </h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
