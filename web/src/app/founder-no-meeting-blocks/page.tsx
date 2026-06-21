import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_blocks: number;
  active_blocks: number;
  total_violations_7d: number;
  declined_7d: number;
  accepted_with_reschedule_7d: number;
  accepted_7d: number;
  pending_7d: number;
};

type BlockRow = {
  id: string;
  block_start: string;
  block_end: string;
  label: string;
  day_of_week: number;
  recurring: boolean;
  active: boolean;
  violation_count: number;
  created_at: string;
};

type ViolationRow = {
  id: string;
  block_id: string;
  block_label: string;
  block_day_of_week: number;
  attempted_meeting_title: string;
  requested_by_email: string;
  requested_at: string;
  decision: string | null;
  alt_time: string | null;
  decided_at: string | null;
};

type DeclineRateRow = {
  block_id: string;
  label: string;
  day_of_week: number;
  total_violations: number;
  declined_count: number;
  decline_rate_pct: number;
};

const DOW_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function dayLabel(d: number) {
  return DOW_LABELS[d] ?? String(d);
}

function fmtTime(t: string) {
  if (!t) return '—';
  return t.slice(0, 5);
}

function fmtTs(ts: string | null) {
  if (!ts) return '—';
  try {
    return new Date(ts).toLocaleString('en-IN', {
      timeZone: 'Asia/Kolkata',
      dateStyle: 'medium',
      timeStyle: 'short',
    });
  } catch {
    return ts;
  }
}

