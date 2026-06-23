import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const metadata = { title: 'Founder customer warranty claim pipeline — r2424' };
export const dynamic = 'force-dynamic';

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return '—';
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function statusBadge(s: string): string {
  if (s === 'refunded') return 'text-emerald-700 font-semibold';
  if (s === 'approved') return 'text-emerald-700';
  if (s === 'denied') return 'text-red-700';
  if (s === 'escalated') return 'text-amber-700 font-semibold';
  if (s === 'pending') return 'text-amber-700';
  return '';
}

function kindLabel(k: string): string {
  if (k === 'defective_part') return 'Defective part';
  if (k === 'workmanship') return 'Workmanship';
  if (k === 'extended_warranty') return 'Extended warranty';
  if (k === 'recall') return 'Recall';
  if (k === 'calibration_drift') return 'Calibration drift';
  return k;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [claimsRes, suppliersRes, funnelRes, topSuppliersRes, trendRes, hospitalsRes, escalatedRes] = await Promise.all([
    supabase.rpc('list_claims_r2424'),
    supabase.rpc('supplier_liability_r2424'),
    supabase.rpc('decision_funnel_r2424'),
    supabase.rpc('top_offending_suppliers_r2424'),
    supabase.rpc('monthly_claim_trend_r2424'),
    supabase.rpc('top_impacted_hospitals_r2424'),
    supabase.rpc('escalated_claims_r2424'),
  ]);

  const claims = (claimsRes.data ?? []) as any[];
  const suppliers = (suppliersRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const topSuppliers = (topSuppliersRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const hospitals = (hospitalsRes.data ?? []) as any[];
  const escalated = (escalatedRes.data ?? []) as any[];

  const claimsColumns: Column<any>[] = [
    { key: 'ref', header: 'Ref', render: (r: any) => <span className="font-mono text-xs">{r.claim_external_ref}</span> },
    { key: 'equipment', header: 'Equipment', render: (r: any) => (
      <div>
        <div>{r.equipment_label}</div>
        {r.equipment_serial ? <div className="text-xs text-gray-500 font-mono">{r.equipment_serial}</div> : null}
      </div>
    ) },
    { key: 'kind', header: 'Kind', render: (r: any) => kindLabel(r.claim_kind) },
    { key: 'submitted', header: 'Submitted', render: (r: any) => fmtDate(r.submitted_at) },
    { key: 'status', header: 'Status', render: (r: any) => <span className={statusBadge(r.decision_status)}>{r.decision_status}</span> },
    { key: 'refund', header: 'Refund', render: (r: any) => fmtRupees(r.refund_amount_rupees) },
    { key: 'liab', header: 'Supplier liab', render: (r: any) => r.supplier_liability_pct == null ? '—' : `${Number(r.supplier_liability_pct).toFixed(0)}%` },
    { key: 'hrs', header: 'Hrs to decision', render: (r: any) => r.hours_to_decision == null ? '—' : Number(r.hours_to_decision).toFixed(1) },
    { key: 'notes', header: 'Notes', render: (r: any) => <span className="text-xs text-gray-600">{r.notes ?? '—'}</span> },
  ];

  const suppliersColumns: Column<any>[] = [
    { key: 'name', header: 'Supplier', render: (r: any) => <span className="font-semibold">{r.supplier_name}</span> },
    { key: 'claims', header: 'Claims 30d', render: (r: any) => r.claims_30d },
    { key: 'approved', header: 'Approved', render: (r: any) => <span className="text-emerald-700">{r.approved_30d}</span> },
    { key: 'denied', header: 'Denied', render: (r: any) => <span className="text-red-700">{r.denied_30d}</span> },
    { key: 'owed', header: 'Owed', render: (r: any) => fmtRupees(r.total_refund_owed_rupees) },
    { key: 'paid', header: 'Paid', render: (r: any) => fmtRupees(r.total_refund_paid_rupees) },
    { key: 'unpaid', header: 'Unpaid', render: (r: any) => <span className={Number(r.unpaid_rupees) > 0 ? 'text-red-700 font-semibold' : 'text-gray-500'}>{fmtRupees(r.unpaid_rupees)}</span> },
    { key: 'hrs', header: 'Avg decision hrs', render: (r: any) => r.avg_decision_hours == null ? '—' : Number(r.avg_decision_hours).toFixed(1) },
    { key: 'last', header: 'Last claim', render: (r: any) => fmtDate(r.last_claim_at) },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => <span className={statusBadge(r.decision_status)}>{r.decision_status}</span> },
    { key: 'count', header: 'Claims', render: (r: any) => r.claim_count },
    { key: 'refund', header: 'Refund total', render: (r: any) => fmtRupees(r.refund_total_rupees) },
  ];

  const topSupColumns: Column<any>[] = [
    { key: 'name', header: 'Supplier', render: (r: any) => r.supplier_name },
    { key: 'c30', header: 'Claims 30d', render: (r: any) => r.claims_30d },
    { key: 'a30', header: 'Approved 30d', render: (r: any) => r.approved_30d },
    { key: 'unpaid', header: 'Unpaid', render: (r: any) => fmtRupees(r.unpaid_rupees) },
    { key: 'hrs', header: 'Avg hrs', render: (r: any) => r.avg_decision_hours == null ? '—' : Number(r.avg_decision_hours).toFixed(1) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'month', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
    { key: 'claims', header: 'Claims', render: (r: any) => r.claims },
    { key: 'approved', header: 'Approved', render: (r: any) => <span className="text-emerald-700">{r.approved}</span> },
    { key: 'denied', header: 'Denied', render: (r: any) => <span className="text-red-700">{r.denied}</span> },
    { key: 'refunded', header: 'Refunded', render: (r: any) => fmtRupees(r.refunded_rupees) },
  ];

  const hospitalsColumns: Column<any>[] = [
    { key: 'h', header: 'Hospital', render: (r: any) => r.hospital_label },
    { key: 'c', header: 'Claims', render: (r: any) => r.claims },
    { key: 'r', header: 'Refunded', render: (r: any) => fmtRupees(r.refunded_rupees) },
    { key: 'last', header: 'Last claim', render: (r: any) => fmtDate(r.last_claim_at) },
  ];

  const escalatedColumns: Column<any>[] = [
    { key: 'ref', header: 'Ref', render: (r: any) => <span className="font-mono text-xs">{r.claim_external_ref}</span> },
    { key: 'eq', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'kind', header: 'Kind', render: (r: any) => kindLabel(r.claim_kind) },
    { key: 'submitted', header: 'Submitted', render: (r: any) => fmtDate(r.submitted_at) },
    { key: 'open', header: 'Hrs open', render: (r: any) => <span className={Number(r.hours_open) > 168 ? 'text-red-700 font-semibold' : 'text-amber-700'}>{Number(r.hours_open).toFixed(1)}</span> },
    { key: 'refund', header: 'Refund', render: (r: any) => fmtRupees(r.refund_amount_rupees) },
    { key: 'liab', header: 'Supplier liab', render: (r: any) => r.supplier_liability_pct == null ? '—' : `${Number(r.supplier_liability_pct).toFixed(0)}%` },
    { key: 'notes', header: 'Notes', render: (r: any) => <span className="text-xs text-gray-600">{r.notes ?? '—'}</span> },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer warranty claim pipeline</h1>
        <p className="text-sm text-gray-600">
          r2424 · claim & kind & status & approve/deny & refund & supplier liability
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelColumns}
          emptyMessage="No claims recorded"
          rowKey={(r: any, i: number) => String(r.id ?? r.decision_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All claims</h2>
        <DataTable
          rows={claims}
          columns={claimsColumns}
          emptyMessage="No claims in pipeline"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Escalated & stuck claims</h2>
        <DataTable
          rows={escalated}
          columns={escalatedColumns}
          emptyMessage="No escalated or stuck claims"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Supplier liability</h2>
        <DataTable
          rows={suppliers}
          columns={suppliersColumns}
          emptyMessage="No supplier liability tracked"
          rowKey={(r: any, i: number) => String(r.id ?? r.supplier_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top offending suppliers</h2>
        <DataTable
          rows={topSuppliers}
          columns={topSupColumns}
          emptyMessage="No offending suppliers"
          rowKey={(r: any, i: number) => String(r.id ?? r.supplier_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly claim trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.id ?? r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top impacted hospitals</h2>
        <DataTable
          rows={hospitals}
          columns={hospitalsColumns}
          emptyMessage="No hospital impact recorded"
          rowKey={(r: any, i: number) => String(r.id ?? r.hospital_label ?? i)}
        />
      </section>
    </main>
  );
}
