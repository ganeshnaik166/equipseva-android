import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SectionStatusRow = { section_status: string; sections: number; total_words: number; avg_citations: number };
type PillarRow = { esg_pillar: string; sections: number; total_co2: number; avg_social_score: number; avg_governance_score: number };
type OpenFindingsRow = { severity: string; open_count: number; p0_p1_share: number };
type GreenwashingRow = { section_name: string; finding_summary: string; severity: string; status: string; confidence_score: number };
type FrameworkRow = { framework: string; findings_referencing: number; open_count: number; resolved_count: number };
type ReadinessRow = { section_name: string; section_status: string; fact_check_status: string; blocking_findings: number; ready: boolean };
type MoMRow = { letter_period: string; total_sections: number; published: number; total_findings: number; p0_p1_findings: number; resolved_findings: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [statusRes, pillarRes, openRes, greenRes, fwRes, readyRes, momRes] = await Promise.all([
    supabase.rpc('r2917_section_status_summary'),
    supabase.rpc('r2917_pillar_metric_rollup'),
    supabase.rpc('r2917_open_findings_by_severity'),
    supabase.rpc('r2917_greenwashing_radar'),
    supabase.rpc('r2917_framework_alignment_coverage'),
    supabase.rpc('r2917_send_readiness_checklist'),
    supabase.rpc('r2917_month_over_month_progress'),
  ]);

  const statusRows: SectionStatusRow[] = (statusRes.data as SectionStatusRow[]) ?? [];
  const pillarRows: PillarRow[] = (pillarRes.data as PillarRow[]) ?? [];
  const openRows: OpenFindingsRow[] = (openRes.data as OpenFindingsRow[]) ?? [];
  const greenRows: GreenwashingRow[] = (greenRes.data as GreenwashingRow[]) ?? [];
  const fwRows: FrameworkRow[] = (fwRes.data as FrameworkRow[]) ?? [];
  const readyRows: ReadinessRow[] = (readyRes.data as ReadinessRow[]) ?? [];
  const momRows: MoMRow[] = (momRes.data as MoMRow[]) ?? [];

  const totalSections = statusRows.reduce((s, r) => s + (r.sections ?? 0), 0);
  const approvedSections = statusRows.filter(r => r.section_status === 'approved' || r.section_status === 'published').reduce((s, r) => s + r.sections, 0);
  const totalOpenP0P1 = openRows.filter(r => r.severity === 'p0' || r.severity === 'p1').reduce((s, r) => s + r.open_count, 0);
  const readySections = readyRows.filter(r => r.ready).length;

  const statusCols: Column<SectionStatusRow>[] = [
    { key: 'section_status', header: 'Status', render: (r) => r.section_status },
    { key: 'sections', header: 'Sections', render: (r) => r.sections },
    { key: 'total_words', header: 'Total Words', render: (r) => r.total_words },
    { key: 'avg_citations', header: 'Avg Citations', render: (r) => r.avg_citations },
  ];

  const pillarCols: Column<PillarRow>[] = [
    { key: 'esg_pillar', header: 'Pillar', render: (r) => r.esg_pillar },
    { key: 'sections', header: 'Sections', render: (r) => r.sections },
    { key: 'total_co2', header: 'Total tCO2', render: (r) => r.total_co2 },
    { key: 'avg_social_score', header: 'Avg Social Score', render: (r) => r.avg_social_score ?? '—' },
    { key: 'avg_governance_score', header: 'Avg Gov Score', render: (r) => r.avg_governance_score ?? '—' },
  ];

  const openCols: Column<OpenFindingsRow>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity.toUpperCase() },
    { key: 'open_count', header: 'Open Count', render: (r) => r.open_count },
    { key: 'p0_p1_share', header: 'P0/P1 Share %', render: (r) => r.p0_p1_share ?? 0 },
  ];

  const greenCols: Column<GreenwashingRow>[] = [
    { key: 'section_name', header: 'Section', render: (r) => r.section_name },
    { key: 'finding_summary', header: 'Finding', render: (r) => r.finding_summary },
    { key: 'severity', header: 'Severity', render: (r) => r.severity.toUpperCase() },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'confidence_score', header: 'Confidence', render: (r) => r.confidence_score },
  ];

  const fwCols: Column<FrameworkRow>[] = [
    { key: 'framework', header: 'Framework', render: (r) => r.framework },
    { key: 'findings_referencing', header: 'Findings', render: (r) => r.findings_referencing },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
    { key: 'resolved_count', header: 'Resolved', render: (r) => r.resolved_count },
  ];

  const readyCols: Column<ReadinessRow>[] = [
    { key: 'section_name', header: 'Section', render: (r) => r.section_name },
    { key: 'section_status', header: 'Draft Status', render: (r) => r.section_status },
    { key: 'fact_check_status', header: 'Fact-Check', render: (r) => r.fact_check_status },
    { key: 'blocking_findings', header: 'P0/P1 Blockers', render: (r) => r.blocking_findings },
    { key: 'ready', header: 'Send-Ready', render: (r) => (r.ready ? 'YES' : 'NO') },
  ];

  const momCols: Column<MoMRow>[] = [
    { key: 'letter_period', header: 'Period', render: (r) => r.letter_period },
    { key: 'total_sections', header: 'Sections', render: (r) => r.total_sections },
    { key: 'published', header: 'Published', render: (r) => r.published },
    { key: 'total_findings', header: 'Findings', render: (r) => r.total_findings },
    { key: 'p0_p1_findings', header: 'P0/P1', render: (r) => r.p0_p1_findings },
    { key: 'resolved_findings', header: 'Resolved', render: (r) => r.resolved_findings },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold">Monthly Strategic ESG & Sustainability Investor Letter Audit</h1>
        <p className="text-gray-600">
          Founder-only QA console for the monthly investor ESG letter — drafts, pillar metrics,
          greenwashing radar, framework alignment (TCFD / SASB / GRI / GHG Protocol), and send-readiness.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-2xl border p-4 bg-white shadow-sm">
          <div className="text-xs uppercase text-gray-500">Sections (Jun)</div>
          <div className="text-3xl font-semibold mt-1">{totalSections}</div>
        </div>
        <div className="rounded-2xl border p-4 bg-white shadow-sm">
          <div className="text-xs uppercase text-gray-500">Approved / Published</div>
          <div className="text-3xl font-semibold mt-1">{approvedSections}</div>
        </div>
        <div className="rounded-2xl border p-4 bg-white shadow-sm">
          <div className="text-xs uppercase text-gray-500">Open P0/P1 Findings</div>
          <div className="text-3xl font-semibold mt-1">{totalOpenP0P1}</div>
        </div>
        <div className="rounded-2xl border p-4 bg-white shadow-sm">
          <div className="text-xs uppercase text-gray-500">Send-Ready Sections</div>
          <div className="text-3xl font-semibold mt-1">{readySections}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Section Status Summary</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No drafts in scope."
          rowKey={(r, i) => String((r as SectionStatusRow).section_status ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">ESG Pillar Metric Rollup</h2>
        <DataTable
          rows={pillarRows}
          columns={pillarCols}
          emptyMessage="No pillar data yet."
          rowKey={(r, i) => String((r as PillarRow).esg_pillar ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Open Findings by Severity</h2>
        <DataTable
          rows={openRows}
          columns={openCols}
          emptyMessage="No open findings — clean letter."
          rowKey={(r, i) => String((r as OpenFindingsRow).severity ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Greenwashing Radar</h2>
        <p className="text-sm text-gray-500">Unsupported environmental claims flagged for restatement.</p>
        <DataTable
          rows={greenRows}
          columns={greenCols}
          emptyMessage="No greenwashing flags."
          rowKey={(r, i) => String((r as GreenwashingRow).section_name ?? i) + '-' + i}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Framework Alignment Coverage</h2>
        <DataTable
          rows={fwRows}
          columns={fwCols}
          emptyMessage="No framework references."
          rowKey={(r, i) => String((r as FrameworkRow).framework ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Send-Readiness Checklist</h2>
        <p className="text-sm text-gray-500">Section is ready when status is approved/published, fact-check verified, and zero P0/P1 blockers remain.</p>
        <DataTable
          rows={readyRows}
          columns={readyCols}
          emptyMessage="No sections."
          rowKey={(r, i) => String((r as ReadinessRow).section_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Month-over-Month Progress</h2>
        <DataTable
          rows={momRows}
          columns={momCols}
          emptyMessage="No historical periods."
          rowKey={(r, i) => String((r as MoMRow).letter_period ?? i)}
        />
      </section>
    </div>
  );
}
