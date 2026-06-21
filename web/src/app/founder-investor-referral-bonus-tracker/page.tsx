import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined) {
  if (!n) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined) {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleString('en-IN');
  } catch {
    return String(d);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [bonusesRes, summaryRes, topRes, commsRes] = await Promise.all([
    sb.rpc('list_bonuses_r1733'),
    sb.rpc('bonus_summary_r1733'),
    sb.rpc('top_referring_investors_r1733'),
    sb.rpc('list_communications_r1733', { p_bonus_id: null }),
  ]);

  const bonuses: any[] = Array.isArray(bonusesRes.data) ? bonusesRes.data : [];
  const summaryRow: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const summary = summaryRow ?? {};
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const comms: any[] = Array.isArray(commsRes.data) ? commsRes.data : [];

  const err =
    bonusesRes.error?.message ||
    summaryRes.error?.message ||
    topRes.error?.message ||
    commsRes.error?.message ||
    null;

  const bonusColumns: Column<any>[] = [
    { key: 'referring_email', header: 'Referring Investor', render: (r: any) => r.referring_email ?? '—' },
    { key: 'referred_email', header: 'Referred Investor', render: (r: any) => r.referred_email ?? '—' },
    { key: 'referral_date', header: 'Referral Date', render: (r: any) => r.referral_date ?? '—' },
    { key: 'funded_at', header: 'Funded At', render: (r: any) => fmtDate(r.funded_at) },
    { key: 'funding_amount_rupees', header: 'Funding', render: (r: any) => rupees(r.funding_amount_rupees) },
    { key: 'bonus_amount_rupees', header: 'Bonus', render: (r: any) => rupees(r.bonus_amount_rupees) },
    { key: 'bonus_status', header: 'Status', render: (r: any) => r.bonus_status ?? '—' },
    { key: 'paid_at', header: 'Paid At', render: (r: any) => fmtDate(r.paid_at) },
  ];

  const topColumns: Column<any>[] = [
    { key: 'referring_email', header: 'Referring Investor', render: (r: any) => r.referring_email ?? '—' },
    { key: 'referral_count', header: 'Referrals', render: (r: any) => String(r.referral_count ?? 0) },
    { key: 'total_funding_rupees', header: 'Total Funding', render: (r: any) => rupees(r.total_funding_rupees) },
    { key: 'total_bonus_rupees', header: 'Total Bonus', render: (r: any) => rupees(r.total_bonus_rupees) },
    { key: 'paid_bonus_rupees', header: 'Paid Bonus', render: (r: any) => rupees(r.paid_bonus_rupees) },
  ];

  const commColumns: Column<any>[] = [
    { key: 'message_type', header: 'Type', render: (r: any) => r.message_type ?? '—' },
    { key: 'sent_at', header: 'Sent At', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'message', header: 'Message', render: (r: any) => (r.message ? String(r.message).slice(0, 120) : '—') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Investor Referral Bonus Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round r1733 · track bonuses per intro that resulted in funding (bonus &gt;= 0).
      </p>

      {err ? (
        <div
          style={{
            padding: 12,
            background: '#fff5f5',
            border: '1px solid #fed7d7',
            borderRadius: 8,
            marginBottom: 16,
            color: '#c53030',
          }}
        >
          Error loading data: {err}
        </div>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
            gap: 12,
          }}
        >
          <Stat label="Total Referrals" value={String(summary.total_bonuses ?? 0)} />
          <Stat label="Pending" value={String(summary.pending_count ?? 0)} />
          <Stat label="Approved" value={String(summary.approved_count ?? 0)} />
          <Stat label="Paid" value={String(summary.paid_count ?? 0)} />
          <Stat label="Declined" value={String(summary.declined_count ?? 0)} />
          <Stat label="Total Funding" value={rupees(summary.total_funding_rupees)} />
          <Stat label="Bonus Paid" value={rupees(summary.total_bonus_paid_rupees)} />
          <Stat label="Bonus Outstanding" value={rupees(summary.total_bonus_pending_rupees)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Referral Bonuses ({bonuses.length})
        </h2>
        <DataTable
          rows={bonuses}
          columns={bonusColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Top Referring Investors (referrals &gt;= 1)
        </h2>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.referring_investor_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Communications ({comms.length})
        </h2>
        <DataTable
          rows={comms}
          columns={commColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        padding: 12,
        background: '#f9fafb',
        border: '1px solid #e5e7eb',
        borderRadius: 8,
      }}
    >
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600 }}>{value}</div>
    </div>
  );
}
