import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: any }) {
  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-3">
      <div className="text-xs text-zinc-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-zinc-900">{value ?? "-"}</div>
    </div>
  );
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisR, activeR, byRiskR, byTypeR, convosR, ladderR, overdueR] = await Promise.all([
    sb.rpc('founder_engineer_side_projects_kpis_r1469'),
    sb.rpc('founder_engineer_side_projects_active_list_r1469'),
    sb.rpc('founder_engineer_side_projects_by_risk_r1469'),
    sb.rpc('founder_engineer_side_projects_by_type_r1469'),
    sb.rpc('founder_engineer_side_projects_recent_convos_r1469'),
    sb.rpc('founder_engineer_side_projects_action_ladder_r1469'),
    sb.rpc('founder_engineer_side_projects_overdue_followups_r1469'),
  ]);

  const k: any = (kpisR.data?.[0]) ?? {};
  const active: any[] = activeR.data ?? [];
  const byRisk: any[] = byRiskR.data ?? [];
  const byType: any[] = byTypeR.data ?? [];
  const convos: any[] = convosR.data ?? [];
  const ladder: any[] = ladderR.data ?? [];
  const overdue: any[] = overdueR.data ?? [];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold text-zinc-900">Engineer side-projects intel</h1>
        <p className="text-sm text-zinc-500">
          Track engineers running side businesses, flag conflict-of-interest, document conversations, escalate via the founder action ladder L1 {"->"} L5.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total intel records" value={k.total_intel_records ?? 0} />
        <Kpi label="Open cases" value={k.open_cases ?? 0} />
        <Kpi label="Investigating" value={k.investigating_cases ?? 0} />
        <Kpi label="Documented" value={k.documented_cases ?? 0} />
        <Kpi label="Resolved" value={k.resolved_cases ?? 0} />
        <Kpi label="Terminated" value={k.terminated_cases ?? 0} />
        <Kpi label="Critical risk" value={k.critical_risk ?? 0} />
        <Kpi label="High risk" value={k.high_risk ?? 0} />
        <Kpi label="Medium risk" value={k.medium_risk ?? 0} />
        <Kpi label="Low risk" value={k.low_risk ?? 0} />
        <Kpi label="Engineers with intel" value={k.engineers_with_intel ?? 0} />
        <Kpi label="Using brand" value={k.using_equipseva_brand ?? 0} />
        <Kpi label="Using parts" value={k.using_equipseva_parts ?? 0} />
        <Kpi label="Poaching customers" value={k.poaching_customers ?? 0} />
        <Kpi label="Est. revenue leak / mo" value={formatRupees(Number(k.est_revenue_leak_rupees ?? 0))} />
        <Kpi label="Overdue follow-ups" value={k.follow_ups_overdue ?? 0} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">Active cases (top 200)</h2>
        <DataTable
          rows={active}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "-" },
            { key: 'side_business_type', header: 'Type', render: (r: any) => r.side_business_type ?? "-" },
            { key: 'business_name', header: 'Business', render: (r: any) => r.business_name ?? "-" },
            { key: 'conflict_risk', header: 'Risk', render: (r: any) => r.conflict_risk ?? "-" },
            { key: 'status', header: 'Status', render: (r: any) => r.status ?? "-" },
            { key: 'founder_action_level', header: 'Action L', render: (r: any) => `L${r.founder_action_level ?? 1}` },
            { key: 'est_monthly_revenue_rupees', header: 'Est ₹/mo', render: (r: any) => formatRupees(Number(r.est_monthly_revenue_rupees ?? 0)) },
            { key: 'uses_brand', header: 'Brand?', render: (r: any) => r.uses_brand ? 'yes' : 'no' },
            { key: 'uses_parts', header: 'Parts?', render: (r: any) => r.uses_parts ? 'yes' : 'no' },
            { key: 'poaching', header: 'Poach?', render: (r: any) => r.poaching ? 'yes' : 'no' },
          ]}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold text-zinc-900">By conflict risk</h2>
          <DataTable
            rows={byRisk}
            rowKey={(r: any) => r.conflict_risk}
            columns={[
              { key: 'conflict_risk', header: 'Risk', render: (r: any) => r.conflict_risk ?? "-" },
              { key: 'case_count', header: 'Cases', render: (r: any) => r.case_count ?? 0 },
              { key: 'est_revenue_leak_rupees', header: 'Est ₹/mo', render: (r: any) => formatRupees(Number(r.est_revenue_leak_rupees ?? 0)) },
              { key: 'avg_action_level', header: 'Avg L', render: (r: any) => Number(r.avg_action_level ?? 0).toFixed(2) },
            ]}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold text-zinc-900">By business type</h2>
          <DataTable
            rows={byType}
            rowKey={(r: any) => r.side_business_type}
            columns={[
              { key: 'side_business_type', header: 'Type', render: (r: any) => r.side_business_type ?? "-" },
              { key: 'case_count', header: 'Cases', render: (r: any) => r.case_count ?? 0 },
              { key: 'critical_or_high', header: 'Crit+High', render: (r: any) => r.critical_or_high ?? 0 },
              { key: 'est_revenue_leak_rupees', header: 'Est ₹/mo', render: (r: any) => formatRupees(Number(r.est_revenue_leak_rupees ?? 0)) },
              { key: 'poaching_count', header: 'Poach', render: (r: any) => r.poaching_count ?? 0 },
            ]}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">Founder action ladder (L1 {"->"} L5)</h2>
        <DataTable
          rows={ladder}
          rowKey={(r: any) => String(r.action_level)}
          columns={[
            { key: 'action_level', header: 'Level', render: (r: any) => `L${r.action_level ?? 1}` },
            { key: 'level_label', header: 'Label', render: (r: any) => r.level_label ?? "-" },
            { key: 'case_count', header: 'Cases', render: (r: any) => r.case_count ?? 0 },
            { key: 'est_revenue_leak_rupees', header: 'Est ₹/mo', render: (r: any) => formatRupees(Number(r.est_revenue_leak_rupees ?? 0)) },
            { key: 'last_convo_at', header: 'Last convo', render: (r: any) => r.last_convo_at ? new Date(r.last_convo_at).toLocaleString() : "-" },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">Recent conversations (100)</h2>
        <DataTable
          rows={convos}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'conversation_at', header: 'When', render: (r: any) => r.conversation_at ? new Date(r.conversation_at).toLocaleString() : "-" },
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "-" },
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? "-" },
            { key: 'tone', header: 'Tone', render: (r: any) => r.tone ?? "-" },
            { key: 'action_level', header: 'Action L', render: (r: any) => `L${r.action_level ?? 1}` },
            { key: 'summary', header: 'Summary', render: (r: any) => r.summary ?? "-" },
            { key: 'follow_up_due_at', header: 'Follow-up due', render: (r: any) => r.follow_up_due_at ? new Date(r.follow_up_due_at).toLocaleDateString() : "-" },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-zinc-900">Overdue follow-ups</h2>
        <DataTable
          rows={overdue}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "-" },
            { key: 'conflict_risk', header: 'Risk', render: (r: any) => r.conflict_risk ?? "-" },
            { key: 'follow_up_due_at', header: 'Due', render: (r: any) => r.follow_up_due_at ? new Date(r.follow_up_due_at).toLocaleDateString() : "-" },
            { key: 'days_overdue', header: 'Days late', render: (r: any) => r.days_overdue ?? 0 },
            { key: 'last_summary', header: 'Last summary', render: (r: any) => r.last_summary ?? "-" },
          ]}
        />
      </section>
    </div>
  );
}
