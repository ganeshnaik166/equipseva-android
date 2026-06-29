import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainFailure = { chain_name: string; audits: number; wrappers_inspected: number; wrappers_failed: number; failure_rate_pct: number | null };
type QuarterStatus = { quarter: string; fiscal_year: string; completed: number; escalated: number; in_progress: number; scheduled: number };
type FailureMode = { failure_mode: string; occurrences: number; total_failed: number };
type Escalated = { chain_name: string; hospital_unit: string; quarter: string; failure_mode: string | null; nabh_compliance_pct: number | null; auditor_name: string | null };
type ActionStatus = { status: string; total: number; critical_count: number; high_count: number; total_cost_rupees: number };
type Overdue = { action_code: string; action_description: string; severity: string; owner_role: string | null; due_date: string; status: string };
type LowNabh = { chain_name: string; hospital_unit: string; quarter: string; nabh_compliance_pct: number | null; csr_room_grade: string | null; bowie_dick_result: string | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [r1, r2, r3, r4, r5, r6, r7] = await Promise.all([
    sb.rpc('r3035_chain_failure_summary'),
    sb.rpc('r3035_quarter_status_breakdown'),
    sb.rpc('r3035_failure_mode_distribution'),
    sb.rpc('r3035_escalated_audits'),
    sb.rpc('r3035_corrective_action_status'),
    sb.rpc('r3035_overdue_actions'),
    sb.rpc('r3035_nabh_low_compliance'),
  ]);

  const chainFailures = (r1.data ?? []) as ChainFailure[];
  const quarterStatus = (r2.data ?? []) as QuarterStatus[];
  const failureModes = (r3.data ?? []) as FailureMode[];
  const escalated = (r4.data ?? []) as Escalated[];
  const actionStatus = (r5.data ?? []) as ActionStatus[];
  const overdue = (r6.data ?? []) as Overdue[];
  const lowNabh = (r7.data ?? []) as LowNabh[];

  const chainCols: Column<ChainFailure>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'audits', header: 'Audits' },
    { key: 'wrappers_inspected', header: 'Inspected' },
    { key: 'wrappers_failed', header: 'Failed' },
    { key: 'failure_rate_pct', header: 'Fail %' },
  ];

  const quarterCols: Column<QuarterStatus>[] = [
    { key: 'quarter', header: 'Quarter' },
    { key: 'fiscal_year', header: 'FY' },
    { key: 'completed', header: 'Completed' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'in_progress', header: 'In Progress' },
    { key: 'scheduled', header: 'Scheduled' },
  ];

  const modeCols: Column<FailureMode>[] = [
    { key: 'failure_mode', header: 'Failure Mode' },
    { key: 'occurrences', header: 'Audits' },
    { key: 'total_failed', header: 'Wrappers Failed' },
  ];

  const escCols: Column<Escalated>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'hospital_unit', header: 'Unit' },
    { key: 'quarter', header: 'Qtr' },
    { key: 'failure_mode', header: 'Mode' },
    { key: 'nabh_compliance_pct', header: 'NABH %' },
    { key: 'auditor_name', header: 'Auditor' },
  ];

  const actionCols: Column<ActionStatus>[] = [
    { key: 'status', header: 'Status' },
    { key: 'total', header: 'Total' },
    { key: 'critical_count', header: 'Critical' },
    { key: 'high_count', header: 'High' },
    { key: 'total_cost_rupees', header: 'Cost (Rs)' },
  ];

  const overdueCols: Column<Overdue>[] = [
    { key: 'action_code', header: 'Code' },
    { key: 'action_description', header: 'Action' },
    { key: 'severity', header: 'Severity' },
    { key: 'owner_role', header: 'Owner' },
    { key: 'due_date', header: 'Due' },
    { key: 'status', header: 'Status' },
  ];

  const lowCols: Column<LowNabh>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'hospital_unit', header: 'Unit' },
    { key: 'quarter', header: 'Qtr' },
    { key: 'nabh_compliance_pct', header: 'NABH %' },
    { key: 'csr_room_grade', header: 'CSR Grade' },
    { key: 'bowie_dick_result', header: 'Bowie-Dick' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Surgical-Instrument Sterilization Wrapper Integrity Audit</h1>
        <p className="text-sm text-gray-600">Round 3035 · chains &amp; CSR units &gt;= quarterly cadence</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Failure Summary</h2>
        <DataTable rows={chainFailures} columns={chainCols} emptyMessage="No chain audits." rowKey={(r, i) => String((r as { chain_name?: string }).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Status Breakdown</h2>
        <DataTable rows={quarterStatus} columns={quarterCols} emptyMessage="No quarter data." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failure Mode Distribution</h2>
        <DataTable rows={failureModes} columns={modeCols} emptyMessage="No failure modes." rowKey={(r, i) => String((r as { failure_mode?: string }).failure_mode ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Escalated Audits</h2>
        <DataTable rows={escalated} columns={escCols} emptyMessage="No escalations." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Corrective Action Status</h2>
        <DataTable rows={actionStatus} columns={actionCols} emptyMessage="No actions." rowKey={(r, i) => String((r as { status?: string }).status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Corrective Actions</h2>
        <DataTable rows={overdue} columns={overdueCols} emptyMessage="No overdue actions." rowKey={(r, i) => String((r as { action_code?: string }).action_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">NABH Low-Compliance Sites (&lt; 95%)</h2>
        <DataTable rows={lowNabh} columns={lowCols} emptyMessage="All sites &gt;= 95%." rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
