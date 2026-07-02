import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_chains: number;
  total_hospitals: number;
  total_night_shifts: number;
  total_covered: number;
  coverage_pct: number | null;
  total_emergencies: number;
  total_resolved: number;
  avg_response: number | null;
  total_breaches: number;
  total_penalty: number;
  total_bonus: number;
};

type ChainRow = {
  id: string;
  chain_code: string;
  chain_name: string;
  month_label: string;
  hospital_count: number;
  night_shifts_total: number;
  night_shifts_covered: number;
  coverage_pct: number | null;
  emergency_calls: number;
  emergency_resolved: number;
  avg_response_minutes: number;
  p95_response_minutes: number;
  sla_breach_count: number;
  uptime_pct: number;
  outcome: string;
  penalty_rupees: number;
  bonus_rupees: number;
};

type OutcomeRow = {
  outcome: string;
  chain_count: number;
  total_breaches: number;
  total_penalty: number;
  total_bonus: number;
};

type IncidentRow = {
  id: string;
  chain_code: string;
  incident_at: string;
  hospital_unit: string;
  device_category: string;
  severity: string;
  response_minutes: number;
  resolution_minutes: number | null;
  on_call_engineer: string;
  outcome: string;
  sla_breach: boolean;
  notes: string | null;
};

type DistRow = {
  bucket: string;
  incident_count: number;
  breach_count: number;
};

type MatrixRow = {
  severity: string;
  outcome: string;
  incident_count: number;
  avg_response: number;
};

type RedRow = {
  chain_code: string;
  chain_name: string;
  sla_breach_count: number;
  uptime_pct: number;
  penalty_rupees: number;
  emergency_calls: number;
  emergency_resolved: number;
  unresolved: number;
};

type LoadRow = {
  on_call_engineer: string;
  incident_count: number;
  breach_count: number;
  avg_response: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined, digits = 2): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(digits);
}

