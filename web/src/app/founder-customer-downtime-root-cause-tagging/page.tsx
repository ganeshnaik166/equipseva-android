import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type EpisodeRow = {
  id: string;
  customer_org_name: string;
  equipment_label: string;
  equipment_serial: string | null;
  episode_started_at: string;
  episode_ended_at: string | null;
  downtime_hours: number | null;
  root_cause_category: string;
  severity: string;
  revenue_impact_rupees: number;
  resolution_status: string;
  tagged_by_email: string;
  tagged_at: string;
};

type CauseSummary = {
  root_cause_category: string;
  episode_count: number;
  total_downtime_hours: number;
  total_revenue_impact_rupees: number;
  open_count: number;
  critical_count: number;
};

type AffectedCustomer = {
  customer_org_name: string;
  episode_count: number;
  total_downtime_hours: number;
  total_revenue_impact_rupees: number;
  last_episode_at: string;
};

type LearningRow = {
  id: string;
  episode_id: string | null;
  root_cause_category: string;
  learning_title: string;
  prevention_action: string;
  action_owner_email: string;
  action_status: string;
  estimated_episodes_prevented: number;
  logged_by_email: string;
  logged_at: string;
};

type Kpis = {
  total_episodes: number;
  open_episodes: number;
  critical_episodes: number;
  total_downtime_hours: number;
  total_revenue_impact_rupees: number;
  total_learnings: number;
  pending_actions: number;
};

