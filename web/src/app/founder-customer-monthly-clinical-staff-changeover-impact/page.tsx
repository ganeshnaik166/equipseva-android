import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_changeovers: number;
  critical_count: number;
  high_count: number;
  avg_adoption_drop: number | null;
  avg_support_uplift: number | null;
  total_mrr_at_risk: number;
};

type Changeover = {
  id: string;
  customer_org_name: string;
  customer_tier: string;
  outgoing_clinician_name: string;
  outgoing_role: string;
  incoming_clinician_name: string;
  incoming_role: string;
  changeover_date: string;
  handoff_days_planned: number;
  handoff_days_actual: number;
  handoff_quality: string;
  knowledge_transfer_pct: number;
  adoption_score_pre: number;
  adoption_score_post: number;
  support_tickets_30d: number;
  support_tickets_pre_30d: number;
  risk_level: string;
};

type HighRisk = {
  customer_org_name: string;
  outgoing_clinician_name: string;
  incoming_clinician_name: string;
  risk_level: string;
  adoption_drop: number;
  support_uplift: number;
  handoff_quality: string;
};

type Monthly = {
  id: string;
  month_start: string;
  customer_org_name: string;
  changeovers_count: number;
  high_risk_count: number;
  avg_adoption_drop_pct: number;
  avg_support_uplift: number;
  mrr_at_risk_rupees: number;
  intervention_status: string;
  csm_owner: string;
  notes: string | null;
};

type Quality = {
  handoff_quality: string;
  n: number;
  avg_adoption_drop: number | null;
  avg_support_uplift: number | null;
};

type RolePattern = {
  outgoing_role: string;
  n: number;
  avg_knowledge_transfer: number | null;
  critical_count: number;
};

