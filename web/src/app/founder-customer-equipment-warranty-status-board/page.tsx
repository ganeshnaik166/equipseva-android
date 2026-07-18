import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerEquipmentWarrantyStatusBoardPage() {
  const supabase = await getSupabaseServerClient();

  const [
    warrantiesRes,
    claimsRes,
    expiringRes,
    renewalsRes,
    oemRes,
    claimOutcomeRes,
    lapsedRes,
  ] = await Promise.all([
    supabase.rpc('list_warranties_r2488'),
    supabase.rpc('list_claim_decisions_r2488'),
    supabase.rpc('expiring_60d_r2488'),
    supabase.rpc('top_renewal_decisions_r2488'),
    supabase.rpc('oem_breakdown_r2488'),
    supabase.rpc('claim_outcome_summary_r2488'),
    supabase.rpc('lapsed_warranty_focus_r2488'),
  ]);

  const warranties = (warrantiesRes.data ?? []) as any[];
  const claims = (claimsRes.data ?? []) as any[];
  const expiring = (expiringRes.data ?? []) as any[];
  const renewals = (renewalsRes.data ?? []) as any[];
  const oem = (oemRes.data ?? []) as any[];
  const claimOutcome = (claimOutcomeRes.data ?? []) as any[];
  const lapsed = (lapsedRes.data ?? []) as any[];

  const rupees = (n: number | null | undefined) =>
    n == null ? '—' : '₹' + Number(n).toLocaleString('en-IN');

  const warrantyCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'equipment_model', header: 'Model', render: (r: any) => String(r.equipment_model ?? '—') },
    { key: 'warranty_start_date', header: 'Start', render: (r: any) => String(r.warranty_start_date ?? '—') },
    { key: 'warranty_end_date', header: 'End', render: (r: any) => String(r.warranty_end_date ?? '—') },
    { key: 'oem_name', header: 'OEM', render: (r: any) => String(r.oem_name ?? '—') },
    { key: 'oem_responsibility_kind', header: 'OEM Resp', render: (r: any) => String(r.oem_responsibility_kind ?? '—') },
    { key: 'days_until_expiry', header: 'Days Left', render: (r: any) => String(r.days_until_expiry ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'renewal_quote_rupees', header: 'Renewal Quote', render: (r: any) => rupees(r.renewal_quote_rupees) },
    { key: 'renewal_decision', header: 'Renewal Decision', render: (r: any) => String(r.renewal_decision ?? '—') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '—') },
  ];

  const claimCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '—') },
    { key: 'claim_filed_at', header: 'Filed', render: (r: any) => r.claim_filed_at ? new Date(r.claim_filed_at).toLocaleString() : '—' },
    { key: 'claim_kind', header: 'Kind', render: (r: any) => String(r.claim_kind ?? '—') },
    { key: 'oem_decision_at', header: 'OEM Decision At', render: (r: any) => r.oem_decision_at ? new Date(r.oem_decision_at).toLocaleString() : '—' },
    { key: 'oem_decision', header: 'OEM Decision', render: (r: any) => String(r.oem_decision ?? '—') },
    { key: 'claim_value_rupees', header: 'Claim Value', render: (r: any) => rupees(r.claim_value_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '—') },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '—') },
    { key: 'oem_name', header: 'OEM', render: (r: any) => String(r.oem_name ?? '—') },
    { key: 'warranty_end_date', header: 'End Date', render: (r: any) => String(r.warranty_end_date ?? '—') },
    { key: 'days_until_expiry', header: 'Days Left', render: (r: any) => String(r.days_until_expiry ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'renewal_quote_rupees', header: 'Quote', render: (r: any) => rupees(r.renewal_quote_rupees) },
    { key: 'renewal_decision', header: 'Decision', render: (r: any) => String(r.renewal_decision ?? '—') },
  ];

  const renewalCols: Column<any>[] = [
    { key: 'renewal_decision', header: 'Renewal Decision', render: (r: any) => String(r.renewal_decision ?? '—') },
    { key: 'warranty_count', header: 'Warranties', render: (r: any) => String(r.warranty_count ?? 0) },
    { key: 'total_quote_rupees', header: 'Total Quote', render: (r: any) => rupees(r.total_quote_rupees) },
    { key: 'avg_quote_rupees', header: 'Avg Quote', render: (r: any) => rupees(r.avg_quote_rupees) },
  ];

  const oemCols: Column<any>[] = [
    { key: 'oem_name', header: 'OEM', render: (r: any) => String(r.oem_name ?? '—') },
    { key: 'warranty_count', header: 'Warranties', render: (r: any) => String(r.warranty_count ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'expired_or_lapsed_count', header: 'Expired/Lapsed', render: (r: any) => String(r.expired_or_lapsed_count ?? 0) },
    { key: 'avg_days_until_expiry', header: 'Avg Days Left', render: (r: any) => String(Math.round(Number(r.avg_days_until_expiry ?? 0))) },
  ];

  const claimOutcomeCols: Column<any>[] = [
    { key: 'oem_decision', header: 'OEM Decision', render: (r: any) => String(r.oem_decision ?? '—') },
    { key: 'claim_count', header: 'Claims', render: (r: any) => String(r.claim_count ?? 0) },
    { key: 'total_claim_value_rupees', header: 'Total Value', render: (r: any) => rupees(r.total_claim_value_rupees) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'closed_count', header: 'Closed', render: (r: any) => String(r.closed_count ?? 0) },
    { key: 'disputed_count', header: 'Disputed', render: (r: any) => String(r.disputed_count ?? 0) },
  ];

  const lapsedCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '—') },
    { key: 'equipment_model', header: 'Model', render: (r: any) => String(r.equipment_model ?? '—') },
    { key: 'oem_name', header: 'OEM', render: (r: any) => String(r.oem_name ?? '—') },
    { key: 'warranty_end_date', header: 'End Date', render: (r: any) => String(r.warranty_end_date ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'days_until_expiry', header: 'Days', render: (r: any) => String(r.days_until_expiry ?? '—') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '—') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
        Customer Equipment Warranty Status Board
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track equipment warranties, OEM responsibility, claim decisions & renewal posture (r2488).
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Warranties</h2>
        <DataTable
          rows={warranties}
          columns={warrantyCols}
          emptyMessage="No warranties tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Claim Decisions</h2>
        <DataTable
          rows={claims}
          columns={claimCols}
          emptyMessage="No claim decisions filed."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Expiring in &lt;= 60 Days</h2>
        <DataTable
          rows={expiring}
          columns={expiringCols}
          emptyMessage="No warranties expiring in the next 60 days."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Renewal Decisions</h2>
        <DataTable
          rows={renewals}
          columns={renewalCols}
          emptyMessage="No renewal decisions logged."
          rowKey={(r: any, i: number) => String(r.renewal_decision ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>OEM Breakdown</h2>
        <DataTable
          rows={oem}
          columns={oemCols}
          emptyMessage="No OEM data available."
          rowKey={(r: any, i: number) => String(r.oem_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Claim Outcome Summary</h2>
        <DataTable
          rows={claimOutcome}
          columns={claimOutcomeCols}
          emptyMessage="No claim outcome data."
          rowKey={(r: any, i: number) => String(r.oem_decision ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Lapsed Warranty Focus</h2>
        <DataTable
          rows={lapsed}
          columns={lapsedCols}
          emptyMessage="No lapsed/expired warranties."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
