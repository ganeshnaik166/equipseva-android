import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(n);
}

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + new Intl.NumberFormat('en-IN').format(n);
}

export default async function FounderHospitalInsuranceClaimPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = null;
  let recent: any[] = [];
  let perHospital: any[] = [];
  let perInsurer: any[] = [];
  let unreconciled: any[] = [];
  let timeline: any[] = [];

  try {
    const r = await sb.rpc('founder_insurance_claim_summary');
    summary = (r.data && r.data[0]) ?? null;
  } catch {}
  try {
    const r = await sb.rpc('founder_insurance_claims_recent', { p_limit: 50 });
    recent = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_insurance_per_hospital');
    perHospital = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_insurance_per_insurer');
    perInsurer = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_insurance_unreconciled');
    unreconciled = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_insurance_status_timeline', { p_days: 30 });
    timeline = r.data ?? [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Total Claims',          value: fmt(summary?.total_claims) },
    { label: 'Filed',                 value: fmt(summary?.filed_claims) },
    { label: 'Approved',              value: fmt(summary?.approved_claims) },
    { label: 'Rejected',              value: fmt(summary?.rejected_claims) },
    { label: 'Partial',               value: fmt(summary?.partial_claims) },
    { label: 'Withdrawn',             value: fmt(summary?.withdrawn_claims) },
    { label: 'Total Claimed',         value: inr(summary?.total_claimed_rupees) },
    { label: 'Total Approved',        value: inr(summary?.total_approved_rupees) },
    { label: 'Approval Rate %',       value: summary?.approval_rate_pct != null ? String(summary.approval_rate_pct) + '%' : '—' },
    { label: 'Reconciled',            value: fmt(summary?.reconciled_claims) },
    { label: 'Unreconciled (approved)', value: fmt(summary?.unreconciled_approved) },
    { label: 'Hospitals w/ Claims',   value: fmt(summary?.hospitals_with_claims) },
    { label: 'Avg Decision Days',     value: summary?.avg_decision_days != null ? String(summary.avg_decision_days) : '—' },
    { label: 'Claims Last 30d',       value: fmt(summary?.claims_last_30d) },
    { label: 'Approved Last 30d',     value: fmt(summary?.approved_last_30d) },
    { label: 'Rejected Last 30d',     value: fmt(summary?.rejected_last_30d) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name',          header: 'Hospital',      render: (r: any) => r.hospital_name ?? '—' },
    { key: 'insurer_name',           header: 'Insurer',       render: (r: any) => r.insurer_name ?? '—' },
    { key: 'claim_reference',        header: 'Ref',           render: (r: any) => r.claim_reference ?? '—' },
    { key: 'status',                 header: 'Status',        render: (r: any) => r.status ?? '—' },
    { key: 'claimed_amount_rupees',  header: 'Claimed',       render: (r: any) => inr(r.claimed_amount_rupees) },
    { key: 'approved_amount_rupees', header: 'Approved',      render: (r: any) => inr(r.approved_amount_rupees) },
    { key: 'filed_at',               header: 'Filed',         render: (r: any) => r.filed_at ? new Date(r.filed_at).toLocaleDateString() : '—' },
    { key: 'decided_at',             header: 'Decided',       render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '—' },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_name',          header: 'Hospital',       render: (r: any) => r.hospital_name ?? '—' },
    { key: 'total_claims',           header: 'Total',          render: (r: any) => fmt(r.total_claims) },
    { key: 'approved_count',         header: 'Approved',       render: (r: any) => fmt(r.approved_count) },
    { key: 'rejected_count',         header: 'Rejected',       render: (r: any) => fmt(r.rejected_count) },
    { key: 'partial_count',          header: 'Partial',        render: (r: any) => fmt(r.partial_count) },
    { key: 'approval_rate_pct',      header: 'Approval %',     render: (r: any) => r.approval_rate_pct != null ? String(r.approval_rate_pct) + '%' : '—' },
    { key: 'total_claimed_rupees',   header: 'Claimed',        render: (r: any) => inr(r.total_claimed_rupees) },
    { key: 'total_approved_rupees',  header: 'Approved ₹',     render: (r: any) => inr(r.total_approved_rupees) },
    { key: 'unreconciled_count',     header: 'Unreconciled',   render: (r: any) => fmt(r.unreconciled_count) },
  ];

  const insurerCols: Column<any>[] = [
    { key: 'insurer_name',           header: 'Insurer',        render: (r: any) => r.insurer_name ?? '—' },
    { key: 'total_claims',           header: 'Total',          render: (r: any) => fmt(r.total_claims) },
    { key: 'approved_count',         header: 'Approved',       render: (r: any) => fmt(r.approved_count) },
    { key: 'rejected_count',         header: 'Rejected',       render: (r: any) => fmt(r.rejected_count) },
    { key: 'approval_rate_pct',      header: 'Approval %',     render: (r: any) => r.approval_rate_pct != null ? String(r.approval_rate_pct) + '%' : '—' },
    { key: 'total_claimed_rupees',   header: 'Claimed',        render: (r: any) => inr(r.total_claimed_rupees) },
    { key: 'total_approved_rupees',  header: 'Approved ₹',     render: (r: any) => inr(r.total_approved_rupees) },
    { key: 'avg_decision_days',      header: 'Avg Days',       render: (r: any) => r.avg_decision_days != null ? String(r.avg_decision_days) : '—' },
  ];

  const unreconciledCols: Column<any>[] = [
    { key: 'hospital_name',          header: 'Hospital',       render: (r: any) => r.hospital_name ?? '—' },
    { key: 'insurer_name',           header: 'Insurer',        render: (r: any) => r.insurer_name ?? '—' },
    { key: 'approved_amount_rupees', header: 'Approved ₹',     render: (r: any) => inr(r.approved_amount_rupees) },
    { key: 'decided_at',             header: 'Decided',        render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '—' },
    { key: 'days_since_decision',    header: 'Days Open',      render: (r: any) => fmt(r.days_since_decision) },
  ];

  const timelineCols: Column<any>[] = [
    { key: 'day',             header: 'Day',      render: (r: any) => r.day ? new Date(r.day).toLocaleDateString() : '—' },
    { key: 'filed_count',     header: 'Filed',    render: (r: any) => fmt(r.filed_count) },
    { key: 'approved_count',  header: 'Approved', render: (r: any) => fmt(r.approved_count) },
    { key: 'rejected_count',  header: 'Rejected', render: (r: any) => fmt(r.rejected_count) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Insurance Claim Tracker</h1>
        <p className="text-sm text-neutral-600">Filed / approved / rejected claim status, per-hospital approval rate, finance reconciliation queue.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border p-3">
            <div className="text-xs text-neutral-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Claims</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per Hospital</h2>
        <DataTable columns={hospitalCols} rows={perHospital} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per Insurer</h2>
        <DataTable columns={insurerCols} rows={perInsurer} rowKey={(r: any) => r.insurer_name} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Finance Reconciliation Queue</h2>
        <DataTable columns={unreconciledCols} rows={unreconciled} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">30-Day Status Timeline</h2>
        <DataTable columns={timelineCols} rows={timeline} rowKey={(r: any) => String(r.day)} />
      </section>
    </main>
  );
}
