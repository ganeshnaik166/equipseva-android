import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderDecisionCycleTimePage() {
  const sb = await getSupabaseServerClient();

  const [decisionsRes, fastRes, recentRes] = await Promise.all([
    sb.rpc('list_decisions_r1990'),
    sb.rpc('fast_decisions_r1990'),
    sb.rpc('recent_phases_r1990'),
  ]);

  const decisions: any[] = Array.isArray(decisionsRes.data) ? decisionsRes.data : [];
  const fast: any[] = Array.isArray(fastRes.data) ? fastRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const decisionCols: Column<any>[] = [
    { key: 'decision_label', header: 'Decision', render: (r: any) => String(r.decision_label ?? '') },
    { key: 'decision_type', header: 'Type', render: (r: any) => String(r.decision_type ?? '') },
    { key: 'urgency', header: 'Urgency', render: (r: any) => String(r.urgency ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleString() : '' },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleString() : '-' },
    { key: 'cycle_time_hours', header: 'Cycle hours', render: (r: any) => r.cycle_time_hours == null ? '-' : String(r.cycle_time_hours) },
  ];

  const fastCols: Column<any>[] = [
    { key: 'decision_label', header: 'Decision', render: (r: any) => String(r.decision_label ?? '') },
    { key: 'decision_type', header: 'Type', render: (r: any) => String(r.decision_type ?? '') },
    { key: 'urgency', header: 'Urgency', render: (r: any) => String(r.urgency ?? '') },
    { key: 'cycle_time_hours', header: 'Hours to decide', render: (r: any) => String(r.cycle_time_hours ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'decision_label', header: 'Decision', render: (r: any) => String(r.decision_label ?? '') },
    { key: 'phase', header: 'Phase', render: (r: any) => String(r.phase ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  const openCount = decisions.filter((d) => d.status === 'opened').length;
  const decidedCount = decisions.filter((d) => d.status === 'decided').length;
  const avgHours = decidedCount === 0
    ? 0
    : Math.round(
        decisions
          .filter((d) => d.status === 'decided' && d.cycle_time_hours != null)
          .reduce((acc, d) => acc + Number(d.cycle_time_hours || 0), 0) / decidedCount
      );

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Decision Cycle Time</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track time to decide on major decisions and log each phase from identified through communicated.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 20 }}>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Open decisions</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{openCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Decided</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{decidedCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Avg cycle hours</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{avgHours}</div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All decisions</h2>
        <DataTable rows={decisions} columns={decisionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Fastest decisions</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Decided items sorted by hours to decide, ascending.</p>
        <DataTable rows={fast} columns={fastCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent phase activity</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Latest phase entries across all decisions.</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
