import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Founder506bComplianceTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [complianceRes, attestationsRes, expiringRes, nonCompliantRes] = await Promise.all([
    sb.rpc('list_506b_compliance_r1809'),
    sb.rpc('list_506b_attestations_r1809'),
    sb.rpc('expiring_506b_verifications_r1809', { p_days_ahead: 30 }),
    sb.rpc('non_compliant_506b_investors_r1809'),
  ]);

  const compliance: any[] = complianceRes.data ?? [];
  const attestations: any[] = attestationsRes.data ?? [];
  const expiring: any[] = expiringRes.data ?? [];
  const nonCompliant: any[] = nonCompliantRes.data ?? [];

  const totalInvestors = compliance.length;
  const currentCount = compliance.filter((c) => c.status === 'current').length;
  const underReviewCount = compliance.filter((c) => c.status === 'under_review').length;
  const expiredCount = compliance.filter((c) => c.status === 'expired').length;

  const complianceColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—' },
    { key: 'accredited_status', header: 'Accredited Status', render: (r: any) => String(r.accredited_status ?? '—').replace(/_/g, ' ') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—').replace(/_/g, ' ') },
    { key: 'last_verified_at', header: 'Last Verified', render: (r: any) => r.last_verified_at ? new Date(r.last_verified_at).toLocaleDateString() : '—' },
    { key: 'verification_doc_url', header: 'Doc', render: (r: any) => r.verification_doc_url ? 'on file' : '—' },
    { key: 'updated_at', header: 'Updated', render: (r: any) => r.updated_at ? new Date(r.updated_at).toLocaleString() : '—' },
  ];

  const attestationColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'attestation_type', header: 'Type', render: (r: any) => String(r.attestation_type ?? '—').replace(/_/g, ' ') },
    { key: 'attestation_text', header: 'Text', render: (r: any) => {
        const t = String(r.attestation_text ?? '');
        return t.length > 80 ? t.slice(0, 80) + '…' : t;
      } },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '—' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
  ];

  const expiringColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'accredited_status', header: 'Status', render: (r: any) => String(r.accredited_status ?? '—').replace(/_/g, ' ') },
    { key: 'last_verified_at', header: 'Last Verified', render: (r: any) => r.last_verified_at ? new Date(r.last_verified_at).toLocaleDateString() : '—' },
    { key: 'days_since_verified', header: 'Days Since', render: (r: any) => String(r.days_since_verified ?? '—') },
  ];

  const nonCompliantColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'accredited_status', header: 'Accred. Status', render: (r: any) => String(r.accredited_status ?? '—').replace(/_/g, ' ') },
    { key: 'status', header: 'State', render: (r: any) => String(r.status ?? '—').replace(/_/g, ' ') },
    { key: 'notes', header: 'Notes', render: (r: any) => {
        const t = String(r.notes ?? '—');
        return t.length > 60 ? t.slice(0, 60) + '…' : t;
      } },
    { key: 'updated_at', header: 'Updated', render: (r: any) => r.updated_at ? new Date(r.updated_at).toLocaleString() : '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Investor 506(b) Compliance Tracker</h1>
        <p className="text-sm text-gray-600">
          US Reg D Rule 506(b) accredited-investor verification & attestation status.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total Investors</div>
          <div className="text-2xl font-semibold">{totalInvestors}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Current</div>
          <div className="text-2xl font-semibold text-green-700">{currentCount}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Under Review</div>
          <div className="text-2xl font-semibold text-amber-700">{underReviewCount}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Expired / Non-Compliant</div>
          <div className="text-2xl font-semibold text-red-700">{expiredCount + nonCompliant.length}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All Compliance Records</h2>
        <p className="text-xs text-gray-500">Verification renewal required when last verified is &gt; 1 year ago.</p>
        <DataTable
          rows={compliance}
          columns={complianceColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Verifications Expiring (next 30 days)</h2>
        <p className="text-xs text-gray-500">Investors whose accredited verification will lapse soon — &lt; 30 days to renewal.</p>
        <DataTable
          rows={expiring}
          columns={expiringColumns}
          rowKey={(r: any, i: number) => String(r.compliance_id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Non-Compliant Investors</h2>
        <p className="text-xs text-gray-500">Investors currently flagged non-compliant or expired — block new offerings.</p>
        <DataTable
          rows={nonCompliant}
          columns={nonCompliantColumns}
          rowKey={(r: any, i: number) => String(r.compliance_id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Attestation Log</h2>
        <p className="text-xs text-gray-500">Signed attestations: income, net worth, entity status & qualified-purchaser claims.</p>
        <DataTable
          rows={attestations}
          columns={attestationColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
