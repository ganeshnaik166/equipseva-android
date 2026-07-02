import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [allRes, upcomingRes, riskRes, calRes] = await Promise.all([
    sb.rpc('list_chain_msa_r2267'),
    sb.rpc('upcoming_chain_msa_renewals_r2267', { p_window_days: 120 }),
    sb.rpc('high_risk_chain_msa_r2267'),
    sb.rpc('chain_msa_renewal_calendar_r2267'),
  ]);

  const msas: any[] = Array.isArray(allRes.data) ? allRes.data : [];
  const upcoming: any[] = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];
  const risk: any[] = Array.isArray(riskRes.data) ? riskRes.data : [];
  const calendar: any[] = Array.isArray(calRes.data) ? calRes.data : [];

  const totalAnnualValue = msas.reduce((s, m) => s + Number(m.annual_value_rupees ?? 0), 0);
  const upcomingCount = upcoming.length;
  const upcomingValue = upcoming.reduce((s, m) => s + Number(m.annual_value_rupees ?? 0), 0);
  const atRiskCount = risk.length;
  const atRiskValue = risk.reduce((s, m) => s + Number(m.annual_value_rupees ?? 0), 0);
  const renewedCount = msas.filter((m) => m.renewal_status === 'renewed').length;
  const lostCount = msas.filter((m) => m.renewal_status === 'lost').length;

  const fmtRupees = (n: number | bigint | null | undefined) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };

  const fmtDate = (d: string | null | undefined) => (d ? new Date(d).toLocaleDateString() : '—');
  const fmtMonth = (d: string | null | undefined) => {
    if (!d) return '—';
    const dt = new Date(d);
    return dt.toLocaleDateString(undefined, { year: 'numeric', month: 'short' });
  };

  const riskBadge = (r: string) => {
    const colors: Record<string, string> = {
      low: '#16a34a',
      medium: '#ca8a04',
      high: '#ea580c',
      critical: '#dc2626',
    };
    const c = colors[r] ?? '#666';
    return (
      <span style={{ color: c, fontWeight: 600 }}>{r}</span>
    );
  };

  const statusBadge = (s: string) => {
    const colors: Record<string, string> = {
      upcoming: '#0ea5e9',
      negotiating: '#a855f7',
      renewed: '#16a34a',
      at_risk: '#ea580c',
      lost: '#dc2626',
    };
    const c = colors[s] ?? '#666';
    return (
      <span style={{ color: c, fontWeight: 600 }}>{s}</span>
    );
  };

  const msaColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (m: any) => m.chain_name },
    { key: 'msa_end_date', header: 'Renewal Date', render: (m: any) => fmtDate(m.msa_end_date) },
    { key: 'days_to_renewal', header: 'Days', render: (m: any) => String(m.days_to_renewal ?? 0) },
    { key: 'hospital_count', header: 'Hospitals', render: (m: any) => String(m.hospital_count ?? 0) },
    { key: 'annual_value_rupees', header: 'Annual Value', render: (m: any) => fmtRupees(m.annual_value_rupees) },
    { key: 'renewal_status', header: 'Status', render: (m: any) => statusBadge(m.renewal_status) },
    { key: 'non_renewal_risk', header: 'Risk', render: (m: any) => riskBadge(m.non_renewal_risk) },
    { key: 'owner_email', header: 'Owner', render: (m: any) => m.owner_email ?? '—' },
    { key: 'primary_contact_email', header: 'Contact', render: (m: any) => m.primary_contact_email ?? '—' },
    { key: 'last_review_date', header: 'Last Review', render: (m: any) => fmtDate(m.last_review_date) },
    { key: 'term_change_count', header: 'Term Changes', render: (m: any) => String(m.term_change_count ?? 0) },
    { key: 'notes', header: 'Notes', render: (m: any) => (m.notes ?? '').slice(0, 120) },
  ];

  const upcomingColumns: Column<any>[] = [
    { key: 'msa_end_date', header: 'Renewal Date', render: (m: any) => fmtDate(m.msa_end_date) },
    { key: 'days_to_renewal', header: 'Days', render: (m: any) => String(m.days_to_renewal ?? 0) },
    { key: 'chain_name', header: 'Chain', render: (m: any) => m.chain_name },
    { key: 'hospital_count', header: 'Hospitals', render: (m: any) => String(m.hospital_count ?? 0) },
    { key: 'annual_value_rupees', header: 'Annual Value', render: (m: any) => fmtRupees(m.annual_value_rupees) },
    { key: 'renewal_status', header: 'Status', render: (m: any) => statusBadge(m.renewal_status) },
    { key: 'non_renewal_risk', header: 'Risk', render: (m: any) => riskBadge(m.non_renewal_risk) },
    { key: 'owner_email', header: 'Owner', render: (m: any) => m.owner_email ?? '—' },
  ];

  const riskColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (m: any) => m.chain_name },
    { key: 'non_renewal_risk', header: 'Risk', render: (m: any) => riskBadge(m.non_renewal_risk) },
    { key: 'renewal_status', header: 'Status', render: (m: any) => statusBadge(m.renewal_status) },
    { key: 'msa_end_date', header: 'Renewal Date', render: (m: any) => fmtDate(m.msa_end_date) },
    { key: 'days_to_renewal', header: 'Days', render: (m: any) => String(m.days_to_renewal ?? 0) },
    { key: 'hospital_count', header: 'Hospitals', render: (m: any) => String(m.hospital_count ?? 0) },
    { key: 'annual_value_rupees', header: 'Annual Value', render: (m: any) => fmtRupees(m.annual_value_rupees) },
    { key: 'owner_email', header: 'Owner', render: (m: any) => m.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (m: any) => (m.notes ?? '').slice(0, 160) },
  ];

  const calColumns: Column<any>[] = [
    { key: 'bucket_month', header: 'Month', render: (r: any) => fmtMonth(r.bucket_month) },
    { key: 'renewal_count', header: 'Renewals', render: (r: any) => String(r.renewal_count ?? 0) },
    { key: 'total_annual_value_rupees', header: 'Total Annual Value', render: (r: any) => fmtRupees(r.total_annual_value_rupees) },
    { key: 'at_risk_count', header: 'At Risk', render: (r: any) => String(r.at_risk_count ?? 0) },
    { key: 'high_risk_value_rupees', header: 'High-Risk Value', render: (r: any) => fmtRupees(r.high_risk_value_rupees) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain MSA Renewal Calendar</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Master service agreement renewals coming up across hospital chains. Track terms to renegotiate and risk of non-renewal so revenue stays locked in.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total chains tracked</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{msas.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total annual value</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalAnnualValue)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Renewing next 120d</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{upcomingCount}</div>
          <div style={{ fontSize: 12, color: '#666' }}>{fmtRupees(upcomingValue)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>High & critical risk</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#dc2626' }}>{atRiskCount}</div>
          <div style={{ fontSize: 12, color: '#666' }}>{fmtRupees(atRiskValue)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Renewed</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#16a34a' }}>{renewedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Lost</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#dc2626' }}>{lostCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Renewals next 120 days</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          MSAs with end_date in the next 120 days that are not yet renewed. Smallest days-to-renewal first.
        </p>
        <DataTable rows={upcoming} columns={upcomingColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>High & critical non-renewal risk</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Chains flagged high or critical and not yet renewed. Founder owns escalation on these.
        </p>
        <DataTable rows={risk} columns={riskColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Monthly renewal calendar</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Bucketed by msa_end_date month. Spot months where multiple chains renew at once.
        </p>
        <DataTable rows={calendar} columns={calColumns} rowKey={(r, i) => String(r.bucket_month ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All MSAs</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Full hospital-chain MSA roster ordered by next renewal date.
        </p>
        <DataTable rows={msas} columns={msaColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
