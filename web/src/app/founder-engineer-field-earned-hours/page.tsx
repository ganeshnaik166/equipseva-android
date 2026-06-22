import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerFieldEarnedHoursPage() {
  const sb = await getSupabaseServerClient();

  const [hoursRes, gapsRes, actionsRes] = await Promise.all([
    sb.rpc('list_hours_r2096'),
    sb.rpc('gaps_r2096'),
    sb.rpc('recent_actions_r2096'),
  ]);

  const hours: any[] = Array.isArray(hoursRes.data) ? hoursRes.data : [];
  const gaps: any[] = Array.isArray(gapsRes.data) ? gapsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const hoursCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'field_hours', header: 'Field hours', render: (r: any) => String(r.field_hours ?? 0) },
    { key: 'billed_hours', header: 'Billed hours', render: (r: any) => String(r.billed_hours ?? 0) },
    { key: 'gap_hours', header: 'Gap hours', render: (r: any) => String(r.gap_hours ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured at', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const gapsCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'rows_count', header: 'Rows', render: (r: any) => String(r.rows_count ?? 0) },
    { key: 'total_gap', header: 'Total gap hours', render: (r: any) => String(r.total_gap ?? 0) },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'hours_id', header: 'Hours row', render: (r: any) => String(r.hours_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Field-Earned Hours</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track engineer field hours versus billed hours and surface gaps that need audit or coaching.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Gap summary by status</h2>
        <DataTable rows={gaps} columns={gapsCols} rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Field-earned hours ledger</h2>
        <DataTable rows={hours} columns={hoursCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent actions</h2>
        <DataTable rows={actions} columns={actionsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
