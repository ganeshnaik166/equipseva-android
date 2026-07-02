import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerToolInventoryPage() {
  const sb = await getSupabaseServerClient();

  const [toolsRes, replacementsRes, urgentRes, summaryRes] = await Promise.all([
    sb.rpc('list_tools_r1720'),
    sb.rpc('list_replacements_r1720', { p_status: null }),
    sb.rpc('urgent_replacements_r1720'),
    sb.rpc('condition_summary_r1720'),
  ]);

  const tools: any[] = Array.isArray(toolsRes.data) ? toolsRes.data : [];
  const replacements: any[] = Array.isArray(replacementsRes.data) ? replacementsRes.data : [];
  const urgent: any[] = Array.isArray(urgentRes.data) ? urgentRes.data : [];
  const summary: any =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0 ? summaryRes.data[0] : null;

  const toolCols: Column<any>[] = [
    { key: 'tool_name', header: 'Tool', render: (r: any) => String(r.tool_name ?? '') },
    { key: 'tool_category', header: 'Category', render: (r: any) => String(r.tool_category ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '—') },
    { key: 'condition', header: 'Condition', render: (r: any) => String(r.condition ?? '') },
    {
      key: 'last_inspected_at',
      header: 'Last Inspected',
      render: (r: any) => (r.last_inspected_at ? new Date(r.last_inspected_at).toLocaleDateString() : '—'),
    },
    {
      key: 'assigned_at',
      header: 'Assigned',
      render: (r: any) => (r.assigned_at ? new Date(r.assigned_at).toLocaleDateString() : '—'),
    },
    {
      key: 'retired_at',
      header: 'Retired',
      render: (r: any) => (r.retired_at ? new Date(r.retired_at).toLocaleDateString() : '—'),
    },
  ];

  const replacementCols: Column<any>[] = [
    { key: 'tool_name', header: 'Tool', render: (r: any) => String(r.tool_name ?? '') },
    { key: 'tool_category', header: 'Category', render: (r: any) => String(r.tool_category ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '—') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    {
      key: 'cost_estimate_rupees',
      header: 'Cost Est',
      render: (r: any) => `₹${Number(r.cost_estimate_rupees ?? 0).toLocaleString()}`,
    },
    {
      key: 'requested_at',
      header: 'Requested',
      render: (r: any) => (r.requested_at ? new Date(r.requested_at).toLocaleString() : '—'),
    },
    {
      key: 'fulfilled_at',
      header: 'Fulfilled',
      render: (r: any) => (r.fulfilled_at ? new Date(r.fulfilled_at).toLocaleDateString() : '—'),
    },
  ];

  const urgentCols: Column<any>[] = [
    { key: 'tool_name', header: 'Tool', render: (r: any) => String(r.tool_name ?? '') },
    { key: 'tool_category', header: 'Category', render: (r: any) => String(r.tool_category ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '—') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '') },
    {
      key: 'cost_estimate_rupees',
      header: 'Cost Est',
      render: (r: any) => `₹${Number(r.cost_estimate_rupees ?? 0).toLocaleString()}`,
    },
    {
      key: 'days_open',
      header: 'Days Open',
      render: (r: any) => {
        const d = Number(r.days_open ?? 0);
        return d >= 7 ? `${d} (overdue)` : String(d);
      },
    },
    {
      key: 'requested_at',
      header: 'Requested',
      render: (r: any) => (r.requested_at ? new Date(r.requested_at).toLocaleDateString() : '—'),
    },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Engineer Tool Inventory
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-engineer tool kit, condition tracker, and replacement queue. Covers diagnostic, repair,
        calibration, safety, and measurement tools across the field force.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Condition Summary</h2>
        {summary ? (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
              gap: 12,
            }}
          >
            <Stat label="Total Tools" value={String(summary.total_tools ?? 0)} />
            <Stat label="New" value={String(summary.new_count ?? 0)} />
            <Stat label="Good" value={String(summary.good_count ?? 0)} />
            <Stat label="Fair" value={String(summary.fair_count ?? 0)} />
            <Stat label="Worn" value={String(summary.worn_count ?? 0)} />
            <Stat
              label="Needs Replacement"
              value={String(summary.needs_replacement_count ?? 0)}
            />
            <Stat label="Retired" value={String(summary.retired_count ?? 0)} />
          </div>
        ) : (
          <p style={{ color: '#999' }}>No summary data.</p>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Urgent Replacements (priority high or urgent, status open or approved)
        </h2>
        <DataTable
          rows={urgent}
          columns={urgentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Tool Inventory (latest 200)
        </h2>
        <DataTable
          rows={tools}
          columns={toolCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Replacement Queue (latest 200)
        </h2>
        <DataTable
          rows={replacements}
          columns={replacementCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        padding: 16,
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        background: '#fafafa',
      }}
    >
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
