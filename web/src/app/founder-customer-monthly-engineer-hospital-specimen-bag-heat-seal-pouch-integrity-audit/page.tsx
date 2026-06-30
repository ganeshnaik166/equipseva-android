import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type Summary = {
  total_audits: number;
  total_pouches_inspected: number;
  total_pouches_failed: number;
  failure_rate_pct: number;
  audits_failed: number;
  remediations_required: number;
  open_remediations: number;
  total_remediation_cost: number;
};

type Region = { region: string; audits: number; pouches_inspected: number; pouches_failed: number; failure_rate_pct: number };
type Grade = { integrity_grade: string; audits: number; pouches_failed: number; share_pct: number };
type Mode = { failure_mode: string; occurrences: number; pouches_failed: number };
type Hospital = { hospital_name: string; audits: number; pouches_failed: number; failure_rate_pct: number };
type Engineer = { engineer_name: string; audits: number; pouches_inspected: number; pristine_audits: number; fail_audits: number };
type Remediation = { id: string; hospital_name: string; action_type: string; priority: string; assigned_to: string; due_date: string; status: string; cost_rupees: number };
type Audit = { id: string; audit_date: string; hospital_name: string; engineer_name: string; pouch_lot_code: string; pouches_inspected: number; pouches_failed: number; integrity_grade: string; status: string; region: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, regionRes, gradeRes, modeRes, hospRes, engRes, remRes, recRes] = await Promise.all([
    supabase.rpc('founder_r3068_summary'),
    supabase.rpc('founder_r3068_by_region'),
    supabase.rpc('founder_r3068_by_grade'),
    supabase.rpc('founder_r3068_failure_modes'),
    supabase.rpc('founder_r3068_top_hospitals'),
    supabase.rpc('founder_r3068_engineer_leaderboard'),
    supabase.rpc('founder_r3068_open_remediations'),
    supabase.rpc('founder_r3068_recent_audits'),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] as Summary) ?? null;
  const regions: Region[] = (regionRes.data as Region[]) ?? [];
  const grades: Grade[] = (gradeRes.data as Grade[]) ?? [];
  const modes: Mode[] = (modeRes.data as Mode[]) ?? [];
  const hospitals: Hospital[] = (hospRes.data as Hospital[]) ?? [];
  const engineers: Engineer[] = (engRes.data as Engineer[]) ?? [];
  const remediations: Remediation[] = (remRes.data as Remediation[]) ?? [];
  const recent: Audit[] = (recRes.data as Audit[]) ?? [];

  const regionCols: Column<Region>[] = [
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Inspected', accessor: (r) => r.pouches_inspected },
    { header: 'Failed', accessor: (r) => r.pouches_failed },
    { header: 'Fail %', accessor: (r) => `${r.failure_rate_pct ?? 0}%` },
  ];

  const gradeCols: Column<Grade>[] = [
    { header: 'Grade', accessor: (r) => r.integrity_grade },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Pouches Failed', accessor: (r) => r.pouches_failed },
    { header: 'Share %', accessor: (r) => `${r.share_pct ?? 0}%` },
  ];

  const modeCols: Column<Mode>[] = [
    { header: 'Failure Mode', accessor: (r) => r.failure_mode },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Pouches Failed', accessor: (r) => r.pouches_failed },
  ];

  const hospCols: Column<Hospital>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Failed', accessor: (r) => r.pouches_failed },
    { header: 'Fail %', accessor: (r) => `${r.failure_rate_pct ?? 0}%` },
  ];

  const engCols: Column<Engineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Inspected', accessor: (r) => r.pouches_inspected },
    { header: 'Pristine', accessor: (r) => r.pristine_audits },
    { header: 'Failed', accessor: (r) => r.fail_audits },
  ];

  const remCols: Column<Remediation>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Priority', accessor: (r) => r.priority },
    { header: 'Owner', accessor: (r) => r.assigned_to },
    { header: 'Due', accessor: (r) => r.due_date },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Cost (Rs)', accessor: (r) => r.cost_rupees },
  ];

  const auditCols: Column<Audit>[] = [
    { header: 'Date', accessor: (r) => r.audit_date },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Lot', accessor: (r) => r.pouch_lot_code },
    { header: 'Inspected', accessor: (r) => r.pouches_inspected },
    { header: 'Failed', accessor: (r) => r.pouches_failed },
    { header: 'Grade', accessor: (r) => r.integrity_grade },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Region', accessor: (r) => r.region },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Round r3068 — Specimen-Bag Heat-Seal Pouch Integrity Audit</h1>
        <p className="text-sm text-gray-600">Customer (hospital) monthly engineer-led pouch integrity sweep — failure rate, modes, remediations.</p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Total Audits</div><div className="text-xl font-semibold">{summary.total_audits}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Pouches Inspected</div><div className="text-xl font-semibold">{summary.total_pouches_inspected}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Pouches Failed</div><div className="text-xl font-semibold">{summary.total_pouches_failed}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Failure Rate</div><div className="text-xl font-semibold">{summary.failure_rate_pct}%</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Audits Failed</div><div className="text-xl font-semibold">{summary.audits_failed}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Remediation Required</div><div className="text-xl font-semibold">{summary.remediations_required}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Open Remediations</div><div className="text-xl font-semibold">{summary.open_remediations}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Remediation Spend (Rs)</div><div className="text-xl font-semibold">{summary.total_remediation_cost}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Failure Rate by Region</h2>
        <DataTable rows={regions} columns={regionCols} emptyMessage="No region data" rowKey={(r, i) => String((r as Region).region ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Integrity Grade Distribution</h2>
        <DataTable rows={grades} columns={gradeCols} emptyMessage="No grade data" rowKey={(r, i) => String((r as Grade).integrity_grade ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failure Mode Breakdown</h2>
        <DataTable rows={modes} columns={modeCols} emptyMessage="No failure modes" rowKey={(r, i) => String((r as Mode).failure_mode ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Hospitals by Pouches Failed</h2>
        <DataTable rows={hospitals} columns={hospCols} emptyMessage="No hospital data" rowKey={(r, i) => String((r as Hospital).hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable rows={engineers} columns={engCols} emptyMessage="No engineer data" rowKey={(r, i) => String((r as Engineer).engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Remediation Actions (p0 &gt;= top)</h2>
        <DataTable rows={remediations} columns={remCols} emptyMessage="No open remediations" rowKey={(r, i) => String((r as Remediation).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Audits (latest 25)</h2>
        <DataTable rows={recent} columns={auditCols} emptyMessage="No audits yet" rowKey={(r, i) => String((r as Audit).id ?? i)} />
      </section>
    </div>
  );
}
