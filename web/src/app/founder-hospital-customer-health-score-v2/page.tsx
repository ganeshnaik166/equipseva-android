import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [healthsRes, criticalRes, recentRes] = await Promise.all([
    sb.rpc('list_healths_r1983'),
    sb.rpc('critical_accounts_r1983'),
    sb.rpc('recent_actions_r1983'),
  ]);

  const healths: any[] = Array.isArray(healthsRes.data) ? healthsRes.data : [];
  const critical: any[] = Array.isArray(criticalRes.data) ? criticalRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const healthCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'health_score', header: 'Score', render: (r: any) => String(r.health_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'last_reviewed_at', header: 'Reviewed', render: (r: any) => r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleString() : '' },
    { key: 'factors_md', header: 'Factors', render: (r: any) => String(r.factors_md ?? '') },
  ];

  const criticalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'health_score', header: 'Score', render: (r: any) => String(r.health_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => String(r.outcome_md ?? '') },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Customer Health Score v2</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Multi-factor customer health snapshots per hospital and action log for retention plays.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical and poor accounts</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Accounts with status critical or poor, sorted by score ascending. Act on these first.
        </p>
        <DataTable
          rows={critical}
          columns={criticalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All health snapshots</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Latest 200 snapshots across all hospitals. Statuses: excellent, good, fair, poor and critical.
        </p>
        <DataTable
          rows={healths}
          columns={healthCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent retention actions</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Latest 100 logged actions: escalation calls, customer reviews, save offers, upsell offers and account recovery.
        </p>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
