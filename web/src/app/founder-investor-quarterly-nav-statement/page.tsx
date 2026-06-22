import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type NavRow = {
  id: string;
  investor_id: string;
  quarter_label: string;
  invested_principal_rupees: number;
  current_nav_rupees: number;
  irr_pct: number;
  status: string;
  calculated_at: string | null;
  sent_at: string | null;
  created_at: string;
};

type RecentNavRow = {
  id: string;
  investor_id: string;
  quarter_label: string;
  current_nav_rupees: number;
  irr_pct: number;
  status: string;
  created_at: string;
};

type ActionRow = {
  id: string;
  nav_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

function fmtRupees(v: number | null | undefined) {
  if (v == null) return '-';
  return 'Rs ' + Number(v).toLocaleString('en-IN');
}

function fmtDate(v: string | null | undefined) {
  if (!v) return '-';
  try { return new Date(v).toLocaleString('en-IN'); } catch { return v; }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [navsRes, recentNavsRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_navs_r1945'),
    sb.rpc('recent_navs_r1945'),
    sb.rpc('recent_actions_r1945'),
  ]);

  const navs: NavRow[] = (navsRes.data as NavRow[]) ?? [];
  const recentNavs: RecentNavRow[] = (recentNavsRes.data as RecentNavRow[]) ?? [];
  const recentActions: ActionRow[] = (recentActionsRes.data as ActionRow[]) ?? [];

  const totalInvested = navs.reduce((s, r) => s + (r.invested_principal_rupees || 0), 0);
  const totalNav = navs.reduce((s, r) => s + (r.current_nav_rupees || 0), 0);
  const draftCount = navs.filter(r => r.status === 'draft').length;
  const disputedCount = navs.filter(r => r.status === 'disputed').length;

  const navColumns: Column<NavRow>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'invested_principal_rupees', header: 'Invested', render: (r: any) => fmtRupees(r.invested_principal_rupees) },
    { key: 'current_nav_rupees', header: 'Current NAV', render: (r: any) => fmtRupees(r.current_nav_rupees) },
    { key: 'irr_pct', header: 'IRR percent', render: (r: any) => (r.irr_pct == null ? '-' : Number(r.irr_pct).toFixed(2)) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'calculated_at', header: 'Calculated', render: (r: any) => fmtDate(r.calculated_at) },
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDate(r.sent_at) },
  ];

  const recentNavColumns: Column<RecentNavRow>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'current_nav_rupees', header: 'NAV', render: (r: any) => fmtRupees(r.current_nav_rupees) },
    { key: 'irr_pct', header: 'IRR percent', render: (r: any) => (r.irr_pct == null ? '-' : Number(r.irr_pct).toFixed(2)) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'nav_id', header: 'NAV', render: (r: any) => String(r.nav_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>
        Investor Quarterly NAV Statement
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track quarterly NAV per investor, send statements, and record acknowledgements or disputes.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Invested</div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(totalInvested)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Current NAV</div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(totalNav)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Draft statements</div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{draftCount}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Disputed</div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{disputedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All NAV statements</h2>
        <DataTable<NavRow>
          rows={navs}
          columns={navColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent NAV statements</h2>
        <DataTable<RecentNavRow>
          rows={recentNavs}
          columns={recentNavColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent NAV actions</h2>
        <DataTable<ActionRow>
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
