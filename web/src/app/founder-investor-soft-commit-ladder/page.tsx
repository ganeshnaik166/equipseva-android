import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [commitsRes, changesRes, droppedRes, totalsRes, funnelRes] = await Promise.all([
    sb.rpc('list_commits_r1793'),
    sb.rpc('list_state_changes_r1793', { p_commit_id: null }),
    sb.rpc('dropped_commits_r1793'),
    sb.rpc('total_soft_committed_r1793'),
    sb.rpc('conversion_funnel_r1793'),
  ]);

  const commits: any[] = Array.isArray(commitsRes.data) ? commitsRes.data : [];
  const changes: any[] = Array.isArray(changesRes.data) ? changesRes.data : [];
  const dropped: any[] = Array.isArray(droppedRes.data) ? droppedRes.data : [];
  const totals: any = Array.isArray(totalsRes.data) && totalsRes.data.length > 0 ? totalsRes.data[0] : null;
  const funnel: any[] = Array.isArray(funnelRes.data) ? funnelRes.data : [];

  const commitsCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id ?? '-' },
    { key: 'soft_commit_amount_rupees', header: 'Amount (Rs)', render: (r: any) => Number(r.soft_commit_amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'current_state', header: 'State', render: (r: any) => String(r.current_state ?? '-') },
    { key: 'soft_commit_at', header: 'Soft Commit At', render: (r: any) => r.soft_commit_at ? new Date(r.soft_commit_at).toLocaleString() : '-' },
    { key: 'expected_hard_commit_date', header: 'Expected Hard Date', render: (r: any) => r.expected_hard_commit_date ?? '-' },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => r.last_touch_at ? new Date(r.last_touch_at).toLocaleString() : '-' },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '-' },
  ];

  const changesCols: Column<any>[] = [
    { key: 'commit_id', header: 'Commit', render: (r: any) => String(r.commit_id ?? '-').slice(0, 8) },
    { key: 'from_state', header: 'From', render: (r: any) => r.from_state ?? '-' },
    { key: 'to_state', header: 'To', render: (r: any) => r.to_state ?? '-' },
    { key: 'change_at', header: 'Changed At', render: (r: any) => r.change_at ? new Date(r.change_at).toLocaleString() : '-' },
    { key: 'change_note', header: 'Note', render: (r: any) => r.change_note ?? '-' },
  ];

  const droppedCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id ?? '-' },
    { key: 'soft_commit_amount_rupees', header: 'Amount (Rs)', render: (r: any) => Number(r.soft_commit_amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'soft_commit_at', header: 'Soft Commit At', render: (r: any) => r.soft_commit_at ? new Date(r.soft_commit_at).toLocaleString() : '-' },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => r.last_touch_at ? new Date(r.last_touch_at).toLocaleString() : '-' },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'state', header: 'State', render: (r: any) => String(r.state ?? '-') },
    { key: 'commit_count', header: 'Count', render: (r: any) => Number(r.commit_count ?? 0).toLocaleString('en-IN') },
    { key: 'total_rupees', header: 'Total (Rs)', render: (r: any) => Number(r.total_rupees ?? 0).toLocaleString('en-IN') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Soft Commit Ladder</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track investor soft commitments and movement toward firm close (r1793).
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Totals</h2>
        {totals ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Soft pipeline (Rs)</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{Number(totals.total_soft_rupees ?? 0).toLocaleString('en-IN')}</div>
              <div style={{ fontSize: 12, color: '#666' }}>{Number(totals.active_count ?? 0)} active</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Firm (Rs)</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{Number(totals.total_firm_rupees ?? 0).toLocaleString('en-IN')}</div>
              <div style={{ fontSize: 12, color: '#666' }}>{Number(totals.firm_count ?? 0)} firm</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Dropped (Rs)</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{Number(totals.total_dropped_rupees ?? 0).toLocaleString('en-IN')}</div>
              <div style={{ fontSize: 12, color: '#666' }}>{Number(totals.dropped_count ?? 0)} dropped</div>
            </div>
          </div>
        ) : (
          <div style={{ color: '#888' }}>No totals available.</div>
        )}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Conversion Funnel</h2>
        <DataTable rows={funnel} columns={funnelCols} rowKey={(r: any, i: number) => String(r.state ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Commits</h2>
        <DataTable rows={commits} columns={commitsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>State Changes</h2>
        <DataTable rows={changes} columns={changesCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Dropped Commits</h2>
        <DataTable rows={dropped} columns={droppedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
