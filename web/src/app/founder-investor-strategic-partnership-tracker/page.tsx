import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorStrategicPartnershipTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [partnershipsRes, milestonesRes, summaryRes, perInvestorRes] = await Promise.all([
    sb.rpc('list_partnerships_r1737'),
    sb.rpc('list_milestones_r1737', { p_partnership_id: null }),
    sb.rpc('partnership_value_summary_r1737'),
    sb.rpc('active_partnerships_per_investor_r1737'),
  ]);

  const partnerships: any[] = Array.isArray(partnershipsRes.data) ? partnershipsRes.data : [];
  const milestones: any[] = Array.isArray(milestonesRes.data) ? milestonesRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) && summaryRes.data.length > 0 ? summaryRes.data[0] : null;
  const perInvestor: any[] = Array.isArray(perInvestorRes.data) ? perInvestorRes.data : [];

  const fmtRupees = (n: number | null | undefined) => {
    const v = Number(n ?? 0);
    return `Rs ${v.toLocaleString('en-IN')}`;
  };
  const fmtDate = (d: string | null | undefined) => (d ? new Date(d).toLocaleDateString('en-IN') : '-');

  const partnershipCols: Column<any>[] = [
    { key: 'partner_org', header: 'Partner Org', render: (r: any) => <span>{r.partner_org ?? '-'}</span> },
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '-'}</span> },
    { key: 'partnership_type', header: 'Type', render: (r: any) => <span>{r.partnership_type ?? '-'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '-'}</span> },
    { key: 'signed_date', header: 'Signed', render: (r: any) => <span>{fmtDate(r.signed_date)}</span> },
    { key: 'partnership_value_rupees', header: 'Value', render: (r: any) => <span>{fmtRupees(r.partnership_value_rupees)}</span> },
    { key: 'terminated_at', header: 'Terminated', render: (r: any) => <span>{r.terminated_at ? new Date(r.terminated_at).toLocaleString('en-IN') : '-'}</span> },
    { key: 'created_at', header: 'Created', render: (r: any) => <span>{new Date(r.created_at).toLocaleDateString('en-IN')}</span> },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'partner_org', header: 'Partner Org', render: (r: any) => <span>{r.partner_org ?? '-'}</span> },
    { key: 'milestone_text', header: 'Milestone', render: (r: any) => <span>{r.milestone_text ?? '-'}</span> },
    { key: 'due_date', header: 'Due', render: (r: any) => <span>{fmtDate(r.due_date)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '-'}</span> },
    { key: 'hit_at', header: 'Hit At', render: (r: any) => <span>{r.hit_at ? new Date(r.hit_at).toLocaleString('en-IN') : '-'}</span> },
  ];

  const perInvestorCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '-'}</span> },
    { key: 'active_count', header: 'Active', render: (r: any) => <span>{r.active_count ?? 0}</span> },
    { key: 'total_count', header: 'Total', render: (r: any) => <span>{r.total_count ?? 0}</span> },
    { key: 'total_value_rupees', header: 'Active Value', render: (r: any) => <span>{fmtRupees(r.total_value_rupees)}</span> },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Strategic Partnership Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Round r1737. Strategic partnership deals where an investor introduced & facilitated the relationship.
        Tracks distribution, technology, customer referral, co-marketing & joint venture deals.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Portfolio Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Partnerships</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.total_partnerships ?? 0}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.active_partnerships ?? 0}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Signed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.signed_partnerships ?? 0}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Exploring</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.exploring_partnerships ?? 0}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Terminated</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.terminated_partnerships ?? 0}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Value</div>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(summary?.total_value_rupees)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active+Signed Value</div>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(summary?.active_value_rupees)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Partnerships</h2>
        <DataTable
          rows={partnerships}
          columns={partnershipCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Milestones</h2>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Partnerships per Investor</h2>
        <DataTable
          rows={perInvestor}
          columns={perInvestorCols}
          rowKey={(r: any, i: number) => String(r.investor_id ?? i)}
        />
      </section>
    </main>
  );
}
