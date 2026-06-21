import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Item = {
  id: string;
  investor_id: string;
  item_label: string;
  category: string;
  required: boolean;
  due_date: string | null;
  status: string;
  submitted_at: string | null;
  cleared_at: string | null;
  note: string | null;
  created_at: string;
};

type Summary = {
  investor_id: string;
  total_items: number;
  pending_count: number;
  submitted_count: number;
  cleared_count: number;
  blocked_count: number;
  overdue_count: number;
  pct_cleared: number | null;
};

type Blocked = {
  id: string;
  investor_id: string;
  item_label: string;
  category: string;
  due_date: string | null;
  status: string;
  note: string | null;
  age_days: number;
};

type Milestone = {
  id: string;
  investor_id: string;
  milestone: string;
  reached_at: string | null;
  note: string | null;
  created_at: string;
};

function shortId(s: string | null | undefined): string {
  if (!s) return '—';
  return s.slice(0, 8);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  } catch {
    return s;
  }
}

function statusPill(status: string) {
  const map: Record<string, { bg: string; fg: string }> = {
    pending:   { bg: '#fef3c7', fg: '#92400e' },
    submitted: { bg: '#dbeafe', fg: '#1e40af' },
    cleared:   { bg: '#d1fae5', fg: '#065f46' },
    blocked:   { bg: '#fee2e2', fg: '#991b1b' },
  };
  const c = map[status] ?? { bg: '#e5e7eb', fg: '#374151' };
  return (
    <span style={{
      background: c.bg,
      color: c.fg,
      padding: '2px 8px',
      borderRadius: 12,
      fontSize: 12,
      fontWeight: 600,
      textTransform: 'uppercase',
    }}>{status}</span>
  );
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [itemsRes, summaryRes, blockedRes, milestonesRes] = await Promise.all([
    sb.rpc('founder_list_diligence_items', { p_investor: null }),
    sb.rpc('founder_investor_diligence_summary'),
    sb.rpc('founder_blocked_diligence_items'),
    sb.rpc('founder_list_diligence_milestones', { p_investor: null }),
  ]);

  const items: Item[]         = (itemsRes.data ?? []) as Item[];
  const summary: Summary[]    = (summaryRes.data ?? []) as Summary[];
  const blocked: Blocked[]    = (blockedRes.data ?? []) as Blocked[];
  const milestones: Milestone[] = (milestonesRes.data ?? []) as Milestone[];

  const totalItems   = items.length;
  const totalCleared = items.filter(i => i.status === 'cleared').length;
  const totalBlocked = blocked.length;
  const totalInvestors = summary.length;
  const avgCleared = summary.length
    ? Math.round(
        (summary.reduce((s, r) => s + (Number(r.pct_cleared) || 0), 0) / summary.length) * 10
      ) / 10
    : 0;

  const summaryCols: Column<Summary>[] = [
    { key: 'investor_id', header: 'Investor', render: (r) => <code style={{ fontSize: 12 }}>{shortId(r.investor_id)}</code> },
    { key: 'total_items', header: 'Total', render: (r) => <span>{r.total_items}</span> },
    { key: 'pending_count', header: 'Pending', render: (r) => <span>{r.pending_count}</span> },
    { key: 'submitted_count', header: 'Submitted', render: (r) => <span>{r.submitted_count}</span> },
    { key: 'cleared_count', header: 'Cleared', render: (r) => <span style={{ color: '#065f46', fontWeight: 600 }}>{r.cleared_count}</span> },
    { key: 'blocked_count', header: 'Blocked', render: (r) => <span style={{ color: '#991b1b', fontWeight: 600 }}>{r.blocked_count}</span> },
    { key: 'overdue_count', header: 'Overdue', render: (r) => <span style={{ color: r.overdue_count > 0 ? '#b45309' : '#6b7280' }}>{r.overdue_count}</span> },
    { key: 'pct_cleared', header: '% Cleared', render: (r) => <strong>{r.pct_cleared ?? 0}%</strong> },
  ];

  const itemCols: Column<Item>[] = [
    { key: 'investor_id', header: 'Investor', render: (r) => <code style={{ fontSize: 12 }}>{shortId(r.investor_id)}</code> },
    { key: 'item_label', header: 'Item', render: (r) => <span>{r.item_label}</span> },
    { key: 'category', header: 'Category', render: (r) => <span style={{ fontSize: 12, color: '#6b7280' }}>{r.category}</span> },
    { key: 'required', header: 'Req', render: (r) => <span>{r.required ? 'Yes' : 'No'}</span> },
    { key: 'due_date', header: 'Due', render: (r) => <span>{fmtDate(r.due_date)}</span> },
    { key: 'status', header: 'Status', render: (r) => statusPill(r.status) },
    { key: 'submitted_at', header: 'Submitted', render: (r) => <span style={{ fontSize: 12 }}>{fmtDate(r.submitted_at)}</span> },
    { key: 'cleared_at', header: 'Cleared', render: (r) => <span style={{ fontSize: 12 }}>{fmtDate(r.cleared_at)}</span> },
  ];

  const blockedCols: Column<Blocked>[] = [
    { key: 'investor_id', header: 'Investor', render: (r) => <code style={{ fontSize: 12 }}>{shortId(r.investor_id)}</code> },
    { key: 'item_label', header: 'Item', render: (r) => <strong>{r.item_label}</strong> },
    { key: 'category', header: 'Category', render: (r) => <span>{r.category}</span> },
    { key: 'due_date', header: 'Due', render: (r) => <span style={{ color: '#991b1b' }}>{fmtDate(r.due_date)}</span> },
    { key: 'status', header: 'Status', render: (r) => statusPill(r.status) },
    { key: 'age_days', header: 'Age', render: (r) => <span>{r.age_days}d</span> },
    { key: 'note', header: 'Note', render: (r) => <span style={{ fontSize: 12, color: '#6b7280' }}>{r.note ?? '—'}</span> },
  ];

  const milestoneCols: Column<Milestone>[] = [
    { key: 'investor_id', header: 'Investor', render: (r) => <code style={{ fontSize: 12 }}>{shortId(r.investor_id)}</code> },
    { key: 'milestone', header: 'Milestone', render: (r) => <strong>{r.milestone}</strong> },
    { key: 'reached_at', header: 'Reached', render: (r) => <span>{fmtDate(r.reached_at)}</span> },
    { key: 'note', header: 'Note', render: (r) => <span style={{ fontSize: 12, color: '#6b7280' }}>{r.note ?? '—'}</span> },
  ];

  const kpiStyle: React.CSSProperties = {
    background: 'white',
    border: '1px solid #e5e7eb',
    borderRadius: 8,
    padding: 16,
    minWidth: 140,
    flex: '1 1 140px',
  };

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Investor Diligence Tracker</h1>
        <p style={{ color: '#6b7280', marginTop: 4, fontSize: 14 }}>
          Per-investor checklist status, milestones, and blocked items. r1665
        </p>
      </header>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 14, fontWeight: 600, textTransform: 'uppercase', color: '#6b7280', letterSpacing: 0.5, marginBottom: 12 }}>
          Summary KPIs
        </h2>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <div style={kpiStyle}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Investors tracked</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{totalInvestors}</div>
          </div>
          <div style={kpiStyle}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Total items</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{totalItems}</div>
          </div>
          <div style={kpiStyle}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Cleared</div>
            <div style={{ fontSize: 28, fontWeight: 700, color: '#065f46' }}>{totalCleared}</div>
          </div>
          <div style={kpiStyle}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Blocked / Overdue</div>
            <div style={{ fontSize: 28, fontWeight: 700, color: '#991b1b' }}>{totalBlocked}</div>
          </div>
          <div style={kpiStyle}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Avg % cleared</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{avgCleared}%</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 14, fontWeight: 600, textTransform: 'uppercase', color: '#6b7280', letterSpacing: 0.5, marginBottom: 12 }}>
          Per-investor summary
        </h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r, i) => String(r.investor_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 14, fontWeight: 600, textTransform: 'uppercase', color: '#6b7280', letterSpacing: 0.5, marginBottom: 12 }}>
          All diligence items
        </h2>
        <DataTable
          rows={items}
          columns={itemCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 14, fontWeight: 600, textTransform: 'uppercase', color: '#b45309', letterSpacing: 0.5, marginBottom: 12 }}>
          Action queue — blocked & overdue
        </h2>
        <DataTable
          rows={blocked}
          columns={blockedCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 14, fontWeight: 600, textTransform: 'uppercase', color: '#6b7280', letterSpacing: 0.5, marginBottom: 12 }}>
          Milestones
        </h2>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
