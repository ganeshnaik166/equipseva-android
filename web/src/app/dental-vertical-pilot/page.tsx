import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Dental vertical pilot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_clinics_invited: number;
  total_clinics_onboarded: number;
  total_clinics_live: number;
  total_clinics_paused: number;
  total_clinics_churned: number;
  total_amcs_signed: number;
  total_suppliers_signed: number;
  total_suppliers_pending: number;
  total_bond_value_rupees: number;
  days_since_pilot_start: number;
  conversion_pct_invited_to_live: number;
  days_to_first_amc_median: number;
};

type Clinic = {
  id: string;
  clinic_name: string;
  city: string | null;
  cohort: string;
  enrollment_status: string;
  invited_at: string;
  onboarded_at: string | null;
  first_amc_signed_at: string | null;
  primary_equipment_categories: string[] | null;
  notes: string | null;
};

type Supplier = {
  id: string;
  supplier_name: string;
  bonded_status: string;
  supported_categories: string[] | null;
  bond_amount_rupees: number;
  bond_signed_at: string | null;
  bond_expires_at: string | null;
  created_at: string;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toISOString().slice(0, 10);
}

function statusTone(status: string): string {
  switch (status) {
    case "live":
    case "signed":
    case "active":
      return "text-[var(--color-ok)]";
    case "onboarding":
    case "pending":
      return "text-[var(--color-warn)]";
    case "paused":
      return "text-[var(--color-info)]";
    case "churned":
    case "revoked":
      return "text-[var(--color-danger)]";
    default:
      return "text-[var(--color-muted)]";
  }
}

