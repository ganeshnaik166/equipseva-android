import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainAccountTeamMappingPage() {
  const sb = await getSupabaseServerClient();
  const { data: { user } } = await sb.auth.getUser();
  const email = user?.email ?? '';

  const [overview, tiers, atRisk, leadLoad, csmLoad, escalations, qbrs] = await Promise.all([
    sb.rpc('r2255_chain_team_overview'),
    sb.rpc('r2255_tier_summary'),
    sb.rpc('r2255_at_risk_chains'),
    sb.rpc('r2255_account_lead_load'),
    sb.rpc('r2255_csm_load'),
    sb.rpc('r2255_escalation_paths'),
    sb.rpc('r2255_upcoming_qbrs'),
  ]);

  const overviewRows = (overview.data ?? []) as any[];
  const tierRows = (tiers.data ?? []) as any[];
  const atRiskRows = (atRisk.data ?? []) as any[];
  const leadRows = (leadLoad.data ?? []) as any[];
  const csmRows = (csmLoad.data ?? []) as any[];
  const escRows = (escalations.data ?? []) as any[];
  const qbrRows = (qbrs.data ?? []) as any[];

  const totalChains = overviewRows.length;
  const totalContract = overviewRows.reduce((s, r) => s + Number(r.contract_value_rupees ?? 0), 0);
  const totalHospitals = overviewRows.reduce((s, r) => s + Number(r.hospital_count ?? 0), 0);
  const atRiskCount = atRiskRows.length;

  const fmtRupees = (n: number) => `Rs ${Math.round(n).toLocaleString('en-IN')}`;

  const overviewCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'account_lead_name', header: 'Account Lead', render: (r) => r.account_lead_name },
    { key: 'csm_name', header: 'CSM', render: (r) => r.csm_name },
    { key: 'primary_engineer_name', header: 'Lead Engineer', render: (r) => r.primary_engineer_name },
    { key: 'health_score', header: 'Health', render: (r) => `${r.health_score}/100` },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'contract_value_rupees', header: 'Contract Value', render: (r) => fmtRupees(Number(r.contract_value_rupees ?? 0)) },
    { key: 'active_amc_count', header: 'Active AMCs', render: (r) => r.active_amc_count },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'chain_count', header: 'Chains', render: (r) => r.chain_count },
    { key: 'total_contract_rupees', header: 'Total Contract', render: (r) => fmtRupees(Number(r.total_contract_rupees ?? 0)) },
    { key: 'avg_health', header: 'Avg Health', render: (r) => Math.round(Number(r.avg_health ?? 0)) },
    { key: 'at_risk_count', header: 'At-Risk', render: (r) => r.at_risk_count },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'account_lead_name', header: 'Account Lead', render: (r) => r.account_lead_name },
    { key: 'csm_name', header: 'CSM', render: (r) => r.csm_name },
    { key: 'health_score', header: 'Health', render: (r) => r.health_score },
    { key: 'contract_value_rupees', header: 'Contract', render: (r) => fmtRupees(Number(r.contract_value_rupees ?? 0)) },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '-' },
  ];

  const leadCols: Column<any>[] = [
    { key: 'account_lead_name', header: 'Account Lead', render: (r) => r.account_lead_name },
    { key: 'chains_assigned', header: 'Chains', render: (r) => r.chains_assigned },
    { key: 'total_hospitals', header: 'Hospitals', render: (r) => r.total_hospitals },
    { key: 'total_contract_rupees', header: 'Total Contract', render: (r) => fmtRupees(Number(r.total_contract_rupees ?? 0)) },
    { key: 'avg_health', header: 'Avg Health', render: (r) => Math.round(Number(r.avg_health ?? 0)) },
  ];

  const csmCols: Column<any>[] = [
    { key: 'csm_name', header: 'CSM', render: (r) => r.csm_name },
    { key: 'chains_assigned', header: 'Chains', render: (r) => r.chains_assigned },
    { key: 'total_amcs', header: 'AMCs', render: (r) => r.total_amcs },
    { key: 'avg_health', header: 'Avg Health', render: (r) => Math.round(Number(r.avg_health ?? 0)) },
    { key: 'at_risk_count', header: 'At-Risk', render: (r) => r.at_risk_count },
  ];

  const escCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'escalation_level', header: 'Level', render: (r) => `L${r.escalation_level}` },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'contact_role', header: 'Role', render: (r) => r.contact_role },
    { key: 'contact_email', header: 'Email', render: (r) => r.contact_email },
    { key: 'response_sla_minutes', header: 'SLA (min)', render: (r) => r.response_sla_minutes },
  ];

  const qbrCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'account_lead_name', header: 'Account Lead', render: (r) => r.account_lead_name },
    { key: 'csm_name', header: 'CSM', render: (r) => r.csm_name },
    { key: 'next_qbr_date', header: 'Next QBR', render: (r) => r.next_qbr_date },
    { key: 'days_until', header: 'Days Until', render: (r) => r.days_until },
    { key: 'health_score', header: 'Health', render: (r) => r.health_score },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Hospital Chain Account-Team Mapping</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>r2255 · Account lead, CSM, engineer team & escalation paths per hospital chain · {email}</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8, background: '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Chains</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalChains}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8, background: '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Hospitals</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalHospitals}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8, background: '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Contract Value</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalContract)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8, background: atRiskCount > 0 ? '#fff5f5' : '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#666' }}>At-Risk / Churned</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: atRiskCount > 0 ? '#c0392b' : undefined }}>{atRiskCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain Overview</h2>
        <DataTable columns={overviewCols} rows={overviewRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tier Summary</h2>
        <DataTable columns={tierCols} rows={tierRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>At-Risk &amp; Churned Chains (health &lt; 75)</h2>
        <DataTable columns={atRiskCols} rows={atRiskRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Account Lead Load</h2>
        <DataTable columns={leadCols} rows={leadRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>CSM Load</h2>
        <DataTable columns={csmCols} rows={csmRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Escalation Paths (L1 → L4)</h2>
        <DataTable columns={escCols} rows={escRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Upcoming QBRs</h2>
        <DataTable columns={qbrCols} rows={qbrRows} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
