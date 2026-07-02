import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summary, log, regions, categories, engineers, verdicts, corridors, highAdoption] = await Promise.all([
    supabase.rpc('founder_transfer_summary_r2796'),
    supabase.rpc('founder_transfer_log_r2796'),
    supabase.rpc('founder_transfer_region_stats_r2796'),
    supabase.rpc('founder_transfer_by_category_r2796'),
    supabase.rpc('founder_transfer_top_engineers_r2796'),
    supabase.rpc('founder_transfer_verdicts_r2796'),
    supabase.rpc('founder_transfer_corridor_pairs_r2796'),
    supabase.rpc('founder_transfer_high_adoption_r2796'),
  ]);

  const s = (summary.data ?? [])[0] ?? { total_transfers: 0, avg_adoption: 0, total_savings: 0, scale_count: 0 };
  const rupee = (n: number) => '₹' + (n ?? 0).toLocaleString('en-IN');

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer Monthly — Engineer Cross-Region Experience Transfer
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Track which engineer insights ported across regions, how customers adopted them, and the rupee impact. Threshold &gt;= 70 marks high adoption.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <KPI label="Total Transfers" value={String(s.total_transfers ?? 0)} />
        <KPI label="Avg Adoption %" value={String(s.avg_adoption ?? 0)} />
        <KPI label="Total Savings" value={rupee(Number(s.total_savings ?? 0))} />
        <KPI label="Scale Verdicts" value={String(s.scale_count ?? 0)} />
      </div>

      <Section title="Transfer Log">
        <DataTable
          rows={log.data ?? []}
          columns={[
            { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
            { key: 'customer_name', header: 'Customer', render: (r: any) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'corridor', header: 'Corridor', render: (r: any) => `${r.source_region} → ${r.target_region}` },
            { key: 'insight_category', header: 'Category', render: (r: any) => r.insight_category },
            { key: 'insight_summary', header: 'Insight', render: (r: any) => r.insight_summary },
            { key: 'adoption_score', header: 'Adoption %', render: (r: any) => r.adoption_score },
            { key: 'cost_saving_rupees', header: 'Savings', render: (r: any) => rupee(r.cost_saving_rupees) },
            { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Region Stats">
        <DataTable
          rows={regions.data ?? []}
          columns={[
            { key: 'region_name', header: 'Region', render: (r: any) => r.region_name },
            { key: 'inbound_transfers', header: 'Inbound', render: (r: any) => r.inbound_transfers },
            { key: 'outbound_transfers', header: 'Outbound', render: (r: any) => r.outbound_transfers },
            { key: 'avg_adoption', header: 'Avg Adoption', render: (r: any) => r.avg_adoption },
            { key: 'total_savings_rupees', header: 'Savings', render: (r: any) => rupee(r.total_savings_rupees) },
            { key: 'net_verdict', header: 'Net Verdict', render: (r: any) => r.net_verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="By Category">
        <DataTable
          rows={categories.data ?? []}
          columns={[
            { key: 'category', header: 'Category', render: (r: any) => r.category },
            { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
            { key: 'avg_adoption', header: 'Avg Adoption', render: (r: any) => r.avg_adoption },
            { key: 'total_savings', header: 'Savings', render: (r: any) => rupee(Number(r.total_savings)) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.category ?? i)}
        />
      </Section>

      <Section title="Top Engineers">
        <DataTable
          rows={engineers.data ?? []}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'transfers', header: 'Transfers', render: (r: any) => r.transfers },
            { key: 'total_savings', header: 'Savings', render: (r: any) => rupee(Number(r.total_savings)) },
            { key: 'avg_adoption', header: 'Avg Adoption', render: (r: any) => r.avg_adoption },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.engineer_name ?? i)}
        />
      </Section>

      <Section title="Verdict Mix">
        <DataTable
          rows={verdicts.data ?? []}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict },
            { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
            { key: 'pct', header: 'Share %', render: (r: any) => r.pct },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.verdict ?? i)}
        />
      </Section>

      <Section title="Corridor Pairs">
        <DataTable
          rows={corridors.data ?? []}
          columns={[
            { key: 'corridor', header: 'Corridor', render: (r: any) => r.corridor },
            { key: 'transfers', header: 'Transfers', render: (r: any) => r.transfers },
            { key: 'total_savings', header: 'Savings', render: (r: any) => rupee(Number(r.total_savings)) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.corridor ?? i)}
        />
      </Section>

      <Section title="High Adoption (>= 70%)">
        <DataTable
          rows={highAdoption.data ?? []}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: any) => r.customer_name },
            { key: 'insight_summary', header: 'Insight', render: (r: any) => r.insight_summary },
            { key: 'adoption_score', header: 'Adoption %', render: (r: any) => r.adoption_score },
            { key: 'cost_saving_rupees', header: 'Savings', render: (r: any) => rupee(r.cost_saving_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>
    </div>
  );
}

function KPI({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: '#f7f7f8', border: '1px solid #e5e5e7', borderRadius: 8, padding: 16 }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 24 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </section>
  );
}