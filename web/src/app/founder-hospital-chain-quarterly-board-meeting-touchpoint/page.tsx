import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtInr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, meetingsRes, commitmentsRes, byChainRes, byTopicRes, followupsRes, blockersRes, byOwnerRes] = await Promise.all([
    supabase.rpc('rpc_r2699_kpis'),
    supabase.rpc('rpc_r2699_meetings_list'),
    supabase.rpc('rpc_r2699_commitments_list'),
    supabase.rpc('rpc_r2699_by_chain'),
    supabase.rpc('rpc_r2699_by_topic'),
    supabase.rpc('rpc_r2699_upcoming_followups'),
    supabase.rpc('rpc_r2699_blockers'),
    supabase.rpc('rpc_r2699_by_owner'),
  ]);

  const kpis = (kpisRes.data?.[0] ?? {}) as Record<string, number>;
  const meetings = (meetingsRes.data ?? []) as Array<Record<string, unknown>>;
  const commitments = (commitmentsRes.data ?? []) as Array<Record<string, unknown>>;
  const byChain = (byChainRes.data ?? []) as Array<Record<string, unknown>>;
  const byTopic = (byTopicRes.data ?? []) as Array<Record<string, unknown>>;
  const followups = (followupsRes.data ?? []) as Array<Record<string, unknown>>;
  const blockers = (blockersRes.data ?? []) as Array<Record<string, unknown>>;
  const byOwner = (byOwnerRes.data ?? []) as Array<Record<string, unknown>>;

  const card = {
    border: '1px solid #e5e7eb',
    borderRadius: 8,
    padding: 16,
    background: '#fff',
  } as const;
  const label = { fontSize: 12, color: '#6b7280', marginBottom: 4 } as const;
  const value = { fontSize: 22, fontWeight: 700, color: '#111827' } as const;

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 800, marginBottom: 6 }}>
          Hospital Chain Quarterly Board Meeting Touchpoint
        </h1>
        <p style={{ color: '#6b7280' }}>
          Chain × board contact × meeting kind × topic × ask × commitment × follow-up — r2699
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={card}><div style={label}>Total Meetings</div><div style={value}>{String(kpis.total_meetings ?? 0)}</div></div>
        <div style={card}><div style={label}>Unique Chains</div><div style={value}>{String(kpis.unique_chains ?? 0)}</div></div>
        <div style={card}><div style={label}>Total Ask</div><div style={value}>{fmtInr(Number(kpis.total_ask_inr))}</div></div>
        <div style={card}><div style={label}>Won Ask</div><div style={value}>{fmtInr(Number(kpis.won_ask_inr))}</div></div>
        <div style={card}><div style={label}>Progressing Ask</div><div style={value}>{fmtInr(Number(kpis.progressing_ask_inr))}</div></div>
        <div style={card}><div style={label}>Open Commitments</div><div style={value}>{String(kpis.open_commitments ?? 0)}</div></div>
        <div style={card}><div style={label}>Slipped / Blocked</div><div style={value}>{String(kpis.slipped_commitments ?? 0)}</div></div>
        <div style={card}><div style={label}>Follow-ups Next 7d</div><div style={value}>{String(kpis.next_7_day_followups ?? 0)}</div></div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Board Meetings</h2>
        <DataTable
          rows={meetings}
          columns={[
            { key: 'meeting_date', header: 'Date', render: (r: Record<string, unknown>) => String(r.meeting_date ?? '') },
            { key: 'chain_name', header: 'Chain', render: (r: Record<string, unknown>) => String(r.chain_name ?? '') },
            { key: 'chain_tier', header: 'Tier', render: (r: Record<string, unknown>) => String(r.chain_tier ?? '') },
            { key: 'board_contact', header: 'Contact', render: (r: Record<string, unknown>) => String(r.board_contact ?? '') + ' (' + String(r.contact_role ?? '') + ')' },
            { key: 'meeting_kind', header: 'Kind', render: (r: Record<string, unknown>) => String(r.meeting_kind ?? '') },
            { key: 'meeting_topic', header: 'Topic', render: (r: Record<string, unknown>) => String(r.meeting_topic ?? '') },
            { key: 'ask_summary', header: 'Ask', render: (r: Record<string, unknown>) => String(r.ask_summary ?? '') },
            { key: 'ask_value_inr', header: 'Ask Value', render: (r: Record<string, unknown>) => fmtInr(Number(r.ask_value_inr)) },
            { key: 'sentiment', header: 'Sentiment', render: (r: Record<string, unknown>) => String(r.sentiment ?? '') },
            { key: 'outcome', header: 'Outcome', render: (r: Record<string, unknown>) => String(r.outcome ?? '') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Record<string, unknown>, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Commitments & Follow-ups</h2>
        <DataTable
          rows={commitments}
          columns={[
            { key: 'due_date', header: 'Due', render: (r: Record<string, unknown>) => String(r.due_date ?? '') },
            { key: 'chain_name', header: 'Chain', render: (r: Record<string, unknown>) => String(r.chain_name ?? '') },
            { key: 'commitment_type', header: 'Type', render: (r: Record<string, unknown>) => String(r.commitment_type ?? '') },
            { key: 'commitment_text', header: 'Commitment', render: (r: Record<string, unknown>) => String(r.commitment_text ?? '') },
            { key: 'owner', header: 'Owner', render: (r: Record<string, unknown>) => String(r.owner ?? '') },
            { key: 'status', header: 'Status', render: (r: Record<string, unknown>) => String(r.status ?? '') },
            { key: 'follow_up_action', header: 'Follow-up', render: (r: Record<string, unknown>) => String(r.follow_up_action ?? '') },
            { key: 'follow_up_date', header: 'FU Date', render: (r: Record<string, unknown>) => String(r.follow_up_date ?? '') },
            { key: 'blocker', header: 'Blocker', render: (r: Record<string, unknown>) => String(r.blocker ?? '—') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Record<string, unknown>, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>By Chain</h2>
        <DataTable
          rows={byChain}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Record<string, unknown>) => String(r.chain_name ?? '') },
            { key: 'meetings', header: 'Meetings', render: (r: Record<string, unknown>) => String(r.meetings ?? 0) },
            { key: 'total_ask_inr', header: 'Total Ask', render: (r: Record<string, unknown>) => fmtInr(Number(r.total_ask_inr)) },
            { key: 'won_inr', header: 'Won', render: (r: Record<string, unknown>) => fmtInr(Number(r.won_inr)) },
            { key: 'open_commits', header: 'Open Commits', render: (r: Record<string, unknown>) => String(r.open_commits ?? 0) },
            { key: 'blocked_commits', header: 'Blocked', render: (r: Record<string, unknown>) => String(r.blocked_commits ?? 0) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Record<string, unknown>, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>By Topic</h2>
        <DataTable
          rows={byTopic}
          columns={[
            { key: 'meeting_topic', header: 'Topic', render: (r: Record<string, unknown>) => String(r.meeting_topic ?? '') },
            { key: 'meetings', header: 'Meetings', render: (r: Record<string, unknown>) => String(r.meetings ?? 0) },
            { key: 'total_ask_inr', header: 'Total Ask', render: (r: Record<string, unknown>) => fmtInr(Number(r.total_ask_inr)) },
            { key: 'won_pct', header: 'Won %', render: (r: Record<string, unknown>) => String(r.won_pct ?? 0) + '%' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Record<string, unknown>, i: number) => String(r.meeting_topic ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Upcoming Follow-ups</h2>
        <DataTable
          rows={followups}
          columns={[
            { key: 'follow_up_date', header: 'Date', render: (r: Record<string, unknown>) => String(r.follow_up_date ?? '') },
            { key: 'chain_name', header: 'Chain', render: (r: Record<string, unknown>) => String(r.chain_name ?? '') },
            { key: 'follow_up_action', header: 'Action', render: (r: Record<string, unknown>) => String(r.follow_up_action ?? '') },
            { key: 'owner', header: 'Owner', render: (r: Record<string, unknown>) => String(r.owner ?? '') },
            { key: 'status', header: 'Status', render: (r: Record<string, unknown>) => String(r.status ?? '') },
            { key: 'days_until', header: 'Days Until', render: (r: Record<string, unknown>) => String(r.days_until ?? 0) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Record<string, unknown>, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Blockers</h2>
        <DataTable
          rows={blockers}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Record<string, unknown>) => String(r.chain_name ?? '') },
            { key: 'commitment_text', header: 'Commitment', render: (r: Record<string, unknown>) => String(r.commitment_text ?? '') },
            { key: 'owner', header: 'Owner', render: (r: Record<string, unknown>) => String(r.owner ?? '') },
            { key: 'due_date', header: 'Due', render: (r: Record<string, unknown>) => String(r.due_date ?? '') },
            { key: 'blocker', header: 'Blocker', render: (r: Record<string, unknown>) => String(r.blocker ?? '—') },
            { key: 'follow_up_date', header: 'FU Date', render: (r: Record<string, unknown>) => String(r.follow_up_date ?? '') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Record<string, unknown>, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>By Owner</h2>
        <DataTable
          rows={byOwner}
          columns={[
            { key: 'owner', header: 'Owner', render: (r: Record<string, unknown>) => String(r.owner ?? '') },
            { key: 'open_count', header: 'Open', render: (r: Record<string, unknown>) => String(r.open_count ?? 0) },
            { key: 'in_progress_count', header: 'In Progress', render: (r: Record<string, unknown>) => String(r.in_progress_count ?? 0) },
            { key: 'blocked_count', header: 'Blocked', render: (r: Record<string, unknown>) => String(r.blocked_count ?? 0) },
            { key: 'total_commits', header: 'Total', render: (r: Record<string, unknown>) => String(r.total_commits ?? 0) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Record<string, unknown>, i: number) => String(r.owner ?? i)}
        />
      </section>
    </div>
  );
}
