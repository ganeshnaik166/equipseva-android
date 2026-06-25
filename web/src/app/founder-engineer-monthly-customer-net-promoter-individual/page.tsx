import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KPI = {
  total_responses: number;
  avg_nps: number;
  promoter_count: number;
  detractor_count: number;
  nps_value: number;
  engineers_covered: number;
};

type PerEngineer = {
  engineer_name: string;
  engineer_code: string;
  responses: number;
  avg_score: number;
  promoters: number;
  detractors: number;
  nps_value: number;
};

type Verbatim = {
  engineer_name: string;
  customer_name: string;
  customer_org: string;
  nps_score: number;
  nps_bucket: string;
  theme: string;
  verbatim_quote: string;
  response_at: string;
};

type ThemeRow = {
  theme: string;
  mentions: number;
  avg_score: number;
  negative_share: number;
};

type Detractor = {
  engineer_name: string;
  customer_name: string;
  customer_org: string;
  nps_score: number;
  theme: string;
  verbatim_quote: string;
  response_at: string;
};

type ActionRow = {
  engineer_name: string;
  action_title: string;
  action_owner: string;
  action_kind: string;
  priority: string;
  status: string;
  due_at: string;
};

type BucketRow = {
  nps_bucket: string;
  responses: number;
  share_pct: number;
};

