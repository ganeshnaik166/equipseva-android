import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyOkrDashboardPage() {
  const sb = await getSupabaseServerClient();

  const [weeksRes, trendRes, winsRes, lossesRes] = await Promise.all([
    sb.rpc('list_weeks_r1814'),
    sb.rpc('week_score_trend_r1814'),
    sb.rpc('biggest_wins_r1814'),
    sb.rpc('biggest_losses_r1814'),
  ]);

  const weeks: any[] = Array.isArray(weeksRes.data) ? weeksRes.data : [];
  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const wins: any[] = Array.isArray(winsRes.data) ? winsRes.data : [];
  const losses: any[] = Array.isArray(lossesRes.data) ? lossesRes.data : [];

  const weekCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => String(r.week_start ?? '') },
    { key: 'total_okrs', header: 'Total OKRs', render: (r: any) => String(r.total_okrs ?? 0) },
    { key: 'on_track', header: 'On Track', render: (r: any) => String(r.on_track ?? 0) },
    { key: 'at_risk', header: 'At Risk', render: (r: any) => String(r.at_risk ?? 0) },
    { key: 'missed', header: 'Missed', render: (r: any) => String(r.missed ?? 0) },
    { key: 'completed', header: 'Completed', render: (r: any) => String(r.completed ?? 0) },
    { key: 'week_score', header: 'Score', render: (r: any) => String(r.week_score ?? 0) },
    { key: 'founder_note', header: 'Note', render: (r: any) => String(r.founder_note ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'week_score', header: 'Score', render: (r: any) => String(r.week_score ?? 0) },
    { key: 'total_okrs', header: 'Total', render: (r: any) => String(r.total_okrs ?? 0) },
    { key: 'completed', header: 'Completed', render: (r: any) => String(r.completed ?? 0) },
  ];

  const winsCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'highlight_text', header: 'Win', render: (r: any) => String(r.highlight_text ?? '') },
    { key: 'created_at', header: 'Logged', render: (r: any) => String(r.created_at ?? '') },
  ];

  const lossesCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'highlight_text', header: 'Loss', render: (r: any) => String(r.highlight_text ?? '') },
    { key: 'created_at', header: 'Logged', render: (r: any) => String(r.created_at ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder Weekly OKR Dashboard</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Per-week OKR roll-up — on-track vs at-risk vs missed, score trend, and biggest wins & losses.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Weeks</h2>
        <DataTable rows={weeks} columns={weekCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Score Trend (last 12 weeks)</h2>
        <DataTable rows={trend} columns={trendCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Biggest Wins</h2>
        <DataTable rows={wins} columns={winsCols} rowKey={(r: any, i: number) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Biggest Losses</h2>
        <DataTable rows={losses} columns={lossesCols} rowKey={(r: any, i: number) => String(i)} />
      </section>
    </main>
  );
}
