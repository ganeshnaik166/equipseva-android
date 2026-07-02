import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Diagnostic = {
  id: string;
  engineer_user_id: string | null;
  skill_area: string | null;
  gap_severity: string | null;
  prescribed_training_md: string | null;
  status: string | null;
  captured_at: string | null;
};

type CriticalGap = {
  id: string;
  engineer_user_id: string | null;
  skill_area: string | null;
  gap_severity: string | null;
  status: string | null;
  captured_at: string | null;
};

type Resolution = {
  id: string;
  diagnostic_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [diagRes, critRes, resRes] = await Promise.all([
    sb.rpc('list_skill_gap_diagnostics_r2084'),
    sb.rpc('critical_skill_gaps_r2084'),
    sb.rpc('recent_skill_gap_resolutions_r2084'),
  ]);

  const diagnostics: Diagnostic[] = Array.isArray(diagRes.data) ? (diagRes.data as Diagnostic[]) : [];
  const critical: CriticalGap[] = Array.isArray(critRes.data) ? (critRes.data as CriticalGap[]) : [];
  const resolutions: Resolution[] = Array.isArray(resRes.data) ? (resRes.data as Resolution[]) : [];

  const diagCols: Column<Diagnostic>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'skill_area', header: 'Skill area', render: (r: any) => String(r.skill_area ?? '') },
    { key: 'gap_severity', header: 'Severity', render: (r: any) => String(r.gap_severity ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'prescribed_training_md', header: 'Prescribed training', render: (r: any) => String(r.prescribed_training_md ?? '').slice(0, 120) },
  ];

  const critCols: Column<CriticalGap>[] = [
    { key: 'gap_severity', header: 'Severity', render: (r: any) => String(r.gap_severity ?? '') },
    { key: 'skill_area', header: 'Skill area', render: (r: any) => String(r.skill_area ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const resCols: Column<Resolution>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'diagnostic_id', header: 'Diagnostic', render: (r: any) => String(r.diagnostic_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 120) },
  ];

  const totalDiag = diagnostics.length;
  const openDiag = diagnostics.filter((d) => d.status === 'open').length;
  const criticalCount = critical.length;
  const recentResCount = resolutions.length;

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Skill Gap Diagnostics</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Diagnose skill gaps across engineers. Track prescribed training, severity, and resolutions.
        Critical gaps escalate to the founder desk.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Total diagnostics</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalDiag}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Open</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{openDiag}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Critical or major</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{criticalCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Recent resolutions</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{recentResCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Critical and major gaps</h2>
        <DataTable
          rows={critical}
          columns={critCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All diagnostics</h2>
        <DataTable
          rows={diagnostics}
          columns={diagCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent resolutions</h2>
        <DataTable
          rows={resolutions}
          columns={resCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ padding: 12, border: '1px solid #eee', borderRadius: 8, color: '#555', fontSize: 13 }}>
        <strong>Notes.</strong> Severity ladder runs none, minor, moderate, major, critical. Statuses
        flow open, training assigned, closed, escalated. All writes log to founder action log.
      </section>
    </main>
  );
}