function fmtDate(s: string) {
  if (!s) return '';
  const d = new Date(s);
  return d.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpis, perEng, verbatims, themes, detractors, actions, mix] = await Promise.all([
    supabase.rpc('engineer_customer_nps_kpis_r2682'),
    supabase.rpc('engineer_customer_nps_per_engineer_r2682'),
    supabase.rpc('engineer_customer_nps_recent_verbatims_r2682'),
    supabase.rpc('engineer_customer_nps_by_theme_r2682'),
    supabase.rpc('engineer_customer_nps_detractors_r2682'),
    supabase.rpc('engineer_customer_nps_open_actions_r2682'),
    supabase.rpc('engineer_customer_nps_bucket_mix_r2682'),
  ]);

  const k: KPI = (kpis.data?.[0] as KPI) ?? {
    total_responses: 0, avg_nps: 0, promoter_count: 0, detractor_count: 0, nps_value: 0, engineers_covered: 0,
  };
  const perEngRows: PerEngineer[] = (perEng.data as PerEngineer[]) ?? [];
  const verbatimRows: Verbatim[] = (verbatims.data as Verbatim[]) ?? [];
  const themeRows: ThemeRow[] = (themes.data as ThemeRow[]) ?? [];
  const detractorRows: Detractor[] = (detractors.data as Detractor[]) ?? [];
  const actionRows: ActionRow[] = (actions.data as ActionRow[]) ?? [];
  const bucketRows: BucketRow[] = (mix.data as BucketRow[]) ?? [];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
          Engineer Monthly Customer NPS — Individual
        </h1>
        <p style={{ color: '#555' }}>
          Per-engineer NPS with verbatim quotes, theme breakdown, detractors &amp; coaching actions. Scores range 0–10 (promoter &gt;=9, detractor &lt;=6).
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Responses" value={k.total_responses} />
        <KpiCard label="Avg NPS Score" value={k.avg_nps} />
        <KpiCard label="Net Promoter Score" value={k.nps_value} suffix="" />
        <KpiCard label="Promoters" value={k.promoter_count} />
        <KpiCard label="Detractors" value={k.detractor_count} />
        <KpiCard label="Engineers Covered" value={k.engineers_covered} />
      </section>

      <Section title="Bucket Mix (Promoter / Passive / Detractor)">
        <DataTable
          rows={bucketRows}
          columns={[
            { key: 'nps_bucket', header: 'Bucket', render: (r: BucketRow) => <strong>{r.nps_bucket}</strong> },
            { key: 'responses', header: 'Responses', render: (r: BucketRow) => <span>{r.responses}</span> },
            { key: 'share_pct', header: 'Share %', render: (r: BucketRow) => <span>{r.share_pct}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: BucketRow, i: number) => String(r.nps_bucket ?? i)}
        />
      </Section>

      <Section title="Per-Engineer Score Card">
        <DataTable
          rows={perEngRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: PerEngineer) => <strong>{r.engineer_name}</strong> },
            { key: 'engineer_code', header: 'Code', render: (r: PerEngineer) => <span>{r.engineer_code}</span> },
            { key: 'responses', header: 'Responses', render: (r: PerEngineer) => <span>{r.responses}</span> },
            { key: 'avg_score', header: 'Avg Score', render: (r: PerEngineer) => <span>{r.avg_score}</span> },
            { key: 'promoters', header: 'Promoters', render: (r: PerEngineer) => <span style={{ color: '#16a34a' }}>{r.promoters}</span> },
            { key: 'detractors', header: 'Detractors', render: (r: PerEngineer) => <span style={{ color: '#dc2626' }}>{r.detractors}</span> },
            { key: 'nps_value', header: 'NPS', render: (r: PerEngineer) => <strong>{r.nps_value}</strong> },
          ]}
          emptyMessage="No data"
          rowKey={(r: PerEngineer, i: number) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Theme Breakdown">
        <DataTable
          rows={themeRows}
          columns={[
            { key: 'theme', header: 'Theme', render: (r: ThemeRow) => <strong>{r.theme}</strong> },
            { key: 'mentions', header: 'Mentions', render: (r: ThemeRow) => <span>{r.mentions}</span> },
            { key: 'avg_score', header: 'Avg Score', render: (r: ThemeRow) => <span>{r.avg_score}</span> },
            { key: 'negative_share', header: 'Negative %', render: (r: ThemeRow) => <span>{r.negative_share}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ThemeRow, i: number) => String(r.theme ?? i)}
        />
      </Section>

      <Section title="Recent Verbatim Quotes">
        <DataTable
          rows={verbatimRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Verbatim) => <strong>{r.engineer_name}</strong> },
            { key: 'customer_name', header: 'Customer', render: (r: Verbatim) => <span>{r.customer_name}</span> },
            { key: 'customer_org', header: 'Org', render: (r: Verbatim) => <span>{r.customer_org}</span> },
            { key: 'nps_score', header: 'Score', render: (r: Verbatim) => <strong>{r.nps_score}</strong> },
            { key: 'nps_bucket', header: 'Bucket', render: (r: Verbatim) => <span>{r.nps_bucket}</span> },
            { key: 'theme', header: 'Theme', render: (r: Verbatim) => <span>{r.theme}</span> },
            { key: 'verbatim_quote', header: 'Quote', render: (r: Verbatim) => <em>“{r.verbatim_quote}”</em> },
            { key: 'response_at', header: 'When', render: (r: Verbatim) => <span>{fmtDate(r.response_at)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Verbatim, i: number) => String(i)}
        />
      </Section>

      <Section title="Detractors — Recovery Targets">
        <DataTable
          rows={detractorRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Detractor) => <strong>{r.engineer_name}</strong> },
            { key: 'customer_name', header: 'Customer', render: (r: Detractor) => <span>{r.customer_name}</span> },
            { key: 'customer_org', header: 'Org', render: (r: Detractor) => <span>{r.customer_org}</span> },
            { key: 'nps_score', header: 'Score', render: (r: Detractor) => <strong style={{ color: '#dc2626' }}>{r.nps_score}</strong> },
            { key: 'theme', header: 'Theme', render: (r: Detractor) => <span>{r.theme}</span> },
            { key: 'verbatim_quote', header: 'Quote', render: (r: Detractor) => <em>“{r.verbatim_quote}”</em> },
            { key: 'response_at', header: 'When', render: (r: Detractor) => <span>{fmtDate(r.response_at)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Detractor, i: number) => String(i)}
        />
      </Section>

      <Section title="Open Coaching / Recovery Actions">
        <DataTable
          rows={actionRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: ActionRow) => <strong>{r.engineer_name}</strong> },
            { key: 'action_title', header: 'Action', render: (r: ActionRow) => <span>{r.action_title}</span> },
            { key: 'action_owner', header: 'Owner', render: (r: ActionRow) => <span>{r.action_owner}</span> },
            { key: 'action_kind', header: 'Kind', render: (r: ActionRow) => <span>{r.action_kind}</span> },
            { key: 'priority', header: 'Priority', render: (r: ActionRow) => <strong>{r.priority.toUpperCase()}</strong> },
            { key: 'status', header: 'Status', render: (r: ActionRow) => <span>{r.status}</span> },
            { key: 'due_at', header: 'Due', render: (r: ActionRow) => <span>{fmtDate(r.due_at)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => String(i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value, suffix }: { label: string; value: number | string; suffix?: string }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>
        {value}{suffix ?? ''}
      </div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
