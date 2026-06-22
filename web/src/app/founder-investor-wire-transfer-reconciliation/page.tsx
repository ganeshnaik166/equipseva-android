import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function InvestorWireTransferReconciliationPage() {
  const sb = await getSupabaseServerClient();

  const [reconsRes, orphanedRes, actionsRes] = await Promise.all([
    sb.rpc('list_recons_r2097'),
    sb.rpc('orphaned_r2097'),
    sb.rpc('recent_actions_r2097'),
  ]);

  const recons: any[] = Array.isArray(reconsRes.data) ? reconsRes.data : [];
  const orphaned: any[] = Array.isArray(orphanedRes.data) ? orphanedRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const reconCols: Column<any>[] = [
    { key: 'intent_label', header: 'Intent', render: (r: any) => String(r.intent_label ?? '') },
    { key: 'expected', header: 'Expected rupees', render: (r: any) => String(r.expected_amount_rupees ?? 0) },
    { key: 'received', header: 'Received rupees', render: (r: any) => String(r.received_amount_rupees ?? 0) },
    { key: 'variance', header: 'Variance rupees', render: (r: any) => String(r.variance_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 19) },
  ];

  const orphanedCols: Column<any>[] = [
    { key: 'intent_label', header: 'Intent', render: (r: any) => String(r.intent_label ?? '') },
    { key: 'received', header: 'Received rupees', render: (r: any) => String(r.received_amount_rupees ?? 0) },
    { key: 'transfer_ref', header: 'Transfer ref', render: (r: any) => String(r.transfer_id_referenced ?? 'none') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 19) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'recon_id', header: 'Recon', render: (r: any) => String(r.recon_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => String(r.taken_at ?? '').slice(0, 19) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Wire Transfer Reconciliation</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Match incoming wire transfers to investor intents. Flag under-received, over-received, orphaned, and disputed wires.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All reconciliations</h2>
        <DataTable rows={recons} columns={reconCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Orphaned wires</h2>
        <p style={{ color: '#777', marginBottom: 8 }}>
          Wires received without a matched intent. Investigate and link or refund.
        </p>
        <DataTable rows={orphaned} columns={orphanedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent action log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
