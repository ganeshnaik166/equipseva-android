import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Negotiation = {
  id: string;
  negotiation_label: string;
  negotiation_type: string;
  outcome: string;
  value_change_rupees: number;
  status: string;
  captured_at: string;
};

type WonRow = {
  id: string;
  negotiation_label: string;
  negotiation_type: string;
  value_change_rupees: number;
  captured_at: string;
};

type ActionRow = {
  id: string;
  negotiation_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return 'Rs ' + v.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return String(s); }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [negRes, wonRes, actRes] = await Promise.all([
    sb.rpc('list_negotiations_r2182'),
    sb.rpc('recent_won_r2182'),
    sb.rpc('recent_actions_r2182'),
  ]);

  const negotiations: Negotiation[] = (negRes.data as Negotiation[] | null) ?? [];
  const won: WonRow[] = (wonRes.data as WonRow[] | null) ?? [];
  const actions: ActionRow[] = (actRes.data as ActionRow[] | null) ?? [];

  const negCols: Column<Negotiation>[] = [
    { key: 'negotiation_label', header: 'Label', render: (r: any) => String(r.negotiation_label ?? '') },
    { key: 'negotiation_type', header: 'Type', render: (r: any) => String(r.negotiation_type ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'value_change_rupees', header: 'Value change', render: (r: any) => fmtRupees(r.value_change_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const wonCols: Column<WonRow>[] = [
    { key: 'negotiation_label', header: 'Label', render: (r: any) => String(r.negotiation_label ?? '') },
    { key: 'negotiation_type', header: 'Type', render: (r: any) => String(r.negotiation_type ?? '') },
    { key: 'value_change_rupees', header: 'Value won', render: (r: any) => fmtRupees(r.value_change_rupees) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const actCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'negotiation_id', header: 'Negotiation', render: (r: any) => String(r.negotiation_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmtDate(r.taken_at) },
  ];

  const totalOpen = negotiations.filter((n) => n.status === 'open').length;
  const totalWonValue = won.reduce((acc, w) => acc + Number(w.value_change_rupees ?? 0), 0);

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>Founder Negotiation Outcome Tracker</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track outcomes across vendor, customer, investor, employee and partner negotiations.
      </p>

      <section style={{ marginBottom: 24, display: 'flex', gap: 16, flexWrap: 'wrap' }}>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, minWidth: 180 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Open negotiations</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{totalOpen}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, minWidth: 180 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Recent won value</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(totalWonValue)}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, minWidth: 180 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Tracked total</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{negotiations.length}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All negotiations</h2>
        <DataTable rows={negotiations} columns={negCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recently won</h2>
        <DataTable rows={won} columns={wonCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={actions} columns={actCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
