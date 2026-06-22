import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "INR " + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(1) + "%";
}

export default async function FounderEngineerExpenseClaimAuditBlitzPage() {
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let samples: any[] = [];
  let categories: any[] = [];
  let findings: any[] = [];
  let engineers: any[] = [];
  let recovery: any[] = [];
  let methods: any[] = [];

  try {
    const r = await sb.rpc('r2290_blitz_kpis');
    kpis = (r.data as any[])?.[0] ?? {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('r2290_sampled_claims');
    samples = (r.data as any[]) ?? [];
  } catch { samples = []; }

  try {
    const r = await sb.rpc('r2290_category_breakdown');
    categories = (r.data as any[]) ?? [];
  } catch { categories = []; }

  try {
    const r = await sb.rpc('r2290_findings_log');
    findings = (r.data as any[]) ?? [];
  } catch { findings = []; }

  try {
    const r = await sb.rpc('r2290_engineer_ranking');
    engineers = (r.data as any[]) ?? [];
  } catch { engineers = []; }

  try {
    const r = await sb.rpc('r2290_recovery_pipeline');
    recovery = (r.data as any[]) ?? [];
  } catch { recovery = []; }

  try {
    const r = await sb.rpc('r2290_method_effectiveness');
    methods = (r.data as any[]) ?? [];
  } catch { methods = []; }

  const cards: Kpi[] = [
    { label: 'Total Samples',        value: String(kpis.total_samples ?? 0) },
    { label: 'In Review',            value: String(kpis.in_review ?? 0) },
    { label: 'Clean Claims',         value: String(kpis.clean_claims ?? 0) },
    { label: 'Fraud Suspected',      value: String(kpis.fraud_suspected ?? 0) },
    { label: 'Recovered',            value: String(kpis.recovered_claims ?? 0) },
    { label: 'Total Flagged',        value: rupees(kpis.total_flagged_rupees) },
    { label: 'Total Recovered',      value: rupees(kpis.total_recovered_rupees) },
    { label: 'Avg Risk Score',       value: String(kpis.avg_risk_score ?? 0) },
  ];

  const sampleCols: Column<any>[] = [
    { key: 'claim_ref',         header: 'Claim Ref',  render: (r: any) => r.claim_ref ?? "—" },
    { key: 'engineer_email',    header: 'Engineer',   render: (r: any) => r.engineer_email ?? "—" },
    { key: 'claim_category',    header: 'Category',   render: (r: any) => r.claim_category ?? "—" },
    { key: 'claim_amount_rupees', header: 'Amount',   render: (r: any) => rupees(r.claim_amount_rupees) },
    { key: 'sample_method',     header: 'Method',     render: (r: any) => r.sample_method ?? "—" },
    { key: 'audit_status',      header: 'Status',     render: (r: any) => r.audit_status ?? "—" },
    { key: 'risk_score',        header: 'Risk',       render: (r: any) => String(r.risk_score ?? 0) },
  ];

  const catCols: Column<any>[] = [
    { key: 'claim_category',    header: 'Category',     render: (r: any) => r.claim_category ?? "—" },
    { key: 'sample_count',      header: 'Samples',      render: (r: any) => String(r.sample_count ?? 0) },
    { key: 'total_amount_rupees', header: 'Total Amount', render: (r: any) => rupees(r.total_amount_rupees) },
    { key: 'fraud_count',       header: 'Fraud',        render: (r: any) => String(r.fraud_count ?? 0) },
    { key: 'clean_count',       header: 'Clean',        render: (r: any) => String(r.clean_count ?? 0) },
  ];

  const findingCols: Column<any>[] = [
    { key: 'claim_ref',         header: 'Claim Ref',  render: (r: any) => r.claim_ref ?? "—" },
    { key: 'engineer_email',    header: 'Engineer',   render: (r: any) => r.engineer_email ?? "—" },
    { key: 'finding_type',      header: 'Finding',    render: (r: any) => r.finding_type ?? "—" },
    { key: 'severity',          header: 'Severity',   render: (r: any) => r.severity ?? "—" },
    { key: 'flagged_amount_rupees', header: 'Flagged',  render: (r: any) => rupees(r.flagged_amount_rupees) },
    { key: 'recovery_amount_rupees', header: 'Recovery', render: (r: any) => rupees(r.recovery_amount_rupees) },
    { key: 'recovery_status',   header: 'Recovery Status', render: (r: any) => r.recovery_status ?? "—" },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_email',    header: 'Engineer',   render: (r: any) => r.engineer_email ?? "—" },
    { key: 'claim_count',       header: 'Claims',     render: (r: any) => String(r.claim_count ?? 0) },
    { key: 'total_flagged_rupees', header: 'Flagged', render: (r: any) => rupees(r.total_flagged_rupees) },
    { key: 'fraud_count',       header: 'Fraud Hits', render: (r: any) => String(r.fraud_count ?? 0) },
    { key: 'recovery_rupees',   header: 'Recovered',  render: (r: any) => rupees(r.recovery_rupees) },
  ];

  const recCols: Column<any>[] = [
    { key: 'recovery_status',   header: 'Status',     render: (r: any) => r.recovery_status ?? "—" },
    { key: 'finding_count',     header: 'Findings',   render: (r: any) => String(r.finding_count ?? 0) },
    { key: 'total_recovery_rupees', header: 'Total',  render: (r: any) => rupees(r.total_recovery_rupees) },
  ];

  const methodCols: Column<any>[] = [
    { key: 'sample_method',     header: 'Method',     render: (r: any) => r.sample_method ?? "—" },
    { key: 'samples_taken',     header: 'Samples',    render: (r: any) => String(r.samples_taken ?? 0) },
    { key: 'fraud_hits',        header: 'Fraud Hits', render: (r: any) => String(r.fraud_hits ?? 0) },
    { key: 'hit_rate_pct',      header: 'Hit Rate',   render: (r: any) => pct(r.hit_rate_pct) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Engineer Expense-Claim Audit Blitz</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Random and risk-weighted sampling of engineer expense claims =&gt; fraud detection =&gt; recovery log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', padding: 12, borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Sampled Claims (Priority Order)</h2>
        <DataTable columns={sampleCols} rows={samples} rowKey={(r: any) => r.sample_id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Category Breakdown</h2>
        <DataTable columns={catCols} rows={categories} rowKey={(r: any) => r.claim_category} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Audit Findings Log</h2>
        <DataTable columns={findingCols} rows={findings} rowKey={(r: any) => r.finding_id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Engineer Offender Ranking</h2>
        <DataTable columns={engCols} rows={engineers} rowKey={(r: any) => r.engineer_email} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recovery Pipeline</h2>
        <DataTable columns={recCols} rows={recovery} rowKey={(r: any) => r.recovery_status} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Sampling-Method Effectiveness</h2>
        <DataTable columns={methodCols} rows={methods} rowKey={(r: any) => r.sample_method} />
      </section>
    </main>
  );
}
