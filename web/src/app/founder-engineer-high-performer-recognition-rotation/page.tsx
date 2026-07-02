import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overviewRes, nomsRes, selsRes, byStatusRes, topRes, trendRes, repeatRes] = await Promise.all([
    sb.rpc('founder_recognition_overview_r2231'),
    sb.rpc('founder_recognition_list_nominations_r2231'),
    sb.rpc('founder_recognition_list_selections_r2231'),
    sb.rpc('founder_recognition_by_status_r2231'),
    sb.rpc('founder_recognition_top_scored_r2231'),
    sb.rpc('founder_recognition_monthly_trend_r2231'),
    sb.rpc('founder_recognition_repeat_winners_r2231'),
  ]);

  const overview = (overviewRes.data?.[0] ?? {}) as any;
  const noms = (nomsRes.data ?? []) as any[];
  const sels = (selsRes.data ?? []) as any[];
  const byStatus = (byStatusRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const repeat = (repeatRes.data ?? []) as any[];

  const nomCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    { key: 'cycle_month', header: 'Cycle', render: (r: any) => String(r.cycle_month ?? '').slice(0, 10) },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => String(r.jobs_completed ?? 0) },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => String(r.avg_rating ?? 0) },
    { key: 'on_time_pct', header: 'On-time %', render: (r: any) => String(r.on_time_pct ?? 0) },
    { key: 'score', header: 'Score', render: (r: any) => String(r.score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'nominated_by_name', header: 'Nominated by', render: (r: any) => String(r.nominated_by_name ?? '') },
  ];

  const selCols: Column<any>[] = [
    { key: 'cycle_month', header: 'Cycle', render: (r: any) => String(r.cycle_month ?? '').slice(0, 10) },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    { key: 'bonus_rupees', header: 'Bonus ₹', render: (r: any) => String(r.bonus_rupees ?? 0) },
    { key: 'shoutout_text', header: 'Shoutout', render: (r: any) => String(r.shoutout_text ?? '').slice(0, 80) },
    { key: 'announced_at', header: 'Announced', render: (r: any) => String(r.announced_at ?? '').slice(0, 10) },
    { key: 'selected_at', header: 'Selected', render: (r: any) => String(r.selected_at ?? '').slice(0, 10) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    { key: 'cycle_month', header: 'Cycle', render: (r: any) => String(r.cycle_month ?? '').slice(0, 10) },
    { key: 'score', header: 'Score', render: (r: any) => String(r.score ?? 0) },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => String(r.jobs_completed ?? 0) },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => String(r.avg_rating ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'cycle_month', header: 'Cycle', render: (r: any) => String(r.cycle_month ?? '').slice(0, 10) },
    { key: 'nominations', header: 'Nominations', render: (r: any) => String(r.nominations ?? 0) },
    { key: 'selections', header: 'Selections', render: (r: any) => String(r.selections ?? 0) },
    { key: 'total_bonus_rupees', header: 'Bonus ₹', render: (r: any) => String(r.total_bonus_rupees ?? 0) },
  ];

  const repeatCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    { key: 'win_count', header: 'Wins', render: (r: any) => String(r.win_count ?? 0) },
    { key: 'total_bonus_rupees', header: 'Total Bonus ₹', render: (r: any) => String(r.total_bonus_rupees ?? 0) },
    { key: 'last_won', header: 'Last Won', render: (r: any) => String(r.last_won ?? '').slice(0, 10) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer High-Performer Recognition Rotation
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Monthly rotation & selection log for engineer recognition (shoutout + bonus + public profile).
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Card label="Total nominations" value={String(overview.total_nominations ?? 0)} />
        <Card label="Pending" value={String(overview.pending_nominations ?? 0)} />
        <Card label="Shortlisted" value={String(overview.shortlisted_nominations ?? 0)} />
        <Card label="Selected (all-time)" value={String(overview.selected_count ?? 0)} />
        <Card label="Current cycle" value={String(overview.current_cycle ?? '').slice(0, 10)} />
        <Card label="This month winner" value={String(overview.current_cycle_selected_engineer ?? '—')} />
        <Card label="Bonus paid ₹" value={String(overview.total_bonus_paid_rupees ?? 0)} />
        <Card label="Avg score" value={String(Number(overview.avg_score ?? 0).toFixed(2))} />
      </div>

      <Section title="Nominations">
        <DataTable columns={nomCols} rows={noms} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Selections (monthly winners)">
        <DataTable columns={selCols} rows={sels} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="By status">
        <DataTable columns={statusCols} rows={byStatus} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Top scored nominations">
        <DataTable columns={topCols} rows={top} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Monthly trend">
        <DataTable columns={trendCols} rows={trend} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Repeat winners">
        <DataTable columns={repeatCols} rows={repeat} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </div>
  );
}
