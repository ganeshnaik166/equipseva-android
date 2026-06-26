import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtINR(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined) {
  return Number(n ?? 0).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined) {
  return Number(n ?? 0).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, byChainRes, byKindRes, claimsRes, verdictsRes, riskRes, insurerRes, pendingRes] = await Promise.all([
    supabase.rpc('founder_r2823_kpis'),
    supabase.rpc('founder_r2823_policies_by_chain'),
    supabase.rpc('founder_r2823_by_insurance_kind'),
    supabase.rpc('founder_r2823_claim_detail'),
    supabase.rpc('founder_r2823_renewal_verdicts'),
    supabase.rpc('founder_r2823_top_risk_assets'),
    supabase.rpc('founder_r2823_insurer_performance'),
    supabase.rpc('founder_r2823_renewal_pending'),
  ]);

  const kpis = (kpisRes.data && kpisRes.data[0]) || {};
  const byChain = byChainRes.data || [];
  const byKind = byKindRes.data || [];
  const claims = claimsRes.data || [];
  const verdicts = verdictsRes.data || [];
  const risk = riskRes.data || [];
  const insurer = insurerRes.data || [];
  const pending = pendingRes.data || [];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
        Hospital Chain Quarterly Equipment Insurance Coverage
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Chain × asset × insurance kind × premium × claim history × renewal verdict. Round r2823.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Total Policies" value={fmtNum(kpis.total_policies)} />
        <KpiCard label="Active" value={fmtNum(kpis.active_policies)} />
        <KpiCard label="Quarterly Premium" value={fmtINR(kpis.total_quarterly_premium_rupees)} />
        <KpiCard label="Asset Value Covered" value={fmtINR(kpis.total_asset_value_rupees)} />
        <KpiCard label="Claims Filed" value={fmtNum(kpis.total_claims_filed)} />
        <KpiCard label="Claim Amount" value={fmtINR(kpis.total_claim_amount_rupees)} />
        <KpiCard label="Approved Amount" value={fmtINR(kpis.total_approved_amount_rupees)} />
        <KpiCard label="Payout Ratio" value={fmtPct(kpis.claim_payout_ratio)} />
        <KpiCard label="Renewal Pending" value={fmtNum(kpis.renewal_pending_count)} />
        <KpiCard label="Lapsed" value={fmtNum(kpis.lapsed_count)} />
      </section>

      <Section title="By Chain">
        <DataTable
          rows={byChain}
          columns={[
            { key: 'chain_code', header: 'Code', render: (r: any) => r.chain_code },
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'policy_count', header: 'Policies', render: (r: any) => fmtNum(r.policy_count) },
            { key: 'active_count', header: 'Active', render: (r: any) => fmtNum(r.active_count) },
            { key: 'lapsed_count', header: 'Lapsed', render: (r: any) => fmtNum(r.lapsed_count) },
            { key: 'quarterly_premium_rupees', header: 'Qtr Premium', render: (r: any) => fmtINR(r.quarterly_premium_rupees) },
            { key: 'asset_value_rupees', header: 'Asset Value', render: (r: any) => fmtINR(r.asset_value_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.chain_code ?? i)}
        />
      </Section>

      <Section title="By Insurance Kind">
        <DataTable
          rows={byKind}
          columns={[
            { key: 'insurance_kind', header: 'Kind', render: (r: any) => r.insurance_kind },
            { key: 'policy_count', header: 'Policies', render: (r: any) => fmtNum(r.policy_count) },
            { key: 'quarterly_premium_rupees', header: 'Qtr Premium', render: (r: any) => fmtINR(r.quarterly_premium_rupees) },
            { key: 'total_claim_amount_rupees', header: 'Claim Amt', render: (r: any) => fmtINR(r.total_claim_amount_rupees) },
            { key: 'total_approved_amount_rupees', header: 'Approved Amt', render: (r: any) => fmtINR(r.total_approved_amount_rupees) },
            { key: 'payout_ratio_pct', header: 'Payout Ratio', render: (r: any) => fmtPct(r.payout_ratio_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.insurance_kind ?? i)}
        />
      </Section>

      <Section title="Claim Detail">
        <DataTable
          rows={claims}
          columns={[
            { key: 'claim_reference', header: 'Ref', render: (r: any) => r.claim_reference },
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'asset_tag', header: 'Asset', render: (r: any) => r.asset_tag },
            { key: 'asset_category', header: 'Cat', render: (r: any) => r.asset_category },
            { key: 'insurance_kind', header: 'Kind', render: (r: any) => r.insurance_kind },
            { key: 'insurer_name', header: 'Insurer', render: (r: any) => r.insurer_name },
            { key: 'incident_date', header: 'Incident', render: (r: any) => r.incident_date },
            { key: 'incident_kind', header: 'Cause', render: (r: any) => r.incident_kind },
            { key: 'claim_amount_rupees', header: 'Claim', render: (r: any) => fmtINR(r.claim_amount_rupees) },
            { key: 'approved_amount_rupees', header: 'Approved', render: (r: any) => fmtINR(r.approved_amount_rupees) },
            { key: 'claim_status', header: 'Status', render: (r: any) => r.claim_status },
            { key: 'resolution_days', header: 'Days', render: (r: any) => fmtNum(r.resolution_days) },
            { key: 'renewal_verdict', header: 'Verdict', render: (r: any) => r.renewal_verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.claim_reference ?? i)}
        />
      </Section>

      <Section title="Renewal Verdicts">
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'renewal_verdict', header: 'Verdict', render: (r: any) => r.renewal_verdict },
            { key: 'policy_count', header: 'Policies', render: (r: any) => fmtNum(r.policy_count) },
            { key: 'claim_count', header: 'Claims', render: (r: any) => fmtNum(r.claim_count) },
            { key: 'quarterly_premium_rupees', header: 'Qtr Premium', render: (r: any) => fmtINR(r.quarterly_premium_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.renewal_verdict ?? i)}
        />
      </Section>

      <Section title="Top Risk Assets">
        <DataTable
          rows={risk}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'asset_tag', header: 'Asset', render: (r: any) => r.asset_tag },
            { key: 'asset_category', header: 'Cat', render: (r: any) => r.asset_category },
            { key: 'total_claims', header: 'Claims', render: (r: any) => fmtNum(r.total_claims) },
            { key: 'total_claim_amount_rupees', header: 'Claim Amt', render: (r: any) => fmtINR(r.total_claim_amount_rupees) },
            { key: 'approved_amount_rupees', header: 'Approved', render: (r: any) => fmtINR(r.approved_amount_rupees) },
            { key: 'rejected_count', header: 'Rejected', render: (r: any) => fmtNum(r.rejected_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String((r.chain_name ?? '') + (r.asset_tag ?? '') + i)}
        />
      </Section>

      <Section title="Insurer Performance">
        <DataTable
          rows={insurer}
          columns={[
            { key: 'insurer_name', header: 'Insurer', render: (r: any) => r.insurer_name },
            { key: 'policy_count', header: 'Policies', render: (r: any) => fmtNum(r.policy_count) },
            { key: 'total_premium_rupees', header: 'Qtr Premium', render: (r: any) => fmtINR(r.total_premium_rupees) },
            { key: 'claims_filed', header: 'Filed', render: (r: any) => fmtNum(r.claims_filed) },
            { key: 'claims_approved', header: 'Approved', render: (r: any) => fmtNum(r.claims_approved) },
            { key: 'claims_rejected', header: 'Rejected', render: (r: any) => fmtNum(r.claims_rejected) },
            { key: 'approval_rate_pct', header: 'Approval Rate', render: (r: any) => fmtPct(r.approval_rate_pct) },
            { key: 'avg_resolution_days', header: 'Avg Days', render: (r: any) => fmtNum(r.avg_resolution_days) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.insurer_name ?? i)}
        />
      </Section>

      <Section title="Renewal Pending or Lapsing Soon">
        <DataTable
          rows={pending}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'asset_tag', header: 'Asset', render: (r: any) => r.asset_tag },
            { key: 'insurer_name', header: 'Insurer', render: (r: any) => r.insurer_name },
            { key: 'policy_number', header: 'Policy #', render: (r: any) => r.policy_number },
            { key: 'coverage_end_date', header: 'Coverage End', render: (r: any) => r.coverage_end_date },
            { key: 'quarterly_premium_rupees', header: 'Qtr Premium', render: (r: any) => fmtINR(r.quarterly_premium_rupees) },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.policy_number ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 10, padding: 14 }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 6 }}>{label}</div>
      <div style={{ fontSize: 19, fontWeight: 700, color: '#111827' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
