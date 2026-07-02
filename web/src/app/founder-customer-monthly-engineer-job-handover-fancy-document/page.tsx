import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_docs: number;
  approved_docs: number;
  pending_docs: number;
  flagship_docs: number;
  total_amount: number;
  avg_fancy: number;
};

type DocRow = {
  document_code: string;
  customer_name: string;
  hospital_tier: string;
  cycle_month: string;
  engineer_name: string;
  jobs_completed: number;
  fancy_score: number;
  design_template: string;
  customer_impact: string;
  verdict: string;
  amount_rupees: number;
};

type TierRow = { hospital_tier: string; doc_count: number; avg_fancy: number; total_amount: number };
type TemplateRow = { design_template: string; doc_count: number; avg_fancy: number };
type BlockRow = { document_code: string; block_name: string; block_type: string; word_count: number; design_score: number; impact_rating: string; verdict: string };
type VerdictRow = { verdict: string; doc_count: number; pct: number };
type EngineerRow = { engineer_name: string; docs_count: number; avg_fancy: number; total_jobs: number };
type ImpactRow = { customer_impact: string; doc_count: number; total_amount: number };

function rupees(n: number | null | undefined): string {
  if (!n) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, docsRes, tierRes, tmplRes, blocksRes, verdictRes, engineersRes, impactRes] = await Promise.all([
    supabase.rpc('handover_doc_kpis_r2824'),
    supabase.rpc('handover_docs_list_r2824'),
    supabase.rpc('handover_by_tier_r2824'),
    supabase.rpc('handover_by_template_r2824'),
    supabase.rpc('handover_blocks_list_r2824'),
    supabase.rpc('handover_verdict_mix_r2824'),
    supabase.rpc('handover_top_engineers_r2824'),
    supabase.rpc('handover_impact_dist_r2824'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_docs: 0, approved_docs: 0, pending_docs: 0, flagship_docs: 0, total_amount: 0, avg_fancy: 0,
  }) as Kpi;
  const docs: DocRow[] = (docsRes.data ?? []) as DocRow[];
  const tiers: TierRow[] = (tierRes.data ?? []) as TierRow[];
  const templates: TemplateRow[] = (tmplRes.data ?? []) as TemplateRow[];
  const blocks: BlockRow[] = (blocksRes.data ?? []) as BlockRow[];
  const verdicts: VerdictRow[] = (verdictRes.data ?? []) as VerdictRow[];
  const engineers: EngineerRow[] = (engineersRes.data ?? []) as EngineerRow[];
  const impacts: ImpactRow[] = (impactRes.data ?? []) as ImpactRow[];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Customer Monthly Engineer Job Handover — Fancy Document Console
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Round r2824 — per-customer per-month fancy handover documents bundling jobs, design templates, impact tier and verdict. Tracks score &gt;= 75 as flagship-ready.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total documents" value={String(kpi.total_docs)} />
        <KpiCard label="Approved" value={String(kpi.approved_docs)} />
        <KpiCard label="Pending" value={String(kpi.pending_docs)} />
        <KpiCard label="Flagship docs" value={String(kpi.flagship_docs)} />
        <KpiCard label="Bundle revenue" value={rupees(kpi.total_amount)} />
        <KpiCard label="Avg fancy score" value={String(kpi.avg_fancy)} />
      </section>

      <Section title="Handover documents">
        <DataTable
          rows={docs}
          columns={[
            { key: 'document_code', header: 'Doc', render: (r: DocRow) => r.document_code },
            { key: 'customer_name', header: 'Customer', render: (r: DocRow) => r.customer_name },
            { key: 'hospital_tier', header: 'Tier', render: (r: DocRow) => r.hospital_tier },
            { key: 'cycle_month', header: 'Cycle', render: (r: DocRow) => r.cycle_month },
            { key: 'engineer_name', header: 'Engineer', render: (r: DocRow) => r.engineer_name },
            { key: 'jobs_completed', header: 'Jobs', render: (r: DocRow) => String(r.jobs_completed) },
            { key: 'fancy_score', header: 'Fancy', render: (r: DocRow) => String(r.fancy_score) },
            { key: 'design_template', header: 'Template', render: (r: DocRow) => r.design_template },
            { key: 'customer_impact', header: 'Impact', render: (r: DocRow) => r.customer_impact },
            { key: 'verdict', header: 'Verdict', render: (r: DocRow) => r.verdict },
            { key: 'amount_rupees', header: 'Amount', render: (r: DocRow) => rupees(r.amount_rupees) },
          ]}
          emptyMessage="No documents"
          rowKey={(r: DocRow, i: number) => String(r.document_code ?? i)}
        />
      </Section>

      <Section title="By hospital tier">
        <DataTable
          rows={tiers}
          columns={[
            { key: 'hospital_tier', header: 'Tier', render: (r: TierRow) => r.hospital_tier },
            { key: 'doc_count', header: 'Docs', render: (r: TierRow) => String(r.doc_count) },
            { key: 'avg_fancy', header: 'Avg fancy', render: (r: TierRow) => String(r.avg_fancy) },
            { key: 'total_amount', header: 'Revenue', render: (r: TierRow) => rupees(r.total_amount) },
          ]}
          emptyMessage="No tier rows"
          rowKey={(r: TierRow, i: number) => String(r.hospital_tier ?? i)}
        />
      </Section>

      <Section title="By design template">
        <DataTable
          rows={templates}
          columns={[
            { key: 'design_template', header: 'Template', render: (r: TemplateRow) => r.design_template },
            { key: 'doc_count', header: 'Docs', render: (r: TemplateRow) => String(r.doc_count) },
            { key: 'avg_fancy', header: 'Avg fancy', render: (r: TemplateRow) => String(r.avg_fancy) },
          ]}
          emptyMessage="No templates"
          rowKey={(r: TemplateRow, i: number) => String(r.design_template ?? i)}
        />
      </Section>

      <Section title="Content blocks">
        <DataTable
          rows={blocks}
          columns={[
            { key: 'document_code', header: 'Doc', render: (r: BlockRow) => r.document_code },
            { key: 'block_name', header: 'Block', render: (r: BlockRow) => r.block_name },
            { key: 'block_type', header: 'Type', render: (r: BlockRow) => r.block_type },
            { key: 'word_count', header: 'Words', render: (r: BlockRow) => String(r.word_count) },
            { key: 'design_score', header: 'Design', render: (r: BlockRow) => String(r.design_score) },
            { key: 'impact_rating', header: 'Impact', render: (r: BlockRow) => r.impact_rating },
            { key: 'verdict', header: 'Verdict', render: (r: BlockRow) => r.verdict },
          ]}
          emptyMessage="No blocks"
          rowKey={(r: BlockRow, i: number) => String(r.document_code + '-' + r.block_name + '-' + i)}
        />
      </Section>

      <Section title="Verdict mix">
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'doc_count', header: 'Docs', render: (r: VerdictRow) => String(r.doc_count) },
            { key: 'pct', header: 'Share %', render: (r: VerdictRow) => String(r.pct) },
          ]}
          emptyMessage="No verdicts"
          rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
        />
      </Section>

      <Section title="Top engineers">
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'docs_count', header: 'Docs', render: (r: EngineerRow) => String(r.docs_count) },
            { key: 'avg_fancy', header: 'Avg fancy', render: (r: EngineerRow) => String(r.avg_fancy) },
            { key: 'total_jobs', header: 'Total jobs', render: (r: EngineerRow) => String(r.total_jobs) },
          ]}
          emptyMessage="No engineers"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </Section>

      <Section title="Impact distribution">
        <DataTable
          rows={impacts}
          columns={[
            { key: 'customer_impact', header: 'Impact', render: (r: ImpactRow) => r.customer_impact },
            { key: 'doc_count', header: 'Docs', render: (r: ImpactRow) => String(r.doc_count) },
            { key: 'total_amount', header: 'Revenue', render: (r: ImpactRow) => rupees(r.total_amount) },
          ]}
          emptyMessage="No impact rows"
          rowKey={(r: ImpactRow, i: number) => String(r.customer_impact ?? i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 10, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
