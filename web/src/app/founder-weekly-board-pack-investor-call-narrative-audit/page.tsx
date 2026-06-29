import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_claims: number;
  locked_claims: number;
  reconciled_claims: number;
  high_risk_claims: number;
  unsupported_claims: number;
  reconciliation_pct: number | null;
  avg_variance_pct: number | null;
  upcoming_drills: number;
  unrehearsed_drills: number;
  escalation_drills: number;
};

type Redline = {
  id: string;
  section: string;
  claim_headline: string;
  narrative_risk: string;
  reconciled: boolean;
  variance_pct: number | null;
  investor_qna_likelihood: string;
  status: string;
};

type SectionRoll = {
  section: string;
  total_claims: number;
  high_risk_claims: number;
  unsupported_claims: number;
  locked_claims: number;
  reconciliation_pct: number | null;
};

type SourceRecon = {
  source_system: string;
  claims_using_source: number;
  reconciled_count: number;
  unreconciled_count: number;
  reconciliation_pct: number | null;
  avg_variance_pct: number | null;
};

type Pipeline = {
  id: string;
  investor_name: string;
  investor_fund: string;
  call_scheduled_at: string;
  hours_until_call: number;
  objection_category: string;
  weakness_self_score: number;
  rehearsed: boolean;
  escalation_required: boolean;
  status: string;
};

type Heat = {
  objection_category: string;
  drills_count: number;
  avg_weakness: number;
  unrehearsed_count: number;
  escalation_count: number;
  highest_weakness: number;
};

