import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, collabsRes, byDomainRes, byChainRes, ipMixRes, atRiskRes, pubPipeRes, stratRes] = await Promise.all([
    supabase.rpc('founder_r2759_overview'),
    supabase.rpc('founder_r2759_collaborations'),
    supabase.rpc('founder_r2759_by_domain'),
    supabase.rpc('founder_r2759_by_chain'),
    supabase.rpc('founder_r2759_ip_mix'),
    supabase.rpc('founder_r2759_at_risk_milestones'),
    supabase.rpc('founder_r2759_publication_pipeline'),
    supabase.rpc('founder_r2759_strategic_value_summary'),
  ]);

  const overview = (overviewRes.data && overviewRes.data[0]) || { total_collabs: 0, active_collabs: 0, flagship_collabs: 0, total_budget_lakhs: 0, publications_pending: 0 };
  const collabs = collabsRes.data || [];
  const byDomain = byDomainRes.data || [];
  const byChain = byChainRes.data || [];
  const ipMix = ipMixRes.data || [];
  const atRisk = atRiskRes.data || [];
  const pubPipe = pubPipeRes.data || [];
  const strat = stratRes.data || [];

  const kpi = (label: string, value: string | number) => (
    <div className="rounded-lg border border-slate-700 bg-slate-900/60 p-4">
      <div className="text-xs uppercase tracking-wide text-slate-400">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-slate-100">{value}</div>
    </div>
  );

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6 text-slate-100">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Clinical Research Collaboration</h1>
        <p className="text-sm text-slate-400">Round r2759 — chain × research × our role × publication × IP × strategic value.</p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-5">
        {kpi('Total collabs', overview.total_collabs)}
        {kpi('Active', overview.active_collabs)}
        {kpi('Flagship', overview.flagship_collabs)}
        {kpi('Budget (lakhs)', `₹${Number(overview.total_budget_lakhs ?? 0).toFixed(1)}L`)}
        {kpi('Publications pending', overview.publications_pending)}
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Active collaborations</h2>
        <DataTable
          rows={collabs}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'research_title', header: 'Title', render: (r: any) => r.research_title },
            { key: 'research_domain', header: 'Domain', render: (r: any) => r.research_domain },
            { key: 'our_role', header: 'Our role', render: (r: any) => r.our_role },
            { key: 'publication_target', header: 'Target', render: (r: any) => r.publication_target },
            { key: 'ip_arrangement', header: 'IP', render: (r: any) => r.ip_arrangement },
            { key: 'strategic_value', header: 'Strategic', render: (r: any) => r.strategic_value },
            { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter },
            { key: 'budget_lakhs', header: 'Budget (L)', render: (r: any) => `₹${Number(r.budget_lakhs).toFixed(1)}` },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div>
          <h2 className="mb-2 text-lg font-semibold">By research domain</h2>
          <DataTable
            rows={byDomain}
            columns={[
              { key: 'research_domain', header: 'Domain', render: (r: any) => r.research_domain },
              { key: 'collab_count', header: 'Count', render: (r: any) => r.collab_count },
              { key: 'total_budget', header: 'Budget (L)', render: (r: any) => `₹${Number(r.total_budget).toFixed(1)}` },
              { key: 'flagship_count', header: 'Flagship', render: (r: any) => r.flagship_count },
            ]}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.research_domain ?? i)}
          />
        </div>

        <div>
          <h2 className="mb-2 text-lg font-semibold">By chain partner</h2>
          <DataTable
            rows={byChain}
            columns={[
              { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
              { key: 'collab_count', header: 'Count', render: (r: any) => r.collab_count },
              { key: 'total_budget', header: 'Budget (L)', render: (r: any) => `₹${Number(r.total_budget).toFixed(1)}` },
              { key: 'our_lead_count', header: 'We lead', render: (r: any) => r.our_lead_count },
            ]}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
          />
        </div>
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div>
          <h2 className="mb-2 text-lg font-semibold">IP arrangement mix</h2>
          <DataTable
            rows={ipMix}
            columns={[
              { key: 'ip_arrangement', header: 'IP', render: (r: any) => r.ip_arrangement },
              { key: 'collab_count', header: 'Count', render: (r: any) => r.collab_count },
              { key: 'total_budget', header: 'Budget (L)', render: (r: any) => `₹${Number(r.total_budget).toFixed(1)}` },
            ]}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.ip_arrangement ?? i)}
          />
        </div>

        <div>
          <h2 className="mb-2 text-lg font-semibold">Strategic value summary</h2>
          <DataTable
            rows={strat}
            columns={[
              { key: 'strategic_value', header: 'Tier', render: (r: any) => r.strategic_value },
              { key: 'collab_count', header: 'Count', render: (r: any) => r.collab_count },
              { key: 'total_budget', header: 'Budget (L)', render: (r: any) => `₹${Number(r.total_budget).toFixed(1)}` },
              { key: 'flagship_publications', header: 'Flagship pubs', render: (r: any) => r.flagship_publications },
            ]}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.strategic_value ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Publication pipeline (unpublished)</h2>
        <DataTable
          rows={pubPipe}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'research_title', header: 'Title', render: (r: any) => r.research_title },
            { key: 'publication_target', header: 'Target', render: (r: any) => r.publication_target },
            { key: 'expected_publication_date', header: 'Expected', render: (r: any) => r.expected_publication_date ?? '—' },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
            { key: 'strategic_value', header: 'Strategic', render: (r: any) => r.strategic_value },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(`${r.chain_name}-${r.research_title}-${i}`)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">At-risk & pending milestones</h2>
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'research_title', header: 'Title', render: (r: any) => r.research_title },
            { key: 'milestone_label', header: 'Milestone', render: (r: any) => r.milestone_label },
            { key: 'milestone_type', header: 'Type', render: (r: any) => r.milestone_type },
            { key: 'due_date', header: 'Due', render: (r: any) => r.due_date },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
            { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>
    </div>
  );
}
