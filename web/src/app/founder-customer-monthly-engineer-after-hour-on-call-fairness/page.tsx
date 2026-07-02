import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_shifts: number;
  total_engineers: number;
  total_hours: number;
  total_jobs: number;
  total_pay: number;
  total_overtime: number;
  avg_fairness: number;
  flagged_count: number;
};

type Shift = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  shift_date: string;
  shift_window: string;
  hours_on_call: number;
  jobs_handled: number;
  base_pay_rupees: number;
  overtime_pay_rupees: number;
  fairness_score: number;
  region: string;
  flagged_unfair: boolean;
};

type EngineerSummary = {
  engineer_code: string;
  engineer_name: string;
  shifts_count: number;
  total_hours: number;
  total_jobs: number;
  total_pay: number;
  avg_fairness: number;
  flagged_shifts: number;
};

type WindowRow = {
  shift_window: string;
  shifts: number;
  total_hours: number;
  total_jobs: number;
  total_overtime: number;
  avg_fairness: number;
};

type RegionRow = {
  region: string;
  engineers: number;
  shifts: number;
  total_hours: number;
  total_pay: number;
  flagged: number;
};

type RefineAction = {
  id: string;
  engineer_code: string;
  action_type: string;
  reason: string;
  status: string;
  proposed_by: string;
  applied_at: string | null;
  delta_rupees: number;
};

