import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_chains: number;
  total_hospitals: number;
  total_clinicians: number;
  total_engineers: number;
  total_requests: number;
  total_completed: number;
  completion_pct: number;
  median_turnaround: number;
  total_breaches: number;
};

type Cycle = {
  id: string;
  chain_code: string;
  chain_name: string;
  quarter_label: string;
  hospitals_in_scope: number;
  clinicians_enrolled: number;
  engineers_assigned: number;
  cosign_requests_total: number;
  cosign_requests_completed: number;
  median_turnaround_hours: number;
  sla_breach_count: number;
  cycle_status: string;
  outcome_grade: string;
  notes: string | null;
};

type Event = {
  id: string;
  chain_code: string;
  hospital_unit: string;
  clinician_name: string;
  clinician_specialty: string;
  engineer_name: string;
  engineer_tier: string;
  request_type: string;
  turnaround_hours: number | null;
  outcome: string;
  risk_score: number;
};

type StatusRow = { cycle_status: string; cycle_count: number; total_requests: number; avg_turnaround: number };
type GradeRow = { outcome_grade: string; chain_count: number; hospitals: number; breaches: number };
type TierRow = { engineer_tier: string; requests: number; approved: number; avg_turnaround: number; avg_risk: number };
type TypeRow = { request_type: string; total: number; approved: number; escalated: number; pending: number };
type BreachRow = { chain_code: string; chain_name: string; sla_breach_count: number; cosign_requests_total: number; breach_pct: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ov, cycles, events, statuses, grades, tiers, types, breaches] = await Promise.all([
    supabase.rpc('r2811_overview'),
    supabase.rpc('r2811_cycles_list'),
    supabase.rpc('r2811_events_list'),
    supabase.rpc('r2811_status_breakdown'),
    supabase.rpc('r2811_outcome_grade'),
    supabase.rpc('r2811_engineer_tier_perf'),
    supabase.rpc('r2811_request_type_mix'),
    supabase.rpc('r2811_top_breach_chains'),
  ]);

  const overview: Overview = (ov.data?.[0] ?? {
    total_chains: 0,
    total_hospitals: 0,
    total_clinicians: 0,
    total_engineers: 0,
    total_requests: 0,
    total_completed: 0,
    completion_pct: 0,
    median_turnaround: 0,
    total_breaches: 0,
  }) as Overview;

  const cycleRows: Cycle[] = (cycles.data ?? []) as Cycle[];
  const eventRows: Event[] = (events.data ?? []) as Event[];
  const statusRows: StatusRow[] = (statuses.data ?? []) as StatusRow[];
  const gradeRows: GradeRow[] = (grades.data ?? []) as GradeRow[];
  const tierRows: TierRow[] = (tiers.data ?? []) as TierRow[];
  const typeRows: TypeRow[] = (types.data ?? []) as TypeRow[];
  const breachRows: BreachRow[] = (breaches.data ?? []) as BreachRow[];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Clinical-Engineer Cosign Cycles</h1>
        <p className="text-sm text-gray-600">
          Chain × clinician × engineer × cosign request × turnaround × outcome. Founder view of every quarterly cosign cycle across our hospital chain accounts.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Chains</div>
          <div className="text-2xl font-semibold">{overview.total_chains}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Hospitals in scope</div>
          <div className="text-2xl font-semibold">{overview.total_hospitals}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Clinicians enrolled</div>
          <div className="text-2xl font-semibold">{overview.total_clinicians}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Engineers assigned</div>
          <div className="text-2xl font-semibold">{overview.total_engineers}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Cosign requests</div>
          <div className="text-2xl font-semibold">{overview.total_requests}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="text-2xl font-semibold">{overview.total_completed}</div>
          <div className="text-xs text-gray-500">{overview.completion_pct}% completion</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Median turnaround (h)</div>
          <div className="text-2xl font-semibold">{overview.median_turnaround}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">SLA breaches</div>
          <div className="text-2xl font-semibold">{overview.total_breaches}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Quarterly cosign cycles by chain</h2>
        <DataTable
          rows={cycleRows}
          columns={[
            { key: 'chain', header: 'Chain', render: (r: Cycle) => `${r.chain_name} (${r.chain_code})` },
            { key: 'quarter', header: 'Quarter', render: (r: Cycle) => r.quarter_label },
            { key: 'units', header: 'Hospitals', render: (r: Cycle) => r.hospitals_in_scope },
            { key: 'clin', header: 'Clinicians', render: (r: Cycle) => r.clinicians_enrolled },
            { key: 'eng', header: 'Engineers', render: (r: Cycle) => r.engineers_assigned },
            { key: 'reqs', header: 'Requests', render: (r: Cycle) => `${r.cosign_requests_completed}/${r.cosign_requests_total}` },
            { key: 'tat', header: 'Median TAT (h)', render: (r: Cycle) => r.median_turnaround_hours },
            { key: 'breach', header: 'Breaches', render: (r: Cycle) => r.sla_breach_count },
            { key: 'status', header: 'Status', render: (r: Cycle) => r.cycle_status },
            { key: 'grade', header: 'Grade', render: (r: Cycle) => r.outcome_grade },
            { key: 'notes', header: 'Notes', render: (r: Cycle) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Cycle, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent cosign request events</h2>
        <DataTable
          rows={eventRows}
          columns={[
            { key: 'chain', header: 'Chain', render: (r: Event) => r.chain_code },
            { key: 'unit', header: 'Hospital unit', render: (r: Event) => r.hospital_unit },
            { key: 'clin', header: 'Clinician', render: (r: Event) => `${r.clinician_name} (${r.clinician_specialty})` },
            { key: 'eng', header: 'Engineer', render: (r: Event) => `${r.engineer_name} (${r.engineer_tier})` },
            { key: 'type', header: 'Type', render: (r: Event) => r.request_type },
            { key: 'tat', header: 'TAT (h)', render: (r: Event) => r.turnaround_hours ?? '—' },
            { key: 'outcome', header: 'Outcome', render: (r: Event) => r.outcome },
            { key: 'risk', header: 'Risk', render: (r: Event) => r.risk_score },
          ]}
          emptyMessage="No data"
          rowKey={(r: Event, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Cycle status breakdown</h2>
          <DataTable
            rows={statusRows}
            columns={[
              { key: 'status', header: 'Status', render: (r: StatusRow) => r.cycle_status },
              { key: 'count', header: 'Cycles', render: (r: StatusRow) => r.cycle_count },
              { key: 'reqs', header: 'Requests', render: (r: StatusRow) => r.total_requests },
              { key: 'tat', header: 'Avg TAT (h)', render: (r: StatusRow) => r.avg_turnaround },
            ]}
            emptyMessage="No data"
            rowKey={(r: StatusRow, i: number) => String(r.cycle_status ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Outcome grade distribution</h2>
          <DataTable
            rows={gradeRows}
            columns={[
              { key: 'grade', header: 'Grade', render: (r: GradeRow) => r.outcome_grade },
              { key: 'chains', header: 'Chains', render: (r: GradeRow) => r.chain_count },
              { key: 'hosp', header: 'Hospitals', render: (r: GradeRow) => r.hospitals },
              { key: 'breaches', header: 'Breaches', render: (r: GradeRow) => r.breaches },
            ]}
            emptyMessage="No data"
            rowKey={(r: GradeRow, i: number) => String(r.outcome_grade ?? i)}
          />
        </div>
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Engineer tier performance</h2>
          <DataTable
            rows={tierRows}
            columns={[
              { key: 'tier', header: 'Tier', render: (r: TierRow) => r.engineer_tier },
              { key: 'reqs', header: 'Requests', render: (r: TierRow) => r.requests },
              { key: 'appr', header: 'Approved', render: (r: TierRow) => r.approved },
              { key: 'tat', header: 'Avg TAT (h)', render: (r: TierRow) => r.avg_turnaround },
              { key: 'risk', header: 'Avg risk', render: (r: TierRow) => r.avg_risk },
            ]}
            emptyMessage="No data"
            rowKey={(r: TierRow, i: number) => String(r.engineer_tier ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Request type mix</h2>
          <DataTable
            rows={typeRows}
            columns={[
              { key: 'type', header: 'Type', render: (r: TypeRow) => r.request_type },
              { key: 'tot', header: 'Total', render: (r: TypeRow) => r.total },
              { key: 'appr', header: 'Approved', render: (r: TypeRow) => r.approved },
              { key: 'esc', header: 'Escalated', render: (r: TypeRow) => r.escalated },
              { key: 'pen', header: 'Pending', render: (r: TypeRow) => r.pending },
            ]}
            emptyMessage="No data"
            rowKey={(r: TypeRow, i: number) => String(r.request_type ?? i)}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top SLA-breach chains</h2>
        <p className="text-xs text-gray-500">Chains with the largest breach counts this quarter. Breach pct compares breaches against total cosign requests.</p>
        <DataTable
          rows={breachRows}
          columns={[
            { key: 'code', header: 'Code', render: (r: BreachRow) => r.chain_code },
            { key: 'name', header: 'Chain', render: (r: BreachRow) => r.chain_name },
            { key: 'breach', header: 'Breaches', render: (r: BreachRow) => r.sla_breach_count },
            { key: 'req', header: 'Requests', render: (r: BreachRow) => r.cosign_requests_total },
            { key: 'pct', header: 'Breach %', render: (r: BreachRow) => `${r.breach_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: BreachRow, i: number) => String(r.chain_code ?? i)}
        />
      </section>
    </div>
  );
}
