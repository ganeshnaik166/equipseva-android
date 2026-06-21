import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return '0';
  return Math.round(v).toLocaleString('en-IN');
}
function fmtRupees(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return 'Rs 0';
  return 'Rs ' + Math.round(v).toLocaleString('en-IN');
}
function fmtPct(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return '0%';
  return v.toFixed(2) + '%';
}
function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(String(s)).toLocaleString('en-IN'); } catch { return String(s); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let k: any = {};
  let rights: any[] = [];
  let overdue: any[] = [];
  let upcoming: any[] = [];
  let followups: any[] = [];
  let breakdown: any[] = [];
  let queue: any[] = [];

  try {
    const r = await sb.rpc('rpc_iprr_summary_kpis');
    k = (r.data as any) ?? {};
  } catch { k = {}; }
  try {
    const r = await sb.rpc('rpc_iprr_list_rights');
    rights = (r.data as any[]) ?? [];
  } catch { rights = []; }
  try {
    const r = await sb.rpc('rpc_iprr_overdue');
    overdue = (r.data as any[]) ?? [];
  } catch { overdue = []; }
  try {
    const r = await sb.rpc('rpc_iprr_upcoming_deadlines');
    upcoming = (r.data as any[]) ?? [];
  } catch { upcoming = []; }
  try {
    const r = await sb.rpc('rpc_iprr_recent_followups');
    followups = (r.data as any[]) ?? [];
  } catch { followups = []; }
  try {
    const r = await sb.rpc('rpc_iprr_status_breakdown');
    breakdown = (r.data as any[]) ?? [];
  } catch { breakdown = []; }
  try {
    const r = await sb.rpc('rpc_iprr_action_queue');
    queue = (r.data as any[]) ?? [];
  } catch { queue = []; }

  const kpis: Kpi[] = [
    { label: 'Investors tracked', value: fmtInt(k.investor_count) },
    { label: 'Pending elections', value: fmtInt(k.pending_count) },
    { label: 'Exercised', value: fmtInt(k.exercised_count) },
    { label: 'Waived', value: fmtInt(k.waived_count) },
    { label: 'Partial', value: fmtInt(k.partial_count) },
    { label: 'Expired', value: fmtInt(k.expired_count) },
    { label: 'Total pro-rata %', value: fmtPct(k.total_pro_rata_pct) },
    { label: 'Total pro-rata amount', value: fmtRupees(k.total_pro_rata_amount) },
    { label: 'Exercised amount', value: fmtRupees(k.total_exercised_amount) },
    { label: 'Waived amount', value: fmtRupees(k.total_waived_amount) },
    { label: 'Overdue', value: fmtInt(k.overdue_count) },
    { label: 'Due in 7 days', value: fmtInt(k.due_7d_count) },
    { label: 'Never contacted', value: fmtInt(k.never_contacted) },
    { label: 'Avg reminders', value: String(k.avg_reminder_count ?? '0') },
    { label: 'Legal notice pending', value: fmtInt(k.legal_notice_pending) },
    { label: 'Exercise rate', value: fmtPct(k.exercise_rate_pct) },
  ];

  const rightsCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'investor_org', header: 'Org', render: (r: any) => String(r.investor_org ?? '—') },
    { key: 'pro_rata_pct', header: 'Pro-rata %', render: (r: any) => fmtPct(r.pro_rata_pct) },
    { key: 'pro_rata_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.pro_rata_amount_rupees) },
    { key: 'exercised_amount_rupees', header: 'Exercised', render: (r: any) => fmtRupees(r.exercised_amount_rupees) },
    { key: 'current_round_label', header: 'Round', render: (r: any) => String(r.current_round_label ?? '—') },
    { key: 'election_status', header: 'Status', render: (r: any) => String(r.election_status ?? '—') },
    { key: 'election_deadline', header: 'Deadline', render: (r: any) => fmtDate(r.election_deadline) },
    { key: 'days_to_deadline', header: 'Days left', render: (r: any) => String(r.days_to_deadline ?? '—') },
    { key: 'reminder_count', header: 'Reminders', render: (r: any) => fmtInt(r.reminder_count) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'investor_email', header: 'Email', render: (r: any) => String(r.investor_email ?? '—') },
    { key: 'pro_rata_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.pro_rata_amount_rupees) },
    { key: 'election_deadline', header: 'Deadline', render: (r: any) => fmtDate(r.election_deadline) },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => String(r.days_overdue ?? '—') },
    { key: 'reminder_count', header: 'Reminders', render: (r: any) => fmtInt(r.reminder_count) },
    { key: 'notice_sent_at', header: 'Notice sent', render: (r: any) => fmtDate(r.notice_sent_at) },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'current_round_label', header: 'Round', render: (r: any) => String(r.current_round_label ?? '—') },
    { key: 'pro_rata_pct', header: 'Pro-rata %', render: (r: any) => fmtPct(r.pro_rata_pct) },
    { key: 'pro_rata_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.pro_rata_amount_rupees) },
    { key: 'election_deadline', header: 'Deadline', render: (r: any) => fmtDate(r.election_deadline) },
    { key: 'days_remaining', header: 'Days left', render: (r: any) => String(r.days_remaining ?? '—') },
    { key: 'reminder_count', header: 'Reminders', render: (r: any) => fmtInt(r.reminder_count) },
  ];

  const followupCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '—') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '—') },
    { key: 'next_action_at', header: 'Next action', render: (r: any) => fmtDate(r.next_action_at) },
    { key: 'founder_note', header: 'Note', render: (r: any) => String(r.founder_note ?? '—') },
    { key: 'created_at', header: 'Logged', render: (r: any) => fmtDate(r.created_at) },
  ];

  const queueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'reason', header: 'Recommended action', render: (r: any) => String(r.reason ?? '—') },
    { key: 'pro_rata_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.pro_rata_amount_rupees) },
    { key: 'election_deadline', header: 'Deadline', render: (r: any) => fmtDate(r.election_deadline) },
    { key: 'reminder_count', header: 'Reminders', render: (r: any) => fmtInt(r.reminder_count) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>Investor pro-rata rights tracker</h1>
      <p style={{ color: '#555', marginBottom: 18 }}>
        Per-investor pro-rata percentage, current-round allocation, election deadline and founder follow-up.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((kpi) => (
          <div key={kpi.label} style={{ border: '1px solid #e5e7eb', borderRadius: 10, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{kpi.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{kpi.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Action queue</h2>
        <DataTable rows={queue} columns={queueCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>All pro-rata rights</h2>
        <DataTable rows={rights} columns={rightsCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Overdue elections</h2>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Upcoming deadlines (30 days)</h2>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent follow-ups</h2>
        <DataTable rows={followups} columns={followupCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 8 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Status breakdown</h2>
        <ul style={{ fontSize: 14, color: '#374151' }}>
          {breakdown.map((b: any, i: number) => (
            <li key={i}>
              {String(b.election_status ?? '—')}: {fmtInt(b.investor_count)} investors, {fmtRupees(b.total_amount_rupees)} ({fmtPct(b.pct_of_round)} of round)
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
