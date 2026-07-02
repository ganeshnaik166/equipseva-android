import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PadRollup = { pad_condition: string; n: number; expired_n: number; overdue_n: number };
type SwapStatus = { site_code: string; device_model: string; pad_condition: string; swap_status: string; next_swap_due: string; expiry_date: string };
type TestRollup = { cycle_result: string; n: number; avg_battery: number | null; avg_joules: number | null };
type FailedDev = { site_code: string; device_serial: string; cycle_result: string; fault_code: string | null; battery_pct: number | null; remediation: string | null };
type Compliance = { audit_month: string; pads_tested: number; pads_overdue: number; tests_total: number; tests_failed: number; tests_missed: number };
type FaultFreq = { fault_code: string; n: number; sites_affected: number };
type Urgent = { site_code: string; issue: string; severity: string; detail: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [r1, r2, r3, r4, r5, r6, r7] = await Promise.all([
    supabase.rpc('founder_r3082_pad_condition_rollup'),
    supabase.rpc('founder_r3082_swap_status_by_site'),
    supabase.rpc('founder_r3082_self_test_rollup'),
    supabase.rpc('founder_r3082_failed_devices'),
    supabase.rpc('founder_r3082_monthly_compliance'),
    supabase.rpc('founder_r3082_fault_code_frequency'),
    supabase.rpc('founder_r3082_urgent_action_queue'),
  ]);

  const padRollup = (r1.data ?? []) as PadRollup[];
  const swapStatus = (r2.data ?? []) as SwapStatus[];
  const testRollup = (r3.data ?? []) as TestRollup[];
  const failedDev = (r4.data ?? []) as FailedDev[];
  const compliance = (r5.data ?? []) as Compliance[];
  const faultFreq = (r6.data ?? []) as FaultFreq[];
  const urgent = (r7.data ?? []) as Urgent[];

  const padCols: Column<PadRollup>[] = [
    { header: 'Condition', accessor: (r) => r.pad_condition },
    { header: 'Count', accessor: (r) => r.n },
    { header: 'Expired', accessor: (r) => r.expired_n },
    { header: 'Overdue', accessor: (r) => r.overdue_n },
  ];

  const swapCols: Column<SwapStatus>[] = [
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Model', accessor: (r) => r.device_model },
    { header: 'Pad', accessor: (r) => r.pad_condition },
    { header: 'Swap', accessor: (r) => r.swap_status },
    { header: 'Next Due', accessor: (r) => r.next_swap_due },
    { header: 'Expiry', accessor: (r) => r.expiry_date },
  ];

  const testCols: Column<TestRollup>[] = [
    { header: 'Result', accessor: (r) => r.cycle_result },
    { header: 'Count', accessor: (r) => r.n },
    { header: 'Avg Battery %', accessor: (r) => r.avg_battery ?? '—' },
    { header: 'Avg Joules', accessor: (r) => r.avg_joules ?? '—' },
  ];

  const failCols: Column<FailedDev>[] = [
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Device', accessor: (r) => r.device_serial },
    { header: 'Result', accessor: (r) => r.cycle_result },
    { header: 'Fault', accessor: (r) => r.fault_code ?? '—' },
    { header: 'Battery %', accessor: (r) => r.battery_pct ?? '—' },
    { header: 'Remediation', accessor: (r) => r.remediation ?? '—' },
  ];

  const compCols: Column<Compliance>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Sites', accessor: (r) => r.pads_tested },
    { header: 'Pads Overdue', accessor: (r) => r.pads_overdue },
    { header: 'Tests', accessor: (r) => r.tests_total },
    { header: 'Failed', accessor: (r) => r.tests_failed },
    { header: 'Missed', accessor: (r) => r.tests_missed },
  ];

  const faultCols: Column<FaultFreq>[] = [
    { header: 'Fault Code', accessor: (r) => r.fault_code },
    { header: 'Count', accessor: (r) => r.n },
    { header: 'Sites Affected', accessor: (r) => r.sites_affected },
  ];

  const urgentCols: Column<Urgent>[] = [
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Issue', accessor: (r) => r.issue },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Detail', accessor: (r) => r.detail },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Defibrillator Trainer-Pads & Self-Test Cycle Audit</h1>
        <p className="text-sm text-gray-600">Monthly engineer audit — pads condition & device self-test cycle compliance</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pad Condition Rollup</h2>
        <DataTable rows={padRollup} columns={padCols} emptyMessage="No pad data" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Swap Status by Site</h2>
        <DataTable rows={swapStatus} columns={swapCols} emptyMessage="No sites" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Self-Test Result Rollup</h2>
        <DataTable rows={testRollup} columns={testCols} emptyMessage="No tests" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failed & Warning Devices</h2>
        <DataTable rows={failedDev} columns={failCols} emptyMessage="No failures" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Compliance</h2>
        <DataTable rows={compliance} columns={compCols} emptyMessage="No months" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fault Code Frequency</h2>
        <DataTable rows={faultFreq} columns={faultCols} emptyMessage="No faults" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Urgent Action Queue</h2>
        <DataTable rows={urgent} columns={urgentCols} emptyMessage="No urgent items" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
