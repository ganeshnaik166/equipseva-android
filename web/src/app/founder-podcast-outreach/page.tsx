import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return '0';
  return v.toLocaleString('en-IN');
}

function fmtRupees(n: any): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return 'Rs ' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return 'Rs ' + (v / 100000).toFixed(2) + ' L';
  return 'Rs ' + v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  const v = Number(n ?? 0);
  return v.toFixed(1) + '%';
}

function fmtDate(s: any): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleDateString('en-IN');
  } catch {
    return String(s);
  }
}

export default async function FounderPodcastOutreachPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = {};
  let targets: any[] = [];
  let topFit: any[] = [];
  let recorded: any[] = [];
  let roiBreakdown: any[] = [];

  try {
    const r = await sb.rpc('founder_podcast_pipeline_summary');
    summary = (r.data && r.data[0]) ?? {};
  } catch {
    summary = {};
  }
  try {
    const r = await sb.rpc('founder_podcast_target_list', { p_status: null });
    targets = r.data ?? [];
  } catch {
    targets = [];
  }
  try {
    const r = await sb.rpc('founder_podcast_top_fit', { p_limit: 20 });
    topFit = r.data ?? [];
  } catch {
    topFit = [];
  }
  try {
    const r = await sb.rpc('founder_podcast_recorded_list');
    recorded = r.data ?? [];
  } catch {
    recorded = [];
  }
  try {
    const r = await sb.rpc('founder_podcast_roi_breakdown');
    roiBreakdown = r.data ?? [];
  } catch {
    roiBreakdown = [];
  }

  const kpis: Kpi[] = [
    { label: 'Total Targets', value: fmtInt(summary.total_targets) },
    { label: 'Identified', value: fmtInt(summary.identified) },
    { label: 'Pitched', value: fmtInt(summary.pitched) },
    { label: 'Responded', value: fmtInt(summary.responded) },
    { label: 'Scheduled', value: fmtInt(summary.scheduled) },
    { label: 'Recorded', value: fmtInt(summary.recorded) },
    { label: 'Published', value: fmtInt(summary.published) },
    { label: 'Rejected', value: fmtInt(summary.rejected) },
    { label: 'Ghosted', value: fmtInt(summary.ghosted) },
    { label: 'Avg Fit Score', value: String(summary.avg_fit_score ?? '0') },
    { label: 'Total Audience', value: fmtInt(summary.total_audience) },
    { label: 'Recorded Audience', value: fmtInt(summary.recorded_audience) },
    { label: 'Response Rate', value: fmtPct(summary.response_rate_pct) },
    { label: 'Recorded Rate', value: fmtPct(summary.recorded_rate_pct) },
    { label: 'Pipeline Value', value: fmtRupees(summary.pipeline_value_rupees) },
    { label: 'Closed Revenue', value: fmtRupees(summary.closed_revenue_rupees) },
  ];

  const targetCols: Column<any>[] = [
    { key: 'podcast_name', header: 'Podcast', render: (r: any) => r.podcast_name ?? '-' },
    { key: 'host_name', header: 'Host', render: (r: any) => r.host_name ?? '-' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '-' },
    { key: 'audience', header: 'Audience', render: (r: any) => fmtInt(r.audience_size_estimate) },
    { key: 'match', header: 'Match', render: (r: any) => fmtPct(r.audience_match_pct) },
    { key: 'fit', header: 'Fit', render: (r: any) => String(r.fit_score ?? '0') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'days', header: 'Days In Stage', render: (r: any) => String(r.days_in_stage ?? '0') },
  ];

  const topFitCols: Column<any>[] = [
    { key: 'podcast_name', header: 'Podcast', render: (r: any) => r.podcast_name ?? '-' },
    { key: 'host_name', header: 'Host', render: (r: any) => r.host_name ?? '-' },
    { key: 'fit_score', header: 'Fit Score', render: (r: any) => String(r.fit_score ?? '0') },
    { key: 'audience', header: 'Audience', render: (r: any) => fmtInt(r.audience_size_estimate) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'contact', header: 'Contact', render: (r: any) => r.contact_email ?? '-' },
  ];

  const recordedCols: Column<any>[] = [
    { key: 'podcast_name', header: 'Podcast', render: (r: any) => r.podcast_name ?? '-' },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
    { key: 'published_at', header: 'Published', render: (r: any) => fmtDate(r.published_at) },
    { key: 'audience', header: 'Audience', render: (r: any) => fmtInt(r.audience_size_estimate) },
    { key: 'signups', header: 'Signups', render: (r: any) => fmtInt(r.signups_attributed) },
    { key: 'closed', header: 'Closed Rev', render: (r: any) => fmtRupees(r.closed_revenue_rupees) },
    { key: 'roi', header: 'ROI Ratio', render: (r: any) => String(r.roi_ratio ?? '0') },
  ];

  const roiCols: Column<any>[] = [
    { key: 'podcast_name', header: 'Podcast', render: (r: any) => r.podcast_name ?? '-' },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
    { key: 'signups', header: 'Signups', render: (r: any) => fmtInt(r.signups) },
    { key: 'hospital_leads', header: 'Hospital Leads', render: (r: any) => fmtInt(r.hospital_leads) },
    { key: 'inbound', header: 'Inbound Msgs', render: (r: any) => fmtInt(r.inbound) },
    { key: 'pipeline', header: 'Pipeline', render: (r: any) => fmtRupees(r.pipeline_rupees) },
    { key: 'closed', header: 'Closed', render: (r: any) => fmtRupees(r.closed_rupees) },
    { key: 'cps', header: 'Cost / Signup', render: (r: any) => fmtRupees(r.cost_per_signup) },
    { key: 'brand', header: 'Brand Lift', render: (r: any) => String(r.brand_lift ?? '0') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Founder Podcast Outreach</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Target list of podcasts to pitch the founder for. Fit score, contact, outreach status, recorded date, ROI per appearance. (r1528)
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All Targets</h2>
        <DataTable columns={targetCols} rows={targets} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Fit (Open Pipeline)</h2>
        <DataTable columns={topFitCols} rows={topFit} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recorded Appearances</h2>
        <DataTable columns={recordedCols} rows={recorded} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>ROI Breakdown</h2>
        <DataTable columns={roiCols} rows={roiBreakdown} rowKey={(r: any) => r.podcast_id} />
      </section>
    </div>
  );
}
