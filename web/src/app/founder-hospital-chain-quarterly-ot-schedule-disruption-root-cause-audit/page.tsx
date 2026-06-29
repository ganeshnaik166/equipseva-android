import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainSummary = {
  chain_name: string;
  quarter_label: string;
  events_total: number;
  cancelled_count: number;
  delayed_count: number;
  avg_delay_minutes: number | null;
  total_revenue_loss_rupees: number;
};

type Pareto = {
  root_cause_category: string;
  event_count: number;
  revenue_loss_rupees: number;
  pct_of_total_loss: number;
};

type SiteOffender = {
  hospital_site: string;
  chain_name: string;
  total_events: number;
  cancellation_rate_pct: number | null;
  total_loss_rupees: number;
  top_root_cause: string | null;
};

type EquipmentHot = {
  equipment_involved: string;
  failure_count: number;
  total_delay_minutes: number;
  total_loss_rupees: number;
  last_event_date: string;
};

type Severity = {
  severity: string;
  event_count: number;
  avg_delay_minutes: number | null;
  total_loss_rupees: number;
  cancellation_count: number;
};

type ActionProgress = {
  chain_name: string;
  open_count: number;
  in_progress_count: number;
  completed_count: number;
  critical_open: number;
  total_estimated_cost: number;
  expected_blended_reduction_pct: number;
};

