import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PipelineRow = {
  id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  amc_contract_id: string | null;
  expires_on: string;
  days_until_expiry: number;
  renewal_probability_pct: number;
  owner_email: string | null;
  last_outreach_at: string | null;
  status: string;
  renewal_value_rupees: number;
};

type RiskRow = {
  id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  expires_on: string;
  days_until_expiry: number;
  renewal_probability_pct: number;
  renewal_value_rupees: number;
  status: string;
  last_outreach_at: string | null;
};

type RenewedRow = {
  id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  expires_on: string;
  status: string;
  renewal_value_rupees: number;
  updated_at: string;
};

type OutreachRow = {
  id: string;
  pipeline_id: string;
  outreach_type: string;
  outreach_at: string;
  by_email: string | null;
  response: string | null;
  notes: string | null;
};

function fmtRupees(n: number | null | undefined) {
  if (!n) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  return new Date(s).toLocaleDateString('en-IN');
}

function fmtTs(s: string | null | undefined) {
  if (!s) return '-';
  return new Date(s).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pipe, risk, renewed, out] = await Promise.all([
    sb.rpc('list_pipeline_r1731', { p_days: 90 }),
    sb.rpc('top_at_risk_renewals_r1731', { p_limit: 20 }),
    sb.rpc('recently_renewed_r1731', { p_days: 30 }),
    sb.rpc('list_outreach_r1731', { p_pipeline_id: null, p_limit: 50 }),
  ]);

  const pipeRows = (pipe.data ?? []) as PipelineRow[];
  const riskRows = (risk.data ?? []) as RiskRow[];
  const renewedRows = (renewed.data ?? []) as RenewedRow[];
  const outRows = (out.data ?? []) as OutreachRow[];

  const totalValue = pipeRows.reduce((s, r) => s + Number(r.renewal_value_rupees ?? 0), 0);
  const atRiskValue = riskRows.reduce((s, r) => s + Number(r.renewal_value_rupees ?? 0), 0);
  const renewedValue = renewedRows.reduce((s, r) => s + Number(r.renewal_value_rupees ?? 0), 0);

  const pipeCols: Column<PipelineRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'expires_on', header: 'Expires', render: (r: any) => fmtDate(r.expires_on) },
    { key: 'days_until_expiry', header: 'Days Left', render: (r: any) => String(r.days_until_expiry) },
    { key: 'renewal_probability_pct', header: 'Probability %', render: (r: any) => String(r.renewal_probability_pct) + '%' },
    { key: 'renewal_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.renewal_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'last_outreach_at', header: 'Last Outreach', render: (r: any) => fmtTs(r.last_outreach_at) },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'expires_on', header: 'Expires', render: (r: any) => fmtDate(r.expires_on) },
    { key: 'days_until_expiry', header: 'Days Left', render: (r: any) => String(r.days_until_expiry) },
    { key: 'renewal_probability_pct', header: 'Probability %', render: (r: any) => String(r.renewal_probability_pct) + '%' },
    { key: 'renewal_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.renewal_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_outreach_at', header: 'Last Outreach', render: (r: any) => fmtTs(r.last_outreach_at) },
  ];

  const renewedCols: Column<RenewedRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'expires_on', header: 'Expires', render: (r: any) => fmtDate(r.expires_on) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'renewal_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.renewal_value_rupees) },
    { key: 'updated_at', header: 'Closed At', render: (r: any) => fmtTs(r.updated_at) },
  ];

  const outCols: Column<OutreachRow>[] = [
    { key: 'outreach_at', header: 'When', render: (r: any) => fmtTs(r.outreach_at) },
    { key: 'outreach_type', header: 'Type', render: (r: any) => r.outreach_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'response', header: 'Response', render: (r: any) => r.response ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Contract Renewal Pipeline</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        AMC renewals due in next 90 days. Probability &gt;= 60% counts as on-track; below that surfaces as at-risk.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Pipeline (90d)</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{pipeRows.length}</div>
          <div style={{ fontSize: 14, color: '#666', marginTop: 4 }}>{fmtRupees(totalValue)} total value</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>At Risk</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: '#dc2626' }}>{riskRows.length}</div>
          <div style={{ fontSize: 14, color: '#666', marginTop: 4 }}>{fmtRupees(atRiskValue)} at risk (probability &lt; 60%)</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Renewed (30d)</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: '#059669' }}>{renewedRows.length}</div>
          <div style={{ fontSize: 14, color: '#666', marginTop: 4 }}>{fmtRupees(renewedValue)} closed</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top At-Risk Renewals</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>
          Probability &lt; 60% and expires within 90 days. Sorted by value descending.
        </p>
        <DataTable<RiskRow>
          rows={riskRows}
          columns={riskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Full Pipeline (Next 90 Days)</h2>
        <DataTable<PipelineRow>
          rows={pipeRows}
          columns={pipeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recently Renewed (30d)</h2>
        <DataTable<RenewedRow>
          rows={renewedRows}
          columns={renewedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Outreach Log</h2>
        <DataTable<OutreachRow>
          rows={outRows}
          columns={outCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
