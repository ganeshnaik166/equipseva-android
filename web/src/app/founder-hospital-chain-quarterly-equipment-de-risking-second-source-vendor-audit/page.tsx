import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainOverview = {
  chain_name: string;
  units: number;
  spend_rupees: number;
  critical_lines: number;
  high_lines: number;
  single_source_lines: number;
  last_audit_age_days: number;
};

type CriticalLine = {
  chain_name: string;
  equipment_category: string;
  primary_vendor: string;
  units: number;
  spend_rupees: number;
  concentration_pct: number;
  risk_tier: string;
  last_audited_at: string;
};

type QuarterlyPipeline = {
  audit_quarter: string;
  total_audits: number;
  qualified: number;
  in_trial: number;
  pending: number;
  avg_score: number;
  total_audit_cost_rupees: number;
};

type AlternateSaving = {
  chain_name: string;
  equipment_category: string;
  alternate_vendor: string;
  projected_savings_rupees: number;
  recommended_share_pct: number;
  qualification_score: number;
  audit_status: string;
};

type LeadTimeRow = {
  chain_name: string;
  equipment_category: string;
  alternate_vendor: string;
  lead_time_days: number;
  audit_status: string;
  qualification_score: number;
};

type KycRow = {
  chain_name: string;
  equipment_category: string;
  primary_vendor: string;
  oem_kyc_status: string;
  annual_spend_rupees: number;
  last_audited_at: string;
};

type OwnerWorkload = {
  audit_owner_email: string;
  active_audits: number;
  qualified: number;
  in_trial: number;
  pending: number;
  avg_score: number;
};

type TopRec = {
  chain_name: string;
  equipment_category: string;
  alternate_vendor: string;
  qualification_score: number;
  price_delta_pct: number;
  recommended_share_pct: number;
  projected_savings_rupees: number;
};

type Concentration = {
  chain_name: string;
  equipment_lines: number;
  avg_concentration_pct: number;
  max_concentration_pct: number;
  single_source_count: number;
};

