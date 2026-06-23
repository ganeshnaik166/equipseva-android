import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Precheck = {
  id: string;
  hospital_name: string;
  readiness_status: string;
  overall_score: number;
  power_score: number;
  network_score: number;
  ac_score: number;
  calibration_score: number;
  scheduled_amc_start_date: string | null;
  assessor_email: string | null;
  open_gaps: number;
  blocker_gaps: number;
};

type Summary = {
  total: number;
  pending: number;
  assessing: number;
  ready: number;
  blocked: number;
  remediated: number;
  avg_overall_score: number;
  open_blockers: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [{ data: summaryData }, { data: rowsData }] = await Promise.all([
    sb.rpc('fn_r2307_precheck_summary'),
    sb.rpc('fn_r2307_list_prechecks', { p_status: null, p_limit: 100 }),
  ]);

  const summary: Summary = (Array.isArray(summaryData) ? summaryData[0] : summaryData) ?? {
    total: 0, pending: 0, assessing: 0, ready: 0, blocked: 0, remediated: 0, avg_overall_score: 0, open_blockers: 0,
  };
  const rows: Precheck[] = (rowsData ?? []) as Precheck[];

  const cols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span className="font-medium">{r.hospital_name}</span> },
    { key: 'readiness_status', header: 'Status', render: (r: any) => {
      const cls = r.readiness_status === 'ready' ? 'bg-emerald-100 text-emerald-800'
        : r.readiness_status === 'blocked' ? 'bg-red-100 text-red-800'
        : r.readiness_status === 'remediated' ? 'bg-blue-100 text-blue-800'
        : r.readiness_status === 'assessing' ? 'bg-amber-100 text-amber-800'
        : 'bg-zinc-100 text-zinc-700';
      return <span className={`px-2 py-0.5 rounded text-xs font-medium ${cls}`}>{r.readiness_status}</span>;
    } },
    { key: 'overall_score', header: 'Overall', render: (r: any) => <span className="font-mono font-semibold">{r.overall_score}/100</span> },
    { key: 'power_score', header: 'Power', render: (r: any) => <span className="font-mono text-xs">{r.power_score}</span> },
    { key: 'network_score', header: 'Net', render: (r: any) => <span className="font-mono text-xs">{r.network_score}</span> },
    { key: 'ac_score', header: 'AC', render: (r: any) => <span className="font-mono text-xs">{r.ac_score}</span> },
    { key: 'calibration_score', header: 'Calib', render: (r: any) => <span className="font-mono text-xs">{r.calibration_score}</span> },
    { key: 'open_gaps', header: 'Open Gaps', render: (r: any) => (
      <span className={r.blocker_gaps > 0 ? 'text-red-700 font-semibold' : ''}>
        {r.open_gaps}{r.blocker_gaps > 0 ? ` (${r.blocker_gaps} blocker)` : ''}
      </span>
    ) },
    { key: 'scheduled_amc_start_date', header: 'AMC Start', render: (r: any) => <span className="text-xs">{r.scheduled_amc_start_date ?? '—'}</span> },
    { key: 'assessor_email', header: 'Assessor', render: (r: any) => <span className="text-xs text-zinc-600">{r.assessor_email ?? '—'}</span> },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Infra Readiness Pre-check</h1>
        <p className="text-sm text-zinc-600 mt-1">
          Before AMC start, assess hospital infrastructure across power, network, AC &amp; calibration room.
          Score &gt;=80 with zero blocker gaps =&gt; ready to onboard. Gap log tracks remediation.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-zinc-500 uppercase">Total</div>
          <div className="text-2xl font-bold mt-1">{summary.total}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-zinc-500 uppercase">Ready</div>
          <div className="text-2xl font-bold mt-1 text-emerald-700">{summary.ready}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-zinc-500 uppercase">Blocked</div>
          <div className="text-2xl font-bold mt-1 text-red-700">{summary.blocked}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-zinc-500 uppercase">Avg Score</div>
          <div className="text-2xl font-bold mt-1">{summary.avg_overall_score}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-zinc-500 uppercase">Pending</div>
          <div className="text-xl font-semibold mt-1">{summary.pending}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-zinc-500 uppercase">Assessing</div>
          <div className="text-xl font-semibold mt-1 text-amber-700">{summary.assessing}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-zinc-500 uppercase">Remediated</div>
          <div className="text-xl font-semibold mt-1 text-blue-700">{summary.remediated}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-zinc-500 uppercase">Open Blockers</div>
          <div className="text-xl font-semibold mt-1 text-red-700">{summary.open_blockers}</div>
        </div>
      </section>

      <section className="rounded border bg-white">
        <div className="px-4 py-3 border-b">
          <h2 className="font-semibold">Pre-check Pipeline</h2>
          <p className="text-xs text-zinc-500 mt-1">Sorted by urgency: blocked &gt; assessing &gt; pending &gt; remediated &gt; ready.</p>
        </div>
        <DataTable
          rows={rows}
          columns={cols}
          rowKey={(r: any, i: number) => r.id ?? String(i)}
          emptyMessage="No prechecks yet. Create one via fn_r2307_create_precheck."
        />
      </section>

      <section className="rounded border bg-amber-50 p-4 text-sm">
        <h2 className="font-semibold text-amber-900">Scoring Rubric</h2>
        <ul className="list-disc ml-5 mt-2 space-y-1 text-amber-900">
          <li>Power: redundant UPS &amp; generator capacity vs equipment draw.</li>
          <li>Network: bandwidth &gt;=50 Mbps, &lt;1% packet loss, static IP availability.</li>
          <li>AC: temperature 18°C - 24°C, humidity &lt;=60%, redundant cooling.</li>
          <li>Calibration: dedicated room, ESD-safe, traceable reference standards.</li>
          <li>Any blocker gap =&gt; status auto-flips to blocked regardless of score.</li>
        </ul>
      </section>
    </div>
  );
}
