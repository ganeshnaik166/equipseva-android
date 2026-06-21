import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Gift = {
  id: string;
  investor_id: string;
  anniversary_date: string;
  gift_type: string;
  gift_value_rupees: number;
  ordered_at: string | null;
  sent_at: string | null;
  status: string;
  founder_note: string | null;
  reaction_count: number;
  created_at: string;
};

type Upcoming = {
  id: string;
  investor_id: string;
  anniversary_date: string;
  gift_type: string;
  status: string;
  days_until: number;
};

type TopRecipient = {
  investor_id: string;
  gift_count: number;
  total_value_rupees: number;
  sent_count: number;
  last_gift_at: string | null;
};

type Reaction = {
  id: string;
  gift_id: string;
  reaction_received: boolean;
  reaction_summary: string | null;
  photo_received: boolean;
  recorded_at: string;
};

function fmtRupees(n: number | null | undefined): string {
  if (!n && n !== 0) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return s; }
}

function fmtDateTime(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

function shortId(s: string | null | undefined): string {
  if (!s) return '—';
  return String(s).slice(0, 8);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [giftsRes, upcomingRes, topRes, reactionsRes] = await Promise.all([
    sb.rpc('list_gifts_r1837'),
    sb.rpc('upcoming_anniversaries_r1837', { p_days: 60 }),
    sb.rpc('top_gift_recipients_r1837'),
    sb.rpc('list_reactions_r1837', { p_gift_id: null }),
  ]);

  const gifts: Gift[] = (giftsRes.data as Gift[] | null) ?? [];
  const upcoming: Upcoming[] = (upcomingRes.data as Upcoming[] | null) ?? [];
  const top: TopRecipient[] = (topRes.data as TopRecipient[] | null) ?? [];
  const reactions: Reaction[] = (reactionsRes.data as Reaction[] | null) ?? [];

  const totalGifts = gifts.length;
  const sentGifts = gifts.filter((g) => g.status === 'sent').length;
  const plannedGifts = gifts.filter((g) => g.status === 'planned').length;
  const totalSpend = gifts.reduce((acc, g) => acc + (g.gift_value_rupees || 0), 0);

  const giftCols: Column<Gift>[] = [
    { key: 'anniversary_date', header: 'Anniversary', render: (r: any) => fmtDate(r.anniversary_date) },
    { key: 'investor_id', header: 'Investor', render: (r: any) => shortId(r.investor_id) },
    { key: 'gift_type', header: 'Type', render: (r: any) => String(r.gift_type).replace(/_/g, ' ') },
    { key: 'gift_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.gift_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDateTime(r.sent_at) },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => String(r.reaction_count ?? 0) },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '—' },
  ];

  const upcomingCols: Column<Upcoming>[] = [
    { key: 'anniversary_date', header: 'Anniversary', render: (r: any) => fmtDate(r.anniversary_date) },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until) },
    { key: 'investor_id', header: 'Investor', render: (r: any) => shortId(r.investor_id) },
    { key: 'gift_type', header: 'Planned Gift', render: (r: any) => String(r.gift_type).replace(/_/g, ' ') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
  ];

  const topCols: Column<TopRecipient>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => shortId(r.investor_id) },
    { key: 'gift_count', header: 'Gifts', render: (r: any) => String(r.gift_count) },
    { key: 'sent_count', header: 'Sent', render: (r: any) => String(r.sent_count) },
    { key: 'total_value_rupees', header: 'Total Spend', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'last_gift_at', header: 'Last Gift', render: (r: any) => fmtDateTime(r.last_gift_at) },
  ];

  const reactionCols: Column<Reaction>[] = [
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDateTime(r.recorded_at) },
    { key: 'gift_id', header: 'Gift', render: (r: any) => shortId(r.gift_id) },
    { key: 'reaction_received', header: 'Reacted', render: (r: any) => (r.reaction_received ? 'yes' : 'no') },
    { key: 'photo_received', header: 'Photo', render: (r: any) => (r.photo_received ? 'yes' : 'no') },
    { key: 'reaction_summary', header: 'Summary', render: (r: any) => r.reaction_summary ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Investor Anniversary Gift Ledger
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track anniversary gifts & founder gestures for big investors. Relationship maintenance ledger.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Gifts</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalGifts}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Sent</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{sentGifts}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Planned</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{plannedGifts}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Spend</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalSpend)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Upcoming Anniversaries (next 60 days)
        </h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Gift Ledger</h2>
        <DataTable
          rows={gifts}
          columns={giftCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Gift Recipients</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.investor_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Reaction Log</h2>
        <DataTable
          rows={reactions}
          columns={reactionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