function fmtInr(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, critical, pipeline, savings, leadtime, kyc, workload, topRec, conc] = await Promise.all([
    supabase.rpc('r2923_chain_risk_overview'),
    supabase.rpc('r2923_critical_single_source_lines'),
    supabase.rpc('r2923_quarterly_audit_pipeline'),
    supabase.rpc('r2923_alternate_vendor_savings'),
    supabase.rpc('r2923_lead_time_risk_lines'),
    supabase.rpc('r2923_oem_kyc_attention'),
    supabase.rpc('r2923_audit_owner_workload'),
    supabase.rpc('r2923_top_savings_recommendations'),
    supabase.rpc('r2923_chain_concentration_summary'),
  ]);

  const overviewRows: ChainOverview[] = overview.data ?? [];
  const criticalRows: CriticalLine[] = critical.data ?? [];
  const pipelineRows: QuarterlyPipeline[] = pipeline.data ?? [];
  const savingsRows: AlternateSaving[] = savings.data ?? [];
  const leadtimeRows: LeadTimeRow[] = leadtime.data ?? [];
  const kycRows: KycRow[] = kyc.data ?? [];
  const workloadRows: OwnerWorkload[] = workload.data ?? [];
  const topRows: TopRec[] = topRec.data ?? [];
  const concRows: Concentration[] = conc.data ?? [];

  const totalSpend = overviewRows.reduce((a, r) => a + Number(r.spend_rupees ?? 0), 0);
  const totalCritical = overviewRows.reduce((a, r) => a + Number(r.critical_lines ?? 0), 0);
  const totalSingleSource = overviewRows.reduce((a, r) => a + Number(r.single_source_lines ?? 0), 0);
  const totalProjectedSavings = topRows.reduce((a, r) => a + Number(r.projected_savings_rupees ?? 0), 0);

  const overviewCols: Column<ChainOverview>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'units', header: 'Units', render: (r) => r.units.toLocaleString('en-IN') },
    { key: 'spend', header: 'Annual Spend', render: (r) => fmtInr(r.spend_rupees) },
    { key: 'crit', header: 'Critical', render: (r) => r.critical_lines },
    { key: 'high', header: 'High', render: (r) => r.high_lines },
    { key: 'ss', header: 'Single-Source', render: (r) => r.single_source_lines },
    { key: 'age', header: 'Oldest Audit (d)', render: (r) => r.last_audit_age_days },
  ];

  const criticalCols: Column<CriticalLine>[] = [
    { key: 'chain', header: 'Chain', render: (r) => r.chain_name },
    { key: 'cat', header: 'Equipment', render: (r) => r.equipment_category },
    { key: 'vendor', header: 'Vendor', render: (r) => r.primary_vendor },
    { key: 'units', header: 'Units', render: (r) => r.units },
    { key: 'spend', header: 'Spend', render: (r) => fmtInr(r.spend_rupees) },
    { key: 'conc', header: 'Conc %', render: (r) => Number(r.concentration_pct).toFixed(1) },
    { key: 'risk', header: 'Risk', render: (r) => r.risk_tier },
  ];

  const pipelineCols: Column<QuarterlyPipeline>[] = [
    { key: 'q', header: 'Quarter', render: (r) => r.audit_quarter },
    { key: 'tot', header: 'Total', render: (r) => r.total_audits },
    { key: 'qual', header: 'Qualified', render: (r) => r.qualified },
    { key: 'trial', header: 'In Trial', render: (r) => r.in_trial },
    { key: 'pend', header: 'Pending', render: (r) => r.pending },
    { key: 'score', header: 'Avg Score', render: (r) => Number(r.avg_score).toFixed(1) },
    { key: 'cost', header: 'Audit Cost', render: (r) => fmtInr(r.total_audit_cost_rupees) },
  ];

  const savingsCols: Column<AlternateSaving>[] = [
    { key: 'chain', header: 'Chain', render: (r) => r.chain_name },
    { key: 'cat', header: 'Equipment', render: (r) => r.equipment_category },
    { key: 'alt', header: 'Alt Vendor', render: (r) => r.alternate_vendor },
    { key: 'save', header: 'Projected Savings', render: (r) => fmtInr(r.projected_savings_rupees) },
    { key: 'share', header: 'Share %', render: (r) => Number(r.recommended_share_pct).toFixed(1) },
    { key: 'score', header: 'Score', render: (r) => r.qualification_score },
    { key: 'st', header: 'Status', render: (r) => r.audit_status },
  ];

  const leadtimeCols: Column<LeadTimeRow>[] = [
    { key: 'chain', header: 'Chain', render: (r) => r.chain_name },
    { key: 'cat', header: 'Equipment', render: (r) => r.equipment_category },
    { key: 'alt', header: 'Alt Vendor', render: (r) => r.alternate_vendor },
    { key: 'lt', header: 'Lead Time (d)', render: (r) => r.lead_time_days },
    { key: 'st', header: 'Status', render: (r) => r.audit_status },
    { key: 'score', header: 'Score', render: (r) => r.qualification_score },
  ];

  const kycCols: Column<KycRow>[] = [
    { key: 'chain', header: 'Chain', render: (r) => r.chain_name },
    { key: 'cat', header: 'Equipment', render: (r) => r.equipment_category },
    { key: 'v', header: 'Vendor', render: (r) => r.primary_vendor },
    { key: 'kyc', header: 'KYC', render: (r) => r.oem_kyc_status },
    { key: 'spend', header: 'Spend', render: (r) => fmtInr(r.annual_spend_rupees) },
  ];

  const workloadCols: Column<OwnerWorkload>[] = [
    { key: 'own', header: 'Audit Owner', render: (r) => r.audit_owner_email },
    { key: 'act', header: 'Active', render: (r) => r.active_audits },
    { key: 'q', header: 'Qualified', render: (r) => r.qualified },
    { key: 't', header: 'In Trial', render: (r) => r.in_trial },
    { key: 'p', header: 'Pending', render: (r) => r.pending },
    { key: 's', header: 'Avg Score', render: (r) => Number(r.avg_score).toFixed(1) },
  ];

  const topCols: Column<TopRec>[] = [
    { key: 'chain', header: 'Chain', render: (r) => r.chain_name },
    { key: 'cat', header: 'Equipment', render: (r) => r.equipment_category },
    { key: 'alt', header: 'Alt Vendor', render: (r) => r.alternate_vendor },
    { key: 'score', header: 'Score', render: (r) => r.qualification_score },
    { key: 'delta', header: 'Price Delta %', render: (r) => Number(r.price_delta_pct).toFixed(1) },
    { key: 'share', header: 'Share %', render: (r) => Number(r.recommended_share_pct).toFixed(1) },
    { key: 'save', header: 'Projected Savings', render: (r) => fmtInr(r.projected_savings_rupees) },
  ];

  const concCols: Column<Concentration>[] = [
    { key: 'chain', header: 'Chain', render: (r) => r.chain_name },
    { key: 'lines', header: 'Equipment Lines', render: (r) => r.equipment_lines },
    { key: 'avg', header: 'Avg Conc %', render: (r) => Number(r.avg_concentration_pct).toFixed(1) },
    { key: 'max', header: 'Max Conc %', render: (r) => Number(r.max_concentration_pct).toFixed(1) },
    { key: 'ss', header: 'Single-Source Lines', render: (r) => r.single_source_count },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '6px' }}>
        Hospital Chain Quarterly Equipment De-Risking
      </h1>
      <p style={{ color: '#555', marginBottom: '20px' }}>
        Round r2923 — 2nd-source vendor audit pipeline across hospital chains. Targets single-source &amp; concentration &gt;= 80%.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '12px', marginBottom: '28px' }}>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Total Annual Spend</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{fmtInr(totalSpend)}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Critical Lines</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{totalCritical}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Single-Source Lines</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{totalSingleSource}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280' }}>Top-10 Projected Savings</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{fmtInr(totalProjectedSavings)}</div>
        </div>
      </div>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Chain Risk Overview</h2>
        <DataTable rows={overviewRows} columns={overviewCols} emptyMessage="No chain risk data." rowKey={(r, i) => String((r as ChainOverview).chain_name ?? i)} />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Critical & Single-Source Equipment Lines</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="No critical lines." rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Quarterly Audit Pipeline</h2>
        <DataTable rows={pipelineRows} columns={pipelineCols} emptyMessage="No pipeline data." rowKey={(r, i) => String((r as QuarterlyPipeline).audit_quarter ?? i)} />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Top Savings Recommendations (Score &gt;= 80, Qualified)</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No qualified recommendations yet." rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Alternate Vendor Savings (All)</h2>
        <DataTable rows={savingsRows} columns={savingsCols} emptyMessage="No savings rows." rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Lead-Time Risk (&gt;= 30 days)</h2>
        <DataTable rows={leadtimeRows} columns={leadtimeCols} emptyMessage="No high lead-time audits." rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>OEM KYC Attention</h2>
        <DataTable rows={kycRows} columns={kycCols} emptyMessage="All OEM KYC verified." rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Audit Owner Workload</h2>
        <DataTable rows={workloadRows} columns={workloadCols} emptyMessage="No owner workload." rowKey={(r, i) => String((r as OwnerWorkload).audit_owner_email ?? i)} />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Chain Concentration Summary</h2>
        <DataTable rows={concRows} columns={concCols} emptyMessage="No concentration data." rowKey={(r, i) => String((r as Concentration).chain_name ?? i)} />
      </section>
    </div>
  );
}