type PriorityAction = {
  action_title: string;
  chain_name: string;
  hospital_site: string;
  owner_role: string;
  due_date: string;
  status: string;
  founder_priority: string;
  expected_reduction_pct: number;
  estimated_cost: number;
  last_update_note: string | null;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '—';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n == null) return '—';
  return `${n}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, paretoRes, sitesRes, equipRes, sevRes, progressRes, queueRes] = await Promise.all([
    supabase.rpc('chain_quarter_disruption_summary_r2907'),
    supabase.rpc('root_cause_pareto_r2907'),
    supabase.rpc('site_worst_offenders_r2907'),
    supabase.rpc('equipment_failure_hotlist_r2907'),
    supabase.rpc('severity_distribution_r2907'),
    supabase.rpc('corrective_action_progress_r2907'),
    supabase.rpc('founder_priority_action_queue_r2907'),
  ]);

  const summary: ChainSummary[] = (summaryRes.data ?? []) as ChainSummary[];
  const pareto: Pareto[] = (paretoRes.data ?? []) as Pareto[];
  const sites: SiteOffender[] = (sitesRes.data ?? []) as SiteOffender[];
  const equip: EquipmentHot[] = (equipRes.data ?? []) as EquipmentHot[];
  const sev: Severity[] = (sevRes.data ?? []) as Severity[];
  const progress: ActionProgress[] = (progressRes.data ?? []) as ActionProgress[];
  const queue: PriorityAction[] = (queueRes.data ?? []) as PriorityAction[];

  const totalEvents = summary.reduce((s, r) => s + Number(r.events_total || 0), 0);
  const totalLoss = summary.reduce((s, r) => s + Number(r.total_revenue_loss_rupees || 0), 0);
  const totalCancelled = summary.reduce((s, r) => s + Number(r.cancelled_count || 0), 0);
  const criticalOpen = progress.reduce((s, r) => s + Number(r.critical_open || 0), 0);

  return (
    <div style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>
        Hospital Chain Quarterly OT-Schedule Disruption Root-Cause Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Founder console r2907 — quarterly OT disruption forensics across hospital chains: delays, cancellations,
        equipment failures, sterilization & staffing root causes, and the corrective-action queue with founder
        priorities & expected disruption reduction.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12, marginBottom: 28 }}>
        <Kpi label="Total Disruption Events" value={String(totalEvents)} />
        <Kpi label="Cancelled Cases" value={String(totalCancelled)} />
        <Kpi label="Revenue Loss (all chains)" value={rupees(totalLoss)} />
        <Kpi label="Critical Open Actions" value={String(criticalOpen)} />
      </section>

      <Section title="Chain x Quarter Disruption Summary">
        <DataTable<ChainSummary>
          rows={summary}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'quarter_label', header: 'Quarter', render: (r) => r.quarter_label },
            { key: 'events_total', header: 'Events', render: (r) => String(r.events_total) },
            { key: 'cancelled_count', header: 'Cancelled', render: (r) => String(r.cancelled_count) },
            { key: 'delayed_count', header: 'Delayed', render: (r) => String(r.delayed_count) },
            { key: 'avg_delay_minutes', header: 'Avg Delay (min)', render: (r) => r.avg_delay_minutes == null ? '—' : String(r.avg_delay_minutes) },
            { key: 'total_revenue_loss_rupees', header: 'Loss', render: (r) => rupees(r.total_revenue_loss_rupees) },
          ]}
          emptyMessage="No chain-quarter summary rows."
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.chain_name}-${r.quarter_label}-${i}`)}
        />
      </Section>

      <Section title="Root-Cause Pareto (revenue-loss weighted)">
        <DataTable<Pareto>
          rows={pareto}
          columns={[
            { key: 'root_cause_category', header: 'Root Cause', render: (r) => r.root_cause_category },
            { key: 'event_count', header: 'Events', render: (r) => String(r.event_count) },
            { key: 'revenue_loss_rupees', header: 'Loss', render: (r) => rupees(r.revenue_loss_rupees) },
            { key: 'pct_of_total_loss', header: '% of Loss', render: (r) => pct(r.pct_of_total_loss) },
          ]}
          emptyMessage="No pareto data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.root_cause_category}-${i}`)}
        />
      </Section>

      <Section title="Site Worst Offenders">
        <DataTable<SiteOffender>
          rows={sites}
          columns={[
            { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'total_events', header: 'Events', render: (r) => String(r.total_events) },
            { key: 'cancellation_rate_pct', header: 'Cancel Rate', render: (r) => pct(r.cancellation_rate_pct) },
            { key: 'total_loss_rupees', header: 'Loss', render: (r) => rupees(r.total_loss_rupees) },
            { key: 'top_root_cause', header: 'Top Cause', render: (r) => r.top_root_cause ?? '—' },
          ]}
          emptyMessage="No site offender rows."
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.hospital_site}-${i}`)}
        />
      </Section>

      <Section title="Equipment Failure Hotlist">
        <DataTable<EquipmentHot>
          rows={equip}
          columns={[
            { key: 'equipment_involved', header: 'Equipment', render: (r) => r.equipment_involved },
            { key: 'failure_count', header: 'Failures', render: (r) => String(r.failure_count) },
            { key: 'total_delay_minutes', header: 'Total Delay (min)', render: (r) => String(r.total_delay_minutes) },
            { key: 'total_loss_rupees', header: 'Loss', render: (r) => rupees(r.total_loss_rupees) },
            { key: 'last_event_date', header: 'Last Event', render: (r) => r.last_event_date },
          ]}
          emptyMessage="No equipment hotlist."
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.equipment_involved}-${i}`)}
        />
      </Section>

      <Section title="Severity Distribution (p0-p3)">
        <DataTable<Severity>
          rows={sev}
          columns={[
            { key: 'severity', header: 'Severity', render: (r) => r.severity },
            { key: 'event_count', header: 'Events', render: (r) => String(r.event_count) },
            { key: 'avg_delay_minutes', header: 'Avg Delay (min)', render: (r) => r.avg_delay_minutes == null ? '—' : String(r.avg_delay_minutes) },
            { key: 'total_loss_rupees', header: 'Loss', render: (r) => rupees(r.total_loss_rupees) },
            { key: 'cancellation_count', header: 'Cancellations', render: (r) => String(r.cancellation_count) },
          ]}
          emptyMessage="No severity data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.severity}-${i}`)}
        />
      </Section>

      <Section title="Corrective-Action Progress by Chain">
        <DataTable<ActionProgress>
          rows={progress}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'open_count', header: 'Open', render: (r) => String(r.open_count) },
            { key: 'in_progress_count', header: 'In Progress', render: (r) => String(r.in_progress_count) },
            { key: 'completed_count', header: 'Completed', render: (r) => String(r.completed_count) },
            { key: 'critical_open', header: 'Critical Open', render: (r) => String(r.critical_open) },
            { key: 'total_estimated_cost', header: 'Est Cost', render: (r) => rupees(r.total_estimated_cost) },
            { key: 'expected_blended_reduction_pct', header: 'Expected Reduction', render: (r) => pct(r.expected_blended_reduction_pct) },
          ]}
          emptyMessage="No corrective-action progress."
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.chain_name}-${i}`)}
        />
      </Section>

      <Section title="Founder-Priority Action Queue (critical & high, open)">
        <DataTable<PriorityAction>
          rows={queue}
          columns={[
            { key: 'action_title', header: 'Action', render: (r) => r.action_title },
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
            { key: 'owner_role', header: 'Owner', render: (r) => r.owner_role },
            { key: 'due_date', header: 'Due', render: (r) => r.due_date },
            { key: 'status', header: 'Status', render: (r) => r.status },
            { key: 'founder_priority', header: 'Priority', render: (r) => r.founder_priority },
            { key: 'expected_reduction_pct', header: 'Expected Reduction', render: (r) => pct(r.expected_reduction_pct) },
            { key: 'estimated_cost', header: 'Est Cost', render: (r) => rupees(r.estimated_cost) },
            { key: 'last_update_note', header: 'Update', render: (r) => r.last_update_note ?? '—' },
          ]}
          emptyMessage="No critical/high open actions — queue clear."
          rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.action_title}-${i}`)}
        />
      </Section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: '#f8f9fb', border: '1px solid #e5e7eb', borderRadius: 8, padding: '14px 16px' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, color: '#111827' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 17, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
