import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Bonus = {
  id: string;
  engineer_user_id: string;
  quarter_label: string;
  base_bonus_rupees: number;
  performance_bonus_rupees: number;
  total_bonus_rupees: number;
  status: string;
  calculated_at: string | null;
  paid_at: string | null;
  created_at: string;
};

type Earner = {
  engineer_user_id: string;
  total_paid_rupees: number;
  bonus_count: number;
};

type Action = {
  id: string;
  bonus_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  amount_rupees: number | null;
  notes_md: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return String(s);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [bonusesRes, earnersRes, actionsRes] = await Promise.all([
    sb.rpc('list_bonuses_r1984'),
    sb.rpc('top_earners_r1984'),
    sb.rpc('recent_actions_r1984'),
  ]);

  const bonuses: Bonus[] = (bonusesRes.data as Bonus[] | null) ?? [];
  const earners: Earner[] = (earnersRes.data as Earner[] | null) ?? [];
  const actions: Action[] = (actionsRes.data as Action[] | null) ?? [];

  const totalCalculated = bonuses.reduce((s, b) => s + Number(b.total_bonus_rupees || 0), 0);
  const paidCount = bonuses.filter((b) => b.status === 'paid').length;
  const disputedCount = bonuses.filter((b) => b.status === 'disputed').length;

  const bonusCols: Column<Bonus>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'base_bonus_rupees', header: 'Base', render: (r: any) => fmtRupees(r.base_bonus_rupees) },
    { key: 'performance_bonus_rupees', header: 'Performance', render: (r: any) => fmtRupees(r.performance_bonus_rupees) },
    { key: 'total_bonus_rupees', header: 'Total', render: (r: any) => fmtRupees(r.total_bonus_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'calculated_at', header: 'Calculated', render: (r: any) => fmtDate(r.calculated_at) },
    { key: 'paid_at', header: 'Paid', render: (r: any) => fmtDate(r.paid_at) },
  ];

  const earnerCols: Column<Earner>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_paid_rupees', header: 'Total Paid', render: (r: any) => fmtRupees(r.total_paid_rupees) },
    { key: 'bonus_count', header: 'Bonus Count', render: (r: any) => String(r.bonus_count ?? 0) },
  ];

  const actionCols: Column<Action>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'bonus_id', header: 'Bonus', render: (r: any) => String(r.bonus_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Quarter Bonus Calculator
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round 1984 founder console for calculating and tracking engineer quarterly bonuses.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Bonus rows</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{bonuses.length}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Total calculated</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(totalCalculated)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Paid</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{paidCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Disputed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{disputedCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Bonuses</h2>
        <DataTable
          rows={bonuses}
          columns={bonusCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Earners</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Engineers ranked by total paid and approved bonus value.
        </p>
        <DataTable
          rows={earners}
          columns={earnerCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Most recent calculate, approve, dispute, adjust, pay and void events across all bonuses.
        </p>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
