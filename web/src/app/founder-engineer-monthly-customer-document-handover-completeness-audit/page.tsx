import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MonthlyRollup = {
  audit_month: string;
  engineers_audited: number;
  avg_completeness: number;
  total_jobs: number;
  total_docs_handed: number;
  total_missing: number;
  fail_count: number;
  warning_count: number;
  pass_count: number;
  total_penalty: number;
  total_bonus: number;
};

type TierRow = {
  engineer_tier: string;
  audits: number;
  avg_completeness: number;
  avg_missing: number;
  total_penalty: number;
  total_bonus: number;
  fail_rate_pct: number;
};

type FailingRow = {
  audit_id: string;
  audit_month: string;
  engineer_id: string;
  engineer_tier: string;
  completeness_pct: number;
  missing_doc_count: number;
  rejected_doc_count: number;
  penalty_rupees: number;
  audit_status: string;
  notes: string | null;
};

type TopPerformer = {
  audit_id: string;
  audit_month: string;
  engineer_id: string;
  engineer_tier: string;
  completeness_pct: number;
  jobs_completed: number;
  bonus_rupees: number;
  notes: string | null;
};

type HeatmapRow = {
  doc_type: string;
  total_events: number;
  missing_count: number;
  rejected_count: number;
  rework_count: number;
  avg_delay_hours: number;
  critical_count: number;
  resolved_count: number;
};

type ChannelRow = {
  channel: string;
  events: number;
  ack_rate_pct: number;
  avg_delay_hours: number;
  resolved_pct: number;
};

