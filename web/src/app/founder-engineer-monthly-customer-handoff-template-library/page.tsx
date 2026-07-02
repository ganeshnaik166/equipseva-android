import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_templates: number;
  active_templates: number;
  winners: number;
  killed: number;
  total_uses: number;
  global_avg_score: number | string;
};

type ByKind = {
  template_kind: string;
  count_total: number;
  count_winner: number;
  count_killed: number;
  avg_score_kind: number | string;
  total_uses: number;
};

type Winner = {
  template_code: string;
  template_name: string;
  template_kind: string;
  use_count: number;
  avg_score: number | string;
  refinement_round: number;
};

type KillRow = {
  template_code: string;
  template_name: string;
  template_kind: string;
  avg_score: number | string;
  use_count: number;
  reason: string;
};

type Refinement = {
  refinement_round: number;
  template_count: number;
  avg_score_round: number | string;
  total_uses_round: number;
};

type Usage = {
  template_code: string;
  engineer_handle: string;
  hospital_name: string;
  sent_at: string;
  customer_score: number | null;
  outcome: string;
};

type Outcome = {
  outcome: string;
  count_outcome: number;
  pct_share: number | string;
};

type Engineer = {
  engineer_handle: string;
  templates_sent: number;
  avg_score_eng: number | string;
  closed_won_count: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, byKindRes, winnersRes, killRes, refinementRes, usageRes, outcomeRes, engRes] =
    await Promise.all([
      supabase.rpc('rpc_handoff_template_kpi_r2706'),
      supabase.rpc('rpc_handoff_template_by_kind_r2706'),
      supabase.rpc('rpc_handoff_template_winners_r2706'),
      supabase.rpc('rpc_handoff_template_kill_list_r2706'),
      supabase.rpc('rpc_handoff_template_refinement_r2706'),
      supabase.rpc('rpc_handoff_template_recent_usage_r2706'),
      supabase.rpc('rpc_handoff_template_outcomes_r2706'),
      supabase.rpc('rpc_handoff_template_top_engineers_r2706'),
    ]);

  const kpi = (kpiRes.data?.[0] ?? null) as Kpi | null;
  const byKind = (byKindRes.data ?? []) as ByKind[];
  const winners = (winnersRes.data ?? []) as Winner[];
  const killList = (killRes.data ?? []) as KillRow[];
  const refinements = (refinementRes.data ?? []) as Refinement[];
  const usage = (usageRes.data ?? []) as Usage[];
  const outcomes = (outcomeRes.data ?? []) as Outcome[];
  const engineers = (engRes.data ?? []) as Engineer[];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Monthly Customer Handoff Template Library</h1>
        <p className="text-sm text-gray-600">
          Round r2706 · template kind × use count × avg score × refinement × winner × kill
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <KpiCard label="Total templates" value={kpi?.total_templates ?? 0} />
        <KpiCard label="Active" value={kpi?.active_templates ?? 0} />
        <KpiCard label="Winners" value={kpi?.winners ?? 0} />
        <KpiCard label="Killed" value={kpi?.killed ?? 0} />
        <KpiCard label="Total uses" value={kpi?.total_uses ?? 0} />
        <KpiCard label="Global avg score" value={String(kpi?.global_avg_score ?? '0')} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">By template kind</h2>
        <DataTable
          rows={byKind}
          columns={[
            { key: 'template_kind', header: 'Kind', render: (r: ByKind) => r.template_kind },
            { key: 'count_total', header: 'Total', render: (r: ByKind) => r.count_total },
            { key: 'count_winner', header: 'Winners', render: (r: ByKind) => r.count_winner },
            { key: 'count_killed', header: 'Killed', render: (r: ByKind) => r.count_killed },
            { key: 'avg_score_kind', header: 'Avg score', render: (r: ByKind) => String(r.avg_score_kind) },
            { key: 'total_uses', header: 'Uses', render: (r: ByKind) => r.total_uses },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByKind, i: number) => String(r.template_kind ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Winners (avg score &gt;= 4.5)</h2>
        <DataTable
          rows={winners}
          columns={[
            { key: 'template_code', header: 'Code', render: (r: Winner) => r.template_code },
            { key: 'template_name', header: 'Name', render: (r: Winner) => r.template_name },
            { key: 'template_kind', header: 'Kind', render: (r: Winner) => r.template_kind },
            { key: 'use_count', header: 'Uses', render: (r: Winner) => r.use_count },
            { key: 'avg_score', header: 'Score', render: (r: Winner) => String(r.avg_score) },
            { key: 'refinement_round', header: 'Refine', render: (r: Winner) => r.refinement_round },
          ]}
          emptyMessage="No winners"
          rowKey={(r: Winner, i: number) => String(r.template_code ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Kill list (score &lt; 3.0 or deprecated)</h2>
        <DataTable
          rows={killList}
          columns={[
            { key: 'template_code', header: 'Code', render: (r: KillRow) => r.template_code },
            { key: 'template_name', header: 'Name', render: (r: KillRow) => r.template_name },
            { key: 'template_kind', header: 'Kind', render: (r: KillRow) => r.template_kind },
            { key: 'avg_score', header: 'Score', render: (r: KillRow) => String(r.avg_score) },
            { key: 'use_count', header: 'Uses', render: (r: KillRow) => r.use_count },
            { key: 'reason', header: 'Reason', render: (r: KillRow) => r.reason },
          ]}
          emptyMessage="No kills"
          rowKey={(r: KillRow, i: number) => String(r.template_code ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Refinement ladder</h2>
        <DataTable
          rows={refinements}
          columns={[
            { key: 'refinement_round', header: 'Round', render: (r: Refinement) => r.refinement_round },
            { key: 'template_count', header: 'Templates', render: (r: Refinement) => r.template_count },
            { key: 'avg_score_round', header: 'Avg score', render: (r: Refinement) => String(r.avg_score_round) },
            { key: 'total_uses_round', header: 'Uses', render: (r: Refinement) => r.total_uses_round },
          ]}
          emptyMessage="No data"
          rowKey={(r: Refinement, i: number) => String(r.refinement_round ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Outcome distribution</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: Outcome) => r.outcome },
            { key: 'count_outcome', header: 'Count', render: (r: Outcome) => r.count_outcome },
            { key: 'pct_share', header: 'Share %', render: (r: Outcome) => String(r.pct_share) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Outcome, i: number) => String(r.outcome ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top engineers</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_handle', header: 'Engineer', render: (r: Engineer) => r.engineer_handle },
            { key: 'templates_sent', header: 'Sent', render: (r: Engineer) => r.templates_sent },
            { key: 'avg_score_eng', header: 'Avg score', render: (r: Engineer) => String(r.avg_score_eng) },
            { key: 'closed_won_count', header: 'Closed won', render: (r: Engineer) => r.closed_won_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: Engineer, i: number) => String(r.engineer_handle ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent usage</h2>
        <DataTable
          rows={usage}
          columns={[
            { key: 'template_code', header: 'Template', render: (r: Usage) => r.template_code },
            { key: 'engineer_handle', header: 'Engineer', render: (r: Usage) => r.engineer_handle },
            { key: 'hospital_name', header: 'Hospital', render: (r: Usage) => r.hospital_name },
            { key: 'sent_at', header: 'Sent', render: (r: Usage) => new Date(r.sent_at).toLocaleString() },
            { key: 'customer_score', header: 'Score', render: (r: Usage) => (r.customer_score == null ? '-' : String(r.customer_score)) },
            { key: 'outcome', header: 'Outcome', render: (r: Usage) => r.outcome },
          ]}
          emptyMessage="No usage"
          rowKey={(r: Usage, i: number) => String(i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-3 shadow-sm">
      <div className="text-xs uppercase text-gray-500">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
    </div>
  );
}