function Card({ label, value, tone, hint }: { label: string; value: string; tone?: string; hint?: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${tone ?? ""}`}>{value}</div>
      {hint ? <div className="mt-1 text-xs text-[var(--color-muted)]">{hint}</div> : null}
    </div>
  );
}

export default async function DentalVerticalPilotPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, clinicsRes, suppliersRes] = await Promise.all([
    supabase.rpc("founder_dental_pilot_summary"),
    supabase.rpc("founder_dental_pilot_clinics", { p_limit: 50 }),
    supabase.rpc("founder_dental_pilot_suppliers", { p_limit: 30 }),
  ]);

  if (summaryRes.error) throw new Error(`founder_dental_pilot_summary: ${summaryRes.error.message}`);
  if (clinicsRes.error) throw new Error(`founder_dental_pilot_clinics: ${clinicsRes.error.message}`);
  if (suppliersRes.error) throw new Error(`founder_dental_pilot_suppliers: ${suppliersRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {
    total_clinics_invited: 0,
    total_clinics_onboarded: 0,
    total_clinics_live: 0,
    total_clinics_paused: 0,
    total_clinics_churned: 0,
    total_amcs_signed: 0,
    total_suppliers_signed: 0,
    total_suppliers_pending: 0,
    total_bond_value_rupees: 0,
    days_since_pilot_start: 0,
    conversion_pct_invited_to_live: 0,
    days_to_first_amc_median: 0,
  }) as Summary;

  const clinics = (clinicsRes.data ?? []) as Clinic[];
  const suppliers = (suppliersRes.data ?? []) as Supplier[];

  const clinicCols: Column<Clinic>[] = [
    { key: "n", header: "Clinic", render: (r) => <span className="text-xs font-medium">{r.clinic_name}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.city ?? "—"}</span> },
    { key: "co", header: "Cohort", render: (r) => <span className="text-xs uppercase tracking-wide text-[var(--color-muted)]">{r.cohort}</span> },
    { key: "st", header: "Status", render: (r) => <span className={`text-xs font-medium uppercase tracking-wide ${statusTone(r.enrollment_status)}`}>{r.enrollment_status}</span> },
    { key: "i", header: "Invited", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{fmtDate(r.invited_at)}</span> },
    { key: "o", header: "Onboarded", render: (r) => <span className="text-xs tabular-nums">{fmtDate(r.onboarded_at)}</span> },
    { key: "a", header: "First AMC", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{fmtDate(r.first_amc_signed_at)}</span> },
    { key: "e", header: "Equipment categories", render: (r) => <span className="text-xs text-[var(--color-muted)]">{(r.primary_equipment_categories ?? []).join(", ") || "—"}</span> },
  ];

  const supplierCols: Column<Supplier>[] = [
    { key: "n", header: "Supplier", render: (r) => <span className="text-xs font-medium">{r.supplier_name}</span> },
    { key: "s", header: "Status", render: (r) => <span className={`text-xs font-medium uppercase tracking-wide ${statusTone(r.bonded_status)}`}>{r.bonded_status}</span> },
    { key: "c", header: "Supported categories", render: (r) => <span className="text-xs text-[var(--color-muted)]">{(r.supported_categories ?? []).join(", ") || "—"}</span> },
    { key: "b", header: "Bond ₹", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.bond_amount_rupees ?? 0))}</span> },
    { key: "ss", header: "Signed", render: (r) => <span className="text-xs tabular-nums">{fmtDate(r.bond_signed_at)}</span> },
    { key: "x", header: "Expires", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{fmtDate(r.bond_expires_at)}</span> },
    { key: "cr", header: "Created", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{fmtDate(r.created_at)}</span> },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dental vertical pilot</h1>
        <span className="text-xs text-[var(--color-muted)]">
          v0.5 Phase 4 P1 · super-specialty wedge · Hyderabad Q3 → Bengaluru Q4 → expansion
        </span>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        <Card label="Clinics invited" value={formatNumber(s.total_clinics_invited)} hint="Top of funnel" />
        <Card label="Onboarding" value={formatNumber(s.total_clinics_onboarded)} tone="text-[var(--color-warn)]" hint="Mid-funnel" />
        <Card label="Live clinics" value={formatNumber(s.total_clinics_live)} tone="text-[var(--color-ok)]" hint="Bottom of funnel" />
        <Card label="Paused" value={formatNumber(s.total_clinics_paused)} tone="text-[var(--color-info)]" hint="Recoverable" />
        <Card label="Churned" value={formatNumber(s.total_clinics_churned)} tone="text-[var(--color-danger)]" hint="Lost" />
        <Card label="AMCs signed" value={formatNumber(s.total_amcs_signed)} tone="text-[var(--color-ok)]" hint="Revenue activated" />
        <Card label="Suppliers signed" value={formatNumber(s.total_suppliers_signed)} tone="text-[var(--color-ok)]" hint="Bonded-parts coverage" />
        <Card label="Suppliers pending" value={formatNumber(s.total_suppliers_pending)} tone="text-[var(--color-warn)]" hint="Awaiting bond" />
        <Card label="Bond value" value={formatRupees(Number(s.total_bond_value_rupees ?? 0))} hint="Total ₹ bonded" />
        <Card label="Days since start" value={formatNumber(s.days_since_pilot_start)} hint="Pilot age" />
        <Card label="Conversion %" value={`${Number(s.conversion_pct_invited_to_live ?? 0).toFixed(1)}%`} tone="text-[var(--color-accent)]" hint="Invited → live" />
        <Card label="Days to first AMC (median)" value={Number(s.days_to_first_amc_median ?? 0).toFixed(1)} hint="Onboarding velocity" />
      </section>

      <section className="space-y-3">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">Pilot clinics ledger (50)</h2>
        <DataTable columns={clinicCols} rows={clinics} rowKey={(r) => r.id} emptyMessage="No clinics enrolled yet." />
      </section>

      <section className="space-y-3">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">Bonded-parts suppliers ledger (30)</h2>
        <DataTable columns={supplierCols} rows={suppliers} rowKey={(r) => r.id} emptyMessage="No suppliers registered yet." />
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <div className="text-sm font-semibold text-[var(--color-fg)]">Notes</div>
        <div>
          <span className="font-medium text-[var(--color-fg)]">Cohort cycle:</span> hyderabad-pilot-2026q3 (Jul-Sep) → bengaluru-pilot-2026q4 (Oct-Dec)
          → expansion (2027+). One geography per quarter; no parallel cohorts until first cohort hits {">"}60% conversion.
        </div>
        <div>
          <span className="font-medium text-[var(--color-fg)]">Bonded-parts SLA:</span> suppliers post ₹ bond against fakes; counterfeit incident triggers
          bond forfeiture + auto-revoke. 48h dispatch SLA for in-stock parts; 7-day for special order. Bond expires must be renewed 30 days before expiry
          or status drops to pending.
        </div>
        <div>
          <span className="font-medium text-[var(--color-fg)]">Dental equipment categories tracked:</span> autoclave, dental_xray, dental_chair,
          ultrasonic_scaler, intraoral_camera, dental_compressor, light_cure_unit, amalgamator, dental_handpiece, suction_unit.
        </div>
      </section>
    </div>
  );
}
