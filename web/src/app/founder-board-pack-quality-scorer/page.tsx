import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderBoardPackQualityScorerPage() {
  const supabase = await getSupabaseServerClient();

  const [packsRes, sectionsRes, omissionsRes, trendRes, kindRes, velocityRes, pulseRes] = await Promise.all([
    supabase.rpc('list_pack_scores_r2481'),
    supabase.rpc('list_section_quality_r2481'),
    supabase.rpc('top_omissions_r2481'),
    supabase.rpc('quarterly_quality_trend_r2481'),
    supabase.rpc('section_kind_breakdown_r2481'),
    supabase.rpc('iteration_velocity_r2481'),
    supabase.rpc('founder_pulse_summary_r2481'),
  ]);

  const packs = (packsRes.data ?? []) as any[];
  const sections = (sectionsRes.data ?? []) as any[];
  const omissions = (omissionsRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const kinds = (kindRes.data ?? []) as any[];
  const velocity = (velocityRes.data ?? []) as any[];
  const pulse = (pulseRes.data ?? []) as any[];
  const summary = pulse[0] ?? null;

  const packCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'delivery', header: 'Delivered / Planned', render: (r: any) => `${r.sections_delivered} / ${r.sections_planned}` },
    { key: 'data_freshness_pct', header: 'Freshness %', render: (r: any) => `${r.data_freshness_pct}%` },
    { key: 'narrative_quality_score', header: 'Narrative', render: (r: any) => `${r.narrative_quality_score}/100` },
    { key: 'iteration_count', header: 'Iterations', render: (r: any) => r.iteration_count },
    { key: 'founder_self_rating', header: 'Self-Rating', render: (r: any) => `${r.founder_self_rating}/10` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleDateString() : '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const sectionCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'section_kind', header: 'Section', render: (r: any) => r.section_kind },
    { key: 'data_freshness_pct', header: 'Freshness %', render: (r: any) => `${r.data_freshness_pct}%` },
    { key: 'narrative_score', header: 'Narrative', render: (r: any) => `${r.narrative_score}/100` },
    { key: 'top_omission', header: 'Top Omission', render: (r: any) => r.top_omission ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const omissionCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'section_kind', header: 'Section', render: (r: any) => r.section_kind },
    { key: 'top_omission', header: 'Omission', render: (r: any) => r.top_omission },
    { key: 'narrative_score', header: 'Narrative', render: (r: any) => `${r.narrative_score}/100` },
    { key: 'data_freshness_pct', header: 'Freshness %', render: (r: any) => `${r.data_freshness_pct}%` },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'avg_freshness', header: 'Avg Freshness', render: (r: any) => `${r.avg_freshness}%` },
    { key: 'avg_narrative', header: 'Avg Narrative', render: (r: any) => `${r.avg_narrative}/100` },
    { key: 'delivery_pct', header: 'Delivery %', render: (r: any) => `${r.delivery_pct}%` },
    { key: 'iteration_count', header: 'Iterations', render: (r: any) => r.iteration_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindCols: Column<any>[] = [
    { key: 'section_kind', header: 'Section Kind', render: (r: any) => r.section_kind },
    { key: 'section_count', header: 'Count', render: (r: any) => r.section_count },
    { key: 'avg_freshness', header: 'Avg Freshness', render: (r: any) => `${r.avg_freshness}%` },
    { key: 'avg_narrative', header: 'Avg Narrative', render: (r: any) => `${r.avg_narrative}/100` },
    { key: 'omissions_flagged', header: 'Omissions Flagged', render: (r: any) => r.omissions_flagged },
  ];

  const velocityCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'iteration_count', header: 'Iterations', render: (r: any) => r.iteration_count },
    { key: 'narrative_quality_score', header: 'Narrative', render: (r: any) => `${r.narrative_quality_score}/100` },
    { key: 'data_freshness_pct', header: 'Freshness %', render: (r: any) => `${r.data_freshness_pct}%` },
    { key: 'founder_self_rating', header: 'Self-Rating', render: (r: any) => `${r.founder_self_rating}/10` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder — Board Pack Quality Scorer</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Score every board pack on freshness & narrative quality. Hunt top omissions before investors do.
      </p>

      {summary && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Packs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.total_packs}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Sent / Final / Closed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.sent_or_final}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Avg Freshness</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.avg_freshness}%</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Avg Narrative</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.avg_narrative}/100</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Avg Iterations</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.avg_iterations}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Draft Packs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.draft_packs}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Omissions</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.total_omissions}</div>
          </div>
        </div>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Board Packs</h2>
        <DataTable
          rows={packs}
          columns={packCols}
          emptyMessage="No packs scored yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Section Quality</h2>
        <DataTable
          rows={sections}
          columns={sectionCols}
          emptyMessage="No section quality entries"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Omissions (fix these first)</h2>
        <DataTable
          rows={omissions}
          columns={omissionCols}
          emptyMessage="No flagged omissions — great work"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly Quality Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No quarterly data yet"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Section-Kind Breakdown (weakest first)</h2>
        <DataTable
          rows={kinds}
          columns={kindCols}
          emptyMessage="No section data"
          rowKey={(r: any, i: number) => String(r.section_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Iteration Velocity</h2>
        <DataTable
          rows={velocity}
          columns={velocityCols}
          emptyMessage="No iteration data"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>
    </div>
  );
}
