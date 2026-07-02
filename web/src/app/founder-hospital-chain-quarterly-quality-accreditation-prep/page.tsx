import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_chains: number;
  total_sites: number;
  avg_prep_pct: number;
  total_open_gaps: number;
  at_risk: number;
  blocked: number;
};

type ChainRow = {
  chain_name: string;
  accreditation_body: string;
  phase: string;
  cycle_quarter: string;
  sites_in_scope: number;
  our_prep_pct: number;
  open_gaps: number;
  verdict: string;
  assessor_visit_on: string | null;
  critical_action: string;
};

type GapRow = {
  chain_name: string;
  gap_area: string;
  severity: string;
  evidence_required: string;
  evidence_supplied_pct: number;
  action_owner: string;
  due_on: string;
  status: string;
  blocker_note: string | null;
};

type PhaseRow = {
  phase: string;
  chains: number;
  sites: number;
  avg_prep_pct: number;
  open_gaps: number;
};

type CriticalGap = {
  chain_name: string;
  gap_area: string;
  evidence_required: string;
  evidence_supplied_pct: number;
  due_on: string;
  blocker_note: string | null;
};

type Visit = {
  chain_name: string;
  accreditation_body: string;
  phase: string;
  assessor_visit_on: string;
  days_remaining: number;
  our_prep_pct: number;
  verdict: string;
};

type Evidence = {
  gap_area: string;
  total_actions: number;
  avg_evidence_pct: number;
  accepted: number;
  in_progress: number;
  not_started: number;
};

