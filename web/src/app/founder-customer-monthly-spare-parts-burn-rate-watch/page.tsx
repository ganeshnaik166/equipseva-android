import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Snapshot = {
  id: string;
  snapshot_month: string;
  customer_org_name: string;
  equipment_label: string;
  equipment_category: string;
  parts_consumed_count: number;
  parts_burn_rupees: number;
  monthly_budget_rupees: number;
  variance_rupees: number;
  variance_pct: number;
  burn_status: string;
  top_part_name: string | null;
  root_cause_code: string;
  corrective_action: string | null;
  owner_engineer_email: string | null;
};

type Focus = {
  customer_org_name: string;
  equipment_label: string;
  parts_burn_rupees: number;
  variance_rupees: number;
  variance_pct: number;
  burn_status: string;
  root_cause_code: string;
};

type Funnel = {
  burn_status: string;
  equipment_count: number;
  total_burn_rupees: number;
  total_variance_rupees: number;
};

type Trend = {
  snapshot_month: string;
  equipment_count: number;
  total_burn_rupees: number;
  total_budget_rupees: number;
  total_variance_rupees: number;
};

type Summary = {
  total_equipment: number;
  total_burn_rupees: number;
  total_budget_rupees: number;
  total_variance_rupees: number;
  over_or_critical: number;
  open_actions: number;
  completed_actions: number;
};

type OwnerLoad = {
  owner_engineer_email: string;
  equipment_count: number;
  total_variance_rupees: number;
  open_actions: number;
};

type RootCause = {
  root_cause_code: string;
  equipment_count: number;
  total_variance_rupees: number;
  avg_variance_pct: number;
};

