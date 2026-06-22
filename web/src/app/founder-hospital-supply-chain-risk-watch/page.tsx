import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [risksRes, criticalRes, recentRes] = await Promise.all([
    sb.rpc('list_supply_risks_r1943'),
    sb.rpc('critical_open_supply_risks_r1943'),
    sb.rpc('recent_supply_risk_actions_r1943'),
  ]);

  const risks: any[] = Array.isArray(risksRes.data) ? risksRes.data : [];
  const critical: any[] = Array.isArray(criticalRes.data) ? criticalRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const fmt = (v: any) => (v ? new Date(v).toLocaleString() : '-');

  const risksCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '-') },
    { key: 'risk_label', header: 'Risk', render: (r: any) => String(r.risk_label ?? '-') },
    { key: 'risk_type', header: 'Type', render: (r: any) => String(r.risk_type ?? '-') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'identified_at', header: 'Identified', render: (r: any) => fmt(r.identified_at) },
    { key: 'last_reviewed_at', header: 'Last Reviewed', render: (r: any) => fmt(r.last_reviewed_at) },
  ];

  const criticalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '-') },
    { key: 'risk_label', header: 'Risk', render: (r: any) => String(r.risk_label ?? '-') },
    { key: 'risk_type', header: 'Type', render: (r: any) => String(r.risk_type ?? '-') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'identified_at', header: 'Identified', render: (r: any) => fmt(r.identified_at) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => fmt(r.taken_at) },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '-') },
    { key: 'risk_label', header: 'Risk', render: (r: any) => String(r.risk_label ?? '-') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '-') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => String(r.outcome_md ?? '-') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Hospital Supply Chain Risk Watch
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Round 1943 — monitor supplier failure, import delay, price volatility,
        regulatory change, and quality issue risks across hospitals. High and critical
        items are surfaced separately.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Critical & High Open Risks ({critical.length})
        </h2>
        <DataTable
          rows={critical}
          columns={criticalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          All Tracked Risks ({risks.length})
        </h2>
        <DataTable
          rows={risks}
          columns={risksCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Recent Risk Mitigation Actions ({recent.length})
        </h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginTop: 24, padding: 16, background: '#f5f5f5', borderRadius: 8 }}>
        <h3 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>RPC Surface</h3>
        <ul style={{ fontSize: 13, color: '#444', lineHeight: 1.7 }}>
          <li>list_supply_risks_r1943 — all risks sorted by severity</li>
          <li>log_supply_risk_r1943(hospital, label, type, severity)</li>
          <li>list_supply_risk_actions_r1943(risk_id)</li>
          <li>log_supply_risk_action_r1943(risk_id, action_type, outcome_md)</li>
          <li>mark_supply_risk_status_r1943(risk_id, status)</li>
          <li>critical_open_supply_risks_r1943 — severity high or critical, status open or escalated</li>
          <li>recent_supply_risk_actions_r1943 — last 50 actions across all risks</li>
        </ul>
      </section>
    </main>
  );
}
