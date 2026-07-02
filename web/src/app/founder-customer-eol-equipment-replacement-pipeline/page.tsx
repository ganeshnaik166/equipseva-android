import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpiRes, summaryRes, atRiskRes, categoryRes, quoteRes, staleRes, spareRes] = await Promise.all([
    sb.rpc('eol_kpi_snapshot_r2296'),
    sb.rpc('eol_pipeline_summary_r2296'),
    sb.rpc('eol_top_at_risk_r2296', { p_limit: 25 }),
    sb.rpc('eol_category_breakdown_r2296'),
    sb.rpc('eol_quote_summary_r2296'),
    sb.rpc('eol_stale_alerts_r2296'),
    sb.rpc('eol_spare_shortage_r2296'),
  ]);

  const kpi = (kpiRes.data ?? [])[0] ?? {};
  const summary = summaryRes.data ?? [];
  const atRisk = atRiskRes.data ?? [];
  const category = categoryRes.data ?? [];
  const quotes = quoteRes.data ?? [];
  const stale = staleRes.data ?? [];
  const spare = spareRes.data ?? [];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '—' : `₹${Number(n).toLocaleString('en-IN')}`;

  const summaryCols: Column<any>[] = [
    { key: 'pipeline_stage', header: 'Stage', render: (r) => r.pipeline_stage },
    { key: 'candidate_count', header: 'Candidates', render: (r) => r.candidate_count },
    { key: 'total_replacement_value_rupees', header: 'Pipeline Value', render: (r) => fmtRupees(r.total_replacement_value_rupees) },
    { key: 'avg_past_eol_years', header: 'Avg Years Past EOL', render: (r) => r.avg_past_eol_years ?? '—' },
    { key: 'avg_risk_score', header: 'Avg Risk', render: (r) => r.avg_risk_score ?? '—' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r) => r.equipment_label },
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? '—' },
    { key: 'past_eol_years', header: 'Yrs Past EOL', render: (r) => r.past_eol_years },
    { key: 'risk_score', header: 'Risk', render: (r) => r.risk_score },
    { key: 'pipeline_stage', header: 'Stage', render: (r) => r.pipeline_stage },
    { key: 'estimated_replacement_cost_rupees', header: 'Est. Cost', render: (r) => fmtRupees(r.estimated_replacement_cost_rupees) },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'candidate_count', header: 'Candidates', render: (r) => r.candidate_count },
    { key: 'spare_parts_unavailable_count', header: 'No Spares', render: (r) => r.spare_parts_unavailable_count },
    { key: 'avg_service_calls_12mo', header: 'Avg Service Calls (12mo)', render: (r) => r.avg_service_calls_12mo ?? '—' },
    { key: 'total_repair_cost_rupees', header: 'Total Repair Cost', render: (r) => fmtRupees(r.total_repair_cost_rupees) },
  ];

  const quoteCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r) => r.equipment_label },
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? '—' },
    { key: 'quote_count', header: 'Quotes', render: (r) => r.quote_count },
    { key: 'min_quote_rupees', header: 'Min Quote', render: (r) => fmtRupees(r.min_quote_rupees) },
    { key: 'max_quote_rupees', header: 'Max Quote', render: (r) => fmtRupees(r.max_quote_rupees) },
    { key: 'accepted_quote_rupees', header: 'Accepted', render: (r) => fmtRupees(r.accepted_quote_rupees) },
  ];

  const staleCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r) => r.equipment_label },
    { key: 'pipeline_stage', header: 'Stage', render: (r) => r.pipeline_stage },
    { key: 'days_stuck', header: 'Days Stuck', render: (r) => r.days_stuck },
    { key: 'past_eol_years', header: 'Yrs Past EOL', render: (r) => r.past_eol_years },
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? '—' },
  ];

  const spareCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r) => r.equipment_label },
    { key: 'manufacturer', header: 'Maker', render: (r) => r.manufacturer ?? '—' },
    { key: 'model_number', header: 'Model', render: (r) => r.model_number ?? '—' },
    { key: 'past_eol_years', header: 'Yrs Past EOL', render: (r) => r.past_eol_years },
    { key: 'service_calls_last_12mo', header: 'Svc Calls (12mo)', render: (r) => r.service_calls_last_12mo },
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? '—' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '4px' }}>
        Customer EOL Equipment Replacement Pipeline
      </h1>
      <p style={{ color: '#666', marginBottom: '20px' }}>
        Aging equipment past supportable life — replacement quotes & decision pipeline.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '28px' }}>
        <Kpi label="Total Candidates" value={kpi.total_candidates ?? 0} />
        <Kpi label="Active" value={kpi.active_candidates ?? 0} />
        <Kpi label="Installed" value={kpi.installed_count ?? 0} />
        <Kpi label="Declined" value={kpi.declined_count ?? 0} />
        <Kpi label="Pipeline Value" value={fmtRupees(kpi.total_pipeline_value_rupees)} />
        <Kpi label="Accepted Quotes" value={fmtRupees(kpi.total_accepted_quotes_rupees)} />
        <Kpi label="Avg Yrs Past EOL" value={kpi.avg_past_eol_years ?? 0} />
        <Kpi label="High Risk (>=75)" value={kpi.high_risk_count ?? 0} />
      </section>

      <Section title="Pipeline Summary by Stage">
        <DataTable columns={summaryCols} rows={summary} rowKey={(r: any) => r.pipeline_stage} />
      </Section>

      <Section title="Top At-Risk Candidates">
        <DataTable columns={atRiskCols} rows={atRisk} rowKey={(r: any) => r.id} />
      </Section>

      <Section title="Category Breakdown">
        <DataTable columns={categoryCols} rows={category} rowKey={(r: any) => r.equipment_category} />
      </Section>

      <Section title="Quote Summary per Candidate">
        <DataTable columns={quoteCols} rows={quotes} rowKey={(r: any) => r.candidate_id} />
      </Section>

      <Section title="Stale Pipeline Alerts (> 30 days)">
        <DataTable columns={staleCols} rows={stale} rowKey={(r: any) => r.id} />
      </Section>

      <Section title="Spare Parts Shortage Flags">
        <DataTable columns={spareCols} rows={spare} rowKey={(r: any) => r.id} />
      </Section>
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: '8px', padding: '12px' }}>
      <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>{label}</div>
      <div style={{ fontSize: '18px', fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '28px' }}>
      <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>{title}</h2>
      {children}
    </section>
  );
}