type Action = {
  id: string;
  customer_org_name: string;
  equipment_label: string;
  action_title: string;
  action_owner_email: string;
  target_savings_rupees: number;
  realised_savings_rupees: number;
  status: string;
  due_at: string;
  closed_at: string | null;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + n.toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n == null) return '-';
  return n.toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [snapsRes, focusRes, funnelRes, monthRes, quarterRes, summaryRes, ownerRes, causeRes, actionsRes] = await Promise.all([
    supabase.rpc('list_burn_snapshots_r2672'),
    supabase.rpc('top_burn_focus_r2672'),
    supabase.rpc('burn_status_funnel_r2672'),
    supabase.rpc('monthly_burn_trend_r2672'),
    supabase.rpc('quarterly_burn_trend_r2672'),
    supabase.rpc('burn_summary_r2672'),
    supabase.rpc('owner_load_r2672'),
    supabase.rpc('root_cause_breakdown_r2672'),
    supabase.rpc('list_corrective_actions_r2672'),
  ]);

  const snapshots = (snapsRes.data ?? []) as Snapshot[];
  const focus = (focusRes.data ?? []) as Focus[];
  const funnel = (funnelRes.data ?? []) as Funnel[];
  const monthly = (monthRes.data ?? []) as Trend[];
  const quarterly = (quarterRes.data ?? []) as { quarter_start: string; equipment_count: number; total_burn_rupees: number; total_variance_rupees: number }[];
  const summary = ((summaryRes.data ?? [])[0] ?? null) as Summary | null;
  const owners = (ownerRes.data ?? []) as OwnerLoad[];
  const causes = (causeRes.data ?? []) as RootCause[];
  const actions = (actionsRes.data ?? []) as Action[];

  return (
    <div style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '4px' }}>
        Customer Monthly Spare Parts Burn Rate Watch
      </h1>
      <p style={{ color: '#666', marginBottom: '20px' }}>
        Round r2672 · equipment × parts burn × budget × variance × root cause × corrective action
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '28px' }}>
        <Kpi label="Equipment tracked" value={String(summary?.total_equipment ?? 0)} />
        <Kpi label="Total burn" value={rupees(summary?.total_burn_rupees ?? 0)} />
        <Kpi label="Total budget" value={rupees(summary?.total_budget_rupees ?? 0)} />
        <Kpi label="Net variance" value={rupees(summary?.total_variance_rupees ?? 0)} />
        <Kpi label="Over & critical" value={String(summary?.over_or_critical ?? 0)} />
        <Kpi label="Open actions" value={String(summary?.open_actions ?? 0)} />
        <Kpi label="Completed actions" value={String(summary?.completed_actions ?? 0)} />
      </div>

      <Section title="Top burn focus (variance >= watch)">
        <DataTable
          rows={focus}
          rowKey={(r, i) => String(r.equipment_label + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: Focus) => r.customer_org_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: Focus) => r.equipment_label },
            { key: 'parts_burn_rupees', header: 'Burn', render: (r: Focus) => rupees(r.parts_burn_rupees) },
            { key: 'variance_rupees', header: 'Variance', render: (r: Focus) => rupees(r.variance_rupees) },
            { key: 'variance_pct', header: 'Variance %', render: (r: Focus) => pct(r.variance_pct) },
            { key: 'burn_status', header: 'Status', render: (r: Focus) => r.burn_status },
            { key: 'root_cause_code', header: 'Root cause', render: (r: Focus) => r.root_cause_code },
          ]}
        />
      </Section>

      <Section title="Burn status funnel">
        <DataTable
          rows={funnel}
          rowKey={(r, i) => String(r.burn_status + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'burn_status', header: 'Status', render: (r: Funnel) => r.burn_status },
            { key: 'equipment_count', header: 'Equipment', render: (r: Funnel) => String(r.equipment_count) },
            { key: 'total_burn_rupees', header: 'Total burn', render: (r: Funnel) => rupees(r.total_burn_rupees) },
            { key: 'total_variance_rupees', header: 'Total variance', render: (r: Funnel) => rupees(r.total_variance_rupees) },
          ]}
        />
      </Section>

      <Section title="Monthly burn trend">
        <DataTable
          rows={monthly}
          rowKey={(r, i) => String(r.snapshot_month + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'snapshot_month', header: 'Month', render: (r: Trend) => r.snapshot_month },
            { key: 'equipment_count', header: 'Equipment', render: (r: Trend) => String(r.equipment_count) },
            { key: 'total_burn_rupees', header: 'Burn', render: (r: Trend) => rupees(r.total_burn_rupees) },
            { key: 'total_budget_rupees', header: 'Budget', render: (r: Trend) => rupees(r.total_budget_rupees) },
            { key: 'total_variance_rupees', header: 'Variance', render: (r: Trend) => rupees(r.total_variance_rupees) },
          ]}
        />
      </Section>

      <Section title="Quarterly burn trend">
        <DataTable
          rows={quarterly}
          rowKey={(r, i) => String(r.quarter_start + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'quarter_start', header: 'Quarter', render: (r: { quarter_start: string }) => r.quarter_start },
            { key: 'equipment_count', header: 'Equipment', render: (r: { equipment_count: number }) => String(r.equipment_count) },
            { key: 'total_burn_rupees', header: 'Burn', render: (r: { total_burn_rupees: number }) => rupees(r.total_burn_rupees) },
            { key: 'total_variance_rupees', header: 'Variance', render: (r: { total_variance_rupees: number }) => rupees(r.total_variance_rupees) },
          ]}
        />
      </Section>

      <Section title="Owner load (engineers carrying variance)">
        <DataTable
          rows={owners}
          rowKey={(r, i) => String(r.owner_engineer_email + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'owner_engineer_email', header: 'Engineer', render: (r: OwnerLoad) => r.owner_engineer_email },
            { key: 'equipment_count', header: 'Equipment', render: (r: OwnerLoad) => String(r.equipment_count) },
            { key: 'total_variance_rupees', header: 'Variance', render: (r: OwnerLoad) => rupees(r.total_variance_rupees) },
            { key: 'open_actions', header: 'Open actions', render: (r: OwnerLoad) => String(r.open_actions) },
          ]}
        />
      </Section>

      <Section title="Root cause breakdown">
        <DataTable
          rows={causes}
          rowKey={(r, i) => String(r.root_cause_code + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'root_cause_code', header: 'Root cause', render: (r: RootCause) => r.root_cause_code },
            { key: 'equipment_count', header: 'Equipment', render: (r: RootCause) => String(r.equipment_count) },
            { key: 'total_variance_rupees', header: 'Total variance', render: (r: RootCause) => rupees(r.total_variance_rupees) },
            { key: 'avg_variance_pct', header: 'Avg variance %', render: (r: RootCause) => pct(r.avg_variance_pct) },
          ]}
        />
      </Section>

      <Section title="All equipment snapshots">
        <DataTable
          rows={snapshots}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'snapshot_month', header: 'Month', render: (r: Snapshot) => r.snapshot_month },
            { key: 'customer_org_name', header: 'Customer', render: (r: Snapshot) => r.customer_org_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: Snapshot) => r.equipment_label },
            { key: 'equipment_category', header: 'Category', render: (r: Snapshot) => r.equipment_category },
            { key: 'parts_consumed_count', header: 'Parts #', render: (r: Snapshot) => String(r.parts_consumed_count) },
            { key: 'parts_burn_rupees', header: 'Burn', render: (r: Snapshot) => rupees(r.parts_burn_rupees) },
            { key: 'monthly_budget_rupees', header: 'Budget', render: (r: Snapshot) => rupees(r.monthly_budget_rupees) },
            { key: 'variance_rupees', header: 'Variance', render: (r: Snapshot) => rupees(r.variance_rupees) },
            { key: 'variance_pct', header: 'Variance %', render: (r: Snapshot) => pct(r.variance_pct) },
            { key: 'burn_status', header: 'Status', render: (r: Snapshot) => r.burn_status },
            { key: 'top_part_name', header: 'Top part', render: (r: Snapshot) => r.top_part_name ?? '-' },
            { key: 'root_cause_code', header: 'Root cause', render: (r: Snapshot) => r.root_cause_code },
            { key: 'corrective_action', header: 'Action', render: (r: Snapshot) => r.corrective_action ?? '-' },
            { key: 'owner_engineer_email', header: 'Owner', render: (r: Snapshot) => r.owner_engineer_email ?? '-' },
          ]}
        />
      </Section>

      <Section title="Corrective action tracker">
        <DataTable
          rows={actions}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: Action) => r.customer_org_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: Action) => r.equipment_label },
            { key: 'action_title', header: 'Action', render: (r: Action) => r.action_title },
            { key: 'action_owner_email', header: 'Owner', render: (r: Action) => r.action_owner_email },
            { key: 'target_savings_rupees', header: 'Target save', render: (r: Action) => rupees(r.target_savings_rupees) },
            { key: 'realised_savings_rupees', header: 'Realised', render: (r: Action) => rupees(r.realised_savings_rupees) },
            { key: 'status', header: 'Status', render: (r: Action) => r.status },
            { key: 'due_at', header: 'Due', render: (r: Action) => r.due_at },
            { key: 'closed_at', header: 'Closed', render: (r: Action) => r.closed_at ?? '-' },
          ]}
        />
      </Section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '12px 14px', background: '#fff' }}>
      <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>{label}</div>
      <div style={{ fontSize: '18px', fontWeight: 600 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '28px' }}>
      <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '10px' }}>{title}</h2>
      {children}
    </section>
  );
}
