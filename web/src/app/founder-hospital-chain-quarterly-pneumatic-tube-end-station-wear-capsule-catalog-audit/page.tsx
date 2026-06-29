import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ChainWear = { chain_code: string; station_count: number; critical_count: number; degraded_count: number; avg_gasket: number | null; avg_diverter: number | null; total_jams: number };
type CritStation = { chain_code: string; hospital_site: string; station_code: string; station_zone: string; gasket_wear_pct: number | null; diverter_wear_pct: number | null; jam_count_q: number | null; next_audit_due: string | null };
type ZoneWear = { station_zone: string; station_count: number; avg_gasket: number | null; max_gasket: number | null; total_arrivals: number; total_jams: number };
type Reorder = { chain_code: string; capsule_sku: string; capsule_size: string; use_class: string; on_hand: number | null; reorder_threshold: number | null; status: string; unit_cost_rupees: number | null };
type LossByClass = { use_class: string; sku_count: number; total_lost: number; total_damaged: number; total_on_hand: number; est_loss_value_rupees: number | null };
type AuditDue = { chain_code: string; hospital_site: string; station_code: string; next_audit_due: string | null; status: string };
type Vendor = { vendor_org: string; sku_count: number; total_on_hand: number; total_lost: number; recalled_count: number; exposure_rupees: number | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [chain, crit, zone, reorder, loss, audits, vendor] = await Promise.all([
    sb.rpc('ptube_r3027_chain_wear_summary'),
    sb.rpc('ptube_r3027_critical_stations'),
    sb.rpc('ptube_r3027_zone_wear'),
    sb.rpc('ptube_r3027_capsule_reorder_list'),
    sb.rpc('ptube_r3027_capsule_loss_by_class'),
    sb.rpc('ptube_r3027_audits_due_soon'),
    sb.rpc('ptube_r3027_vendor_exposure'),
  ]);

  const chainRows: ChainWear[] = (chain.data ?? []) as ChainWear[];
  const critRows: CritStation[] = (crit.data ?? []) as CritStation[];
  const zoneRows: ZoneWear[] = (zone.data ?? []) as ZoneWear[];
  const reorderRows: Reorder[] = (reorder.data ?? []) as Reorder[];
  const lossRows: LossByClass[] = (loss.data ?? []) as LossByClass[];
  const auditRows: AuditDue[] = (audits.data ?? []) as AuditDue[];
  const vendorRows: Vendor[] = (vendor.data ?? []) as Vendor[];

  const chainCols: Column<ChainWear>[] = [
    { key: 'chain_code', header: 'Chain', render: (r) => r.chain_code },
    { key: 'station_count', header: 'Stations', render: (r) => r.station_count },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'degraded_count', header: 'Degraded', render: (r) => r.degraded_count },
    { key: 'avg_gasket', header: 'Avg gasket %', render: (r) => r.avg_gasket ?? '—' },
    { key: 'avg_diverter', header: 'Avg diverter %', render: (r) => r.avg_diverter ?? '—' },
    { key: 'total_jams', header: 'Jams (Q)', render: (r) => r.total_jams },
  ];

  const critCols: Column<CritStation>[] = [
    { key: 'chain_code', header: 'Chain', render: (r) => r.chain_code },
    { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
    { key: 'station_code', header: 'Station', render: (r) => r.station_code },
    { key: 'station_zone', header: 'Zone', render: (r) => r.station_zone },
    { key: 'gasket_wear_pct', header: 'Gasket %', render: (r) => r.gasket_wear_pct ?? '—' },
    { key: 'diverter_wear_pct', header: 'Diverter %', render: (r) => r.diverter_wear_pct ?? '—' },
    { key: 'jam_count_q', header: 'Jams', render: (r) => r.jam_count_q ?? 0 },
    { key: 'next_audit_due', header: 'Next audit', render: (r) => r.next_audit_due ?? '—' },
  ];

  const zoneCols: Column<ZoneWear>[] = [
    { key: 'station_zone', header: 'Zone', render: (r) => r.station_zone },
    { key: 'station_count', header: 'Stations', render: (r) => r.station_count },
    { key: 'avg_gasket', header: 'Avg gasket %', render: (r) => r.avg_gasket ?? '—' },
    { key: 'max_gasket', header: 'Max gasket %', render: (r) => r.max_gasket ?? '—' },
    { key: 'total_arrivals', header: 'Arrivals (Q)', render: (r) => r.total_arrivals },
    { key: 'total_jams', header: 'Jams (Q)', render: (r) => r.total_jams },
  ];

  const reorderCols: Column<Reorder>[] = [
    { key: 'chain_code', header: 'Chain', render: (r) => r.chain_code },
    { key: 'capsule_sku', header: 'SKU', render: (r) => r.capsule_sku },
    { key: 'capsule_size', header: 'Size', render: (r) => r.capsule_size },
    { key: 'use_class', header: 'Use', render: (r) => r.use_class },
    { key: 'on_hand', header: 'On hand', render: (r) => r.on_hand ?? 0 },
    { key: 'reorder_threshold', header: 'Reorder at', render: (r) => r.reorder_threshold ?? 0 },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'unit_cost_rupees', header: 'Unit Rs', render: (r) => r.unit_cost_rupees ?? 0 },
  ];

  const lossCols: Column<LossByClass>[] = [
    { key: 'use_class', header: 'Use class', render: (r) => r.use_class },
    { key: 'sku_count', header: 'SKUs', render: (r) => r.sku_count },
    { key: 'total_lost', header: 'Lost (Q)', render: (r) => r.total_lost },
    { key: 'total_damaged', header: 'Damaged (Q)', render: (r) => r.total_damaged },
    { key: 'total_on_hand', header: 'On hand', render: (r) => r.total_on_hand },
    { key: 'est_loss_value_rupees', header: 'Loss Rs', render: (r) => r.est_loss_value_rupees ?? 0 },
  ];

  const auditCols: Column<AuditDue>[] = [
    { key: 'chain_code', header: 'Chain', render: (r) => r.chain_code },
    { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
    { key: 'station_code', header: 'Station', render: (r) => r.station_code },
    { key: 'next_audit_due', header: 'Audit due', render: (r) => r.next_audit_due ?? '—' },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const vendorCols: Column<Vendor>[] = [
    { key: 'vendor_org', header: 'Vendor', render: (r) => r.vendor_org },
    { key: 'sku_count', header: 'SKUs', render: (r) => r.sku_count },
    { key: 'total_on_hand', header: 'On hand', render: (r) => r.total_on_hand },
    { key: 'total_lost', header: 'Lost (Q)', render: (r) => r.total_lost },
    { key: 'recalled_count', header: 'Recalled', render: (r) => r.recalled_count },
    { key: 'exposure_rupees', header: 'Exposure Rs', render: (r) => r.exposure_rupees ?? 0 },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Pneumatic-Tube End-Station Wear & Capsule Catalog Audit</h1>
        <p className="text-sm text-gray-600">Round r3027 — quarterly wear & capsule inventory across hospital chains.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain wear summary</h2>
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chains." rowKey={(r, i) => String((r as ChainWear).chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & degraded stations</h2>
        <DataTable rows={critRows} columns={critCols} emptyMessage="No critical stations." rowKey={(r, i) => String((r as CritStation).station_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Wear by zone</h2>
        <DataTable rows={zoneRows} columns={zoneCols} emptyMessage="No zones." rowKey={(r, i) => String((r as ZoneWear).station_zone ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Capsule reorder list</h2>
        <DataTable rows={reorderRows} columns={reorderCols} emptyMessage="All stocked." rowKey={(r, i) => String((r as Reorder).capsule_sku ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Capsule loss & damage by use class</h2>
        <DataTable rows={lossRows} columns={lossCols} emptyMessage="No loss data." rowKey={(r, i) => String((r as LossByClass).use_class ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audits due (next 90 days)</h2>
        <DataTable rows={auditRows} columns={auditCols} emptyMessage="No audits due." rowKey={(r, i) => String((r as AuditDue).station_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor exposure</h2>
        <DataTable rows={vendorRows} columns={vendorCols} emptyMessage="No vendors." rowKey={(r, i) => String((r as Vendor).vendor_org ?? i)} />
      </section>
    </div>
  );
}
