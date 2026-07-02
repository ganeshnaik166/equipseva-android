import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorSeriesTermSheetNegotiatorPage() {
  const sb = await getSupabaseServerClient();

  const [negsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_negotiations_r1989'),
    sb.rpc('active_negotiations_r1989'),
    sb.rpc('recent_actions_r1989'),
  ]);

  const negs: any[] = Array.isArray(negsRes.data) ? negsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const negColumns: Column<any>[] = [
    { key: 'series_label', header: 'Series', render: (r: any) => String(r.series_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'current_valuation_pre_rupees', header: 'Current Pre (rupees)', render: (r: any) => Number(r.current_valuation_pre_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'target_valuation_pre_rupees', header: 'Target Pre (rupees)', render: (r: any) => Number(r.target_valuation_pre_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'current_dilution_pct', header: 'Current Dilution pct', render: (r: any) => String(r.current_dilution_pct ?? 0) },
    { key: 'target_dilution_pct', header: 'Target Dilution pct', render: (r: any) => String(r.target_dilution_pct ?? 0) },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString('en-IN') : '' },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString('en-IN') : '' },
  ];

  const activeColumns: Column<any>[] = [
    { key: 'series_label', header: 'Series', render: (r: any) => String(r.series_label ?? '') },
    { key: 'current_valuation_pre_rupees', header: 'Current Pre (rupees)', render: (r: any) => Number(r.current_valuation_pre_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'target_valuation_pre_rupees', header: 'Target Pre (rupees)', render: (r: any) => Number(r.target_valuation_pre_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'current_dilution_pct', header: 'Current Dilution pct', render: (r: any) => String(r.current_dilution_pct ?? 0) },
    { key: 'target_dilution_pct', header: 'Target Dilution pct', render: (r: any) => String(r.target_dilution_pct ?? 0) },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString('en-IN') : '' },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'negotiation_id', header: 'Negotiation', render: (r: any) => String(r.negotiation_id ?? '').slice(0, 8) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Series Term Sheet Negotiator</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track active negotiations across series term sheets and the actions taken on each.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Negotiations</h2>
        <DataTable rows={active} columns={activeColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Negotiations</h2>
        <DataTable rows={negs} columns={negColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
