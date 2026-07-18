import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [wavesRes, actionsRes, complaintsRes, kindRes, completionRes, trendRes, topNpsRes] = await Promise.all([
    supabase.rpc('list_waves_r2520'),
    supabase.rpc('list_actions_r2520'),
    supabase.rpc('top_complaint_themes_r2520'),
    supabase.rpc('action_kind_summary_r2520'),
    supabase.rpc('wave_completion_summary_r2520'),
    supabase.rpc('monthly_wave_trend_r2520'),
    supabase.rpc('top_hospitals_by_nps_in_wave_r2520'),
  ]);

  const waves = (wavesRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const complaints = (complaintsRes.data ?? []) as any[];
  const kinds = (kindRes.data ?? []) as any[];
  const completion = (completionRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const topNps = (topNpsRes.data ?? []) as any[];

  const wavesCols: Column<any>[] = [
    { key: 'wave_label', header: 'Wave', render: (r: any) => r.wave_label },
    { key: 'window', header: 'Window', render: (r: any) => `${r.wave_start} => ${r.wave_end}` },
    { key: 'hospitals_count', header: 'Hospitals', render: (r: any) => r.hospitals_count },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps ?? '-' },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat ?? '-' },
    { key: 'completion_rate_pct', header: 'Completion %', render: (r: any) => r.completion_rate_pct ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'wave_label', header: 'Wave', render: (r: any) => r.wave_label },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'action_summary_md', header: 'Action', render: (r: any) => r.action_summary_md },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'target_at', header: 'Target', render: (r: any) => r.target_at ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'closed_at', header: 'Closed', render: (r: any) => r.closed_at ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const complaintsCols: Column<any>[] = [
    { key: 'wave_label', header: 'Wave', render: (r: any) => r.wave_label },
    { key: 'top_complaint_md', header: 'Top complaint', render: (r: any) => r.top_complaint_md },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps ?? '-' },
    { key: 'hospitals_count', header: 'Hospitals', render: (r: any) => r.hospitals_count },
  ];

  const kindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'positive_count', header: 'Positive outcomes', render: (r: any) => r.positive_count },
  ];

  const completionCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'waves_count', header: 'Waves', render: (r: any) => r.waves_count },
    { key: 'avg_completion_pct', header: 'Avg completion %', render: (r: any) => r.avg_completion_pct ?? '-' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'waves_count', header: 'Waves', render: (r: any) => r.waves_count },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps ?? '-' },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat ?? '-' },
  ];

  const topNpsCols: Column<any>[] = [
    { key: 'wave_label', header: 'Wave', render: (r: any) => r.wave_label },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps ?? '-' },
    { key: 'hospitals_count', header: 'Hospitals', render: (r: any) => r.hospitals_count },
    { key: 'completion_rate_pct', header: 'Completion %', render: (r: any) => r.completion_rate_pct ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 6 }}>
        Customer onboarding & feedback trends
      </h1>
      <p style={{ color: '#64748b', marginBottom: 24 }}>
        Hospital wave &gt; NPS & CSAT &gt; top compliment & complaint &gt; action taken & deflection.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Feedback waves</h2>
        <DataTable
          rows={waves}
          columns={wavesCols}
          emptyMessage="No waves recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Actions taken (deflection)</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top complaint themes (lowest NPS first)</h2>
        <DataTable
          rows={complaints}
          columns={complaintsCols}
          emptyMessage="No complaint themes."
          rowKey={(r: any, i: number) => String(r.wave_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Action kind summary</h2>
        <DataTable
          rows={kinds}
          columns={kindCols}
          emptyMessage="No actions yet."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Wave completion summary</h2>
        <DataTable
          rows={completion}
          columns={completionCols}
          emptyMessage="No waves yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly wave trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top waves by NPS</h2>
        <DataTable
          rows={topNps}
          columns={topNpsCols}
          emptyMessage="No NPS data yet."
          rowKey={(r: any, i: number) => String(r.wave_label ?? i)}
        />
      </section>
    </main>
  );
}
