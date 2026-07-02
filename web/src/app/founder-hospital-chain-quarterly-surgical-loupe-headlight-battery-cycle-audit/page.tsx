import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital chain loupe & headlight battery audit — r3083" };
export const dynamic = "force-dynamic";

type DeviceRow = {
  id: string;
  chain_name: string;
  hospital_site: string;
  device_kind: string;
  brand: string;
  model_code: string;
  battery_chemistry: string;
  battery_capacity_mah: number;
  rated_cycle_count: number;
  purchased_on: string;
  warranty_until: string | null;
  current_status: string;
  notes: string | null;
  created_at: string;
};

type AuditRow = {
  audit_id: string;
  device_id: string;
  chain_name: string;
  hospital_site: string;
  device_kind: string;
  audit_quarter: string;
  audit_date: string;
  cycles_used: number;
  measured_capacity_mah: number;
  health_score: number;
  needs_replacement: boolean;
  recommendation: string;
  cost_estimate_rupees: number | null;
  follow_up_due: string | null;
  closed_at: string | null;
};

type ChainRollupRow = {
  chain_name: string;
  device_count: number;
  healthy_count: number;
  degraded_count: number;
  retire_soon_count: number;
  retired_count: number;
  avg_health_score: number;
  replace_needed_count: number;
};

type ReplaceRow = {
  device_id: string;
  chain_name: string;
  hospital_site: string;
  device_kind: string;
  brand: string;
  model_code: string;
  health_score: number;
  cycles_used: number;
  rated_cycle_count: number;
  recommendation: string;
  cost_estimate_rupees: number | null;
};

type ChemistryRow = {
  battery_chemistry: string;
  device_count: number;
  avg_capacity_mah: number;
  avg_rated_cycles: number;
  avg_health_score: number;
};

type WarrantyRow = {
  device_id: string;
  chain_name: string;
  hospital_site: string;
  device_kind: string;
  brand: string;
  model_code: string;
  warranty_until: string | null;
  days_to_expiry: number;
  current_status: string;
};