function fmtDate(s: string | null) {
  if (!s) return '-';
  return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function FounderCustomerDowntimeRootCauseTaggingPage() {
  const supabase = await getSupabaseServerClient();

  const [episodesRes, summaryRes, customersRes, learningsRes, kpisRes] = await Promise.all([
    supabase.rpc('r2348_list_downtime_episodes'),
    supabase.rpc('r2348_root_cause_summary'),
    supabase.rpc('r2348_top_affected_customers'),
    supabase.rpc('r2348_list_prevention_learnings'),
    supabase.rpc('r2348_kpis'),
  ]);

  const episodes: EpisodeRow[] = (episodesRes.data as EpisodeRow[]) ?? [];
  const summary: CauseSummary[] = (summaryRes.data as CauseSummary[]) ?? [];
  const customers: AffectedCustomer[] = (customersRes.data as AffectedCustomer[]) ?? [];
  const learnings: LearningRow[] = (learningsRes.data as LearningRow[]) ?? [];
  const kpis: Kpis = (kpisRes.data as Kpis[] | null)?.[0] ?? {
    total_episodes: 0,
    open_episodes: 0,
    critical_episodes: 0,
    total_downtime_hours: 0,
    total_revenue_impact_rupees: 0,
    total_learnings: 0,
    pending_actions: 0,
  };

  const episodeCols: Column<EpisodeRow>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r: EpisodeRow) => r.customer_org_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: EpisodeRow) => r.equipment_label + (r.equipment_serial ? ' / ' + r.equipment_serial : '') },
    { key: 'episode_started_at', header: 'Started', render: (r: EpisodeRow) => fmtDate(r.episode_started_at) },
    { key: 'downtime_hours', header: 'Downtime (hrs)', render: (r: EpisodeRow) => r.downtime_hours != null ? Number(r.downtime_hours).toFixed(1) : '-' },
    { key: 'root_cause_category', header: 'Root Cause', render: (r: EpisodeRow) => r.root_cause_category },
    { key: 'severity', header: 'Severity', render: (r: EpisodeRow) => r.severity },
    { key: 'revenue_impact_rupees', header: 'Revenue Impact', render: (r: EpisodeRow) => fmtRupees(r.revenue_impact_rupees) },
    { key: 'resolution_status', header: 'Status', render: (r: EpisodeRow) => r.resolution_status },
    { key: 'tagged_by_email', header: 'Tagged By', render: (r: EpisodeRow) => r.tagged_by_email },
  ];

  const summaryCols: Column<CauseSummary>[] = [
    { key: 'root_cause_category', header: 'Root Cause', render: (r: CauseSummary) => r.root_cause_category },
    { key: 'episode_count', header: 'Episodes', render: (r: CauseSummary) => String(r.episode_count) },
    { key: 'total_downtime_hours', header: 'Total Downtime (hrs)', render: (r: CauseSummary) => Number(r.total_downtime_hours).toFixed(1) },
    { key: 'total_revenue_impact_rupees', header: 'Revenue Impact', render: (r: CauseSummary) => fmtRupees(r.total_revenue_impact_rupees) },
    { key: 'open_count', header: 'Open', render: (r: CauseSummary) => String(r.open_count) },
    { key: 'critical_count', header: 'Critical', render: (r: CauseSummary) => String(r.critical_count) },
  ];

  const customerCols: Column<AffectedCustomer>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r: AffectedCustomer) => r.customer_org_name },
    { key: 'episode_count', header: 'Episodes', render: (r: AffectedCustomer) => String(r.episode_count) },
    { key: 'total_downtime_hours', header: 'Downtime (hrs)', render: (r: AffectedCustomer) => Number(r.total_downtime_hours).toFixed(1) },
    { key: 'total_revenue_impact_rupees', header: 'Revenue Impact', render: (r: AffectedCustomer) => fmtRupees(r.total_revenue_impact_rupees) },
    { key: 'last_episode_at', header: 'Last Episode', render: (r: AffectedCustomer) => fmtDate(r.last_episode_at) },
  ];

  const learningCols: Column<LearningRow>[] = [
    { key: 'logged_at', header: 'Logged', render: (r: LearningRow) => fmtDate(r.logged_at) },
    { key: 'root_cause_category', header: 'Cause', render: (r: LearningRow) => r.root_cause_category },
    { key: 'learning_title', header: 'Learning', render: (r: LearningRow) => r.learning_title },
    { key: 'prevention_action', header: 'Prevention Action', render: (r: LearningRow) => r.prevention_action },
    { key: 'action_owner_email', header: 'Owner', render: (r: LearningRow) => r.action_owner_email },
    { key: 'action_status', header: 'Status', render: (r: LearningRow) => r.action_status },
    { key: 'estimated_episodes_prevented', header: 'Est. Prevented', render: (r: LearningRow) => String(r.estimated_episodes_prevented) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Customer Downtime Root-Cause Tagging</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track customer equipment downtime episodes, tag root causes & log prevention learnings.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, background: '#f5f5f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Episodes</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpis.total_episodes}</div>
        </div>
        <div style={{ padding: 16, background: '#fff4e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpis.open_episodes}</div>
        </div>
        <div style={{ padding: 16, background: '#ffe5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Critical</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpis.critical_episodes}</div>
        </div>
        <div style={{ padding: 16, background: '#f5f5f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Downtime (hrs)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{Number(kpis.total_downtime_hours).toFixed(1)}</div>
        </div>
        <div style={{ padding: 16, background: '#f5f5f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Revenue Impact</div>
          <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtRupees(kpis.total_revenue_impact_rupees)}</div>
        </div>
        <div style={{ padding: 16, background: '#e5f5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Learnings</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpis.total_learnings}</div>
        </div>
        <div style={{ padding: 16, background: '#fff4e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending Actions</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{kpis.pending_actions}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Root-Cause Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No root-cause summary yet."
          rowKey={(r: CauseSummary) => r.root_cause_category}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Affected Customers</h2>
        <DataTable
          rows={customers}
          columns={customerCols}
          emptyMessage="No affected customers yet."
          rowKey={(r: AffectedCustomer) => r.customer_org_name}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Downtime Episodes</h2>
        <DataTable
          rows={episodes}
          columns={episodeCols}
          emptyMessage="No downtime episodes tagged yet."
          rowKey={(r: EpisodeRow) => r.id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Prevention Learnings</h2>
        <DataTable
          rows={learnings}
          columns={learningCols}
          emptyMessage="No prevention learnings logged yet."
          rowKey={(r: LearningRow) => r.id}
        />
      </section>
    </main>
  );
}
