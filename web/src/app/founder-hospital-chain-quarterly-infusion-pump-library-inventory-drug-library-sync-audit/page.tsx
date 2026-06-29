import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { chain_name: string; pump_count: number; current_sync: number; stale: number; out_of_sync: number; offline: number; quarantined: number };
type Stale = { chain_name: string; hospital_site: string; pump_model: string; pump_serial: string; ward: string; drug_library_version: string | null; last_sync_at: string | null };
type AuditSummary = { chain_name: string; audits: number; total_targeted: number; total_synced: number; total_failed: number; sync_rate_pct: number | null };
type Variance = { chain_name: string; hospital_site: string; library_version: string; pumps_targeted: number; pumps_failed: number; remediation_status: string; push_initiated_at: string };
type Firmware = { pump_model: string; firmware_version: string; units: number };
type Coverage = { drug_library_version: string; units: number; chains: number };
type Escalation = { chain_name: string; hospital_site: string; library_version: string; pumps_failed: number; variance_flag: string; push_initiated_at: string; approved_by_pharmacy: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, st, sum, sv, fw, cov, esc] = await Promise.all([
    supabase.rpc('inventory_overview_r3023'),
    supabase.rpc('stale_pumps_r3023'),
    supabase.rpc('sync_audit_summary_r3023'),
    supabase.rpc('severe_variance_sites_r3023'),
    supabase.rpc('firmware_spread_r3023'),
    supabase.rpc('library_version_coverage_r3023'),
    supabase.rpc('escalation_queue_r3023'),
  ]);

  const overview = (ov.data ?? []) as Overview[];
  const stale = (st.data ?? []) as Stale[];
  const summary = (sum.data ?? []) as AuditSummary[];
  const variance = (sv.data ?? []) as Variance[];
  const firmware = (fw.data ?? []) as Firmware[];
  const coverage = (cov.data ?? []) as Coverage[];
  const escalations = (esc.data ?? []) as Escalation[];

  const overviewCols: Column<Overview>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Pumps', cell: (r) => r.pump_count },
    { header: 'Current', cell: (r) => r.current_sync },
    { header: 'Stale', cell: (r) => r.stale },
    { header: 'Out-of-sync', cell: (r) => r.out_of_sync },
    { header: 'Offline', cell: (r) => r.offline },
    { header: 'Quarantined', cell: (r) => r.quarantined },
  ];

  const staleCols: Column<Stale>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Site', cell: (r) => r.hospital_site },
    { header: 'Model', cell: (r) => r.pump_model },
    { header: 'Serial', cell: (r) => r.pump_serial },
    { header: 'Ward', cell: (r) => r.ward },
    { header: 'DL Ver', cell: (r) => r.drug_library_version ?? '—' },
    { header: 'Last sync', cell: (r) => r.last_sync_at ?? '—' },
  ];

  const summaryCols: Column<AuditSummary>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Targeted', cell: (r) => r.total_targeted },
    { header: 'Synced', cell: (r) => r.total_synced },
    { header: 'Failed', cell: (r) => r.total_failed },
    { header: 'Sync %', cell: (r) => (r.sync_rate_pct ?? 0) + '%' },
  ];

  const varianceCols: Column<Variance>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Site', cell: (r) => r.hospital_site },
    { header: 'Lib', cell: (r) => r.library_version },
    { header: 'Targeted', cell: (r) => r.pumps_targeted },
    { header: 'Failed', cell: (r) => r.pumps_failed },
    { header: 'Status', cell: (r) => r.remediation_status },
    { header: 'Initiated', cell: (r) => r.push_initiated_at },
  ];

  const firmwareCols: Column<Firmware>[] = [
    { header: 'Model', cell: (r) => r.pump_model },
    { header: 'Firmware', cell: (r) => r.firmware_version },
    { header: 'Units', cell: (r) => r.units },
  ];

  const coverageCols: Column<Coverage>[] = [
    { header: 'Drug library', cell: (r) => r.drug_library_version },
    { header: 'Units', cell: (r) => r.units },
    { header: 'Chains', cell: (r) => r.chains },
  ];

  const escCols: Column<Escalation>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Site', cell: (r) => r.hospital_site },
    { header: 'Lib', cell: (r) => r.library_version },
    { header: 'Failed', cell: (r) => r.pumps_failed },
    { header: 'Variance', cell: (r) => r.variance_flag },
    { header: 'Initiated', cell: (r) => r.push_initiated_at },
    { header: 'Approved by', cell: (r) => r.approved_by_pharmacy },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Infusion-Pump Library Inventory &amp; Drug-Library Sync Audit</h1>
        <p className="text-sm text-gray-600">Quarter rollup of pump fleet sync state across hospital chains. Severe variance =&gt; escalation queue.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain inventory overview</h2>
        <DataTable rows={overview} columns={overviewCols} emptyMessage="No chains" rowKey={(r, i) => String((r as Overview).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale &amp; out-of-sync pumps</h2>
        <DataTable rows={stale} columns={staleCols} emptyMessage="All pumps current" rowKey={(r, i) => String((r as Stale).pump_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Sync audit rollup (sync % &lt;= 100)</h2>
        <DataTable rows={summary} columns={summaryCols} emptyMessage="No audits" rowKey={(r, i) => String((r as AuditSummary).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severe variance sites (moderate & severe)</h2>
        <DataTable rows={variance} columns={varianceCols} emptyMessage="No variance" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Firmware spread</h2>
        <DataTable rows={firmware} columns={firmwareCols} emptyMessage="No firmware data" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Drug-library coverage</h2>
        <DataTable rows={coverage} columns={coverageCols} emptyMessage="No coverage data" rowKey={(r, i) => String((r as Coverage).drug_library_version ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Escalation queue</h2>
        <DataTable rows={escalations} columns={escCols} emptyMessage="Queue empty" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
