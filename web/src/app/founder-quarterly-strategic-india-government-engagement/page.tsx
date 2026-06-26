import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type EventRow = {
  id: string;
  event_code: string;
  event_name: string;
  event_date: string;
  quarter: string;
  department: string;
  ministry_level: string;
  topic: string;
  founder_ask: string;
  commitment_received: string | null;
  business_impact_inr_cr: number;
  follow_up_status: string;
  priority: string;
};

type KpiRow = {
  total_events: number;
  total_business_impact_cr: number;
  active_engagements: number;
  p0_priority_count: number;
  completed_count: number;
  escalated_count: number;
  total_hours_invested: number;
  departments_engaged: number;
};

type DepartmentRow = {
  department: string;
  event_count: number;
  total_impact_cr: number;
  p0_count: number;
  active_count: number;
};

type FollowupRow = {
  id: string;
  event_code: string;
  followup_date: string;
  channel: string;
  contact_person: string;
  contact_designation: string;
  outcome: string;
  notes: string;
  hours_invested: number;
  next_step: string | null;
};

type P0Row = {
  event_code: string;
  event_name: string;
  department: string;
  business_impact_inr_cr: number;
  follow_up_status: string;
  next_action_date: string | null;
  days_until_next_action: number | null;
};

type QuarterRow = {
  quarter: string;
  event_count: number;
  total_impact_cr: number;
  completed_count: number;
  active_count: number;
};

type OutcomeRow = {
  outcome: string;
  followup_count: number;
  total_hours: number;
  distinct_events: number;
};

