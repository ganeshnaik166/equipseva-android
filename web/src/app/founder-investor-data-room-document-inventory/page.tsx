import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type DocRow = {
  id: string;
  document_label: string;
  document_category: string;
  document_version: string;
  status: string;
  last_updated_at: string;
};

type ActionRow = {
  id: string;
  doc_id: string;
  document_label: string | null;
  action_type: string;
  taken_at: string;
  by_email: string | null;
};

type InventoryRow = {
  document_category: string;
  current_count: number;
  superseded_count: number;
  archived_count: number;
  retracted_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [docsRes, invRes, recentRes] = await Promise.all([
    sb.rpc('list_docs_r2093'),
    sb.rpc('current_inventory_r2093'),
    sb.rpc('recent_actions_r2093'),
  ]);

  const docs: DocRow[] = Array.isArray(docsRes.data) ? (docsRes.data as DocRow[]) : [];
  const inv: InventoryRow[] = Array.isArray(invRes.data) ? (invRes.data as InventoryRow[]) : [];
  const recent: ActionRow[] = Array.isArray(recentRes.data) ? (recentRes.data as ActionRow[]) : [];

  const docColumns: Column<DocRow>[] = [
    { key: 'document_label', header: 'Document', render: (r: any) => String(r.document_label ?? '') },
    { key: 'document_category', header: 'Category', render: (r: any) => String(r.document_category ?? '') },
    { key: 'document_version', header: 'Version', render: (r: any) => String(r.document_version ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_updated_at', header: 'Last Updated', render: (r: any) => r.last_updated_at ? new Date(r.last_updated_at).toLocaleString() : '' },
  ];

  const invColumns: Column<InventoryRow>[] = [
    { key: 'document_category', header: 'Category', render: (r: any) => String(r.document_category ?? '') },
    { key: 'current_count', header: 'Current', render: (r: any) => String(r.current_count ?? 0) },
    { key: 'superseded_count', header: 'Superseded', render: (r: any) => String(r.superseded_count ?? 0) },
    { key: 'archived_count', header: 'Archived', render: (r: any) => String(r.archived_count ?? 0) },
    { key: 'retracted_count', header: 'Retracted', render: (r: any) => String(r.retracted_count ?? 0) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'document_label', header: 'Document', render: (r: any) => String(r.document_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Data Room Document Inventory</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Inventory of all documents in the investor data room. Tracks current, superseded, archived, and retracted versions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Inventory by Category</h2>
        <DataTable<InventoryRow>
          rows={inv}
          columns={invColumns}
          rowKey={(r: any, i: number) => String(r.document_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Documents</h2>
        <DataTable<DocRow>
          rows={docs}
          columns={docColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable<ActionRow>
          rows={recent}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