function fmtTs(s: string): string {
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return s;
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, chainsRes, outcomeRes, incidentsRes, distRes, matrixRes, redRes, loadRes] =
    await Promise.all([
      supabase.rpc('r2743_chain_month_summary'),
      supabase.rpc('r2743_chain_rows'),
      supabase.rpc('r2743_outcome_breakdown'),
      supabase.rpc('r2743_incidents_rows'),
      supabase.rpc('r2743_response_distribution'),
      supabase.rpc('r2743_severity_outcome_matrix'),
      supabase.rpc('r2743_red_chains'),
      supabase.rpc('r2743_on_call_load'),
    ]);

  const summary = (summaryRes.data?.[0] ?? null) as SummaryRow | null;
  const chains = (chainsRes.data ?? []) as ChainRow[];
  const outcomes = (outcomeRes.data ?? []) as OutcomeRow[];
  const incidents = (incidentsRes.data ?? []) as IncidentRow[];
  const dist = (distRes.data ?? []) as DistRow[];
  const matrix = (matrixRes.data ?? []) as MatrixRow[];
  const red = (redRes.data ?? []) as RedRow[];
  const load = (loadRes.data ?? []) as LoadRow[];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Hospital Chain — Monthly Night Shift Coverage</h1>
        <p className="text-sm text-gray-600">
          Chain × night SLA × on-call × emergency × response time × outcome.
          Coverage &gt;= 99% earns bonus; uptime &lt;= 95% flags red.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <KpiCard label="Chains" value={summary ? String(summary.total_chains) : '0'} />
        <KpiCard label="Hospitals" value={summary ? String(summary.total_hospitals) : '0'} />
        <KpiCard
          label="Night Shifts"
          value={summary ? String(summary.total_night_shifts) : '0'}
          hint={summary ? 'Covered ' + summary.total_covered : ''}
        />
        <KpiCard
          label="Coverage %"
          value={summary ? fmtNum(summary.coverage_pct, 2) + '%' : '-'}
        />
        <KpiCard
          label="Emergencies"
          value={summary ? String(summary.total_emergencies) : '0'}
          hint={summary ? 'Resolved ' + summary.total_resolved : ''}
        />
        <KpiCard
          label="Avg Response"
          value={summary ? fmtNum(summary.avg_response, 2) + ' min' : '-'}
        />
        <KpiCard
          label="SLA Breaches"
          value={summary ? String(summary.total_breaches) : '0'}
        />
        <KpiCard
          label="Net Penalty/Bonus"
          value={
            summary
              ? fmtRupees(Number(summary.total_bonus) - Number(summary.total_penalty))
              : '-'
          }
          hint={
            summary
              ? 'Bonus ' + fmtRupees(summary.total_bonus) + ' / Penalty ' + fmtRupees(summary.total_penalty)
              : ''
          }
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Chain × Month</h2>
        <DataTable
          rows={chains}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: ChainRow) => r.chain_code },
            { key: 'chain_name', header: 'Name', render: (r: ChainRow) => r.chain_name },
            { key: 'month_label', header: 'Month', render: (r: ChainRow) => r.month_label },
            { key: 'hospital_count', header: 'Hospitals', render: (r: ChainRow) => r.hospital_count },
            {
              key: 'coverage',
              header: 'Coverage',
              render: (r: ChainRow) =>
                r.night_shifts_covered + ' / ' + r.night_shifts_total + ' (' + fmtNum(r.coverage_pct, 2) + '%)',
            },
            {
              key: 'emergencies',
              header: 'Emergencies',
              render: (r: ChainRow) => r.emergency_resolved + ' / ' + r.emergency_calls,
            },
            {
              key: 'avg_response_minutes',
              header: 'Avg min',
              render: (r: ChainRow) => fmtNum(r.avg_response_minutes, 2),
            },
            {
              key: 'p95_response_minutes',
              header: 'p95 min',
              render: (r: ChainRow) => fmtNum(r.p95_response_minutes, 2),
            },
            {
              key: 'sla_breach_count',
              header: 'Breaches',
              render: (r: ChainRow) => r.sla_breach_count,
            },
            {
              key: 'uptime_pct',
              header: 'Uptime %',
              render: (r: ChainRow) => fmtNum(r.uptime_pct, 2) + '%',
            },
            {
              key: 'outcome',
              header: 'Outcome',
              render: (r: ChainRow) => <OutcomeBadge value={r.outcome} />,
            },
            {
              key: 'penalty_rupees',
              header: 'Penalty',
              render: (r: ChainRow) => fmtRupees(r.penalty_rupees),
            },
            {
              key: 'bonus_rupees',
              header: 'Bonus',
              render: (r: ChainRow) => fmtRupees(r.bonus_rupees),
            },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Outcome Breakdown</h2>
        <DataTable
          rows={outcomes}
          rowKey={(r, i) => String(r.outcome ?? i)}
          emptyMessage="No data"
          columns={[
            {
              key: 'outcome',
              header: 'Outcome',
              render: (r: OutcomeRow) => <OutcomeBadge value={r.outcome} />,
            },
            { key: 'chain_count', header: 'Chains', render: (r: OutcomeRow) => r.chain_count },
            {
              key: 'total_breaches',
              header: 'Breaches',
              render: (r: OutcomeRow) => r.total_breaches,
            },
            {
              key: 'total_penalty',
              header: 'Penalty',
              render: (r: OutcomeRow) => fmtRupees(r.total_penalty),
            },
            {
              key: 'total_bonus',
              header: 'Bonus',
              render: (r: OutcomeRow) => fmtRupees(r.total_bonus),
            },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Red &amp; Amber Chains</h2>
        <p className="text-sm text-gray-600">
          Chains with breaches &gt;= 5 or uptime &lt;= 98%. Founder escalation required.
        </p>
        <DataTable
          rows={red}
          rowKey={(r, i) => String(r.chain_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: RedRow) => r.chain_code },
            { key: 'chain_name', header: 'Name', render: (r: RedRow) => r.chain_name },
            {
              key: 'sla_breach_count',
              header: 'Breaches',
              render: (r: RedRow) => r.sla_breach_count,
            },
            {
              key: 'uptime_pct',
              header: 'Uptime %',
              render: (r: RedRow) => fmtNum(r.uptime_pct, 2) + '%',
            },
            {
              key: 'emergency_calls',
              header: 'Calls',
              render: (r: RedRow) => r.emergency_calls,
            },
            {
              key: 'unresolved',
              header: 'Unresolved',
              render: (r: RedRow) => r.unresolved,
            },
            {
              key: 'penalty_rupees',
              header: 'Penalty',
              render: (r: RedRow) => fmtRupees(r.penalty_rupees),
            },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Night Incidents</h2>
        <DataTable
          rows={incidents}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'incident_at', header: 'When', render: (r: IncidentRow) => fmtTs(r.incident_at) },
            { key: 'chain_code', header: 'Chain', render: (r: IncidentRow) => r.chain_code },
            {
              key: 'hospital_unit',
              header: 'Unit',
              render: (r: IncidentRow) => r.hospital_unit,
            },
            {
              key: 'device_category',
              header: 'Device',
              render: (r: IncidentRow) => r.device_category,
            },
            {
              key: 'severity',
              header: 'Severity',
              render: (r: IncidentRow) => r.severity.toUpperCase(),
            },
            {
              key: 'response_minutes',
              header: 'Resp min',
              render: (r: IncidentRow) => fmtNum(r.response_minutes, 2),
            },
            {
              key: 'resolution_minutes',
              header: 'Res min',
              render: (r: IncidentRow) =>
                r.resolution_minutes === null ? '-' : fmtNum(r.resolution_minutes, 2),
            },
            {
              key: 'on_call_engineer',
              header: 'On-call',
              render: (r: IncidentRow) => r.on_call_engineer,
            },
            {
              key: 'outcome',
              header: 'Outcome',
              render: (r: IncidentRow) => r.outcome,
            },
            {
              key: 'sla_breach',
              header: 'Breach',
              render: (r: IncidentRow) => (r.sla_breach ? 'YES' : 'no'),
            },
            {
              key: 'notes',
              header: 'Notes',
              render: (r: IncidentRow) => r.notes ?? '',
            },
          ]}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Response Distribution</h2>
          <DataTable
            rows={dist}
            rowKey={(r, i) => String(r.bucket ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'bucket', header: 'Bucket', render: (r: DistRow) => r.bucket },
              {
                key: 'incident_count',
                header: 'Incidents',
                render: (r: DistRow) => r.incident_count,
              },
              {
                key: 'breach_count',
                header: 'Breaches',
                render: (r: DistRow) => r.breach_count,
              },
            ]}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Severity × Outcome</h2>
          <DataTable
            rows={matrix}
            rowKey={(r, i) => r.severity + '-' + r.outcome + '-' + i}
            emptyMessage="No data"
            columns={[
              {
                key: 'severity',
                header: 'Severity',
                render: (r: MatrixRow) => r.severity.toUpperCase(),
              },
              {
                key: 'outcome',
                header: 'Outcome',
                render: (r: MatrixRow) => r.outcome,
              },
              {
                key: 'incident_count',
                header: 'Count',
                render: (r: MatrixRow) => r.incident_count,
              },
              {
                key: 'avg_response',
                header: 'Avg min',
                render: (r: MatrixRow) => fmtNum(r.avg_response, 2),
              },
            ]}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">On-Call Engineer Load</h2>
        <DataTable
          rows={load}
          rowKey={(r, i) => String(r.on_call_engineer ?? i)}
          emptyMessage="No data"
          columns={[
            {
              key: 'on_call_engineer',
              header: 'Engineer',
              render: (r: LoadRow) => r.on_call_engineer,
            },
            {
              key: 'incident_count',
              header: 'Incidents',
              render: (r: LoadRow) => r.incident_count,
            },
            {
              key: 'breach_count',
              header: 'Breaches',
              render: (r: LoadRow) => r.breach_count,
            },
            {
              key: 'avg_response',
              header: 'Avg min',
              render: (r: LoadRow) => fmtNum(r.avg_response, 2),
            },
          ]}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
      {hint ? <div className="mt-1 text-xs text-gray-500">{hint}</div> : null}
    </div>
  );
}

function OutcomeBadge({ value }: { value: string }) {
  const v = (value || '').toLowerCase();
  const color =
    v === 'green'
      ? 'bg-green-100 text-green-800'
      : v === 'amber'
      ? 'bg-amber-100 text-amber-800'
      : v === 'red'
      ? 'bg-red-100 text-red-800'
      : 'bg-gray-100 text-gray-800';
  return (
    <span className={'inline-block rounded-full px-2 py-0.5 text-xs font-medium ' + color}>
      {v}
    </span>
  );
}