type Intervention = {
  customer_org_name: string;
  csm_owner: string;
  intervention_status: string;
  mrr_at_risk_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, changeoversRes, highRiskRes, monthlyRes, qualityRes, roleRes, interventionRes] = await Promise.all([
    supabase.rpc('founder_r2772_summary'),
    supabase.rpc('founder_r2772_changeovers'),
    supabase.rpc('founder_r2772_high_risk'),
    supabase.rpc('founder_r2772_monthly_impact'),
    supabase.rpc('founder_r2772_handoff_quality_breakdown'),
    supabase.rpc('founder_r2772_role_pattern'),
    supabase.rpc('founder_r2772_intervention_queue'),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] as Summary | undefined) ?? null;
  const changeovers: Changeover[] = (changeoversRes.data as Changeover[] | null) ?? [];
  const highRisk: HighRisk[] = (highRiskRes.data as HighRisk[] | null) ?? [];
  const monthly: Monthly[] = (monthlyRes.data as Monthly[] | null) ?? [];
  const quality: Quality[] = (qualityRes.data as Quality[] | null) ?? [];
  const roles: RolePattern[] = (roleRes.data as RolePattern[] | null) ?? [];
  const interventions: Intervention[] = (interventionRes.data as Intervention[] | null) ?? [];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Customer Monthly Clinical Staff Changeover Impact</h1>
        <p className="text-sm text-gray-600">
          Track outgoing → incoming clinician handoffs, knowledge transfer, adoption drop, and
          support need uplift across customer accounts.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-4">
        <KPI label="Total Changeovers" value={summary?.total_changeovers ?? 0} />
        <KPI label="Critical Risk" value={summary?.critical_count ?? 0} tone="red" />
        <KPI label="High Risk" value={summary?.high_count ?? 0} tone="amber" />
        <KPI label="Avg Adoption Drop" value={`${summary?.avg_adoption_drop ?? 0} pts`} />
        <KPI label="Avg Support Uplift" value={`${summary?.avg_support_uplift ?? 0} tix`} />
        <KPI label="MRR at Risk" value={`Rs ${(summary?.total_mrr_at_risk ?? 0).toLocaleString('en-IN')}`} tone="red" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">High-Risk Changeovers (adoption drop &gt;= threshold)</h2>
        <DataTable
          rows={highRisk}
          rowKey={(r, i) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: HighRisk) => r.customer_org_name },
            { key: 'outgoing_clinician_name', header: 'Outgoing', render: (r: HighRisk) => r.outgoing_clinician_name },
            { key: 'incoming_clinician_name', header: 'Incoming', render: (r: HighRisk) => r.incoming_clinician_name },
            { key: 'risk_level', header: 'Risk', render: (r: HighRisk) => r.risk_level },
            { key: 'adoption_drop', header: 'Adoption Drop', render: (r: HighRisk) => `${r.adoption_drop} pts` },
            { key: 'support_uplift', header: 'Support Uplift', render: (r: HighRisk) => `${r.support_uplift} tix` },
            { key: 'handoff_quality', header: 'Handoff', render: (r: HighRisk) => r.handoff_quality },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Changeover Events</h2>
        <DataTable
          rows={changeovers}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'changeover_date', header: 'Date', render: (r: Changeover) => r.changeover_date },
            { key: 'customer_org_name', header: 'Customer', render: (r: Changeover) => `${r.customer_org_name} (${r.customer_tier})` },
            { key: 'outgoing', header: 'Outgoing', render: (r: Changeover) => `${r.outgoing_clinician_name} / ${r.outgoing_role}` },
            { key: 'incoming', header: 'Incoming', render: (r: Changeover) => `${r.incoming_clinician_name} / ${r.incoming_role}` },
            { key: 'handoff_days', header: 'Handoff Days (plan/actual)', render: (r: Changeover) => `${r.handoff_days_planned} / ${r.handoff_days_actual}` },
            { key: 'handoff_quality', header: 'Quality', render: (r: Changeover) => r.handoff_quality },
            { key: 'knowledge_transfer_pct', header: 'KT %', render: (r: Changeover) => `${r.knowledge_transfer_pct}%` },
            { key: 'adoption', header: 'Adoption (pre → post)', render: (r: Changeover) => `${r.adoption_score_pre} → ${r.adoption_score_post}` },
            { key: 'support', header: 'Support 30d (pre / post)', render: (r: Changeover) => `${r.support_tickets_pre_30d} / ${r.support_tickets_30d}` },
            { key: 'risk_level', header: 'Risk', render: (r: Changeover) => r.risk_level },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Impact Rollup</h2>
        <DataTable
          rows={monthly}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'month_start', header: 'Month', render: (r: Monthly) => r.month_start },
            { key: 'customer_org_name', header: 'Customer', render: (r: Monthly) => r.customer_org_name },
            { key: 'changeovers_count', header: 'Events', render: (r: Monthly) => r.changeovers_count },
            { key: 'high_risk_count', header: 'High-Risk', render: (r: Monthly) => r.high_risk_count },
            { key: 'avg_adoption_drop_pct', header: 'Avg Adoption Drop %', render: (r: Monthly) => `${r.avg_adoption_drop_pct}%` },
            { key: 'avg_support_uplift', header: 'Avg Support Uplift', render: (r: Monthly) => r.avg_support_uplift },
            { key: 'mrr_at_risk_rupees', header: 'MRR at Risk', render: (r: Monthly) => `Rs ${r.mrr_at_risk_rupees.toLocaleString('en-IN')}` },
            { key: 'intervention_status', header: 'Status', render: (r: Monthly) => r.intervention_status },
            { key: 'csm_owner', header: 'CSM', render: (r: Monthly) => r.csm_owner },
            { key: 'notes', header: 'Notes', render: (r: Monthly) => r.notes ?? '' },
          ]}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Handoff Quality Breakdown</h2>
          <DataTable
            rows={quality}
            rowKey={(r, i) => String(i)}
            emptyMessage="No data"
            columns={[
              { key: 'handoff_quality', header: 'Quality', render: (r: Quality) => r.handoff_quality },
              { key: 'n', header: 'N', render: (r: Quality) => r.n },
              { key: 'avg_adoption_drop', header: 'Avg Adoption Drop', render: (r: Quality) => r.avg_adoption_drop ?? 0 },
              { key: 'avg_support_uplift', header: 'Avg Support Uplift', render: (r: Quality) => r.avg_support_uplift ?? 0 },
            ]}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Role Pattern</h2>
          <DataTable
            rows={roles}
            rowKey={(r, i) => String(i)}
            emptyMessage="No data"
            columns={[
              { key: 'outgoing_role', header: 'Outgoing Role', render: (r: RolePattern) => r.outgoing_role },
              { key: 'n', header: 'N', render: (r: RolePattern) => r.n },
              { key: 'avg_knowledge_transfer', header: 'Avg KT %', render: (r: RolePattern) => `${r.avg_knowledge_transfer ?? 0}%` },
              { key: 'critical_count', header: 'Critical Events', render: (r: RolePattern) => r.critical_count },
            ]}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Intervention Queue (active)</h2>
        <DataTable
          rows={interventions}
          rowKey={(r, i) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: Intervention) => r.customer_org_name },
            { key: 'csm_owner', header: 'CSM Owner', render: (r: Intervention) => r.csm_owner },
            { key: 'intervention_status', header: 'Status', render: (r: Intervention) => r.intervention_status },
            { key: 'mrr_at_risk_rupees', header: 'MRR at Risk', render: (r: Intervention) => `Rs ${r.mrr_at_risk_rupees.toLocaleString('en-IN')}` },
            { key: 'notes', header: 'Notes', render: (r: Intervention) => r.notes ?? '' },
          ]}
        />
      </section>
    </main>
  );
}

function KPI({ label, value, tone }: { label: string; value: string | number; tone?: 'red' | 'amber' }) {
  const toneClass = tone === 'red' ? 'text-red-700' : tone === 'amber' ? 'text-amber-700' : 'text-gray-900';
  return (
    <div className="rounded border border-gray-200 p-3 bg-white">
      <div className="text-xs text-gray-500">{label}</div>
      <div className={`text-xl font-semibold ${toneClass}`}>{value}</div>
    </div>
  );
}