type Priority = {
  id: string;
  investor_name: string;
  investor_fund: string;
  call_scheduled_at: string;
  hours_until_call: number;
  objection_category: string;
  objection_text: string;
  weakness_self_score: number;
  escalation_required: boolean;
  priority_score: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    summaryRes,
    redlineRes,
    sectionRes,
    sourceRes,
    pipelineRes,
    heatRes,
    priorityRes,
  ] = await Promise.all([
    supabase.rpc('weekly_board_pack_summary_r2889'),
    supabase.rpc('narrative_audit_redline_r2889'),
    supabase.rpc('section_risk_rollup_r2889'),
    supabase.rpc('source_system_reconciliation_r2889'),
    supabase.rpc('investor_call_pipeline_r2889'),
    supabase.rpc('weakness_heatmap_r2889'),
    supabase.rpc('founder_prep_priorities_r2889'),
  ]);

  const summary: Summary | null =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0
      ? (summaryRes.data[0] as Summary)
      : null;
  const redlines: Redline[] = (redlineRes.data as Redline[]) ?? [];
  const sections: SectionRoll[] = (sectionRes.data as SectionRoll[]) ?? [];
  const sources: SourceRecon[] = (sourceRes.data as SourceRecon[]) ?? [];
  const pipeline: Pipeline[] = (pipelineRes.data as Pipeline[]) ?? [];
  const heatmap: Heat[] = (heatRes.data as Heat[]) ?? [];
  const priorities: Priority[] = (priorityRes.data as Priority[]) ?? [];

  const kpis = [
    { label: 'Total board claims', value: summary?.total_claims ?? 0 },
    { label: 'Locked', value: summary?.locked_claims ?? 0 },
    { label: 'Reconciled', value: summary?.reconciled_claims ?? 0 },
    { label: 'High-risk claims', value: summary?.high_risk_claims ?? 0 },
    { label: 'Unsupported', value: summary?.unsupported_claims ?? 0 },
    {
      label: 'Reconciliation %',
      value:
        summary?.reconciliation_pct != null
          ? `${summary.reconciliation_pct}%`
          : '—',
    },
    {
      label: 'Avg variance %',
      value:
        summary?.avg_variance_pct != null
          ? `${summary.avg_variance_pct}%`
          : '—',
    },
    { label: 'Upcoming investor calls', value: summary?.upcoming_drills ?? 0 },
    { label: 'Unrehearsed drills', value: summary?.unrehearsed_drills ?? 0 },
    { label: 'Escalation drills', value: summary?.escalation_drills ?? 0 },
  ];

  const redlineCols: Column<Redline>[] = [
    { key: 'section', header: 'Section', render: (r) => r.section },
    { key: 'claim_headline', header: 'Claim', render: (r) => r.claim_headline },
    {
      key: 'narrative_risk',
      header: 'Risk',
      render: (r) => r.narrative_risk,
    },
    {
      key: 'reconciled',
      header: 'Reconciled',
      render: (r) => (r.reconciled ? 'yes' : 'no'),
    },
    {
      key: 'variance_pct',
      header: 'Variance %',
      render: (r) => (r.variance_pct != null ? `${r.variance_pct}%` : '—'),
    },
    {
      key: 'investor_qna_likelihood',
      header: 'Q&A likelihood',
      render: (r) => r.investor_qna_likelihood,
    },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const sectionCols: Column<SectionRoll>[] = [
    { key: 'section', header: 'Section', render: (r) => r.section },
    { key: 'total_claims', header: 'Claims', render: (r) => r.total_claims },
    {
      key: 'high_risk_claims',
      header: 'High-risk',
      render: (r) => r.high_risk_claims,
    },
    {
      key: 'unsupported_claims',
      header: 'Unsupported',
      render: (r) => r.unsupported_claims,
    },
    {
      key: 'locked_claims',
      header: 'Locked',
      render: (r) => r.locked_claims,
    },
    {
      key: 'reconciliation_pct',
      header: 'Reconciled %',
      render: (r) =>
        r.reconciliation_pct != null ? `${r.reconciliation_pct}%` : '—',
    },
  ];

  const sourceCols: Column<SourceRecon>[] = [
    {
      key: 'source_system',
      header: 'Source system',
      render: (r) => r.source_system,
    },
    {
      key: 'claims_using_source',
      header: 'Claims',
      render: (r) => r.claims_using_source,
    },
    {
      key: 'reconciled_count',
      header: 'Reconciled',
      render: (r) => r.reconciled_count,
    },
    {
      key: 'unreconciled_count',
      header: 'Unreconciled',
      render: (r) => r.unreconciled_count,
    },
    {
      key: 'reconciliation_pct',
      header: 'Reconciled %',
      render: (r) =>
        r.reconciliation_pct != null ? `${r.reconciliation_pct}%` : '—',
    },
    {
      key: 'avg_variance_pct',
      header: 'Avg variance %',
      render: (r) =>
        r.avg_variance_pct != null ? `${r.avg_variance_pct}%` : '—',
    },
  ];

  const pipelineCols: Column<Pipeline>[] = [
    {
      key: 'investor_name',
      header: 'Investor',
      render: (r) => r.investor_name,
    },
    { key: 'investor_fund', header: 'Fund', render: (r) => r.investor_fund },
    {
      key: 'hours_until_call',
      header: 'Hours to call',
      render: (r) => r.hours_until_call,
    },
    {
      key: 'objection_category',
      header: 'Category',
      render: (r) => r.objection_category,
    },
    {
      key: 'weakness_self_score',
      header: 'Weakness (1-5)',
      render: (r) => r.weakness_self_score,
    },
    {
      key: 'rehearsed',
      header: 'Rehearsed',
      render: (r) => (r.rehearsed ? 'yes' : 'no'),
    },
    {
      key: 'escalation_required',
      header: 'Escalate',
      render: (r) => (r.escalation_required ? 'yes' : 'no'),
    },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const heatCols: Column<Heat>[] = [
    {
      key: 'objection_category',
      header: 'Category',
      render: (r) => r.objection_category,
    },
    {
      key: 'drills_count',
      header: 'Drills',
      render: (r) => r.drills_count,
    },
    {
      key: 'avg_weakness',
      header: 'Avg weakness',
      render: (r) => r.avg_weakness,
    },
    {
      key: 'unrehearsed_count',
      header: 'Unrehearsed',
      render: (r) => r.unrehearsed_count,
    },
    {
      key: 'escalation_count',
      header: 'Escalations',
      render: (r) => r.escalation_count,
    },
    {
      key: 'highest_weakness',
      header: 'Max weakness',
      render: (r) => r.highest_weakness,
    },
  ];

  const priorityCols: Column<Priority>[] = [
    {
      key: 'priority_score',
      header: 'Priority',
      render: (r) => r.priority_score,
    },
    {
      key: 'investor_name',
      header: 'Investor',
      render: (r) => r.investor_name,
    },
    { key: 'investor_fund', header: 'Fund', render: (r) => r.investor_fund },
    {
      key: 'hours_until_call',
      header: 'Hrs to call',
      render: (r) => r.hours_until_call,
    },
    {
      key: 'objection_category',
      header: 'Category',
      render: (r) => r.objection_category,
    },
    {
      key: 'objection_text',
      header: 'Objection',
      render: (r) => r.objection_text,
    },
    {
      key: 'weakness_self_score',
      header: 'Weakness',
      render: (r) => r.weakness_self_score,
    },
    {
      key: 'escalation_required',
      header: 'Escalate',
      render: (r) => (r.escalation_required ? 'yes' : 'no'),
    },
  ];

  return (
    <main style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, margin: 0 }}>
          Founder Weekly Board-Pack & Pre-Investor-Call Narrative Audit
        </h1>
        <p style={{ marginTop: 8, color: '#475569', maxWidth: 920 }}>
          CEO-grade readout: every claim in this week's board pack
          reconciled against source systems, every upcoming investor call
          drilled against the objection categories most likely to surface.
          Spin-risk &gt;= aggressive is flagged. Weakness self-score 4+ with
          call &lt;= 48 hours is escalation-required.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 32,
        }}
      >
        {kpis.map((k) => (
          <div
            key={k.label}
            style={{
              border: '1px solid #e2e8f0',
              borderRadius: 10,
              padding: 14,
              background: '#f8fafc',
            }}
          >
            <div style={{ fontSize: 12, color: '#64748b' }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>
              {k.value}
            </div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Narrative audit redline — claims needing rework before lock
        </h2>
        <DataTable
          rows={redlines}
          columns={redlineCols}
          emptyMessage="No redlines — board pack is clean."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Section risk rollup
        </h2>
        <DataTable
          rows={sections}
          columns={sectionCols}
          emptyMessage="No sections."
          rowKey={(r, i) => String(r.section ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Source-system reconciliation health
        </h2>
        <DataTable
          rows={sources}
          columns={sourceCols}
          emptyMessage="No sources."
          rowKey={(r, i) => String(r.source_system ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Investor call pipeline (next calls first)
        </h2>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          emptyMessage="No upcoming calls."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Objection-category weakness heatmap
        </h2>
        <DataTable
          rows={heatmap}
          columns={heatCols}
          emptyMessage="No categories."
          rowKey={(r, i) => String(r.objection_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Founder prep priorities — what to rehearse next
        </h2>
        <DataTable
          rows={priorities}
          columns={priorityCols}
          emptyMessage="Nothing queued — all prep done."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