type QuarterRow = {
  audit_quarter: string;
  audit_count: number;
  continue_count: number;
  recalibrate_count: number;
  replace_cell_count: number;
  retire_count: number;
  avg_health_score: number;
  total_replacement_cost: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function statusColor(s: string): string {
  if (s === "healthy") return "text-emerald-700";
  if (s === "degraded") return "text-amber-700";
  if (s === "retire_soon") return "text-orange-700";
  if (s === "retired") return "text-gray-500";
  if (s === "swapped_out") return "text-blue-700";
  return "";
}

function recColor(s: string): string {
  if (s === "continue") return "text-emerald-700";
  if (s === "recalibrate") return "text-amber-700";
  if (s === "replace_cell") return "text-orange-700";
  if (s === "retire") return "text-red-700";
  return "";
}

export default async function FounderHospitalChainLoupeHeadlightBatteryAuditPage() {
  const sb = await getSupabaseServerClient();
  const [devicesRes, auditsRes, rollupRes, replaceRes, chemistryRes, warrantyRes, quarterRes] = await Promise.all([
    sb.rpc("list_chain_loupe_devices_r3083"),
    sb.rpc("list_chain_loupe_audits_r3083"),
    sb.rpc("chain_loupe_rollup_r3083"),
    sb.rpc("chain_loupe_replacement_candidates_r3083"),
    sb.rpc("chain_loupe_chemistry_breakdown_r3083"),
    sb.rpc("chain_loupe_warranty_expiring_r3083"),
    sb.rpc("chain_loupe_quarter_summary_r3083"),
  ]);

  if (devicesRes.error) throw new Error(`list_chain_loupe_devices_r3083: ${devicesRes.error.message}`);
  if (auditsRes.error) throw new Error(`list_chain_loupe_audits_r3083: ${auditsRes.error.message}`);
  if (rollupRes.error) throw new Error(`chain_loupe_rollup_r3083: ${rollupRes.error.message}`);
  if (replaceRes.error) throw new Error(`chain_loupe_replacement_candidates_r3083: ${replaceRes.error.message}`);
  if (chemistryRes.error) throw new Error(`chain_loupe_chemistry_breakdown_r3083: ${chemistryRes.error.message}`);
  if (warrantyRes.error) throw new Error(`chain_loupe_warranty_expiring_r3083: ${warrantyRes.error.message}`);
  if (quarterRes.error) throw new Error(`chain_loupe_quarter_summary_r3083: ${quarterRes.error.message}`);

  const devices = (devicesRes.data ?? []) as DeviceRow[];
  const audits = (auditsRes.data ?? []) as AuditRow[];
  const rollup = (rollupRes.data ?? []) as ChainRollupRow[];
  const replaceCandidates = (replaceRes.data ?? []) as ReplaceRow[];
  const chemistry = (chemistryRes.data ?? []) as ChemistryRow[];
  const warranty = (warrantyRes.data ?? []) as WarrantyRow[];
  const quarters = (quarterRes.data ?? []) as QuarterRow[];

  const totalDevices = devices.length;
  const healthyDevices = devices.filter((d) => d.current_status === "healthy").length;
  const degradedDevices = devices.filter((d) => d.current_status === "degraded").length;
  const retireSoonDevices = devices.filter((d) => d.current_status === "retire_soon").length;
  const retiredDevices = devices.filter((d) => d.current_status === "retired").length;
  const replaceNeeded = audits.filter((a) => a.needs_replacement).length;

  const deviceCols: Column<DeviceRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "hospital_site", header: "Site", render: (r: any) => r.hospital_site },
    { key: "device_kind", header: "Kind", render: (r: any) => r.device_kind },
    { key: "brand", header: "Brand", render: (r: any) => r.brand },
    { key: "model_code", header: "Model", render: (r: any) => r.model_code },
    { key: "battery_chemistry", header: "Chemistry", render: (r: any) => r.battery_chemistry },
    { key: "battery_capacity_mah", header: "mAh", render: (r: any) => r.battery_capacity_mah },
    { key: "rated_cycle_count", header: "Rated cycles", render: (r: any) => r.rated_cycle_count },
    { key: "current_status", header: "Status", render: (r: any) => <span className={statusColor(r.current_status)}>{r.current_status}</span> },
    { key: "warranty_until", header: "Warranty until", render: (r: any) => fmtDate(r.warranty_until) },
  ];

  const auditCols: Column<AuditRow>[] = [
    { key: "audit_quarter", header: "Quarter", render: (r: any) => <span className="font-medium">{r.audit_quarter}</span> },
    { key: "audit_date", header: "Date", render: (r: any) => fmtDate(r.audit_date) },
    { key: "chain_name", header: "Chain", render: (r: any) => r.chain_name },
    { key: "hospital_site", header: "Site", render: (r: any) => r.hospital_site },
    { key: "device_kind", header: "Kind", render: (r: any) => r.device_kind },
    { key: "cycles_used", header: "Cycles", render: (r: any) => r.cycles_used },
    { key: "measured_capacity_mah", header: "Measured mAh", render: (r: any) => r.measured_capacity_mah },
    { key: "health_score", header: "Health", render: (r: any) => Number(r.health_score).toFixed(2) },
    { key: "recommendation", header: "Rec", render: (r: any) => <span className={recColor(r.recommendation)}>{r.recommendation}</span> },
    { key: "needs_replacement", header: "Replace?", render: (r: any) => (r.needs_replacement ? "yes" : "no") },
    { key: "cost_estimate_rupees", header: "Cost", render: (r: any) => (r.cost_estimate_rupees ?? 0) },
    { key: "follow_up_due", header: "Follow-up", render: (r: any) => fmtDate(r.follow_up_due) },
  ];

  const rollupCols: Column<ChainRollupRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "device_count", header: "Devices", render: (r: any) => r.device_count },
    { key: "healthy_count", header: "Healthy", render: (r: any) => <span className="text-emerald-700">{r.healthy_count}</span> },
    { key: "degraded_count", header: "Degraded", render: (r: any) => <span className="text-amber-700">{r.degraded_count}</span> },
    { key: "retire_soon_count", header: "Retire soon", render: (r: any) => <span className="text-orange-700">{r.retire_soon_count}</span> },
    { key: "retired_count", header: "Retired", render: (r: any) => <span className="text-gray-500">{r.retired_count}</span> },
    { key: "avg_health_score", header: "Avg health", render: (r: any) => Number(r.avg_health_score).toFixed(2) },
    { key: "replace_needed_count", header: "Replace needed", render: (r: any) => <span className="text-red-700">{r.replace_needed_count}</span> },
  ];

  const replaceCols: Column<ReplaceRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "hospital_site", header: "Site", render: (r: any) => r.hospital_site },
    { key: "device_kind", header: "Kind", render: (r: any) => r.device_kind },
    { key: "brand", header: "Brand", render: (r: any) => r.brand },
    { key: "model_code", header: "Model", render: (r: any) => r.model_code },
    { key: "health_score", header: "Health", render: (r: any) => Number(r.health_score).toFixed(2) },
    { key: "cycles_used", header: "Cycles used", render: (r: any) => r.cycles_used },
    { key: "rated_cycle_count", header: "Rated", render: (r: any) => r.rated_cycle_count },
    { key: "recommendation", header: "Rec", render: (r: any) => <span className={recColor(r.recommendation)}>{r.recommendation}</span> },
    { key: "cost_estimate_rupees", header: "Cost", render: (r: any) => (r.cost_estimate_rupees ?? 0) },
  ];

  const chemistryCols: Column<ChemistryRow>[] = [
    { key: "battery_chemistry", header: "Chemistry", render: (r: any) => <span className="font-medium">{r.battery_chemistry}</span> },
    { key: "device_count", header: "Devices", render: (r: any) => r.device_count },
    { key: "avg_capacity_mah", header: "Avg mAh", render: (r: any) => Number(r.avg_capacity_mah).toFixed(0) },
    { key: "avg_rated_cycles", header: "Avg rated cycles", render: (r: any) => Number(r.avg_rated_cycles).toFixed(0) },
    { key: "avg_health_score", header: "Avg health", render: (r: any) => Number(r.avg_health_score).toFixed(2) },
  ];

  const warrantyCols: Column<WarrantyRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "hospital_site", header: "Site", render: (r: any) => r.hospital_site },
    { key: "device_kind", header: "Kind", render: (r: any) => r.device_kind },
    { key: "brand", header: "Brand", render: (r: any) => r.brand },
    { key: "model_code", header: "Model", render: (r: any) => r.model_code },
    { key: "warranty_until", header: "Until", render: (r: any) => fmtDate(r.warranty_until) },
    { key: "days_to_expiry", header: "Days left", render: (r: any) => <span className={r.days_to_expiry < 30 ? "text-red-700" : "text-amber-700"}>{r.days_to_expiry}</span> },
    { key: "current_status", header: "Status", render: (r: any) => <span className={statusColor(r.current_status)}>{r.current_status}</span> },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { key: "audit_quarter", header: "Quarter", render: (r: any) => <span className="font-medium">{r.audit_quarter}</span> },
    { key: "audit_count", header: "Audits", render: (r: any) => r.audit_count },
    { key: "continue_count", header: "Continue", render: (r: any) => <span className="text-emerald-700">{r.continue_count}</span> },
    { key: "recalibrate_count", header: "Recalibrate", render: (r: any) => <span className="text-amber-700">{r.recalibrate_count}</span> },
    { key: "replace_cell_count", header: "Replace cell", render: (r: any) => <span className="text-orange-700">{r.replace_cell_count}</span> },
    { key: "retire_count", header: "Retire", render: (r: any) => <span className="text-red-700">{r.retire_count}</span> },
    { key: "avg_health_score", header: "Avg health", render: (r: any) => Number(r.avg_health_score).toFixed(2) },
    { key: "total_replacement_cost", header: "Total cost", render: (r: any) => r.total_replacement_cost },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Hospital chain quarterly surgical loupe & headlight battery cycle audit</h1>
        <p className="text-sm text-gray-600">Round r3083 — track loupe + headlight battery lifecycle across hospital chains; flag replacements before they die mid-surgery.</p>
      </header>

      <section className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Total devices</div><div className="text-xl font-bold">{totalDevices}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Healthy</div><div className="text-xl font-bold text-emerald-700">{healthyDevices}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Degraded</div><div className="text-xl font-bold text-amber-700">{degradedDevices}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Retire soon</div><div className="text-xl font-bold text-orange-700">{retireSoonDevices}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Retired</div><div className="text-xl font-bold text-gray-500">{retiredDevices}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Replace needed</div><div className="text-xl font-bold text-red-700">{replaceNeeded}</div></div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain rollup</h2>
        <DataTable rows={rollup} columns={rollupCols} emptyMessage="No chain rollup yet" rowKey={(r: any, i: number) => String(r.chain_name ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Quarter summary</h2>
        <DataTable rows={quarters} columns={quarterCols} emptyMessage="No quarter data" rowKey={(r: any, i: number) => String(r.audit_quarter ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Battery chemistry breakdown</h2>
        <DataTable rows={chemistry} columns={chemistryCols} emptyMessage="No chemistry data" rowKey={(r: any, i: number) => String(r.battery_chemistry ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Replacement candidates (health &lt; threshold)</h2>
        <DataTable rows={replaceCandidates} columns={replaceCols} emptyMessage="No replacement candidates" rowKey={(r: any, i: number) => String(r.device_id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Warranty expiring &lt;= 180 days</h2>
        <DataTable rows={warranty} columns={warrantyCols} emptyMessage="No warranties expiring soon" rowKey={(r: any, i: number) => String(r.device_id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Devices</h2>
        <DataTable rows={devices} columns={deviceCols} emptyMessage="No devices" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Audits</h2>
        <DataTable rows={audits} columns={auditCols} emptyMessage="No audits" rowKey={(r: any, i: number) => String(r.audit_id ?? i)} />
      </section>
    </div>
  );
}
