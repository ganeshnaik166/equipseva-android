import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyThinkingTimeBlocksPage() {
  const supabase = await getSupabaseServerClient();

  const [weeksRes, protectionRes, decisionsRes] = await Promise.all([
    supabase.rpc('list_thinking_weeks_r2397'),
    supabase.rpc('thinking_protection_rate_r2397'),
    supabase.rpc('thinking_decisions_emerged_r2397'),
  ]);

  const weeks = (weeksRes.data ?? []) as any[];
  const protection = (protectionRes.data ?? []) as any[];
  const decisions = (decisionsRes.data ?? []) as any[];

  const weekCols: Column<any>[] = [
    { key: 'week_start_date', header: 'Week Start', render: (r) => String(r.week_start_date ?? '') },
    { key: 'week_theme', header: 'Theme', render: (r) => String(r.week_theme ?? '') },
    { key: 'target_block_count', header: 'Target Blocks', render: (r) => String(r.target_block_count ?? 0) },
    { key: 'completed_block_count', header: 'Done', render: (r) => String(r.completed_block_count ?? 0) },
    { key: 'target_total_minutes', header: 'Target Min', render: (r) => String(r.target_total_minutes ?? 0) },
    { key: 'completed_minutes', header: 'Done Min', render: (r) => String(r.completed_minutes ?? 0) },
    { key: 'decision_count', header: 'Decisions', render: (r) => String(r.decision_count ?? 0) },
    { key: 'target_met', header: 'Target Met', render: (r) => (r.target_met ? 'YES' : 'no') },
  ];

  const protectionCols: Column<any>[] = [
    { key: 'week_start_date', header: 'Week', render: (r) => String(r.week_start_date ?? '') },
    { key: 'total_blocks', header: 'Total', render: (r) => String(r.total_blocks ?? 0) },
    { key: 'protected_blocks', header: 'Protected', render: (r) => String(r.protected_blocks ?? 0) },
    { key: 'interrupted_blocks', header: 'Interrupted', render: (r) => String(r.interrupted_blocks ?? 0) },
    { key: 'skipped_blocks', header: 'Skipped', render: (r) => String(r.skipped_blocks ?? 0) },
    { key: 'protection_pct', header: 'Protection %', render: (r) => String(r.protection_pct ?? 0) },
    { key: 'avg_quality', header: 'Avg Quality', render: (r) => (r.avg_quality == null ? '-' : String(r.avg_quality)) },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'block_date', header: 'Date', render: (r) => String(r.block_date ?? '') },
    { key: 'topic', header: 'Topic', render: (r) => String(r.topic ?? '') },
    { key: 'decision_emerged', header: 'Decision', render: (r) => String(r.decision_emerged ?? '') },
    { key: 'decision_owner_email', header: 'Owner', render: (r) => String(r.decision_owner_email ?? '-') },
    { key: 'duration_minutes', header: 'Minutes', render: (r) => String(r.duration_minutes ?? 0) },
    { key: 'quality_rating', header: 'Quality', render: (r) => (r.quality_rating == null ? '-' : String(r.quality_rating)) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Founder Weekly Thinking-Time Block Tracker</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Protected deep-thinking blocks per week — target met & decisions that emerged.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Weeks & targets</h2>
        <DataTable
          rows={weeks}
          emptyMessage="No thinking weeks scheduled yet."
          rowKey={(r) => String(r.id)}
          columns={weekCols}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Protection rate per week</h2>
        <DataTable
          rows={protection}
          emptyMessage="No protection data."
          rowKey={(r) => String(r.week_start_date)}
          columns={protectionCols}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Decisions that emerged from thinking blocks</h2>
        <DataTable
          rows={decisions}
          emptyMessage="No decisions emerged yet — book more blocks."
          rowKey={(r) => String(r.block_id)}
          columns={decisionCols}
        />
      </section>
    </main>
  );
}