const inr = (n: number) =>
  '₹' + Number(n ?? 0).toLocaleString('en-IN', { maximumFractionDigits: 2 });

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, shiftsRes, engineersRes, windowsRes, unfairRes, regionsRes, actionsRes] =
    await Promise.all([
      supabase.rpc('r2848_oncall_kpis'),
      supabase.rpc('r2848_shifts_list'),
      supabase.rpc('r2848_engineer_summary'),
      supabase.rpc('r2848_shift_window_breakdown'),
      supabase.rpc('r2848_unfair_shifts'),
      supabase.rpc('r2848_region_load'),
      supabase.rpc('r2848_refine_actions_list'),
    ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_shifts: 0,
    total_engineers: 0,
    total_hours: 0,
    total_jobs: 0,
    total_pay: 0,
    total_overtime: 0,
    avg_fairness: 0,
    flagged_count: 0,
  }) as Kpi;

  const shifts: Shift[] = (shiftsRes.data ?? []) as Shift[];
  const engineers: EngineerSummary[] = (engineersRes.data ?? []) as EngineerSummary[];
  const windows: WindowRow[] = (windowsRes.data ?? []) as WindowRow[];
  const unfair: Shift[] = (unfairRes.data ?? []) as Shift[];
  const regions: RegionRow[] = (regionsRes.data ?? []) as RegionRow[];
  const actions: RefineAction[] = (actionsRes.data ?? []) as RefineAction[];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">
          Customer Monthly · Engineer After-Hour On-Call Fairness
        </h1>
        <p className="text-sm text-neutral-600">
          Engineer × shift × jobs × pay × overtime × fairness × refine action.
          Flags shifts where fairness score is &lt; 60 or load is &gt;= 2× peer median.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Shifts" value={String(kpi.total_shifts)} />
        <KpiCard label="Engineers" value={String(kpi.total_engineers)} />
        <KpiCard label="Hours On-Call" value={Number(kpi.total_hours).toFixed(1)} />
        <KpiCard label="Jobs Handled" value={String(kpi.total_jobs)} />
        <KpiCard label="Total Pay" value={inr(kpi.total_pay)} />
        <KpiCard label="Overtime Pay" value={inr(kpi.total_overtime)} />
        <KpiCard label="Avg Fairness" value={Number(kpi.avg_fairness).toFixed(1)} />
        <KpiCard label="Flagged Unfair" value={String(kpi.flagged_count)} />
      </section>

      <Section title="All Shifts">
        <DataTable
          rows={shifts}
          columns={[
            { key: 'shift_date', header: 'Date', render: (r: Shift) => r.shift_date },
            { key: 'engineer', header: 'Engineer', render: (r: Shift) => `${r.engineer_code} — ${r.engineer_name}` },
            { key: 'shift_window', header: 'Window', render: (r: Shift) => r.shift_window },
            { key: 'region', header: 'Region', render: (r: Shift) => r.region },
            { key: 'hours_on_call', header: 'Hours', render: (r: Shift) => Number(r.hours_on_call).toFixed(1) },
            { key: 'jobs_handled', header: 'Jobs', render: (r: Shift) => String(r.jobs_handled) },
            { key: 'base_pay_rupees', header: 'Base Pay', render: (r: Shift) => inr(r.base_pay_rupees) },
            { key: 'overtime_pay_rupees', header: 'Overtime', render: (r: Shift) => inr(r.overtime_pay_rupees) },
            { key: 'fairness_score', header: 'Fairness', render: (r: Shift) => Number(r.fairness_score).toFixed(1) },
            { key: 'flagged_unfair', header: 'Flag', render: (r: Shift) => (r.flagged_unfair ? 'YES' : '—') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Shift, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Engineer Summary (sorted by fairness ascending)">
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: EngineerSummary) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: EngineerSummary) => r.engineer_name },
            { key: 'shifts_count', header: 'Shifts', render: (r: EngineerSummary) => String(r.shifts_count) },
            { key: 'total_hours', header: 'Hours', render: (r: EngineerSummary) => Number(r.total_hours).toFixed(1) },
            { key: 'total_jobs', header: 'Jobs', render: (r: EngineerSummary) => String(r.total_jobs) },
            { key: 'total_pay', header: 'Pay', render: (r: EngineerSummary) => inr(r.total_pay) },
            { key: 'avg_fairness', header: 'Avg Fairness', render: (r: EngineerSummary) => Number(r.avg_fairness).toFixed(1) },
            { key: 'flagged_shifts', header: 'Flagged', render: (r: EngineerSummary) => String(r.flagged_shifts) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerSummary, i: number) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Shift Window Breakdown">
        <DataTable
          rows={windows}
          columns={[
            { key: 'shift_window', header: 'Window', render: (r: WindowRow) => r.shift_window },
            { key: 'shifts', header: 'Shifts', render: (r: WindowRow) => String(r.shifts) },
            { key: 'total_hours', header: 'Hours', render: (r: WindowRow) => Number(r.total_hours).toFixed(1) },
            { key: 'total_jobs', header: 'Jobs', render: (r: WindowRow) => String(r.total_jobs) },
            { key: 'total_overtime', header: 'Overtime Pay', render: (r: WindowRow) => inr(r.total_overtime) },
            { key: 'avg_fairness', header: 'Avg Fairness', render: (r: WindowRow) => Number(r.avg_fairness).toFixed(1) },
          ]}
          emptyMessage="No data"
          rowKey={(r: WindowRow, i: number) => String(r.shift_window ?? i)}
        />
      </Section>

      <Section title="Unfair Shifts (fairness < 60 or flagged)">
        <DataTable
          rows={unfair}
          columns={[
            { key: 'shift_date', header: 'Date', render: (r: Shift) => r.shift_date },
            { key: 'engineer', header: 'Engineer', render: (r: Shift) => `${r.engineer_code} — ${r.engineer_name}` },
            { key: 'shift_window', header: 'Window', render: (r: Shift) => r.shift_window },
            { key: 'hours_on_call', header: 'Hours', render: (r: Shift) => Number(r.hours_on_call).toFixed(1) },
            { key: 'jobs_handled', header: 'Jobs', render: (r: Shift) => String(r.jobs_handled) },
            { key: 'fairness_score', header: 'Fairness', render: (r: Shift) => Number(r.fairness_score).toFixed(1) },
            { key: 'flagged_unfair', header: 'Flag', render: (r: Shift) => (r.flagged_unfair ? 'YES' : '—') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Shift, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Region Load">
        <DataTable
          rows={regions}
          columns={[
            { key: 'region', header: 'Region', render: (r: RegionRow) => r.region },
            { key: 'engineers', header: 'Engineers', render: (r: RegionRow) => String(r.engineers) },
            { key: 'shifts', header: 'Shifts', render: (r: RegionRow) => String(r.shifts) },
            { key: 'total_hours', header: 'Hours', render: (r: RegionRow) => Number(r.total_hours).toFixed(1) },
            { key: 'total_pay', header: 'Pay', render: (r: RegionRow) => inr(r.total_pay) },
            { key: 'flagged', header: 'Flagged', render: (r: RegionRow) => String(r.flagged) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RegionRow, i: number) => String(r.region ?? i)}
        />
      </Section>

      <Section title="Refine Actions">
        <DataTable
          rows={actions}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: RefineAction) => r.engineer_code },
            { key: 'action_type', header: 'Action', render: (r: RefineAction) => r.action_type },
            { key: 'reason', header: 'Reason', render: (r: RefineAction) => r.reason },
            { key: 'status', header: 'Status', render: (r: RefineAction) => r.status },
            { key: 'proposed_by', header: 'Proposed By', render: (r: RefineAction) => r.proposed_by },
            { key: 'delta_rupees', header: 'Delta', render: (r: RefineAction) => inr(r.delta_rupees) },
            { key: 'applied_at', header: 'Applied', render: (r: RefineAction) => r.applied_at ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: RefineAction, i: number) => String(r.id ?? i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold">{title}</h2>
      {children}
    </section>
  );
}
