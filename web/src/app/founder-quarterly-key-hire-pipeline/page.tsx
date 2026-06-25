import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_candidates: number;
  in_flight: number;
  offers_extended: number;
  offers_accepted: number;
  offers_declined: number;
  avg_signal: number | string;
  critical_roles_open: number;
  total_offer_value_rupees: number;
};

type PipelineRow = {
  id: string;
  quarter: string;
  role_title: string;
  role_band: string;
  candidate_name: string;
  candidate_source: string;
  stage: string;
  signal_score: number;
  offer_amount_rupees: number | null;
  accepted: boolean;
  decision_impact: string;
  notes: string | null;
};

type FunnelRow = {
  stage: string;
  candidate_count: number;
  avg_signal: number | string;
  pct_of_total: number | string;
};

type SourceRow = {
  candidate_source: string;
  candidates: number;
  accepted_count: number;
  acceptance_rate: number | string | null;
  avg_signal: number | string;
};

type ImpactRow = {
  decision_impact: string;
  candidates: number;
  in_flight: number;
  closed_won: number;
  closed_lost: number;
  total_offer_value_rupees: number;
};

type EventRow = {
  candidate_name: string;
  role_title: string;
  event_type: string;
  from_stage: string | null;
  to_stage: string | null;
  signal_delta: number | null;
  event_at: string;
  note: string | null;
};

