import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [handoversRes, discrepancyRes, focusRes, shiftRes, signoffRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_handovers_r2594'),
    supabase.rpc('list_discrepancy_resolution_r2594'),
    supabase.rpc('top_discrepancy_focus_r2594'),
    supabase.rpc('shift_kind_breakdown_r2594'),
    supabase.rpc('signoff_status_summary_r2594'),
    supabase.rpc('monthly_handover_trend_r2594'),
    supabase.rpc('owner_load_r2594'),
  ]);

  const handovers = (handoversRes.data ?? []) as any[];
  const discrepancies = (discrepancyRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const shifts = (shiftRes.data ?? []) as any[];
  const signoffs = (signoffRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const owners = (ownerRes.data ?? []) as any[];

  const handoverCols: Column<any>[] = [
    { key: 'handover_at', header: 'Handover At', render: (r: any) => r.handover_at ? new Date(r.handover_at).toLocaleString() : '—' },
    { key: 'shift_kind', header: 'Shift', render: (r: any) => r.shift_kind ?? '—' },
    { key: 'handover_items_count', header: 'Items', render: (r: any) => String(r.handover_items_count ?? 0) },
    { key: 'signoff_status', header: 'Signoff', render: (r: any) => r.signoff_status ?? '—' },
    { key: 'discrepancies_count', header: 'Discrepancies', render: (r: any) => String(r.discrepancies_count ?? 0) },
    { key: 'top_handover_item_md', header: 'Top Item', render: (r: any) => r.top_handover_item_md ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const discrepancyCols: Column<any>[] = [
    { key: 'discrepancy_kind', header: 'Kind', render: (r: any) => r.discrepancy_kind ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'resolution_summary', header: 'Resolution', render: (r: any) => r.resolution_summary ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'discrepancy_kind', header: 'Kind', render: (r: any) => r.discrepancy_kind ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
  ];

  const shiftCols: Column<any>[] = [
    { key: 'shift_kind', header: 'Shift', render: (r: any) => r.shift_kind ?? '—' },
    { key: 'handovers', header: 'Handovers', render: (r: any) => String(r.handovers ?? 0) },
    { key: 'total_items', header: 'Items', render: (r: any) => String(r.total_items ?? 0) },
    { key: 'total_discrepancies', header: 'Discrepancies', render: (r: any) => String(r.total_discrepancies ?? 0) },
  ];

  const signoffCols: Column<any>[] = [
    { key: 'signoff_status', header: 'Signoff', render: (r: any) => r.signoff_status ?? '—' },
    { key: 'handovers', header: 'Handovers', render: (r: any) => String(r.handovers ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '—' },
    { key: 'handovers', header: 'Handovers', render: (r: any) => String(r.handovers ?? 0) },
    { key: 'total_discrepancies', header: 'Discrepancies', render: (r: any) => String(r.total_discrepancies ?? 0) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'handovers', header: 'Handovers', render: (r: any) => String(r.handovers ?? 0) },
    { key: 'open_discrepancies', header: 'Open Disc.', render: (r: any) => String(r.open_discrepancies ?? 0) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer On-Call Shift Handover Ledger</h1>
        <p style={{ color: '#555' }}>Shift > outgoing & incoming engineers > items, signoff, discrepancies.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Handovers</h2>
        <DataTable
          rows={handovers}
          columns={handoverCols}
          emptyMessage="No handovers recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Discrepancy Resolutions</h2>
        <DataTable
          rows={discrepancies}
          columns={discrepancyCols}
          emptyMessage="No discrepancies logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Discrepancy Focus</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No open discrepancies."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Shift Kind Breakdown</h2>
        <DataTable
          rows={shifts}
          columns={shiftCols}
          emptyMessage="No shifts."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Signoff Status Summary</h2>
        <DataTable
          rows={signoffs}
          columns={signoffCols}
          emptyMessage="No signoff data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Handover Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owners."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>
    </main>
  );
}
