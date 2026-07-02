import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_brand: string; audits: number; avg_score: number | null; failed: number; escalated: number; cdsco_reportable: number };
type LockRow = { hospital_name: string; chain_brand: string; asset_label: string; lock_status: string; audit_score: number; drug_inspector_notified: boolean };
type CtrlRow = { hospital_name: string; chain_brand: string; asset_label: string; controlled_substance_count: number; controlled_substance_variance: number; cdsco_reportable: boolean };
type TempRow = { hospital_name: string; asset_label: string; asset_kind: string; temperature_max_celsius: number | null; temperature_breach_minutes: number; audit_score: number };
type ExpiryRow = { hospital_name: string; asset_label: string; expired_skus_count: number; near_expiry_skus_count: number; total_at_risk: number };
type FindingRow = { hospital_name: string; finding_category: string; severity: string; sku_or_asset: string; rupees_at_risk: number; regulatory_clock_hours: number; resolution_status: string };
type QuarterRow = { audit_quarter: string; scheduled: number; in_progress: number; passed: number; flagged: number; failed: number; escalated: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chain, locks, ctrl, temps, expiry, crit, quarter] = await Promise.all([
    supabase.rpc('r3015_chain_rollup'),
    supabase.rpc('r3015_lock_breach_watchlist'),
    supabase.rpc('r3015_controlled_substance_variance'),
    supabase.rpc('r3015_temperature_breach_hotspots'),
    supabase.rpc('r3015_expiry_risk_window'),
    supabase.rpc('r3015_critical_open_findings'),
    supabase.rpc('r3015_quarter_status_summary'),
  ]);

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_brand },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Score', accessor: (r) => r.avg_score ?? '—' },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Escalated', accessor: (r) => r.escalated },
    { header: 'CDSCO', accessor: (r) => r.cdsco_reportable },
  ];
  const lockCols: Column<LockRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Chain', accessor: (r) => r.chain_brand },
    { header: 'Asset', accessor: (r) => r.asset_label },
    { header: 'Lock Status', accessor: (r) => r.lock_status },
    { header: 'Score', accessor: (r) => r.audit_score },
    { header: 'Drug Insp', accessor: (r) => r.drug_inspector_notified ? 'yes' : 'no' },
  ];
  const ctrlCols: Column<CtrlRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Chain', accessor: (r) => r.chain_brand },
    { header: 'Asset', accessor: (r) => r.asset_label },
    { header: 'Count', accessor: (r) => r.controlled_substance_count },
    { header: 'Variance', accessor: (r) => r.controlled_substance_variance },
    { header: 'CDSCO', accessor: (r) => r.cdsco_reportable ? 'yes' : 'no' },
  ];
  const tempCols: Column<TempRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Asset', accessor: (r) => r.asset_label },
    { header: 'Kind', accessor: (r) => r.asset_kind },
    { header: 'Peak °C', accessor: (r) => r.temperature_max_celsius ?? '—' },
    { header: 'Breach min', accessor: (r) => r.temperature_breach_minutes },
    { header: 'Score', accessor: (r) => r.audit_score },
  ];
  const expiryCols: Column<ExpiryRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Asset', accessor: (r) => r.asset_label },
    { header: 'Expired', accessor: (r) => r.expired_skus_count },
    { header: 'Near-expiry', accessor: (r) => r.near_expiry_skus_count },
    { header: 'Total at risk', accessor: (r) => r.total_at_risk },
  ];
  const critCols: Column<FindingRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'SKU/Asset', accessor: (r) => r.sku_or_asset },
    { header: '₹ at risk', accessor: (r) => r.rupees_at_risk.toLocaleString('en-IN') },
    { header: 'Reg clock h', accessor: (r) => r.regulatory_clock_hours },
    { header: 'Status', accessor: (r) => r.resolution_status },
  ];
  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.audit_quarter },
    { header: 'Scheduled', accessor: (r) => r.scheduled },
    { header: 'In progress', accessor: (r) => r.in_progress },
    { header: 'Passed', accessor: (r) => r.passed },
    { header: 'Flagged', accessor: (r) => r.flagged },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Escalated', accessor: (r) => r.escalated },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Quarterly Pharmacy Cold-Storage & Crash-Cabinet Lock + Expiry Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 24, fontSize: 14 }}>
        Founder console — round 3015. Lock-integrity, controlled-substance variance, temperature breach & expiry surfacing across hospital pharmacy assets.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain rollup</h2>
        <DataTable<ChainRow>
          rows={(chain.data ?? []) as ChainRow[]}
          columns={chainCols}
          emptyMessage="No chain rollup."
          rowKey={(r, i) => String(r.chain_brand ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Lock-breach watchlist</h2>
        <DataTable<LockRow>
          rows={(locks.data ?? []) as LockRow[]}
          columns={lockCols}
          emptyMessage="All locks intact."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Controlled-substance variance (narcotic & crash cabinets)</h2>
        <DataTable<CtrlRow>
          rows={(ctrl.data ?? []) as CtrlRow[]}
          columns={ctrlCols}
          emptyMessage="Zero variance across all controlled-substance assets."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Temperature-breach hotspots (cold storage &gt;= breach)</h2>
        <DataTable<TempRow>
          rows={(temps.data ?? []) as TempRow[]}
          columns={tempCols}
          emptyMessage="No temperature breaches recorded."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expiry risk window (expired + &lt;= 30 days)</h2>
        <DataTable<ExpiryRow>
          rows={(expiry.data ?? []) as ExpiryRow[]}
          columns={expiryCols}
          emptyMessage="No expiry risk."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical & high open findings (regulatory clock running)</h2>
        <DataTable<FindingRow>
          rows={(crit.data ?? []) as FindingRow[]}
          columns={critCols}
          emptyMessage="No critical or high open findings."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarter status summary</h2>
        <DataTable<QuarterRow>
          rows={(quarter.data ?? []) as QuarterRow[]}
          columns={quarterCols}
          emptyMessage="No audits this quarter."
          rowKey={(r, i) => String(r.audit_quarter ?? i)}
        />
      </section>
    </main>
  );
}
