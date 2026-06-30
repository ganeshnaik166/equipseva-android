import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = { hospital_chain: string; audits: number; compliant: number; non_compliant: number; marginal: number; units: number; total_remediation_rupees: number };
type DefibFail = { hospital_chain: string; hospital_unit: string; monitor_model: string; monitor_serial: string; leakage_current_microamp: number; defib_proof_status: string; audit_date: string };
type LeadMix = { leadwire_condition: string; audits: number; pct: number };
type RemPipe = { status: string; priority: string; jobs: number; parts_rupees: number; labour_rupees: number; downtime_hours: number };
type HighLeak = { hospital_chain: string; hospital_unit: string; monitor_model: string; leakage_current_microamp: number; insulation_resistance_megohm: number; iec_60601_2_27_pass: boolean };
type QtrCmp = { audit_quarter: string; audit_year: number; audits: number; avg_leakage: number; avg_insulation: number; fail_rate_pct: number };
type VendorCost = { vendor_name: string; jobs: number; parts_rupees: number; labour_rupees: number; avg_downtime: number; closed: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rollup, defib, mix, pipe, leak, qtr, vendor] = await Promise.all([
    sb.rpc('fn_r3063_chain_rollup'),
    sb.rpc('fn_r3063_defib_failures'),
    sb.rpc('fn_r3063_leadwire_mix'),
    sb.rpc('fn_r3063_remediation_pipeline'),
    sb.rpc('fn_r3063_high_leakage'),
    sb.rpc('fn_r3063_quarter_compare'),
    sb.rpc('fn_r3063_vendor_cost'),
  ]);

  const rollupRows = (rollup.data ?? []) as ChainRollup[];
  const defibRows = (defib.data ?? []) as DefibFail[];
  const mixRows = (mix.data ?? []) as LeadMix[];
  const pipeRows = (pipe.data ?? []) as RemPipe[];
  const leakRows = (leak.data ?? []) as HighLeak[];
  const qtrRows = (qtr.data ?? []) as QtrCmp[];
  const vendorRows = (vendor.data ?? []) as VendorCost[];

  const rollupCols: Column<ChainRollup>[] = [
    { header: 'Chain', cell: (r) => r.hospital_chain },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Compliant', cell: (r) => r.compliant },
    { header: 'Non-comp', cell: (r) => r.non_compliant },
    { header: 'Marginal', cell: (r) => r.marginal },
    { header: 'Units', cell: (r) => r.units },
    { header: 'Remediation ₹', cell: (r) => r.total_remediation_rupees.toLocaleString('en-IN') },
  ];

  const defibCols: Column<DefibFail>[] = [
    { header: 'Chain', cell: (r) => r.hospital_chain },
    { header: 'Unit', cell: (r) => r.hospital_unit },
    { header: 'Model', cell: (r) => r.monitor_model },
    { header: 'Serial', cell: (r) => r.monitor_serial },
    { header: 'Leakage µA', cell: (r) => r.leakage_current_microamp },
    { header: 'Status', cell: (r) => r.defib_proof_status },
    { header: 'Audited', cell: (r) => r.audit_date },
  ];

  const mixCols: Column<LeadMix>[] = [
    { header: 'Condition', cell: (r) => r.leadwire_condition },
    { header: 'Audits', cell: (r) => r.audits },
    { header: '% of fleet', cell: (r) => `${r.pct}%` },
  ];

  const pipeCols: Column<RemPipe>[] = [
    { header: 'Status', cell: (r) => r.status },
    { header: 'Priority', cell: (r) => r.priority },
    { header: 'Jobs', cell: (r) => r.jobs },
    { header: 'Parts ₹', cell: (r) => r.parts_rupees.toLocaleString('en-IN') },
    { header: 'Labour ₹', cell: (r) => r.labour_rupees.toLocaleString('en-IN') },
    { header: 'Downtime h', cell: (r) => r.downtime_hours },
  ];

  const leakCols: Column<HighLeak>[] = [
    { header: 'Chain', cell: (r) => r.hospital_chain },
    { header: 'Unit', cell: (r) => r.hospital_unit },
    { header: 'Model', cell: (r) => r.monitor_model },
    { header: 'Leakage µA', cell: (r) => r.leakage_current_microamp },
    { header: 'Insulation MΩ', cell: (r) => r.insulation_resistance_megohm },
    { header: 'IEC 60601-2-27', cell: (r) => (r.iec_60601_2_27_pass ? 'pass' : 'fail') },
  ];

  const qtrCols: Column<QtrCmp>[] = [
    { header: 'Quarter', cell: (r) => r.audit_quarter },
    { header: 'Year', cell: (r) => r.audit_year },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Avg leakage µA', cell: (r) => r.avg_leakage },
    { header: 'Avg insulation MΩ', cell: (r) => r.avg_insulation },
    { header: 'Fail %', cell: (r) => `${r.fail_rate_pct}%` },
  ];

  const vendorCols: Column<VendorCost>[] = [
    { header: 'Vendor', cell: (r) => r.vendor_name },
    { header: 'Jobs', cell: (r) => r.jobs },
    { header: 'Parts ₹', cell: (r) => r.parts_rupees.toLocaleString('en-IN') },
    { header: 'Labour ₹', cell: (r) => r.labour_rupees.toLocaleString('en-IN') },
    { header: 'Avg downtime h', cell: (r) => r.avg_downtime },
    { header: 'Closed', cell: (r) => r.closed },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">ICU Patient Monitor Lead-Wire Insulation & Defib-Proof Audit</h1>
        <p className="text-sm text-gray-600">Round 3063 · Batch 440 milestone · Quarterly hospital-chain audit dashboard</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Chain rollup</h2>
        <DataTable
          rows={rollupRows}
          columns={rollupCols}
          emptyMessage="No chain rollup yet"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Defib-proof failures (non-compliant / marginal / untested)</h2>
        <DataTable
          rows={defibRows}
          columns={defibCols}
          emptyMessage="No defib-proof failures"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Lead-wire condition mix</h2>
        <DataTable
          rows={mixRows}
          columns={mixCols}
          emptyMessage="No condition data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Remediation pipeline</h2>
        <DataTable
          rows={pipeRows}
          columns={pipeCols}
          emptyMessage="Pipeline empty"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">High leakage outliers (&gt; 20µA)</h2>
        <DataTable
          rows={leakRows}
          columns={leakCols}
          emptyMessage="No outliers"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Quarter comparison</h2>
        <DataTable
          rows={qtrRows}
          columns={qtrCols}
          emptyMessage="No quarter data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Vendor cost burndown</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor work logged"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
