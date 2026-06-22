import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderTimeBlockAdherencePage() {
  const sb = await getSupabaseServerClient();

  const [blocksRes, trendRes, actionsRes] = await Promise.all([
    sb.rpc('list_time_blocks_r1978', { p_limit: 100 }),
    sb.rpc('adherence_trend_r1978', { p_days: 14 }),
    sb.rpc('recent_block_actions_r1978', { p_limit: 50 }),
  ]);

  const blocks: any[] = Array.isArray(blocksRes.data) ? blocksRes.data : [];
  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const totalBlocks = blocks.length;
  const onTarget = blocks.filter((b) => b.status === 'on_target').length;
  const missed = blocks.filter((b) => b.status === 'missed').length;
  const avgAdherence =
    blocks.length === 0
      ? 0
      : Math.round(
          blocks.reduce((s, b) => s + Number(b.adherence_pct || 0), 0) / blocks.length,
        );

  const blockColumns: Column<any>[] = [
    { key: 'block_date', header: 'Date', render: (r: any) => String(r.block_date ?? '') },
    { key: 'block_label', header: 'Label', render: (r: any) => String(r.block_label ?? '') },
    { key: 'block_category', header: 'Category', render: (r: any) => String(r.block_category ?? '') },
    { key: 'scheduled_minutes', header: 'Scheduled min', render: (r: any) => String(r.scheduled_minutes ?? 0) },
    { key: 'actual_minutes', header: 'Actual min', render: (r: any) => String(r.actual_minutes ?? 0) },
    { key: 'adherence_pct', header: 'Adherence %', render: (r: any) => String(r.adherence_pct ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'block_date', header: 'Date', render: (r: any) => String(r.block_date ?? '') },
    { key: 'total_blocks', header: 'Total blocks', render: (r: any) => String(r.total_blocks ?? 0) },
    { key: 'on_target_blocks', header: 'On target', render: (r: any) => String(r.on_target_blocks ?? 0) },
    { key: 'missed_blocks', header: 'Missed', render: (r: any) => String(r.missed_blocks ?? 0) },
    { key: 'avg_adherence', header: 'Avg adherence %', render: (r: any) => String(r.avg_adherence ?? 0) },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'taken_at', header: 'Taken at', render: (r: any) => String(r.taken_at ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Founder Time-Block Adherence
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track deep work vs distraction. Log scheduled and actual minutes per block, mark status,
        and review adherence trend across the last 14 days.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Total blocks</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalBlocks}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>On target</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{onTarget}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Missed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{missed}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Avg adherence %</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{avgAdherence}</div>
          </div>
        </div>
        <p style={{ color: '#999', fontSize: 12, marginTop: 8 }}>
          Status counts blocks at least once logged. Adherence above 100 means block ran longer than scheduled.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent blocks</h2>
        <DataTable
          rows={blocks}
          columns={blockColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Adherence trend (14 days)</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          rowKey={(r: any, i: number) => String(r.block_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
