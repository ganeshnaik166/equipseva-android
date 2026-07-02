import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type QuarterRollup = {
  fiscal_quarter: string;
  sessions_total: number;
  sessions_attended: number;
  no_show_count: number;
  avg_satisfaction: number | null;
  founder_minutes: number;
};

type TierTopic = {
  engineer_tier: string;
  topic_category: string;
  session_count: number;
  avg_score: number | null;
};

type RegionCoverage = {
  region: string;
  attended: number;
  no_show: number;
  rescheduled: number;
  cancelled: number;
  coverage_pct: number | null;
};

type FormatRow = {
  session_format: string;
  session_count: number;
  avg_satisfaction: number | null;
  avg_action_items: number | null;
  followup_rate_pct: number | null;
};

type SeverityRow = {
  severity: string;
  total: number;
  open_count: number;
  in_remediation: number;
  resolved: number;
  affected_engineers: number;
};

type LoadRisk = {
  fiscal_quarter: string;
  founder_hours: number | null;
  sessions_with_founder: number;
  unique_engineers: number;
  load_signal: string;
};

type OpenFinding = {
  finding_code: string;
  severity: string;
  finding_area: string;
  affected_engineers_count: number;
  status: string;
  remediation_due_date: string | null;
  days_to_due: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [rollup, tierTopic, region, format, severity, load, openFindings] = await Promise.all([
    supabase.rpc('r3053_quarter_rollup'),
    supabase.rpc('r3053_tier_topic_matrix'),
    supabase.rpc('r3053_region_coverage_gap'),
    supabase.rpc('r3053_format_effectiveness'),
    supabase.rpc('r3053_findings_by_severity'),
    supabase.rpc('r3053_founder_load_risk'),
    supabase.rpc('r3053_open_findings_detail'),
  ]);

  const rollupRows = (rollup.data ?? []) as QuarterRollup[];
  const tierRows = (tierTopic.data ?? []) as TierTopic[];
  const regionRows = (region.data ?? []) as RegionCoverage[];
  const formatRows = (format.data ?? []) as FormatRow[];
  const severityRows = (severity.data ?? []) as SeverityRow[];
  const loadRows = (load.data ?? []) as LoadRisk[];
  const openRows = (openFindings.data ?? []) as OpenFinding[];

  const rollupCols: Column<QuarterRollup>[] = [
    { header: 'Quarter', cell: (r) => r.fiscal_quarter },
    { header: 'Total', cell: (r) => r.sessions_total },
    { header: 'Attended', cell: (r) => r.sessions_attended },
    { header: 'No-show', cell: (r) => r.no_show_count },
    { header: 'Avg CSAT', cell: (r) => (r.avg_satisfaction ?? '—') },
    { header: 'Founder min', cell: (r) => r.founder_minutes },
  ];

  const tierCols: Column<TierTopic>[] = [
    { header: 'Tier', cell: (r) => r.engineer_tier },
    { header: 'Topic', cell: (r) => r.topic_category },
    { header: 'Sessions', cell: (r) => r.session_count },
    { header: 'Avg score', cell: (r) => (r.avg_score ?? '—') },
  ];

  const regionCols: Column<RegionCoverage>[] = [
    { header: 'Region', cell: (r) => r.region },
    { header: 'Attended', cell: (r) => r.attended },
    { header: 'No-show', cell: (r) => r.no_show },
    { header: 'Resched.', cell: (r) => r.rescheduled },
    { header: 'Cancel', cell: (r) => r.cancelled },
    { header: 'Coverage %', cell: (r) => (r.coverage_pct ?? '—') },
  ];

  const formatCols: Column<FormatRow>[] = [
    { header: 'Format', cell: (r) => r.session_format },
    { header: 'Count', cell: (r) => r.session_count },
    { header: 'Avg CSAT', cell: (r) => (r.avg_satisfaction ?? '—') },
    { header: 'Avg action items', cell: (r) => (r.avg_action_items ?? '—') },
    { header: 'Followup %', cell: (r) => (r.followup_rate_pct ?? '—') },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Total', cell: (r) => r.total },
    { header: 'Open', cell: (r) => r.open_count },
    { header: 'In remediation', cell: (r) => r.in_remediation },
    { header: 'Resolved', cell: (r) => r.resolved },
    { header: 'Affected engineers', cell: (r) => r.affected_engineers },
  ];

  const loadCols: Column<LoadRisk>[] = [
    { header: 'Quarter', cell: (r) => r.fiscal_quarter },
    { header: 'Founder hours', cell: (r) => (r.founder_hours ?? '—') },
    { header: 'Sessions w/ founder', cell: (r) => r.sessions_with_founder },
    { header: 'Unique engineers', cell: (r) => r.unique_engineers },
    { header: 'Signal', cell: (r) => r.load_signal },
  ];

  const openCols: Column<OpenFinding>[] = [
    { header: 'Code', cell: (r) => r.finding_code },
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Area', cell: (r) => r.finding_area },
    { header: 'Affected', cell: (r) => r.affected_engineers_count },
    { header: 'Status', cell: (r) => r.status },
    { header: 'Due', cell: (r) => (r.remediation_due_date ?? '—') },
    { header: 'Days to due', cell: (r) => (r.days_to_due ?? '—') },
    { header: 'Notes', cell: (r) => (r.notes ?? '—') },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Engineer-Founder Mentor Office-Hours Audit</h1>
        <p className="text-sm text-gray-500">Founder-owned audit of mentor office-hours coverage & load (round r3053)</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter rollup</h2>
        <DataTable
          rows={rollupRows}
          columns={rollupCols}
          emptyMessage="No quarter rollup data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier × topic matrix</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier/topic data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Region coverage gap</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Format effectiveness</h2>
        <DataTable
          rows={formatRows}
          columns={formatCols}
          emptyMessage="No format data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Findings by severity</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No findings"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Founder load risk</h2>
        <DataTable
          rows={loadRows}
          columns={loadCols}
          emptyMessage="No load data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open findings detail</h2>
        <DataTable
          rows={openRows}
          columns={openCols}
          emptyMessage="No open findings"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
