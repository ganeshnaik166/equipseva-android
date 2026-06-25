import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtRupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  if (v >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
  if (v >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
  return `Rs ${v.toLocaleString('en-IN')}`;
}

function fmtDate(d: string | null | undefined) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryR, stageR, categoryR, criticalR, milestonesR, blockedR, winrateR] = await Promise.all([
    supabase.rpc('founder_psp_summary_r2789'),
    supabase.rpc('founder_psp_by_stage_r2789'),
    supabase.rpc('founder_psp_by_category_r2789'),
    supabase.rpc('founder_psp_critical_r2789'),
    supabase.rpc('founder_psp_upcoming_milestones_r2789'),
    supabase.rpc('founder_psp_blocked_r2789'),
    supabase.rpc('founder_psp_winrate_r2789'),
  ]);

  const summary = (summaryR.data && summaryR.data[0]) || {
    total_partners: 0,
    active_partners: 0,
    signed_partners: 0,
    stalled_partners: 0,
    total_commit_arr_rupees: 0,
    weighted_pipeline_rupees: 0,
    business_impact_rupees: 0,
    critical_count: 0,
  };
  const stages = stageR.data ?? [];
  const categories = categoryR.data ?? [];
  const critical = criticalR.data ?? [];
  const milestones = milestonesR.data ?? [];
  const blocked = blockedR.data ?? [];
  const winrate = winrateR.data ?? [];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Quarterly Strategic Partnership Pipeline</h1>
        <p className="text-sm text-gray-600">
          Partner x stage x strategic value x terms x commit x success x business impact. Round r2789.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <Kpi label="Total partners" value={String(summary.total_partners)} />
        <Kpi label="Active in pipeline" value={String(summary.active_partners)} />
        <Kpi label="Signed / live" value={String(summary.signed_partners)} />
        <Kpi label="Stalled" value={String(summary.stalled_partners)} />
        <Kpi label="Total commit ARR" value={fmtRupees(summary.total_commit_arr_rupees)} />
        <Kpi label="Weighted pipeline" value={fmtRupees(summary.weighted_pipeline_rupees)} />
        <Kpi label="Business impact" value={fmtRupees(summary.business_impact_rupees)} />
        <Kpi label="Critical partners" value={String(summary.critical_count)} />
      </section>

      <Section title="Pipeline by stage" description="Distribution across funnel stages with weighted ARR.">
        <DataTable
          rows={stages}
          columns={[
            { key: 'stage', header: 'Stage', render: (r: any) => <span className="capitalize">{String(r.stage).replace('_', ' ')}</span> },
            { key: 'partners', header: 'Partners', render: (r: any) => r.partners },
            { key: 'commit_arr_rupees', header: 'Commit ARR', render: (r: any) => fmtRupees(r.commit_arr_rupees) },
            { key: 'weighted_arr_rupees', header: 'Weighted ARR', render: (r: any) => fmtRupees(r.weighted_arr_rupees) },
            { key: 'avg_probability_pct', header: 'Avg probability', render: (r: any) => `${r.avg_probability_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.stage ?? i)}
        />
      </Section>

      <Section title="Pipeline by partner category" description="Weighted ARR and business impact bucketed by partner type.">
        <DataTable
          rows={categories}
          columns={[
            { key: 'partner_category', header: 'Category', render: (r: any) => <span className="capitalize">{String(r.partner_category).replace('_', ' ')}</span> },
            { key: 'partners', header: 'Partners', render: (r: any) => r.partners },
            { key: 'weighted_arr_rupees', header: 'Weighted ARR', render: (r: any) => fmtRupees(r.weighted_arr_rupees) },
            { key: 'business_impact_rupees', header: 'Business impact', render: (r: any) => fmtRupees(r.business_impact_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.partner_category ?? i)}
        />
      </Section>

      <Section title="Critical & high-value partners" description="Strategic value tier critical or high, ranked by commit ARR.">
        <DataTable
          rows={critical}
          columns={[
            { key: 'partner_name', header: 'Partner', render: (r: any) => <span className="font-medium">{r.partner_name}</span> },
            { key: 'partner_category', header: 'Category', render: (r: any) => <span className="capitalize">{String(r.partner_category).replace('_', ' ')}</span> },
            { key: 'stage', header: 'Stage', render: (r: any) => <span className="capitalize">{String(r.stage).replace('_', ' ')}</span> },
            { key: 'commit_arr_rupees', header: 'Commit ARR', render: (r: any) => fmtRupees(r.commit_arr_rupees) },
            { key: 'probability_pct', header: 'Probability', render: (r: any) => `${r.probability_pct}%` },
            { key: 'expected_close_date', header: 'Expected close', render: (r: any) => fmtDate(r.expected_close_date) },
            { key: 'next_step', header: 'Next step', render: (r: any) => r.next_step ?? '—' },
            { key: 'next_step_due_date', header: 'Due', render: (r: any) => fmtDate(r.next_step_due_date) },
            { key: 'business_impact_rupees', header: 'Impact', render: (r: any) => fmtRupees(r.business_impact_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.partner_name ?? i)}
        />
      </Section>

      <Section title="Upcoming milestones" description="Scheduled and blocked milestones across the pipeline.">
        <DataTable
          rows={milestones}
          columns={[
            { key: 'partner_name', header: 'Partner', render: (r: any) => <span className="font-medium">{r.partner_name}</span> },
            { key: 'milestone_title', header: 'Milestone', render: (r: any) => r.milestone_title },
            { key: 'milestone_kind', header: 'Kind', render: (r: any) => <span className="capitalize">{String(r.milestone_kind).replace('_', ' ')}</span> },
            { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_date) },
            { key: 'days_until', header: 'Days until', render: (r: any) => r.days_until },
            { key: 'status', header: 'Status', render: (r: any) => <span className="capitalize">{r.status}</span> },
            { key: 'blocker', header: 'Blocker', render: (r: any) => r.blocker ?? '—' },
            { key: 'owner_name', header: 'Owner', render: (r: any) => r.owner_name ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(i)}
        />
      </Section>

      <Section title="Blocked & stalled" description="Partners stuck on legal, procurement, or external approvals.">
        <DataTable
          rows={blocked}
          columns={[
            { key: 'partner_name', header: 'Partner', render: (r: any) => <span className="font-medium">{r.partner_name}</span> },
            { key: 'stage', header: 'Stage', render: (r: any) => <span className="capitalize">{r.stage}</span> },
            { key: 'milestone_title', header: 'Milestone', render: (r: any) => r.milestone_title ?? '—' },
            { key: 'blocker', header: 'Blocker', render: (r: any) => r.blocker ?? '—' },
            { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_date) },
            { key: 'business_impact_rupees', header: 'Impact at risk', render: (r: any) => fmtRupees(r.business_impact_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(i)}
        />
      </Section>

      <Section title="Win rate by category" description="Signed vs lost across closed funnel stages.">
        <DataTable
          rows={winrate}
          columns={[
            { key: 'partner_category', header: 'Category', render: (r: any) => <span className="capitalize">{String(r.partner_category).replace('_', ' ')}</span> },
            { key: 'total', header: 'Total', render: (r: any) => r.total },
            { key: 'signed', header: 'Signed', render: (r: any) => r.signed },
            { key: 'lost', header: 'Lost', render: (r: any) => r.lost },
            { key: 'win_rate_pct', header: 'Win rate', render: (r: any) => `${r.win_rate_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.partner_category ?? i)}
        />
      </Section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}

function Section({ title, description, children }: { title: string; description?: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <div>
        <h2 className="text-lg font-semibold text-gray-900">{title}</h2>
        {description ? <p className="text-sm text-gray-600">{description}</p> : null}
      </div>
      <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white shadow-sm">
        {children}
      </div>
    </section>
  );
}
