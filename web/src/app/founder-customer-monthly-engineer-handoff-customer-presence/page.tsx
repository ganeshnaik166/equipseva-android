import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_handoffs: number;
  customer_present_pct: number | null;
  full_signoff_pct: number | null;
  followups_open: number;
  total_job_value_rupees: number;
};

type EngineerRow = {
  engineer_name: string;
  total_handoffs: number;
  presence_pct: number | null;
  signoff_pct: number | null;
  avg_checklist_pct: number | null;
  followups_open: number;
  grade: string;
  coaching_required: boolean;
};

type EventRow = {
  job_code: string;
  engineer_name: string;
  customer_name: string;
  hospital_name: string;
  presence_mode: string;
  checklist_passed: number;
  checklist_total: number;
  signoff_status: string;
  followup_required: boolean;
  followup_due_date: string | null;
  job_value_rupees: number;
};

type PresenceRow = {
  presence_mode: string;
  event_count: number;
  share_pct: number | null;
  avg_checklist_pct: number | null;
};

type FollowupRow = {
  job_code: string;
  engineer_name: string;
  customer_name: string;
  hospital_name: string;
  followup_due_date: string | null;
  followup_reason: string | null;
  days_to_due: number | null;
};

type SignoffRow = {
  signoff_method: string;
  signoff_status: string;
  event_count: number;
  total_value_rupees: number;
};

type CoachingRow = {
  engineer_name: string;
  grade: string;
  presence_pct: number | null;
  signoff_pct: number | null;
  followups_open: number;
  notes: string | null;
};

type CityRow = {
  city: string;
  events: number;
  presence_pct: number | null;
  signoff_pct: number | null;
  total_value_rupees: number;
};

function rupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, engRes, evtRes, presRes, folRes, sigRes, coachRes, cityRes] = await Promise.all([
    supabase.rpc('founder_r2776_kpi'),
    supabase.rpc('founder_r2776_engineer_rollup'),
    supabase.rpc('founder_r2776_events'),
    supabase.rpc('founder_r2776_presence_breakdown'),
    supabase.rpc('founder_r2776_open_followups'),
    supabase.rpc('founder_r2776_signoff_mix'),
    supabase.rpc('founder_r2776_coaching_watchlist'),
    supabase.rpc('founder_r2776_city_health'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_handoffs: 0,
    customer_present_pct: 0,
    full_signoff_pct: 0,
    followups_open: 0,
    total_job_value_rupees: 0,
  };
  const engineers: EngineerRow[] = (engRes.data as EngineerRow[]) ?? [];
  const events: EventRow[] = (evtRes.data as EventRow[]) ?? [];
  const presence: PresenceRow[] = (presRes.data as PresenceRow[]) ?? [];
  const followups: FollowupRow[] = (folRes.data as FollowupRow[]) ?? [];
  const signoffs: SignoffRow[] = (sigRes.data as SignoffRow[]) ?? [];
  const coaching: CoachingRow[] = (coachRes.data as CoachingRow[]) ?? [];
  const cities: CityRow[] = (cityRes.data as CityRow[]) ?? [];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
          Customer Monthly — Engineer Handoff & Customer Presence
        </h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Round r2776 · job × engineer × customer present × handoff completeness × signoff × follow-up.
          Coaching watchlist auto-flags engineers where presence pct &lt; 70% or signoff pct &lt;= 50%.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Total handoffs (MTD)" value={String(kpi.total_handoffs ?? 0)} />
        <KpiCard label="Customer present %" value={pct(kpi.customer_present_pct)} />
        <KpiCard label="Full signoff %" value={pct(kpi.full_signoff_pct)} />
        <KpiCard label="Open follow-ups" value={String(kpi.followups_open ?? 0)} />
        <KpiCard label="Job value (MTD)" value={rupees(kpi.total_job_value_rupees)} />
      </section>

      <Section title="Engineer monthly rollup" subtitle="Per-engineer presence, signoff & grade.">
        <DataTable
          rows={engineers}
          rowKey={(r, i) => String((r as EngineerRow).engineer_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'total_handoffs', header: 'Handoffs', render: (r: EngineerRow) => String(r.total_handoffs) },
            { key: 'presence_pct', header: 'Presence %', render: (r: EngineerRow) => pct(r.presence_pct) },
            { key: 'signoff_pct', header: 'Signoff %', render: (r: EngineerRow) => pct(r.signoff_pct) },
            { key: 'avg_checklist_pct', header: 'Checklist %', render: (r: EngineerRow) => pct(r.avg_checklist_pct) },
            { key: 'followups_open', header: 'Follow-ups', render: (r: EngineerRow) => String(r.followups_open) },
            { key: 'grade', header: 'Grade', render: (r: EngineerRow) => r.grade },
            { key: 'coaching_required', header: 'Coach?', render: (r: EngineerRow) => (r.coaching_required ? 'Yes' : 'No') },
          ]}
        />
      </Section>

      <Section title="Handoff events (MTD)" subtitle="One row per job handoff this month.">
        <DataTable
          rows={events}
          rowKey={(r, i) => String((r as EventRow).job_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'job_code', header: 'Job', render: (r: EventRow) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: EventRow) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: EventRow) => r.customer_name },
            { key: 'hospital_name', header: 'Hospital', render: (r: EventRow) => r.hospital_name },
            { key: 'presence_mode', header: 'Presence', render: (r: EventRow) => r.presence_mode },
            { key: 'checklist', header: 'Checklist', render: (r: EventRow) => r.checklist_passed + ' / ' + r.checklist_total },
            { key: 'signoff_status', header: 'Signoff', render: (r: EventRow) => r.signoff_status },
            { key: 'followup_required', header: 'Follow-up', render: (r: EventRow) => (r.followup_required ? 'Yes' : 'No') },
            { key: 'job_value_rupees', header: 'Value', render: (r: EventRow) => rupees(r.job_value_rupees) },
          ]}
        />
      </Section>

      <Section title="Presence mode breakdown" subtitle="How customers are present at handoff.">
        <DataTable
          rows={presence}
          rowKey={(r, i) => String((r as PresenceRow).presence_mode ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'presence_mode', header: 'Mode', render: (r: PresenceRow) => r.presence_mode },
            { key: 'event_count', header: 'Events', render: (r: PresenceRow) => String(r.event_count) },
            { key: 'share_pct', header: 'Share %', render: (r: PresenceRow) => pct(r.share_pct) },
            { key: 'avg_checklist_pct', header: 'Avg checklist %', render: (r: PresenceRow) => pct(r.avg_checklist_pct) },
          ]}
        />
      </Section>

      <Section title="Open follow-ups" subtitle="Pending revisits / signoff captures.">
        <DataTable
          rows={followups}
          rowKey={(r, i) => String((r as FollowupRow).job_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'job_code', header: 'Job', render: (r: FollowupRow) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: FollowupRow) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: FollowupRow) => r.customer_name },
            { key: 'hospital_name', header: 'Hospital', render: (r: FollowupRow) => r.hospital_name },
            { key: 'followup_due_date', header: 'Due', render: (r: FollowupRow) => r.followup_due_date ?? '—' },
            { key: 'days_to_due', header: 'Days', render: (r: FollowupRow) => (r.days_to_due === null ? '—' : String(r.days_to_due)) },
            { key: 'followup_reason', header: 'Reason', render: (r: FollowupRow) => r.followup_reason ?? '—' },
          ]}
        />
      </Section>

      <Section title="Signoff method & status mix" subtitle="Where signoff captures concentrate.">
        <DataTable
          rows={signoffs}
          rowKey={(r, i) => String((r as SignoffRow).signoff_method + '|' + (r as SignoffRow).signoff_status + '|' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'signoff_method', header: 'Method', render: (r: SignoffRow) => r.signoff_method },
            { key: 'signoff_status', header: 'Status', render: (r: SignoffRow) => r.signoff_status },
            { key: 'event_count', header: 'Events', render: (r: SignoffRow) => String(r.event_count) },
            { key: 'total_value_rupees', header: 'Value', render: (r: SignoffRow) => rupees(r.total_value_rupees) },
          ]}
        />
      </Section>

      <Section title="Coaching watchlist" subtitle="Engineers flagged by grade D / F or coaching flag.">
        <DataTable
          rows={coaching}
          rowKey={(r, i) => String((r as CoachingRow).engineer_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: CoachingRow) => r.engineer_name },
            { key: 'grade', header: 'Grade', render: (r: CoachingRow) => r.grade },
            { key: 'presence_pct', header: 'Presence %', render: (r: CoachingRow) => pct(r.presence_pct) },
            { key: 'signoff_pct', header: 'Signoff %', render: (r: CoachingRow) => pct(r.signoff_pct) },
            { key: 'followups_open', header: 'Follow-ups', render: (r: CoachingRow) => String(r.followups_open) },
            { key: 'notes', header: 'Notes', render: (r: CoachingRow) => r.notes ?? '—' },
          ]}
        />
      </Section>

      <Section title="City health" subtitle="Presence & signoff health by city.">
        <DataTable
          rows={cities}
          rowKey={(r, i) => String((r as CityRow).city ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'city', header: 'City', render: (r: CityRow) => r.city },
            { key: 'events', header: 'Events', render: (r: CityRow) => String(r.events) },
            { key: 'presence_pct', header: 'Presence %', render: (r: CityRow) => pct(r.presence_pct) },
            { key: 'signoff_pct', header: 'Signoff %', render: (r: CityRow) => pct(r.signoff_pct) },
            { key: 'total_value_rupees', header: 'Value', render: (r: CityRow) => rupees(r.total_value_rupees) },
          ]}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 14, background: '#fff' }}>
      <div style={{ color: '#6b7280', fontSize: 12, marginBottom: 6 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>{title}</h2>
      {subtitle ? <p style={{ color: '#6b7280', fontSize: 13, marginBottom: 10 }}>{subtitle}</p> : null}
      {children}
    </section>
  );
}
