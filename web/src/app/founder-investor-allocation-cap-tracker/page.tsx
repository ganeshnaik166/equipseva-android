import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CapRow = {
  id: string;
  investor_id: string | null;
  investor_email: string | null;
  round_label: string | null;
  allocation_cap_rupees: number | null;
  allocation_used_rupees: number | null;
  status: string | null;
  captured_at: string | null;
};

type NearCapRow = {
  id: string;
  investor_id: string | null;
  investor_email: string | null;
  round_label: string | null;
  allocation_cap_rupees: number | null;
  allocation_used_rupees: number | null;
  pct_used: number | null;
  status: string | null;
};

type ActionRow = {
  id: string;
  cap_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  amount_rupees: number | null;
  investor_email: string | null;
  round_label: string | null;
};

function formatRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function formatDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return String(s);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [capsRes, nearRes, recentRes] = await Promise.all([
    sb.rpc('list_caps_r2057'),
    sb.rpc('near_cap_r2057'),
    sb.rpc('recent_actions_r2057'),
  ]);

  const caps: CapRow[] = (capsRes.data as CapRow[]) ?? [];
  const nearCaps: NearCapRow[] = (nearRes.data as NearCapRow[]) ?? [];
  const recent: ActionRow[] = (recentRes.data as ActionRow[]) ?? [];

  const capsColumns: Column<CapRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '-' },
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label ?? '-' },
    { key: 'allocation_cap_rupees', header: 'Cap', render: (r: any) => formatRupees(r.allocation_cap_rupees) },
    { key: 'allocation_used_rupees', header: 'Used', render: (r: any) => formatRupees(r.allocation_used_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => formatDate(r.captured_at) },
  ];

  const nearColumns: Column<NearCapRow>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '-' },
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label ?? '-' },
    { key: 'allocation_cap_rupees', header: 'Cap', render: (r: any) => formatRupees(r.allocation_cap_rupees) },
    { key: 'allocation_used_rupees', header: 'Used', render: (r: any) => formatRupees(r.allocation_used_rupees) },
    { key: 'pct_used', header: 'Pct used', render: (r: any) => (r.pct_used !== null && r.pct_used !== undefined ? String(r.pct_used) + ' percent' : '-') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => formatDate(r.taken_at) },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '-' },
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => formatRupees(r.amount_rupees) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
  ];

  return (
    <main style={{ padding: '1.5rem', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '1.5rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.25rem' }}>
          Investor Allocation Cap Tracker
        </h1>
        <p style={{ color: '#555' }}>
          Track per-investor allocation caps across rounds. Watch for investors nearing or exceeding cap.
        </p>
      </header>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.5rem' }}>
          All caps
        </h2>
        <p style={{ color: '#666', marginBottom: '0.5rem' }}>
          Most recent 200 cap records across all investors and rounds.
        </p>
        <DataTable
          rows={caps}
          columns={capsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.5rem' }}>
          Near cap (active, ninety percent or above)
        </h2>
        <p style={{ color: '#666', marginBottom: '0.5rem' }}>
          Active caps where utilisation is at or above ninety percent. Flag for follow-up before the round closes.
        </p>
        <DataTable
          rows={nearCaps}
          columns={nearColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.5rem' }}>
          Recent action log
        </h2>
        <p style={{ color: '#666', marginBottom: '0.5rem' }}>
          Most recent 200 cap actions: cap set, allocation increased, allocation used, exceeded, closed, superseded.
        </p>
        <DataTable
          rows={recent}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