type Kpi = {
  total_audits: number;
  avg_completeness: number;
  engineers_flagged: number;
  total_penalty_rupees: number;
  total_bonus_rupees: number;
  total_missing_docs: number;
  critical_events: number;
  unresolved_events: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [rollup, tiers, failing, top, heatmap, channels, kpis] = await Promise.all([
    supabase.rpc('fn_r2898_monthly_rollup'),
    supabase.rpc('fn_r2898_tier_breakdown'),
    supabase.rpc('fn_r2898_failing_engineers'),
    supabase.rpc('fn_r2898_top_performers'),
    supabase.rpc('fn_r2898_doc_type_heatmap'),
    supabase.rpc('fn_r2898_channel_mix'),
    supabase.rpc('fn_r2898_founder_kpis'),
  ]);

  const rollupRows = (rollup.data ?? []) as MonthlyRollup[];
  const tierRows = (tiers.data ?? []) as TierRow[];
  const failingRows = (failing.data ?? []) as FailingRow[];
  const topRows = (top.data ?? []) as TopPerformer[];
  const heatmapRows = (heatmap.data ?? []) as HeatmapRow[];
  const channelRows = (channels.data ?? []) as ChannelRow[];
  const kpi = ((kpis.data ?? [])[0] ?? null) as Kpi | null;

  const rollupCols: Column<MonthlyRollup>[] = [
    { key: 'audit_month', header: 'Month', render: (r) => String(r.audit_month).slice(0, 10) },
    { key: 'engineers_audited', header: 'Engineers', render: (r) => r.engineers_audited },
    { key: 'avg_completeness', header: 'Avg Completeness %', render: (r) => `${r.avg_completeness}%` },
    { key: 'total_jobs', header: 'Jobs', render: (r) => r.total_jobs },
    { key: 'total_docs_handed', header: 'Docs Handed', render: (r) => r.total_docs_handed },
    { key: 'total_missing', header: 'Missing', render: (r) => r.total_missing },
    { key: 'pass_count', header: 'Pass', render: (r) => r.pass_count },
    { key: 'warning_count', header: 'Warn', render: (r) => r.warning_count },
    { key: 'fail_count', header: 'Fail', render: (r) => r.fail_count },
    { key: 'total_penalty', header: 'Penalty', render: (r) => `₹${r.total_penalty}` },
    { key: 'total_bonus', header: 'Bonus', render: (r) => `₹${r.total_bonus}` },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'audits', header: 'Audits', render: (r) => r.audits },
    { key: 'avg_completeness', header: 'Avg Completeness %', render: (r) => `${r.avg_completeness}%` },
    { key: 'avg_missing', header: 'Avg Missing', render: (r) => r.avg_missing },
    { key: 'fail_rate_pct', header: 'Fail Rate %', render: (r) => `${r.fail_rate_pct}%` },
    { key: 'total_penalty', header: 'Penalty', render: (r) => `₹${r.total_penalty}` },
    { key: 'total_bonus', header: 'Bonus', render: (r) => `₹${r.total_bonus}` },
  ];

  const failingCols: Column<FailingRow>[] = [
    { key: 'audit_month', header: 'Month', render: (r) => String(r.audit_month).slice(0, 10) },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'completeness_pct', header: 'Completeness %', render: (r) => `${r.completeness_pct}%` },
    { key: 'missing_doc_count', header: 'Missing', render: (r) => r.missing_doc_count },
    { key: 'rejected_doc_count', header: 'Rejected', render: (r) => r.rejected_doc_count },
    { key: 'penalty_rupees', header: 'Penalty', render: (r) => `₹${r.penalty_rupees}` },
    { key: 'audit_status', header: 'Status', render: (r) => r.audit_status },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const topCols: Column<TopPerformer>[] = [
    { key: 'audit_month', header: 'Month', render: (r) => String(r.audit_month).slice(0, 10) },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'completeness_pct', header: 'Completeness %', render: (r) => `${r.completeness_pct}%` },
    { key: 'jobs_completed', header: 'Jobs', render: (r) => r.jobs_completed },
    { key: 'bonus_rupees', header: 'Bonus', render: (r) => `₹${r.bonus_rupees}` },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const heatmapCols: Column<HeatmapRow>[] = [
    { key: 'doc_type', header: 'Doc Type', render: (r) => r.doc_type },
    { key: 'total_events', header: 'Events', render: (r) => r.total_events },
    { key: 'missing_count', header: 'Missing', render: (r) => r.missing_count },
    { key: 'rejected_count', header: 'Rejected', render: (r) => r.rejected_count },
    { key: 'rework_count', header: 'Rework', render: (r) => r.rework_count },
    { key: 'avg_delay_hours', header: 'Avg Delay (h)', render: (r) => r.avg_delay_hours },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'resolved_count', header: 'Resolved', render: (r) => r.resolved_count },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'channel', header: 'Channel', render: (r) => r.channel },
    { key: 'events', header: 'Events', render: (r) => r.events },
    { key: 'ack_rate_pct', header: 'Ack Rate %', render: (r) => `${r.ack_rate_pct}%` },
    { key: 'avg_delay_hours', header: 'Avg Delay (h)', render: (r) => r.avg_delay_hours },
    { key: 'resolved_pct', header: 'Resolved %', render: (r) => `${r.resolved_pct}%` },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: '1.5rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>
          Engineer Monthly Customer Document Handover Completeness Audit
        </h1>
        <p style={{ color: '#666', marginTop: '0.5rem' }}>
          Founder console: monthly accountability sweep on engineer post-service document handover.
          Flags failing engineers where completeness &lt; 80%, surfaces top performers earning bonus,
          and breaks down missing docs by type &amp; channel.
        </p>
      </header>

      {kpi && (
        <section
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: '0.75rem',
            marginBottom: '2rem',
          }}
        >
          <KpiCard label="Total Audits" value={String(kpi.total_audits)} />
          <KpiCard label="Avg Completeness" value={`${kpi.avg_completeness}%`} />
          <KpiCard label="Engineers Flagged" value={String(kpi.engineers_flagged)} />
          <KpiCard label="Missing Docs" value={String(kpi.total_missing_docs)} />
          <KpiCard label="Critical Events" value={String(kpi.critical_events)} />
          <KpiCard label="Unresolved" value={String(kpi.unresolved_events)} />
          <KpiCard label="Penalty Total" value={`₹${kpi.total_penalty_rupees}`} />
          <KpiCard label="Bonus Total" value={`₹${kpi.total_bonus_rupees}`} />
        </section>
      )}

      <Section title="Monthly Rollup">
        <DataTable
          rows={rollupRows}
          columns={rollupCols}
          emptyMessage="No monthly rollup yet."
          rowKey={(r, i) => String((r as MonthlyRollup).audit_month ?? i)}
        />
      </Section>

      <Section title="Tier Breakdown">
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier data."
          rowKey={(r, i) => String((r as TierRow).engineer_tier ?? i)}
        />
      </Section>

      <Section title="Failing Engineers (Founder Flagged)">
        <DataTable
          rows={failingRows}
          columns={failingCols}
          emptyMessage="No failing engineers — clean month."
          rowKey={(r, i) => String((r as FailingRow).audit_id ?? i)}
        />
      </Section>

      <Section title="Top Performers (Bonus Earners)">
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No bonus earners this period."
          rowKey={(r, i) => String((r as TopPerformer).audit_id ?? i)}
        />
      </Section>

      <Section title="Doc-Type Missing Heatmap">
        <DataTable
          rows={heatmapRows}
          columns={heatmapCols}
          emptyMessage="No doc events recorded."
          rowKey={(r, i) => String((r as HeatmapRow).doc_type ?? i)}
        />
      </Section>

      <Section title="Dispatch Channel Mix">
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No dispatch channels logged."
          rowKey={(r, i) => String((r as ChannelRow).channel ?? i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: '0.85rem 1rem',
        background: '#fafafa',
      }}
    >
      <div style={{ fontSize: '0.75rem', color: '#666', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
        {label}
      </div>
      <div style={{ fontSize: '1.4rem', fontWeight: 700, marginTop: '0.25rem' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '2rem' }}>
      <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.6rem' }}>{title}</h2>
      {children}
    </section>
  );
}