type MinistryRow = {
  ministry_level: string;
  event_count: number;
  total_impact_cr: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [eventsRes, kpisRes, deptRes, followupsRes, p0Res, quarterRes, outcomeRes, ministryRes] = await Promise.all([
    supabase.rpc('get_gov_engagement_events_r2877'),
    supabase.rpc('get_gov_engagement_kpis_r2877'),
    supabase.rpc('get_gov_engagement_by_department_r2877'),
    supabase.rpc('get_gov_engagement_followups_r2877'),
    supabase.rpc('get_gov_engagement_p0_events_r2877'),
    supabase.rpc('get_gov_engagement_by_quarter_r2877'),
    supabase.rpc('get_gov_engagement_outcome_funnel_r2877'),
    supabase.rpc('get_gov_engagement_by_ministry_level_r2877'),
  ]);

  const events: EventRow[] = (eventsRes.data as EventRow[]) ?? [];
  const kpis: KpiRow = ((kpisRes.data as KpiRow[]) ?? [])[0] ?? {
    total_events: 0,
    total_business_impact_cr: 0,
    active_engagements: 0,
    p0_priority_count: 0,
    completed_count: 0,
    escalated_count: 0,
    total_hours_invested: 0,
    departments_engaged: 0,
  };
  const depts: DepartmentRow[] = (deptRes.data as DepartmentRow[]) ?? [];
  const followups: FollowupRow[] = (followupsRes.data as FollowupRow[]) ?? [];
  const p0Events: P0Row[] = (p0Res.data as P0Row[]) ?? [];
  const quarters: QuarterRow[] = (quarterRes.data as QuarterRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const ministries: MinistryRow[] = (ministryRes.data as MinistryRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Founder Quarterly Strategic India Government Engagement</h1>
        <p className="text-sm text-gray-600 mt-1">
          Event × department × topic × ask × commitment × business impact × follow-up — round r2877
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Events" value={String(kpis.total_events)} />
        <KpiCard label="Business Impact (Cr)" value={`Rs ${Number(kpis.total_business_impact_cr).toFixed(2)}`} />
        <KpiCard label="Active Engagements" value={String(kpis.active_engagements)} />
        <KpiCard label="P0 Priority" value={String(kpis.p0_priority_count)} />
        <KpiCard label="Completed" value={String(kpis.completed_count)} />
        <KpiCard label="Escalated" value={String(kpis.escalated_count)} />
        <KpiCard label="Founder Hours Invested" value={`${Number(kpis.total_hours_invested).toFixed(1)} h`} />
        <KpiCard label="Departments Engaged" value={String(kpis.departments_engaged)} />
      </div>

      <Section title="P0 Priority Events — immediate action required">
        <DataTable
          rows={p0Events}
          columns={[
            { key: 'event_code', header: 'Event Code', render: (r: P0Row) => r.event_code },
            { key: 'event_name', header: 'Event', render: (r: P0Row) => r.event_name },
            { key: 'department', header: 'Department', render: (r: P0Row) => r.department },
            { key: 'business_impact_inr_cr', header: 'Impact (Cr)', render: (r: P0Row) => `Rs ${Number(r.business_impact_inr_cr).toFixed(2)}` },
            { key: 'follow_up_status', header: 'Status', render: (r: P0Row) => r.follow_up_status },
            { key: 'next_action_date', header: 'Next Action', render: (r: P0Row) => r.next_action_date ?? '-' },
            { key: 'days_until_next_action', header: 'Days Left', render: (r: P0Row) => r.days_until_next_action === null ? '-' : String(r.days_until_next_action) },
          ]}
          emptyMessage="No data"
          rowKey={(r: P0Row, i: number) => String(r.event_code ?? i)}
        />
      </Section>

      <Section title="Engagement Events — full registry">
        <DataTable
          rows={events}
          columns={[
            { key: 'event_code', header: 'Code', render: (r: EventRow) => r.event_code },
            { key: 'event_name', header: 'Event', render: (r: EventRow) => r.event_name },
            { key: 'event_date', header: 'Date', render: (r: EventRow) => r.event_date },
            { key: 'quarter', header: 'Quarter', render: (r: EventRow) => r.quarter },
            { key: 'department', header: 'Department', render: (r: EventRow) => r.department },
            { key: 'ministry_level', header: 'Level', render: (r: EventRow) => r.ministry_level },
            { key: 'topic', header: 'Topic', render: (r: EventRow) => r.topic },
            { key: 'founder_ask', header: 'Founder Ask', render: (r: EventRow) => r.founder_ask },
            { key: 'commitment_received', header: 'Commitment', render: (r: EventRow) => r.commitment_received ?? '-' },
            { key: 'business_impact_inr_cr', header: 'Impact (Cr)', render: (r: EventRow) => `Rs ${Number(r.business_impact_inr_cr).toFixed(2)}` },
            { key: 'follow_up_status', header: 'Status', render: (r: EventRow) => r.follow_up_status },
            { key: 'priority', header: 'Priority', render: (r: EventRow) => r.priority },
          ]}
          emptyMessage="No data"
          rowKey={(r: EventRow, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="By Department — impact distribution">
        <DataTable
          rows={depts}
          columns={[
            { key: 'department', header: 'Department', render: (r: DepartmentRow) => r.department },
            { key: 'event_count', header: 'Events', render: (r: DepartmentRow) => String(r.event_count) },
            { key: 'total_impact_cr', header: 'Impact (Cr)', render: (r: DepartmentRow) => `Rs ${Number(r.total_impact_cr).toFixed(2)}` },
            { key: 'p0_count', header: 'P0 Count', render: (r: DepartmentRow) => String(r.p0_count) },
            { key: 'active_count', header: 'Active', render: (r: DepartmentRow) => String(r.active_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: DepartmentRow, i: number) => String(r.department ?? i)}
        />
      </Section>

      <Section title="By Quarter — quarterly flow">
        <DataTable
          rows={quarters}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: QuarterRow) => r.quarter },
            { key: 'event_count', header: 'Events', render: (r: QuarterRow) => String(r.event_count) },
            { key: 'total_impact_cr', header: 'Impact (Cr)', render: (r: QuarterRow) => `Rs ${Number(r.total_impact_cr).toFixed(2)}` },
            { key: 'completed_count', header: 'Completed', render: (r: QuarterRow) => String(r.completed_count) },
            { key: 'active_count', header: 'Active', render: (r: QuarterRow) => String(r.active_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuarterRow, i: number) => String(r.quarter ?? i)}
        />
      </Section>

      <Section title="By Ministry Level — seniority targeting">
        <DataTable
          rows={ministries}
          columns={[
            { key: 'ministry_level', header: 'Level', render: (r: MinistryRow) => r.ministry_level },
            { key: 'event_count', header: 'Events', render: (r: MinistryRow) => String(r.event_count) },
            { key: 'total_impact_cr', header: 'Impact (Cr)', render: (r: MinistryRow) => `Rs ${Number(r.total_impact_cr).toFixed(2)}` },
          ]}
          emptyMessage="No data"
          rowKey={(r: MinistryRow, i: number) => String(r.ministry_level ?? i)}
        />
      </Section>

      <Section title="Outcome Funnel — follow-up effectiveness">
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'followup_count', header: 'Follow-ups', render: (r: OutcomeRow) => String(r.followup_count) },
            { key: 'total_hours', header: 'Hours Spent', render: (r: OutcomeRow) => `${Number(r.total_hours).toFixed(1)} h` },
            { key: 'distinct_events', header: 'Events Touched', render: (r: OutcomeRow) => String(r.distinct_events) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
        />
      </Section>

      <Section title="Follow-up Activity Log">
        <DataTable
          rows={followups}
          columns={[
            { key: 'followup_date', header: 'Date', render: (r: FollowupRow) => r.followup_date },
            { key: 'event_code', header: 'Event', render: (r: FollowupRow) => r.event_code },
            { key: 'channel', header: 'Channel', render: (r: FollowupRow) => r.channel },
            { key: 'contact_person', header: 'Contact', render: (r: FollowupRow) => r.contact_person },
            { key: 'contact_designation', header: 'Designation', render: (r: FollowupRow) => r.contact_designation },
            { key: 'outcome', header: 'Outcome', render: (r: FollowupRow) => r.outcome },
            { key: 'hours_invested', header: 'Hours', render: (r: FollowupRow) => `${Number(r.hours_invested).toFixed(1)} h` },
            { key: 'notes', header: 'Notes', render: (r: FollowupRow) => r.notes },
            { key: 'next_step', header: 'Next Step', render: (r: FollowupRow) => r.next_step ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: FollowupRow, i: number) => String(r.id ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs font-medium text-gray-500 uppercase tracking-wide">{label}</div>
      <div className="mt-1 text-xl font-bold text-gray-900">{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold text-gray-900" dangerouslySetInnerHTML={{ __html: title }} />
      <div className="overflow-x-auto">{children}</div>
    </section>
  );
}
