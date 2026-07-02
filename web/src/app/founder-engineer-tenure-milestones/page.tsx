import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: Record<string, any> = {};
  let eligible: any[] = [];
  let recent: any[] = [];
  let pending: any[] = [];
  let queue: any[] = [];

  try {
    const r = await sb.rpc('founder_tenure_milestone_kpis');
    kpis = (r.data as any) || {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_tenure_milestone_eligible');
    eligible = (r.data as any[]) || [];
  } catch { eligible = []; }

  try {
    const r = await sb.rpc('founder_tenure_milestone_recent');
    recent = (r.data as any[]) || [];
  } catch { recent = []; }

  try {
    const r = await sb.rpc('founder_tenure_milestone_pending');
    pending = (r.data as any[]) || [];
  } catch { pending = []; }

  try {
    const r = await sb.rpc('founder_tenure_milestone_queue');
    queue = (r.data as any[]) || [];
  } catch { queue = []; }

  const kpiCards: Kpi[] = [
    { label: 'Total awards', value: kpis.total_awards ?? '-' },
    { label: 'Pending', value: kpis.pending ?? '-' },
    { label: 'Approved', value: kpis.approved ?? '-' },
    { label: 'Paid', value: kpis.paid ?? '-' },
    { label: 'Skipped', value: kpis.skipped ?? '-' },
    { label: '90-day awards', value: kpis.day_90_count ?? '-' },
    { label: '1-year awards', value: kpis.year_1_count ?? '-' },
    { label: '2-year awards', value: kpis.year_2_count ?? '-' },
    { label: '5-year awards', value: kpis.year_5_count ?? '-' },
    { label: 'Total bonus', value: fmtRupees(kpis.total_bonus_rupees) },
    { label: 'Paid bonus', value: fmtRupees(kpis.paid_bonus_rupees) },
    { label: 'Pending bonus', value: fmtRupees(kpis.pending_bonus_rupees) },
    { label: 'Emails sent', value: kpis.emails_sent ?? '-' },
    { label: 'Notes written', value: kpis.notes_written ?? '-' },
    { label: 'Queue size', value: kpis.queue_size ?? '-' },
    { label: 'Queue dispatched', value: kpis.queue_dispatched ?? '-' },
  ];

  const eligibleCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '-' },
    { key: 'tenure_days', header: 'Tenure (days)', render: (r: any) => r.tenure_days ?? '-' },
    { key: 'next_milestone', header: 'Next milestone', render: (r: any) => r.next_milestone ?? '-' },
    { key: 'already_awarded_kinds', header: 'Already awarded', render: (r: any) => r.already_awarded_kinds || '-' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '-' },
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind ?? '-' },
    { key: 'tenure_days', header: 'Tenure (d)', render: (r: any) => r.tenure_days ?? '-' },
    { key: 'bonus_amount_rupees', header: 'Bonus', render: (r: any) => fmtRupees(r.bonus_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'email_sent', header: 'Email', render: (r: any) => (r.email_sent ? 'sent' : '-') },
    { key: 'has_note', header: 'Note', render: (r: any) => (r.has_note ? 'yes' : '-') },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '-' },
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind ?? '-' },
    { key: 'tenure_days', header: 'Tenure (d)', render: (r: any) => r.tenure_days ?? '-' },
    { key: 'bonus_amount_rupees', header: 'Bonus', render: (r: any) => fmtRupees(r.bonus_amount_rupees) },
    { key: 'created_at', header: 'Created', render: (r: any) => (r.created_at ? String(r.created_at).slice(0, 10) : '-') },
  ];

  const queueCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '-' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'payout_status', header: 'Payout', render: (r: any) => r.payout_status ?? '-' },
    { key: 'queued_at', header: 'Queued', render: (r: any) => (r.queued_at ? String(r.queued_at).slice(0, 10) : '-') },
    { key: 'dispatched_at', header: 'Dispatched', render: (r: any) => (r.dispatched_at ? String(r.dispatched_at).slice(0, 10) : '-') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Tenure Milestone Awards</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Celebrate engineer milestones (90d, 1yr, 2yr, 5yr) with auto-bonus, recognition email, and a personal founder note.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpiCards.map((k) => (
          <div key={k.label} style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fafafa' }}>
            <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Eligible engineers</h2>
        <DataTable rows={eligible} columns={eligibleCols} rowKey={(r: any) => r.engineer_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pending approval</h2>
        <DataTable rows={pending} columns={pendingCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent awards</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Bonus payout queue</h2>
        <DataTable rows={queue} columns={queueCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