export default async function FounderNoMeetingBlocksPage() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, blocksRes, violationsRes, declineRes] = await Promise.all([
    sb.rpc('weekly_block_summary_r1670'),
    sb.rpc('list_blocks_r1670'),
    sb.rpc('list_violations_r1670'),
    sb.rpc('decline_rate_r1670'),
  ]);

  const summary: SummaryRow = (summaryRes.data?.[0] ?? {
    total_blocks: 0,
    active_blocks: 0,
    total_violations_7d: 0,
    declined_7d: 0,
    accepted_with_reschedule_7d: 0,
    accepted_7d: 0,
    pending_7d: 0,
  }) as SummaryRow;

  const blocks: BlockRow[] = (blocksRes.data ?? []) as BlockRow[];
  const violations: ViolationRow[] = (violationsRes.data ?? []) as ViolationRow[];
  const declineRates: DeclineRateRow[] = (declineRes.data ?? []) as DeclineRateRow[];

  const pendingQueue = violations.filter((v) => v.decision === null);

  const declineRatePct =
    summary.total_violations_7d > 0
      ? ((summary.declined_7d / summary.total_violations_7d) * 100).toFixed(1)
      : '0.0';

  const blockCols: Column<BlockRow>[] = [
    {
      key: 'day',
      header: 'Day',
      render: (r) => <span style={{ fontWeight: 600 }}>{dayLabel(r.day_of_week)}</span>,
    },
    {
      key: 'window',
      header: 'Block Window',
      render: (r) => (
        <span style={{ fontFamily: 'monospace' }}>
          {fmtTime(r.block_start)} – {fmtTime(r.block_end)}
        </span>
      ),
    },
    {
      key: 'label',
      header: 'Label',
      render: (r) => r.label,
    },
    {
      key: 'recurring',
      header: 'Recurring',
      render: (r) => (r.recurring ? 'Weekly' : 'One-off'),
    },
    {
      key: 'active',
      header: 'Status',
      render: (r) => (
        <span
          style={{
            padding: '2px 8px',
            borderRadius: 4,
            background: r.active ? '#dcfce7' : '#fee2e2',
            color: r.active ? '#166534' : '#991b1b',
            fontSize: 12,
          }}
        >
          {r.active ? 'ACTIVE' : 'PAUSED'}
        </span>
      ),
    },
    {
      key: 'violations',
      header: 'Violations',
      render: (r) => <span style={{ fontWeight: 600 }}>{r.violation_count}</span>,
    },
  ];

  const violationCols: Column<ViolationRow>[] = [
    {
      key: 'requested_at',
      header: 'Requested',
      render: (r) => <span style={{ fontSize: 12 }}>{fmtTs(r.requested_at)}</span>,
    },
    {
      key: 'block',
      header: 'Block Hit',
      render: (r) => (
        <span>
          {dayLabel(r.block_day_of_week)} · {r.block_label}
        </span>
      ),
    },
    {
      key: 'meeting',
      header: 'Meeting',
      render: (r) => r.attempted_meeting_title,
    },
    {
      key: 'requester',
      header: 'Requested By',
      render: (r) => <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{r.requested_by_email}</span>,
    },
    {
      key: 'decision',
      header: 'Decision',
      render: (r) => {
        if (!r.decision) {
          return (
            <span
              style={{
                padding: '2px 8px',
                borderRadius: 4,
                background: '#fef3c7',
                color: '#92400e',
                fontSize: 12,
              }}
            >
              PENDING
            </span>
          );
        }
        const colors: Record<string, { bg: string; fg: string }> = {
          declined: { bg: '#dcfce7', fg: '#166534' },
          accepted_with_reschedule: { bg: '#fef3c7', fg: '#92400e' },
          accepted: { bg: '#fee2e2', fg: '#991b1b' },
        };
        const c = colors[r.decision] ?? { bg: '#e5e7eb', fg: '#111827' };
        return (
          <span
            style={{
              padding: '2px 8px',
              borderRadius: 4,
              background: c.bg,
              color: c.fg,
              fontSize: 12,
            }}
          >
            {r.decision.toUpperCase()}
          </span>
        );
      },
    },
    {
      key: 'alt_time',
      header: 'Reschedule To',
      render: (r) => <span style={{ fontSize: 12 }}>{fmtTs(r.alt_time)}</span>,
    },
  ];

  const queueCols: Column<ViolationRow>[] = [
    {
      key: 'requested_at',
      header: 'Requested',
      render: (r) => <span style={{ fontSize: 12 }}>{fmtTs(r.requested_at)}</span>,
    },
    {
      key: 'meeting',
      header: 'Meeting',
      render: (r) => <span style={{ fontWeight: 600 }}>{r.attempted_meeting_title}</span>,
    },
    {
      key: 'requester',
      header: 'From',
      render: (r) => <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{r.requested_by_email}</span>,
    },
    {
      key: 'block',
      header: 'Conflicts With',
      render: (r) => (
        <span>
          {dayLabel(r.block_day_of_week)} · {r.block_label}
        </span>
      ),
    },
    {
      key: 'action',
      header: 'Action',
      render: () => (
        <span style={{ fontSize: 12, color: '#6b7280' }}>
          Decide via RPC: decide_violation_r1670
        </span>
      ),
    },
  ];

  const declineCols: Column<DeclineRateRow>[] = [
    {
      key: 'day',
      header: 'Day',
      render: (r) => dayLabel(r.day_of_week),
    },
    {
      key: 'label',
      header: 'Block',
      render: (r) => <span style={{ fontWeight: 600 }}>{r.label}</span>,
    },
    {
      key: 'total',
      header: 'Total Requests',
      render: (r) => r.total_violations,
    },
    {
      key: 'declined',
      header: 'Declined',
      render: (r) => r.declined_count,
    },
    {
      key: 'rate',
      header: 'Decline Rate',
      render: (r) => (
        <span
          style={{
            fontWeight: 600,
            color: r.decline_rate_pct >= 75 ? '#166534' : r.decline_rate_pct >= 50 ? '#92400e' : '#991b1b',
          }}
        >
          {r.decline_rate_pct}%
        </span>
      ),
    },
  ];

  const kpi = (label: string, value: string | number, sub?: string) => (
    <div
      style={{
        padding: 16,
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        background: '#fff',
        minWidth: 140,
      }}
    >
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>
        {label}
      </div>
      <div style={{ fontSize: 28, fontWeight: 700, marginTop: 4 }}>{value}</div>
      {sub ? <div style={{ fontSize: 11, color: '#9ca3af', marginTop: 2 }}>{sub}</div> : null}
    </div>
  );

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>
          Founder Weekly No-Meeting Block
        </h1>
        <p style={{ color: '#6b7280', marginTop: 4 }}>
          Protect deep-work blocks. Opt-out by default. Triage the reschedule queue.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Last 7 Days</h2>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          {kpi('Active Blocks', summary.active_blocks, `${summary.total_blocks} total`)}
          {kpi('Requests', summary.total_violations_7d, '7-day window')}
          {kpi('Declined', summary.declined_7d, `${declineRatePct}% decline rate`)}
          {kpi('Rescheduled', summary.accepted_with_reschedule_7d, 'moved out of block')}
          {kpi('Accepted', summary.accepted_7d, 'block broken')}
          {kpi('Pending', summary.pending_7d, 'needs decision')}
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Action Queue ({pendingQueue.length} pending)
        </h2>
        <DataTable
          rows={pendingQueue}
          columns={queueCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Protected Blocks</h2>
        <DataTable
          rows={blocks}
          columns={blockCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Decline Rate by Block</h2>
        <p style={{ fontSize: 13, color: '#6b7280', marginTop: 0 }}>
          Higher decline rate = stronger boundary. Target ≥ 75%.
        </p>
        <DataTable
          rows={declineRates}
          columns={declineCols}
          rowKey={(r, i) => String(r.block_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Violations (last 200)
        </h2>
        <DataTable
          rows={violations}
          columns={violationCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
