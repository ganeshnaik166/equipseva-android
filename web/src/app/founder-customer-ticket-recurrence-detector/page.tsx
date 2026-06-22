import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpis, topClusters, categoryBreakdown, hospitalRanking, rcaLog, patternAnalysis, rcaEffectiveness] = await Promise.all([
    sb.rpc('r2284_recurrence_kpis'),
    sb.rpc('r2284_top_clusters'),
    sb.rpc('r2284_category_breakdown'),
    sb.rpc('r2284_hospital_ranking'),
    sb.rpc('r2284_rca_log'),
    sb.rpc('r2284_pattern_analysis'),
    sb.rpc('r2284_rca_effectiveness'),
  ]);

  const kpi = (kpis.data?.[0] ?? {}) as Record<string, unknown>;

  const clusterCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'issue_signature', header: 'Issue', render: (r) => r.issue_signature },
    { key: 'issue_category', header: 'Category', render: (r) => r.issue_category },
    { key: 'ticket_count', header: 'Tickets', render: (r) => r.ticket_count },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'pattern_type', header: 'Pattern', render: (r) => r.pattern_type },
    { key: 'cluster_status', header: 'Status', render: (r) => r.cluster_status },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'cluster_count', header: 'Clusters', render: (r) => r.cluster_count },
    { key: 'total_tickets', header: 'Total Tickets', render: (r) => r.total_tickets },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'cluster_count', header: 'Clusters', render: (r) => r.cluster_count },
    { key: 'total_tickets', header: 'Total Tickets', render: (r) => r.total_tickets },
    { key: 'worst_severity', header: 'Worst Severity', render: (r) => r.worst_severity },
  ];

  const rcaCols: Column<any>[] = [
    { key: 'issue_signature', header: 'Issue', render: (r) => r.issue_signature },
    { key: 'root_cause', header: 'Root Cause', render: (r) => r.root_cause },
    { key: 'root_cause_category', header: 'RC Category', render: (r) => r.root_cause_category },
    { key: 'corrective_action', header: 'Corrective Action', render: (r) => r.corrective_action },
    { key: 'owner_email', header: 'Owner', render: (r) => r.owner_email },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const patternCols: Column<any>[] = [
    { key: 'pattern_type', header: 'Pattern Type', render: (r) => r.pattern_type },
    { key: 'occurrence_count', header: 'Occurrences', render: (r) => r.occurrence_count },
    { key: 'avg_ticket_count', header: 'Avg Tickets', render: (r) => r.avg_ticket_count },
    { key: 'high_severity_pct', header: 'High Sev %', render: (r) => `${r.high_severity_pct ?? 0}%` },
  ];

  const effCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r) => r.metric },
    { key: 'value', header: 'Value', render: (r) => r.value },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Customer Ticket Recurrence Detector
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Same hospital + same issue repeating &gt;= 3x in 30 days =&gt; product or process problem. Root-cause log tracks fixes.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        {[
          ['Total Clusters', kpi.total_clusters],
          ['Open', kpi.open_clusters],
          ['Critical', kpi.critical_clusters],
          ['RCAs Logged', kpi.rca_logged],
          ['Avg Tickets/Cluster', kpi.avg_tickets_per_cluster],
          ['Hospitals Affected', kpi.hospitals_affected],
          ['Resolved', kpi.resolved_clusters],
        ].map(([label, val]) => (
          <div key={String(label)} style={{ background: '#f6f7f9', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{String(label)}</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{String(val ?? 0)}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Recurring Clusters</h2>
        <DataTable columns={clusterCols} rows={topClusters.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Category Breakdown</h2>
        <DataTable columns={categoryCols} rows={categoryBreakdown.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Hospital Repeat-Offender Ranking</h2>
        <DataTable columns={hospitalCols} rows={hospitalRanking.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>RCA Log</h2>
        <DataTable columns={rcaCols} rows={rcaLog.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pattern Analysis</h2>
        <DataTable columns={patternCols} rows={patternAnalysis.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>RCA Effectiveness</h2>
        <DataTable columns={effCols} rows={rcaEffectiveness.data ?? []} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
