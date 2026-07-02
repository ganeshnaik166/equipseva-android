import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [shiftsRes, actionsRes, earnersRes, aggRes] = await Promise.all([
    sb.rpc('list_night_shift_logs_r2222', { p_limit: 100 }),
    sb.rpc('recent_actions_night_shift_r2222', { p_limit: 50 }),
    sb.rpc('top_night_shift_earners_r2222', { p_limit: 20 }),
    sb.rpc('aggregate_night_shift_r2222'),
  ]);

  const shifts = (shiftsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const earners = (earnersRes.data ?? []) as any[];
  const agg = ((aggRes.data ?? [])[0] ?? {}) as any;

  const shiftCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'job_ref', header: 'Job', render: (r: any) => String(r.job_ref ?? '') },
    { key: 'shift_kind', header: 'Kind', render: (r: any) => String(r.shift_kind ?? '') },
    { key: 'shift_started_at', header: 'Started', render: (r: any) => r.shift_started_at ? new Date(r.shift_started_at).toLocaleString() : '' },
    { key: 'hours_worked', header: 'Hours', render: (r: any) => String(r.hours_worked ?? '0') },
    { key: 'premium_multiplier', header: 'Mult', render: (r: any) => String(r.premium_multiplier ?? '1.00') + 'x' },
    { key: 'base_pay_rupees', header: 'Base', render: (r: any) => '₹' + String(r.base_pay_rupees ?? 0) },
    { key: 'premium_pay_rupees', header: 'Premium', render: (r: any) => '₹' + String(r.premium_pay_rupees ?? 0) },
    { key: 'location_city', header: 'City', render: (r: any) => String(r.location_city ?? '') },
    { key: 'approval_status', header: 'Status', render: (r: any) => String(r.approval_status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'op_name', header: 'Op', render: (r: any) => String(r.op_name ?? '') },
    { key: 'after_value', header: 'Payload', render: (r: any) => JSON.stringify(r.after_value ?? {}).slice(0, 120) },
  ];

  const earnerCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'shift_count', header: 'Shifts', render: (r: any) => String(r.shift_count ?? 0) },
    { key: 'total_premium_pay_rupees', header: 'Total Premium', render: (r: any) => '₹' + String(r.total_premium_pay_rupees ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>Engineer Night-Shift Premium Tracker</h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Track jobs after 8pm & weekends & holidays. Premium multiplier calculation & monthly reconciliation.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Stat label="Total shifts" value={String(agg.total_shifts ?? 0)} />
        <Stat label="Pending approval" value={String(agg.pending_shifts ?? 0)} />
        <Stat label="Approved" value={String(agg.approved_shifts ?? 0)} />
        <Stat label="Paid" value={String(agg.paid_shifts ?? 0)} />
        <Stat label="Premium payout" value={'₹' + String(agg.total_premium_pay_rupees ?? 0)} />
        <Stat label="Total hours" value={String(agg.total_hours ?? 0)} />
        <Stat label="Weekend shifts" value={String(agg.weekend_shifts ?? 0)} />
        <Stat label="Night shifts (post-8pm)" value={String(agg.night_shifts ?? 0)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent shifts</h2>
        <DataTable columns={shiftCols} rows={shifts} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top earners (approved & paid)</h2>
        <DataTable columns={earnerCols} rows={earners} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Audit log</h2>
        <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#888', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}
