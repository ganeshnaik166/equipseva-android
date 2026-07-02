import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusMix = { audit_status: string; n: number; avg_battery: number };
type CityRollup = { city: string; audits: number; fails: number; warns: number; avg_health: number };
type ModelRisk = { hoist_model: string; n: number; fail_rate_pct: number; avg_cycles: number };
type EngScore = { engineer_name: string; audits: number; passes: number; fails: number };
type FailingCharger = { audit_date: string; customer_org: string; charger_serial: string; battery_health_pct: number; fault_code: string | null };
type RemOpen = { action_date: string; customer_org: string; action_type: string; priority: string; status: string; sla_due_on: string };
type RemSpend = { action_type: string; n: number; total_cost: number; avg_cost: number };
type Retest = { next_audit_due_on: string; customer_org: string; charger_serial: string; audit_status: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [mix, city, model, eng, fail, open, spend, retest] = await Promise.all([
    sb.rpc('r3046_status_mix'),
    sb.rpc('r3046_city_rollup'),
    sb.rpc('r3046_model_risk'),
    sb.rpc('r3046_engineer_scorecard'),
    sb.rpc('r3046_failing_chargers'),
    sb.rpc('r3046_remediation_open'),
    sb.rpc('r3046_remediation_spend'),
    sb.rpc('r3046_upcoming_retests'),
  ]);

  const mixRows = (mix.data ?? []) as StatusMix[];
  const cityRows = (city.data ?? []) as CityRollup[];
  const modelRows = (model.data ?? []) as ModelRisk[];
  const engRows = (eng.data ?? []) as EngScore[];
  const failRows = (fail.data ?? []) as FailingCharger[];
  const openRows = (open.data ?? []) as RemOpen[];
  const spendRows = (spend.data ?? []) as RemSpend[];
  const retestRows = (retest.data ?? []) as Retest[];

  const mixCols: Column<StatusMix>[] = [
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Audits', accessor: (r) => r.n },
    { header: 'Avg Battery %', accessor: (r) => r.avg_battery },
  ];
  const cityCols: Column<CityRollup>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Fails', accessor: (r) => r.fails },
    { header: 'Warns', accessor: (r) => r.warns },
    { header: 'Avg Health', accessor: (r) => r.avg_health },
  ];
  const modelCols: Column<ModelRisk>[] = [
    { header: 'Hoist Model', accessor: (r) => r.hoist_model },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Fail Rate %', accessor: (r) => r.fail_rate_pct },
    { header: 'Avg Cycles', accessor: (r) => r.avg_cycles },
  ];
  const engCols: Column<EngScore>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Pass', accessor: (r) => r.passes },
    { header: 'Fail', accessor: (r) => r.fails },
  ];
  const failCols: Column<FailingCharger>[] = [
    { header: 'Date', accessor: (r) => r.audit_date },
    { header: 'Customer', accessor: (r) => r.customer_org },
    { header: 'Charger', accessor: (r) => r.charger_serial },
    { header: 'Health %', accessor: (r) => r.battery_health_pct },
    { header: 'Fault', accessor: (r) => r.fault_code ?? '-' },
  ];
  const openCols: Column<RemOpen>[] = [
    { header: 'Date', accessor: (r) => r.action_date },
    { header: 'Customer', accessor: (r) => r.customer_org },
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Priority', accessor: (r) => r.priority },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'SLA Due', accessor: (r) => r.sla_due_on },
  ];
  const spendCols: Column<RemSpend>[] = [
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Total ₹', accessor: (r) => r.total_cost },
    { header: 'Avg ₹', accessor: (r) => r.avg_cost },
  ];
  const retestCols: Column<Retest>[] = [
    { header: 'Due', accessor: (r) => r.next_audit_due_on },
    { header: 'Customer', accessor: (r) => r.customer_org },
    { header: 'Charger', accessor: (r) => r.charger_serial },
    { header: 'Status', accessor: (r) => r.audit_status },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Site Patient-Hoist Battery Charger Health Audit</h1>
        <p className="text-sm text-gray-600">Round r3046 — charger battery health across customer sites; flags fails & retests.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Status Mix</h2>
        <DataTable rows={mixRows} columns={mixCols} emptyMessage="No audits" rowKey={(r, i) => String((r as { audit_status?: string }).audit_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Rollup</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String((r as { city?: string }).city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Model Risk (fail rate &gt;= 0%)</h2>
        <DataTable rows={modelRows} columns={modelCols} emptyMessage="No models" rowKey={(r, i) => String((r as { hoist_model?: string }).hoist_model ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Scorecard</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failing &amp; Retest-Due Chargers</h2>
        <DataTable rows={failRows} columns={failCols} emptyMessage="None failing" rowKey={(r, i) => String((r as { charger_serial?: string }).charger_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Remediation Actions</h2>
        <DataTable rows={openRows} columns={openCols} emptyMessage="All closed" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation Spend by Action</h2>
        <DataTable rows={spendRows} columns={spendCols} emptyMessage="No spend" rowKey={(r, i) => String((r as { action_type?: string }).action_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Retests (&lt;= 30d)</h2>
        <DataTable rows={retestRows} columns={retestCols} emptyMessage="No retests due" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