type CriticalRow = {
  role_title: string;
  candidate_name: string;
  stage: string;
  signal_score: number;
  days_in_pipeline: number;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '—';
  return '₹' + new Intl.NumberFormat('en-IN').format(n);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, pipelineRes, funnelRes, sourceRes, impactRes, eventsRes, criticalRes] = await Promise.all([
    supabase.rpc('founder_r2733_kpis'),
    supabase.rpc('founder_r2733_pipeline'),
    supabase.rpc('founder_r2733_stage_funnel'),
    supabase.rpc('founder_r2733_source_mix'),
    supabase.rpc('founder_r2733_impact_breakdown'),
    supabase.rpc('founder_r2733_recent_events'),
    supabase.rpc('founder_r2733_critical_open'),
  ]);

  const kpis: Kpis | null = (kpisRes.data?.[0] as Kpis | undefined) ?? null;
  const pipeline: PipelineRow[] = (pipelineRes.data as PipelineRow[]) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[]) ?? [];
  const source: SourceRow[] = (sourceRes.data as SourceRow[]) ?? [];
  const impact: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const events: EventRow[] = (eventsRes.data as EventRow[]) ?? [];
  const critical: CriticalRow[] = (criticalRes.data as CriticalRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Key Hire Pipeline</h1>
        <p className="text-sm text-gray-600">
          Role × candidate × stage × signal × offer × accept × decision impact.
          Track every executive and senior hire from sourced through accepted, weighted by signal score (0–100)
          and decision impact (critical &gt;= high &gt;= medium &gt;= low).
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Candidates</div>
          <div className="text-2xl font-semibold">{kpis?.total_candidates ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">In Flight</div>
          <div className="text-2xl font-semibold">{kpis?.in_flight ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Offers Accepted</div>
          <div className="text-2xl font-semibold">{kpis?.offers_accepted ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Offers Declined</div>
          <div className="text-2xl font-semibold">{kpis?.offers_declined ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg Signal</div>
          <div className="text-2xl font-semibold">{String(kpis?.avg_signal ?? '0')}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Critical Roles Open</div>
          <div className="text-2xl font-semibold">{kpis?.critical_roles_open ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4 col-span-2">
          <div className="text-xs text-gray-500">Total Offer Value</div>
          <div className="text-2xl font-semibold">{fmtRupees(kpis?.total_offer_value_rupees ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical Roles Still Open</h2>
        <DataTable
          rows={critical}
          columns={[
            { key: 'role_title', header: 'Role', render: (r: CriticalRow) => <span>{r.role_title}</span> },
            { key: 'candidate_name', header: 'Candidate', render: (r: CriticalRow) => <span>{r.candidate_name}</span> },
            { key: 'stage', header: 'Stage', render: (r: CriticalRow) => <span className="uppercase text-xs">{r.stage}</span> },
            { key: 'signal_score', header: 'Signal', render: (r: CriticalRow) => <span>{r.signal_score}</span> },
            { key: 'days_in_pipeline', header: 'Days In Pipeline', render: (r: CriticalRow) => <span>{r.days_in_pipeline}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: CriticalRow, i: number) => String((r as unknown as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Full Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={[
            { key: 'role_title', header: 'Role', render: (r: PipelineRow) => <span>{r.role_title}</span> },
            { key: 'role_band', header: 'Band', render: (r: PipelineRow) => <span className="uppercase text-xs">{r.role_band}</span> },
            { key: 'candidate_name', header: 'Candidate', render: (r: PipelineRow) => <span>{r.candidate_name}</span> },
            { key: 'candidate_source', header: 'Source', render: (r: PipelineRow) => <span>{r.candidate_source}</span> },
            { key: 'stage', header: 'Stage', render: (r: PipelineRow) => <span className="uppercase text-xs">{r.stage}</span> },
            { key: 'signal_score', header: 'Signal', render: (r: PipelineRow) => <span>{r.signal_score}</span> },
            { key: 'offer_amount_rupees', header: 'Offer', render: (r: PipelineRow) => <span>{fmtRupees(r.offer_amount_rupees)}</span> },
            { key: 'accepted', header: 'Accepted', render: (r: PipelineRow) => <span>{r.accepted ? 'yes' : 'no'}</span> },
            { key: 'decision_impact', header: 'Impact', render: (r: PipelineRow) => <span className="uppercase text-xs">{r.decision_impact}</span> },
            { key: 'notes', header: 'Notes', render: (r: PipelineRow) => <span className="text-xs text-gray-600">{r.notes ?? ''}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: PipelineRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stage Funnel</h2>
        <DataTable
          rows={funnel}
          columns={[
            { key: 'stage', header: 'Stage', render: (r: FunnelRow) => <span className="uppercase text-xs">{r.stage}</span> },
            { key: 'candidate_count', header: 'Count', render: (r: FunnelRow) => <span>{r.candidate_count}</span> },
            { key: 'avg_signal', header: 'Avg Signal', render: (r: FunnelRow) => <span>{String(r.avg_signal ?? '0')}</span> },
            { key: 'pct_of_total', header: '% of Total', render: (r: FunnelRow) => <span>{String(r.pct_of_total ?? '0')}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: FunnelRow, i: number) => String(r.stage ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Source Mix</h2>
        <DataTable
          rows={source}
          columns={[
            { key: 'candidate_source', header: 'Source', render: (r: SourceRow) => <span>{r.candidate_source}</span> },
            { key: 'candidates', header: 'Candidates', render: (r: SourceRow) => <span>{r.candidates}</span> },
            { key: 'accepted_count', header: 'Accepted', render: (r: SourceRow) => <span>{r.accepted_count}</span> },
            { key: 'acceptance_rate', header: 'Acceptance %', render: (r: SourceRow) => <span>{String(r.acceptance_rate ?? '0')}%</span> },
            { key: 'avg_signal', header: 'Avg Signal', render: (r: SourceRow) => <span>{String(r.avg_signal ?? '0')}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: SourceRow, i: number) => String(r.candidate_source ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Impact Breakdown</h2>
        <DataTable
          rows={impact}
          columns={[
            { key: 'decision_impact', header: 'Impact', render: (r: ImpactRow) => <span className="uppercase text-xs">{r.decision_impact}</span> },
            { key: 'candidates', header: 'Candidates', render: (r: ImpactRow) => <span>{r.candidates}</span> },
            { key: 'in_flight', header: 'In Flight', render: (r: ImpactRow) => <span>{r.in_flight}</span> },
            { key: 'closed_won', header: 'Closed Won', render: (r: ImpactRow) => <span>{r.closed_won}</span> },
            { key: 'closed_lost', header: 'Closed Lost', render: (r: ImpactRow) => <span>{r.closed_lost}</span> },
            { key: 'total_offer_value_rupees', header: 'Offer Value', render: (r: ImpactRow) => <span>{fmtRupees(r.total_offer_value_rupees)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ImpactRow, i: number) => String(r.decision_impact ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Stage Events</h2>
        <DataTable
          rows={events}
          columns={[
            { key: 'event_at', header: 'When', render: (r: EventRow) => <span className="text-xs">{new Date(r.event_at).toLocaleString('en-IN')}</span> },
            { key: 'candidate_name', header: 'Candidate', render: (r: EventRow) => <span>{r.candidate_name}</span> },
            { key: 'role_title', header: 'Role', render: (r: EventRow) => <span>{r.role_title}</span> },
            { key: 'event_type', header: 'Event', render: (r: EventRow) => <span className="uppercase text-xs">{r.event_type}</span> },
            { key: 'from_stage', header: 'From', render: (r: EventRow) => <span>{r.from_stage ?? ''}</span> },
            { key: 'to_stage', header: 'To', render: (r: EventRow) => <span>{r.to_stage ?? ''}</span> },
            { key: 'signal_delta', header: 'Signal Delta', render: (r: EventRow) => <span>{r.signal_delta ?? 0}</span> },
            { key: 'note', header: 'Note', render: (r: EventRow) => <span className="text-xs text-gray-600">{r.note ?? ''}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: EventRow, i: number) => String(i)}
        />
      </section>
    </div>
  );
}
