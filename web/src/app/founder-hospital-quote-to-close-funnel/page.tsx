import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [funnelsRes, summaryRes, recentRes] = await Promise.all([
    sb.rpc('list_funnels_r2003'),
    sb.rpc('conversion_summary_r2003'),
    sb.rpc('recent_stages_r2003'),
  ]);

  const funnels: any[] = (funnelsRes.data as any[]) ?? [];
  const summary: any[] = (summaryRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const funnelCols: Column<any>[] = [
    { key: 'quote_id', header: 'Quote', render: (r: any) => String(r.quote_id ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'quote_value_rupees', header: 'Quote Rupees', render: (r: any) => Number(r.quote_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'days_to_response', header: 'Days', render: (r: any) => String(r.days_to_response ?? 0) },
    { key: 'response_status', header: 'Response', render: (r: any) => String(r.response_status ?? '') },
    { key: 'close_value_rupees', header: 'Close Rupees', render: (r: any) => Number(r.close_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
    { key: 'total_quote', header: 'Total Quote Rupees', render: (r: any) => Number(r.total_quote ?? 0).toLocaleString('en-IN') },
    { key: 'total_close', header: 'Total Close Rupees', render: (r: any) => Number(r.total_close ?? 0).toLocaleString('en-IN') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'funnel_id', header: 'Funnel', render: (r: any) => String(r.funnel_id ?? '').slice(0, 8) },
    { key: 'stage', header: 'Stage', render: (r: any) => String(r.stage ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 16 }}>Hospital Quote-to-Close Funnel</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track every hospital quote from initial response through final close. Stage log captures touchpoints
        and notes per funnel record.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Conversion Summary</h2>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Active and Closed Funnels</h2>
        <DataTable rows={funnels} columns={funnelCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Stage Activity</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
