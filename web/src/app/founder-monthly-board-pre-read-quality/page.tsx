import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [preReads, sections, omissions, monthlyTrend, kindBreakdown, iterations, pulse] = await Promise.all([
    supabase.rpc('list_pre_reads_r2533'),
    supabase.rpc('list_section_quality_r2533'),
    supabase.rpc('top_omission_sections_r2533'),
    supabase.rpc('monthly_quality_trend_r2533'),
    supabase.rpc('section_kind_breakdown_r2533'),
    supabase.rpc('iteration_velocity_r2533'),
    supabase.rpc('founder_pulse_summary_r2533'),
  ]);

  const preReadCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '') },
    { key: 'sections_count', header: 'Sections', render: (r: any) => String(r.sections_count ?? 0) },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => `${Number(r.clarity_score ?? 0)}/100` },
    { key: 'completeness_score', header: 'Completeness', render: (r: any) => `${Number(r.completeness_score ?? 0)}/100` },
    { key: 'founder_self_grade', header: 'Self Grade', render: (r: any) => String(r.founder_self_grade ?? '') },
    { key: 'iteration_count', header: 'Iterations', render: (r: any) => String(r.iteration_count ?? 0) },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? String(r.sent_at).slice(0, 10) : '—' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const sectionCols: Column<any>[] = [
    { key: 'section_kind', header: 'Section', render: (r: any) => String(r.section_kind ?? '') },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => `${Number(r.clarity_score ?? 0)}/100` },
    { key: 'completeness_score', header: 'Completeness', render: (r: any) => `${Number(r.completeness_score ?? 0)}/100` },
    { key: 'top_omission', header: 'Top Omission', render: (r: any) => String(r.top_omission ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
  ];

  const omissionCols: Column<any>[] = [
    { key: 'section_kind', header: 'Section', render: (r: any) => String(r.section_kind ?? '') },
    { key: 'top_omission', header: 'Top Omission', render: (r: any) => String(r.top_omission ?? '') },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => `${Number(r.clarity_score ?? 0)}/100` },
    { key: 'completeness_score', header: 'Completeness', render: (r: any) => `${Number(r.completeness_score ?? 0)}/100` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '') },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => `${Number(r.clarity_score ?? 0)}/100` },
    { key: 'completeness_score', header: 'Completeness', render: (r: any) => `${Number(r.completeness_score ?? 0)}/100` },
    { key: 'founder_self_grade', header: 'Grade', render: (r: any) => String(r.founder_self_grade ?? '') },
    { key: 'iteration_count', header: 'Iterations', render: (r: any) => String(r.iteration_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'section_kind', header: 'Section', render: (r: any) => String(r.section_kind ?? '') },
    { key: 'sections_count', header: 'Count', render: (r: any) => String(r.sections_count ?? 0) },
    { key: 'avg_clarity', header: 'Avg Clarity', render: (r: any) => `${Number(r.avg_clarity ?? 0).toFixed(2)}/100` },
    { key: 'avg_completeness', header: 'Avg Completeness', render: (r: any) => `${Number(r.avg_completeness ?? 0).toFixed(2)}/100` },
  ];

  const iterCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '') },
    { key: 'iteration_count', header: 'Iterations', render: (r: any) => String(r.iteration_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? String(r.sent_at).slice(0, 10) : '—' },
  ];

  const pulseRow = Array.isArray(pulse.data) && pulse.data.length > 0 ? pulse.data[0] : null;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>Founder Monthly Board Pre-Read Quality</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Pre-read pack > sections > clarity > completeness > board feedback > iteration.
      </p>

      {pulseRow && (
        <section style={{ background: '#f8fafc', padding: 16, borderRadius: 8, marginBottom: 24, border: '1px solid #e2e8f0' }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Founder Pulse Summary</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div><strong>Total Pre-Reads:</strong> {String(pulseRow.total_pre_reads ?? 0)}</div>
            <div><strong>Sent / Final:</strong> {String(pulseRow.sent_count ?? 0)}</div>
            <div><strong>Drafts:</strong> {String(pulseRow.draft_count ?? 0)}</div>
            <div><strong>Avg Clarity:</strong> {Number(pulseRow.avg_clarity ?? 0).toFixed(2)}/100</div>
            <div><strong>Avg Completeness:</strong> {Number(pulseRow.avg_completeness ?? 0).toFixed(2)}/100</div>
            <div><strong>Avg Iterations:</strong> {Number(pulseRow.avg_iterations ?? 0).toFixed(2)}</div>
            <div><strong>Total Sections:</strong> {String(pulseRow.total_sections ?? 0)}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pre-Reads</h2>
        <DataTable
          rows={preReads.data ?? []}
          columns={preReadCols}
          emptyMessage="No pre-reads recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Section Quality</h2>
        <DataTable
          rows={sections.data ?? []}
          columns={sectionCols}
          emptyMessage="No section quality entries"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Omission Sections</h2>
        <DataTable
          rows={omissions.data ?? []}
          columns={omissionCols}
          emptyMessage="No flagged omissions"
          rowKey={(r: any, i: number) => String(`${r.section_kind ?? ''}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Quality Trend</h2>
        <DataTable
          rows={monthlyTrend.data ?? []}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Section Kind Breakdown</h2>
        <DataTable
          rows={kindBreakdown.data ?? []}
          columns={breakdownCols}
          emptyMessage="No breakdown data"
          rowKey={(r: any, i: number) => String(r.section_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Iteration Velocity</h2>
        <DataTable
          rows={iterations.data ?? []}
          columns={iterCols}
          emptyMessage="No iteration data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </main>
  );
}
