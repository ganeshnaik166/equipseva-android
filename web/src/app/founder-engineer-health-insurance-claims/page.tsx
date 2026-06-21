import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  } catch {
    return String(d);
  }
}

function fmtDateTime(d: string | null | undefined): string {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleString('en-IN');
  } catch {
    return String(d);
  }
}

export default async function FounderEngineerHealthInsuranceClaimsPage() {
  const sb = await getSupabaseServerClient();

  const [claimsRes, summaryRes, recentRes] = await Promise.all([
    sb.rpc('list_engineer_health_claims_r1836', { p_status: null, p_limit: 200 }),
    sb.rpc('engineer_health_claims_summary_per_engineer_r1836'),
    sb.rpc('recent_engineer_health_claims_r1836', { p_days: 30 }),
  ]);

  const claims = (claimsRes.data ?? []) as Array<Record<string, any>>;
  const summary = (summaryRes.data ?? []) as Array<Record<string, any>>;
  const recent = (recentRes.data ?? []) as Array<Record<string, any>>;

  const totalClaimed = claims.reduce((s, r) => s + Number(r.claim_amount_rupees ?? 0), 0);
  const totalPaid = claims.reduce((s, r) => s + Number(r.payout_rupees ?? 0), 0);
  const pendingCount = claims.filter((r) => r.status === 'filed' || r.status === 'processing').length;
  const paidCount = claims.filter((r) => r.status === 'paid').length;

  const claimsColumns: Column<Record<string, any>>[] = [
    { key: 'claim_date', header: 'Claim Date', render: (r: any) => fmtDate(r.claim_date) },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'claim_type', header: 'Type', render: (r: any) => r.claim_type ?? '-' },
    { key: 'insurer_name', header: 'Insurer', render: (r: any) => r.insurer_name ?? '-' },
    { key: 'claim_amount_rupees', header: 'Claimed', render: (r: any) => fmtRupees(r.claim_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'payout_rupees', header: 'Payout', render: (r: any) => fmtRupees(r.payout_rupees) },
    { key: 'decided_at', header: 'Decided', render: (r: any) => fmtDateTime(r.decided_at) },
  ];

  const summaryColumns: Column<Record<string, any>>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'total_claims', header: 'Total', render: (r: any) => String(r.total_claims ?? 0) },
    { key: 'filed_count', header: 'Filed', render: (r: any) => String(r.filed_count ?? 0) },
    { key: 'processing_count', header: 'Processing', render: (r: any) => String(r.processing_count ?? 0) },
    { key: 'approved_count', header: 'Approved', render: (r: any) => String(r.approved_count ?? 0) },
    { key: 'rejected_count', header: 'Rejected', render: (r: any) => String(r.rejected_count ?? 0) },
    { key: 'paid_count', header: 'Paid', render: (r: any) => String(r.paid_count ?? 0) },
    { key: 'total_claimed_rupees', header: 'Claimed', render: (r: any) => fmtRupees(r.total_claimed_rupees) },
    { key: 'total_payout_rupees', header: 'Payout', render: (r: any) => fmtRupees(r.total_payout_rupees) },
  ];

  const recentColumns: Column<Record<string, any>>[] = [
    { key: 'created_at', header: 'Filed', render: (r: any) => fmtDateTime(r.created_at) },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'claim_type', header: 'Type', render: (r: any) => r.claim_type ?? '-' },
    { key: 'insurer_name', header: 'Insurer', render: (r: any) => r.insurer_name ?? '-' },
    { key: 'claim_amount_rupees', header: 'Claimed', render: (r: any) => fmtRupees(r.claim_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'payout_rupees', header: 'Payout', render: (r: any) => fmtRupees(r.payout_rupees) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Health Insurance Claims
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Corporate health policy claim tracking — file, process & settle engineer medical claims.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
          <div style={{ padding: '16px', background: '#f8f9fa', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Total claims</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{claims.length}</div>
          </div>
          <div style={{ padding: '16px', background: '#f8f9fa', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Pending (filed/processing)</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{pendingCount}</div>
          </div>
          <div style={{ padding: '16px', background: '#f8f9fa', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Paid</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{paidCount}</div>
          </div>
          <div style={{ padding: '16px', background: '#f8f9fa', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Total claimed</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{fmtRupees(totalClaimed)}</div>
          </div>
          <div style={{ padding: '16px', background: '#f8f9fa', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Total paid out</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{fmtRupees(totalPaid)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>All claims</h2>
        <DataTable
          rows={claims}
          columns={claimsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Per-engineer summary</h2>
        <DataTable
          rows={summary}
          columns={summaryColumns}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent claims (last 30 days)</h2>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