type VerdictMix = {
  verdict: string;
  chains: number;
  sites: number;
  share_pct: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ov, chains, gaps, phases, critical, visits, evidence, verdicts] = await Promise.all([
    supabase.rpc('rpc_r2779_overview'),
    supabase.rpc('rpc_r2779_by_chain'),
    supabase.rpc('rpc_r2779_gap_actions'),
    supabase.rpc('rpc_r2779_by_phase'),
    supabase.rpc('rpc_r2779_critical_gaps'),
    supabase.rpc('rpc_r2779_upcoming_visits'),
    supabase.rpc('rpc_r2779_evidence_progress'),
    supabase.rpc('rpc_r2779_verdict_mix'),
  ]);

  const o: Overview = (ov.data?.[0] as Overview) ?? {
    total_chains: 0,
    total_sites: 0,
    avg_prep_pct: 0,
    total_open_gaps: 0,
    at_risk: 0,
    blocked: 0,
  };

  const chainRows: ChainRow[] = (chains.data as ChainRow[]) ?? [];
  const gapRows: GapRow[] = (gaps.data as GapRow[]) ?? [];
  const phaseRows: PhaseRow[] = (phases.data as PhaseRow[]) ?? [];
  const criticalRows: CriticalGap[] = (critical.data as CriticalGap[]) ?? [];
  const visitRows: Visit[] = (visits.data as Visit[]) ?? [];
  const evidenceRows: Evidence[] = (evidence.data as Evidence[]) ?? [];
  const verdictRows: VerdictMix[] = (verdicts.data as VerdictMix[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Quality Accreditation Prep</h1>
        <p className="text-sm text-gray-600">
          Track NABH / JCI / ISO / NABL / AERB / CAP accreditation readiness across hospital
          chains. Phase, our prep percent, open gaps, action, verdict — quarter by quarter.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Chains</div>
          <div className="text-xl font-semibold">{o.total_chains}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Sites in scope</div>
          <div className="text-xl font-semibold">{o.total_sites}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Avg prep %</div>
          <div className="text-xl font-semibold">{Number(o.avg_prep_pct).toFixed(1)}%</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Open gaps</div>
          <div className="text-xl font-semibold">{o.total_open_gaps}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">At risk</div>
          <div className="text-xl font-semibold text-amber-600">{o.at_risk}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Blocked</div>
          <div className="text-xl font-semibold text-red-600">{o.blocked}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain x Accreditation x Phase</h2>
        <DataTable<ChainRow>
          rows={chainRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'accreditation_body', header: 'Body', render: (r) => r.accreditation_body.toUpperCase() },
            { key: 'phase', header: 'Phase', render: (r) => r.phase.replace(/_/g, ' ') },
            { key: 'cycle_quarter', header: 'Cycle', render: (r) => r.cycle_quarter.toUpperCase() },
            { key: 'sites_in_scope', header: 'Sites', render: (r) => r.sites_in_scope },
            { key: 'our_prep_pct', header: 'Prep %', render: (r) => `${Number(r.our_prep_pct).toFixed(1)}%` },
            { key: 'open_gaps', header: 'Open gaps', render: (r) => r.open_gaps },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict.replace(/_/g, ' ') },
            { key: 'assessor_visit_on', header: 'Assessor visit', render: (r) => r.assessor_visit_on ?? '-' },
            { key: 'critical_action', header: 'Critical action', render: (r) => r.critical_action },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.chain_name + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Gap x Severity x Action</h2>
        <DataTable<GapRow>
          rows={gapRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'gap_area', header: 'Gap area', render: (r) => r.gap_area.replace(/_/g, ' ') },
            { key: 'severity', header: 'Severity', render: (r) => r.severity },
            { key: 'evidence_required', header: 'Evidence required', render: (r) => r.evidence_required },
            { key: 'evidence_supplied_pct', header: 'Supplied %', render: (r) => `${Number(r.evidence_supplied_pct).toFixed(0)}%` },
            { key: 'action_owner', header: 'Owner', render: (r) => r.action_owner },
            { key: 'due_on', header: 'Due', render: (r) => r.due_on },
            { key: 'status', header: 'Status', render: (r) => r.status.replace(/_/g, ' ') },
            { key: 'blocker_note', header: 'Blocker', render: (r) => r.blocker_note ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.chain_name + '-' + r.gap_area + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & High Gaps</h2>
        <DataTable<CriticalGap>
          rows={criticalRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'gap_area', header: 'Gap area', render: (r) => r.gap_area.replace(/_/g, ' ') },
            { key: 'evidence_required', header: 'Evidence', render: (r) => r.evidence_required },
            { key: 'evidence_supplied_pct', header: 'Supplied %', render: (r) => `${Number(r.evidence_supplied_pct).toFixed(0)}%` },
            { key: 'due_on', header: 'Due', render: (r) => r.due_on },
            { key: 'blocker_note', header: 'Blocker', render: (r) => r.blocker_note ?? '-' },
          ]}
          emptyMessage="No critical gaps"
          rowKey={(r, i) => String(r.chain_name + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Assessor Visits</h2>
        <DataTable<Visit>
          rows={visitRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'accreditation_body', header: 'Body', render: (r) => r.accreditation_body.toUpperCase() },
            { key: 'phase', header: 'Phase', render: (r) => r.phase.replace(/_/g, ' ') },
            { key: 'assessor_visit_on', header: 'Visit on', render: (r) => r.assessor_visit_on },
            { key: 'days_remaining', header: 'Days remaining', render: (r) => r.days_remaining },
            { key: 'our_prep_pct', header: 'Prep %', render: (r) => `${Number(r.our_prep_pct).toFixed(1)}%` },
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict.replace(/_/g, ' ') },
          ]}
          emptyMessage="No upcoming visits"
          rowKey={(r, i) => String(r.chain_name + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Phase Roll-up</h2>
        <DataTable<PhaseRow>
          rows={phaseRows}
          columns={[
            { key: 'phase', header: 'Phase', render: (r) => r.phase.replace(/_/g, ' ') },
            { key: 'chains', header: 'Chains', render: (r) => r.chains },
            { key: 'sites', header: 'Sites', render: (r) => r.sites },
            { key: 'avg_prep_pct', header: 'Avg prep %', render: (r) => `${Number(r.avg_prep_pct).toFixed(1)}%` },
            { key: 'open_gaps', header: 'Open gaps', render: (r) => r.open_gaps },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.phase + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Evidence Progress by Gap Area</h2>
        <DataTable<Evidence>
          rows={evidenceRows}
          columns={[
            { key: 'gap_area', header: 'Gap area', render: (r) => r.gap_area.replace(/_/g, ' ') },
            { key: 'total_actions', header: 'Actions', render: (r) => r.total_actions },
            { key: 'avg_evidence_pct', header: 'Avg evidence %', render: (r) => `${Number(r.avg_evidence_pct).toFixed(1)}%` },
            { key: 'accepted', header: 'Accepted', render: (r) => r.accepted },
            { key: 'in_progress', header: 'In progress', render: (r) => r.in_progress },
            { key: 'not_started', header: 'Not started', render: (r) => r.not_started },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.gap_area + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Verdict Mix</h2>
        <DataTable<VerdictMix>
          rows={verdictRows}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r) => r.verdict.replace(/_/g, ' ') },
            { key: 'chains', header: 'Chains', render: (r) => r.chains },
            { key: 'sites', header: 'Sites', render: (r) => r.sites },
            { key: 'share_pct', header: 'Share %', render: (r) => `${Number(r.share_pct).toFixed(1)}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.verdict + '-' + i)}
        />
      </section>
    </div>
  );
}
