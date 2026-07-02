import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TargetRow = {
  id: string;
  hospital_id: string;
  hospital_name: string | null;
  hospital_city: string | null;
  target_segment: string;
  abm_priority: string;
  status: string;
  last_touched_at: string | null;
  created_at: string;
};

type CriticalRow = {
  id: string;
  hospital_id: string;
  hospital_name: string | null;
  target_segment: string;
  status: string;
  last_touched_at: string | null;
  days_since_touch: number | null;
};

type RecentTouchRow = {
  id: string;
  target_id: string;
  hospital_name: string | null;
  touch_type: string;
  touched_at: string;
  by_email: string | null;
  outcome_md: string | null;
};

function fmtDate(v: string | null | undefined): string {
  if (!v) return 'never';
  try {
    return new Date(v).toLocaleString();
  } catch {
    return String(v);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [targetsRes, criticalRes, recentRes] = await Promise.all([
    sb.rpc('list_abm_targets_r1947'),
    sb.rpc('critical_abm_targets_r1947'),
    sb.rpc('recent_abm_touches_r1947'),
  ]);

  const targets: TargetRow[] = (targetsRes.data as TargetRow[] | null) ?? [];
  const critical: CriticalRow[] = (criticalRes.data as CriticalRow[] | null) ?? [];
  const recent: RecentTouchRow[] = (recentRes.data as RecentTouchRow[] | null) ?? [];

  const totalTargets = targets.length;
  const activeTargets = targets.filter((t) => !['won', 'lost', 'pause'].includes(t.status)).length;
  const wonCount = targets.filter((t) => t.status === 'won').length;
  const criticalCount = critical.length;

  const targetColumns: Column<TargetRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'hospital_city', header: 'City', render: (r: any) => r.hospital_city ?? '—' },
    { key: 'target_segment', header: 'Segment', render: (r: any) => r.target_segment },
    { key: 'abm_priority', header: 'Priority', render: (r: any) => r.abm_priority },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_touched_at', header: 'Last Touched', render: (r: any) => fmtDate(r.last_touched_at) },
    { key: 'created_at', header: 'Added', render: (r: any) => fmtDate(r.created_at) },
  ];

  const criticalColumns: Column<CriticalRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'target_segment', header: 'Segment', render: (r: any) => r.target_segment },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_touched_at', header: 'Last Touched', render: (r: any) => fmtDate(r.last_touched_at) },
    {
      key: 'days_since_touch',
      header: 'Days Since',
      render: (r: any) => (r.days_since_touch == null ? 'never' : String(r.days_since_touch)),
    },
  ];

  const recentColumns: Column<RecentTouchRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'touch_type', header: 'Type', render: (r: any) => r.touch_type },
    { key: 'touched_at', header: 'When', render: (r: any) => fmtDate(r.touched_at) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    {
      key: 'outcome_md',
      header: 'Outcome',
      render: (r: any) => {
        const v = (r.outcome_md ?? '') as string;
        return v.length > 120 ? v.slice(0, 120) + '…' : v || '—';
      },
    },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Account-Based Marketing</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Round 1947 · Track ABM activities per hospital target across segments and touch types.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pipeline summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total targets</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{totalTargets}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{activeTargets}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Won</div>
            <div style={{ fontSize: 28, fontWeight: 700, color: '#16a34a' }}>{wonCount}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Critical open</div>
            <div style={{ fontSize: 28, fontWeight: 700, color: '#dc2626' }}>{criticalCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Critical targets needing attention</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Priority equals critical and status not in won, lost, or pause. Sorted by least recently touched.
        </p>
        <DataTable
          rows={critical}
          columns={criticalColumns}
          rowKey={(r, i) => String((r as any).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All ABM targets</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Ordered by priority then last touched. Showing up to 500 rows.
        </p>
        <DataTable
          rows={targets}
          columns={targetColumns}
          rowKey={(r, i) => String((r as any).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent touches</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Latest 100 touch events across all targets.
        </p>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r, i) => String((r as any).id ?? i)}
        />
      </section>

      <footer style={{ marginTop: 32, paddingTop: 16, borderTop: '1px solid #e5e7eb', color: '#888', fontSize: 12 }}>
        Founder console · r1947 hospital ABM tracker
      </footer>
    </div>
  );
}
