import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    requestsRes,
    logRes,
    topRoiRes,
    funnelRes,
    kindRes,
    trendRes,
    hospitalsRes,
  ] = await Promise.all([
    supabase.rpc('list_requests_r2456'),
    supabase.rpc('list_scoring_log_r2456'),
    supabase.rpc('top_roi_requests_r2456'),
    supabase.rpc('status_funnel_r2456'),
    supabase.rpc('kind_breakdown_r2456'),
    supabase.rpc('weekly_submission_trend_r2456'),
    supabase.rpc('top_hospitals_by_requests_r2456'),
  ]);

  const requests = (requestsRes.data ?? []) as any[];
  const log = (logRes.data ?? []) as any[];
  const topRoi = (topRoiRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const kind = (kindRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const hospitals = (hospitalsRes.data ?? []) as any[];

  const fmtMoney = (n: any) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');
  const fmtDate = (s: any) =>
    s ? new Date(s).toLocaleDateString('en-IN') : '-';
  const fmtDateTime = (s: any) =>
    s ? new Date(s).toLocaleString('en-IN') : '-';

  const requestCols: Column<any>[] = [
    { key: 'priority_rank', header: 'Rank', render: (r: any) => <span>#{r.priority_rank}</span> },
    { key: 'request_title', header: 'Title', render: (r: any) => <span>{r.request_title}</span> },
    { key: 'request_kind', header: 'Kind', render: (r: any) => <span>{r.request_kind}</span> },
    { key: 'frequency_score', header: 'Freq', render: (r: any) => <span>{r.frequency_score}</span> },
    { key: 'revenue_impact_estimate_rupees', header: 'Revenue Impact', render: (r: any) => <span>{fmtMoney(r.revenue_impact_estimate_rupees)}</span> },
    { key: 'engineering_cost_estimate_rupees', header: 'Eng Cost', render: (r: any) => <span>{fmtMoney(r.engineering_cost_estimate_rupees)}</span> },
    { key: 'roi_score', header: 'ROI', render: (r: any) => <span>{Number(r.roi_score).toFixed(2)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => <span>{fmtDate(r.submitted_at)}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span>{r.owner_email ?? '-'}</span> },
  ];

  const logCols: Column<any>[] = [
    { key: 'scored_at', header: 'Scored At', render: (r: any) => <span>{fmtDateTime(r.scored_at)}</span> },
    { key: 'request_title', header: 'Request', render: (r: any) => <span>{r.request_title ?? '-'}</span> },
    { key: 'scored_by_email', header: 'Scorer', render: (r: any) => <span>{r.scored_by_email}</span> },
    { key: 'frequency_score_delta', header: 'Δ Freq', render: (r: any) => <span>{r.frequency_score_delta}</span> },
    { key: 'revenue_score_delta', header: 'Δ Revenue', render: (r: any) => <span>{r.revenue_score_delta}</span> },
    { key: 'cost_score_delta', header: 'Δ Cost', render: (r: any) => <span>{r.cost_score_delta}</span> },
    { key: 'final_roi', header: 'Final ROI', render: (r: any) => <span>{Number(r.final_roi).toFixed(2)}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span>{r.notes ?? '-'}</span> },
  ];

  const topRoiCols: Column<any>[] = [
    { key: 'request_title', header: 'Title', render: (r: any) => <span>{r.request_title}</span> },
    { key: 'request_kind', header: 'Kind', render: (r: any) => <span>{r.request_kind}</span> },
    { key: 'roi_score', header: 'ROI', render: (r: any) => <span>{Number(r.roi_score).toFixed(2)}</span> },
    { key: 'revenue_impact_estimate_rupees', header: 'Revenue', render: (r: any) => <span>{fmtMoney(r.revenue_impact_estimate_rupees)}</span> },
    { key: 'engineering_cost_estimate_rupees', header: 'Cost', render: (r: any) => <span>{fmtMoney(r.engineering_cost_estimate_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'request_count', header: 'Count', render: (r: any) => <span>{r.request_count}</span> },
    { key: 'total_revenue_impact_rupees', header: 'Total Revenue Impact', render: (r: any) => <span>{fmtMoney(r.total_revenue_impact_rupees)}</span> },
    { key: 'total_eng_cost_rupees', header: 'Total Eng Cost', render: (r: any) => <span>{fmtMoney(r.total_eng_cost_rupees)}</span> },
  ];

  const kindCols: Column<any>[] = [
    { key: 'request_kind', header: 'Kind', render: (r: any) => <span>{r.request_kind}</span> },
    { key: 'request_count', header: 'Count', render: (r: any) => <span>{r.request_count}</span> },
    { key: 'avg_roi', header: 'Avg ROI', render: (r: any) => <span>{Number(r.avg_roi).toFixed(2)}</span> },
    { key: 'total_revenue_impact_rupees', header: 'Total Revenue', render: (r: any) => <span>{fmtMoney(r.total_revenue_impact_rupees)}</span> },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => <span>{fmtDate(r.week_start)}</span> },
    { key: 'submissions', header: 'Submissions', render: (r: any) => <span>{r.submissions}</span> },
    { key: 'shipped_in_week', header: 'Shipped', render: (r: any) => <span>{r.shipped_in_week}</span> },
  ];

  const hospitalsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span>{r.hospital_email}</span> },
    { key: 'request_count', header: 'Requests', render: (r: any) => <span>{r.request_count}</span> },
    { key: 'avg_frequency', header: 'Avg Freq', render: (r: any) => <span>{Number(r.avg_frequency ?? 0).toFixed(1)}</span> },
    { key: 'total_revenue_impact_rupees', header: 'Total Revenue Impact', render: (r: any) => <span>{fmtMoney(r.total_revenue_impact_rupees)}</span> },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Customer Feature Request ROI Scorer
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Request × frequency × revenue impact × engineering cost × ROI => prioritization rank.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top ROI (active)</h2>
        <DataTable
          rows={topRoi}
          columns={topRoiCols}
          emptyMessage="No active high-ROI requests."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All requests by priority</h2>
        <DataTable
          rows={requests}
          columns={requestCols}
          emptyMessage="No requests recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Kind breakdown</h2>
        <DataTable
          rows={kind}
          columns={kindCols}
          emptyMessage="No kind data."
          rowKey={(r: any, i: number) => String(r.request_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Weekly submission trend (12 weeks)</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top hospitals by request volume</h2>
        <DataTable
          rows={hospitals}
          columns={hospitalsCols}
          emptyMessage="No hospital activity."
          rowKey={(r: any, i: number) => String(r.hospital_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Scoring log</h2>
        <DataTable
          rows={log}
          columns={logCols}
          emptyMessage="No scoring entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
