import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [anomalies, actions, focus, kindBreakdown, autoRate, trend, hospitals] = await Promise.all([
    supabase.rpc('list_anomalies_r2604'),
    supabase.rpc('list_correction_actions_r2604'),
    supabase.rpc('top_dispute_risk_focus_r2604'),
    supabase.rpc('anomaly_kind_breakdown_r2604'),
    supabase.rpc('auto_correction_rate_r2604'),
    supabase.rpc('monthly_anomaly_trend_r2604'),
    supabase.rpc('top_impacted_hospitals_r2604'),
  ]);

  const anomalyCols: Column<any>[] = [
    { key: 'invoice_external_ref', header: 'Invoice', render: (r: any) => r.invoice_external_ref },
    { key: 'detected_at', header: 'Detected', render: (r: any) => r.detected_at ? new Date(r.detected_at).toLocaleString() : '-' },
    { key: 'anomaly_kind', header: 'Kind', render: (r: any) => r.anomaly_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'dispute_risk_kind', header: 'Dispute Risk', render: (r: any) => r.dispute_risk_kind },
    { key: 'auto_correction_applied', header: 'Auto-Corrected', render: (r: any) => r.auto_correction_applied ? 'yes' : 'no' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'invoice_external_ref', header: 'Invoice', render: (r: any) => r.invoice_external_ref ?? '-' },
    { key: 'action_at', header: 'Action At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '-' },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'invoice_external_ref', header: 'Invoice', render: (r: any) => r.invoice_external_ref },
    { key: 'anomaly_kind', header: 'Kind', render: (r: any) => r.anomaly_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'dispute_risk_kind', header: 'Dispute Risk', render: (r: any) => r.dispute_risk_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'detected_at', header: 'Detected', render: (r: any) => r.detected_at ? new Date(r.detected_at).toLocaleString() : '-' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'anomaly_kind', header: 'Kind', render: (r: any) => r.anomaly_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'auto_corrected_count', header: 'Auto-Corrected', render: (r: any) => r.auto_corrected_count },
  ];

  const autoCols: Column<any>[] = [
    { key: 'total_anomalies', header: 'Total Anomalies', render: (r: any) => r.total_anomalies },
    { key: 'auto_corrected', header: 'Auto-Corrected', render: (r: any) => r.auto_corrected },
    { key: 'auto_correction_pct', header: 'Auto-Correction %', render: (r: any) => r.auto_correction_pct },
    { key: 'manual_required', header: 'Manual Required', render: (r: any) => r.manual_required },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'auto_corrected_count', header: 'Auto-Corrected', render: (r: any) => r.auto_corrected_count },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email },
    { key: 'anomaly_count', header: 'Anomalies', render: (r: any) => r.anomaly_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'disputed_count', header: 'Disputed', render: (r: any) => r.disputed_count },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Customer Monthly Billing Anomaly Detection</h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Hospital & invoice anomalies => severity & dispute risk => auto-correction tracking. Round r2604.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Dispute-Risk Focus</h2>
        <DataTable
          rows={(focus.data ?? []) as any[]}
          columns={focusCols}
          emptyMessage="No high-risk anomalies."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Auto-Correction Rate</h2>
        <DataTable
          rows={(autoRate.data ?? []) as any[]}
          columns={autoCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Anomaly Kind Breakdown</h2>
        <DataTable
          rows={(kindBreakdown.data ?? []) as any[]}
          columns={kindCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.anomaly_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Anomaly Trend</h2>
        <DataTable
          rows={(trend.data ?? []) as any[]}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Impacted Hospitals</h2>
        <DataTable
          rows={(hospitals.data ?? []) as any[]}
          columns={hospitalCols}
          emptyMessage="No hospital impact data."
          rowKey={(r: any, i: number) => String(r.hospital_email ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All Anomalies</h2>
        <DataTable
          rows={(anomalies.data ?? []) as any[]}
          columns={anomalyCols}
          emptyMessage="No anomalies logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Correction Actions</h2>
        <DataTable
          rows={(actions.data ?? []) as any[]}
          columns={actionCols}
          emptyMessage="No correction actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
