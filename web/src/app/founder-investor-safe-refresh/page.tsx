import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_safes: number;
  active_safes: number;
  expiring_safes: number;
  expired_safes: number;
  repapered_safes: number;
  total_principal_rupees: number;
  expiring_principal_rupees: number;
  pending_queue_items: number;
  urgent_queue_items: number;
};

function fmtRupees(v: number | null | undefined) {
  if (v == null) return '—';
  return '₹' + Number(v).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const summaryRes = await sb.rpc('founder_safe_portfolio_summary');
  const allRes = await sb.rpc('founder_safe_list_all', { p_limit: 200 });
  const expiringRes = await sb.rpc('founder_safe_list_expiring', { p_within_days: 120 });
  const queueRes = await sb.rpc('founder_safe_action_queue', { p_limit: 100 });

  const summary: Summary | null = (summaryRes.data?.[0] as Summary | undefined) ?? null;
  const all = (allRes.data ?? []) as any[];
  const expiring = (expiringRes.data ?? []) as any[];
  const queue = (queueRes.data ?? []) as any[];

  const allCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'investor_email', header: 'Email', render: (r) => r.investor_email ?? '—' },
    { key: 'principal_rupees', header: 'Principal', render: (r) => fmtRupees(r.principal_rupees) },
    { key: 'valuation_cap_rupees', header: 'Cap', render: (r) => fmtRupees(r.valuation_cap_rupees) },
    { key: 'discount_pct', header: 'Discount %', render: (r) => r.discount_pct != null ? String(r.discount_pct) + '%' : '—' },
    { key: 'signed_at', header: 'Signed', render: (r) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '—' },
    { key: 'expires_at', header: 'Expires', render: (r) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
    { key: 'days_to_expiry', header: 'Days Left', render: (r) => r.days_to_expiry != null ? String(r.days_to_expiry) : '—' },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'principal_rupees', header: 'Principal', render: (r) => fmtRupees(r.principal_rupees) },
    { key: 'expires_at', header: 'Expires', render: (r) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
    { key: 'days_to_expiry', header: 'Days Left', render: (r) => r.days_to_expiry != null ? String(r.days_to_expiry) : '—' },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'has_pending_action', header: 'In Queue', render: (r) => r.has_pending_action ? 'yes' : 'no' },
  ];

  const queueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type ?? '—' },
    { key: 'priority', header: 'Priority', render: (r) => r.priority ?? '—' },
    { key: 'due_by', header: 'Due', render: (r) => r.due_by ? new Date(r.due_by).toLocaleString() : '—' },
    { key: 'hours_until_due', header: 'Hrs to Due', render: (r) => r.hours_until_due != null ? String(r.hours_until_due) : '—' },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 20 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Investor SAFE Auto-Refresh</h1>
        <p style={{ color: '#555', marginTop: 4, fontSize: 13 }}>
          Track SAFE notes, surface expiring instruments {"<"}120 days, drive re-papering action queue.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Stat label="Total SAFEs" value={summary?.total_safes ?? 0} />
        <Stat label="Active" value={summary?.active_safes ?? 0} />
        <Stat label="Expiring {'<'}90d" value={summary?.expiring_safes ?? 0} />
        <Stat label="Expired" value={summary?.expired_safes ?? 0} />
        <Stat label="Repapered" value={summary?.repapered_safes ?? 0} />
        <Stat label="Total Principal" value={fmtRupees(summary?.total_principal_rupees ?? 0)} />
        <Stat label="Expiring Principal" value={fmtRupees(summary?.expiring_principal_rupees ?? 0)} />
        <Stat label="Pending Actions" value={summary?.pending_queue_items ?? 0} />
        <Stat label="Urgent" value={summary?.urgent_queue_items ?? 0} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Queue</h2>
        <DataTable
          rows={queue}
          columns={queueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expiring SAFEs</h2>
        <DataTable
          rows={expiring}
          columns={expiringCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All SAFE Notes</h2>
        <DataTable
          rows={all}
          columns={allCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
