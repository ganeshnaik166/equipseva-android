import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderRiskRegisterPage() {
  const sb = await getSupabaseServerClient();

  const [topRes, allRes, recentRes] = await Promise.all([
    sb.rpc('top_risks_r1926', { p_limit: 10 }),
    sb.rpc('list_risks_r1926'),
    sb.rpc('recent_mitigations_r1926', { p_limit: 50 }),
  ]);

  const topRisks: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const allRisks: any[] = Array.isArray(allRes.data) ? allRes.data : [];
  const recentMits: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const openCount = allRisks.filter((r) => r.status === 'open').length;
  const escalatedCount = allRisks.filter((r) => r.status === 'escalated').length;
  const mitigatedCount = allRisks.filter((r) => r.status === 'mitigated').length;
  const closedCount = allRisks.filter((r) => r.status === 'closed').length;
  const totalCount = allRisks.length;

  const topRiskCols: Column<any>[] = [
    { key: 'risk_label', header: 'Risk', render: (r: any) => <span>{r.risk_label ?? '—'}</span> },
    { key: 'risk_category', header: 'Category', render: (r: any) => <span>{r.risk_category ?? '—'}</span> },
    { key: 'likelihood', header: 'Likelihood', render: (r: any) => <span>{r.likelihood ?? '—'}</span> },
    { key: 'impact', header: 'Impact', render: (r: any) => <span>{r.impact ?? '—'}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <strong>{r.score ?? '—'}</strong> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '—'}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span>{r.owner_email ?? '—'}</span> },
  ];

  const allRiskCols: Column<any>[] = [
    { key: 'risk_label', header: 'Risk', render: (r: any) => <span>{r.risk_label ?? '—'}</span> },
    { key: 'risk_category', header: 'Category', render: (r: any) => <span>{r.risk_category ?? '—'}</span> },
    { key: 'likelihood', header: 'L', render: (r: any) => <span>{r.likelihood ?? '—'}</span> },
    { key: 'impact', header: 'I', render: (r: any) => <span>{r.impact ?? '—'}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span>{r.score ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '—'}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span>{r.owner_email ?? '—'}</span> },
    { key: 'identified_at', header: 'Identified', render: (r: any) => <span>{r.identified_at ? new Date(r.identified_at).toLocaleDateString() : '—'}</span> },
    { key: 'last_reviewed_at', header: 'Reviewed', render: (r: any) => <span>{r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleDateString() : '—'}</span> },
  ];

  const mitCols: Column<any>[] = [
    { key: 'risk_label', header: 'Risk', render: (r: any) => <span>{r.risk_label ?? '—'}</span> },
    { key: 'mitigation_action_md', header: 'Mitigation Action', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{r.mitigation_action_md ?? '—'}</span> },
    { key: 'action_status', header: 'Status', render: (r: any) => <span>{r.action_status ?? '—'}</span> },
    { key: 'taken_at', header: 'Taken', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString() : '—'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '—'}</span> },
  ];

  return (
    <main style={{ maxWidth: 1200, margin: '0 auto', padding: '24px 16px' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Founder Risk Register</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Top organizational risks & mitigations — likelihood times impact = score.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Portfolio summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total risks</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Open</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{openCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Escalated</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{escalatedCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Mitigated</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{mitigatedCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Closed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{closedCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top risks (open and escalated)</h2>
        <DataTable rows={topRisks} columns={topRiskCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Full register</h2>
        <DataTable rows={allRisks} columns={allRiskCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent mitigation actions</h2>
        <DataTable rows={recentMits} columns={mitCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}