import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type IntelRow = {
  id?: string;
  hospital_org_id: string;
  hospital_name: string | null;
  state: string | null;
  officer_count: number | null;
  approver_count: number | null;
  avg_budget_authority_rupees: number | null;
  active_signal_count: number | null;
  total_signal_value_rupees: number | null;
  last_engaged_at: string | null;
};

type SignalRow = {
  id?: string;
  signal_id: string;
  hospital_org_id: string;
  hospital_name: string | null;
  signal_type: string | null;
  signal_strength: string | null;
  estimated_value_rupees: number | null;
  observed_at: string | null;
  expires_at: string | null;
  source: string | null;
};

type BudgetRow = {
  id?: string;
  budget_month: number | null;
  hospital_count: number | null;
  total_budget_authority_rupees: number | null;
};

const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "₹" + Math.round(n).toLocaleString("en-IN");
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  try { return new Date(s).toLocaleString("en-IN"); } catch { return s; }
}

export default async function FounderHospitalProcurementIntelPage() {
  const sb = await getSupabaseServerClient();

  let intel: IntelRow[] = [];
  let signals: SignalRow[] = [];
  let budgetWindows: BudgetRow[] = [];
  let errorMsg: string | null = null;

  try {
    const { data, error } = await sb.rpc("list_hospital_procurement_intel");
    if (error) throw error;
    intel = (data ?? []) as IntelRow[];
  } catch (e: any) {
    errorMsg = e?.message ?? "Failed to load intel";
  }

  try {
    const { data, error } = await sb.rpc("list_active_procurement_signals");
    if (error) throw error;
    signals = (data ?? []) as SignalRow[];
  } catch {
    signals = [];
  }

  try {
    const { data, error } = await sb.rpc("summarize_budget_timing_windows");
    if (error) throw error;
    budgetWindows = (data ?? []) as BudgetRow[];
  } catch {
    budgetWindows = [];
  }

  const totalSignalValue = signals.reduce((acc, s) => acc + (s.estimated_value_rupees ?? 0), 0);
  const confirmedCount = signals.filter((s) => s.signal_strength === "confirmed").length;
  const strongCount = signals.filter((s) => s.signal_strength === "strong").length;

  const intelColumns: Column<IntelRow>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: IntelRow) => r.hospital_name ?? "—" },
    { key: "state", header: "State", render: (r: IntelRow) => r.state ?? "—" },
    { key: "officer_count", header: "Officers", render: (r: IntelRow) => String(r.officer_count ?? 0) },
    { key: "approver_count", header: "Approvers", render: (r: IntelRow) => String(r.approver_count ?? 0) },
    { key: "avg_budget_authority_rupees", header: "Avg Budget Auth", render: (r: IntelRow) => fmtRupees(r.avg_budget_authority_rupees) },
    { key: "active_signal_count", header: "Live Signals", render: (r: IntelRow) => String(r.active_signal_count ?? 0) },
    { key: "total_signal_value_rupees", header: "Pipeline", render: (r: IntelRow) => fmtRupees(r.total_signal_value_rupees) },
    { key: "last_engaged_at", header: "Last Engaged", render: (r: IntelRow) => fmtDate(r.last_engaged_at) },
  ];

  const signalColumns: Column<SignalRow>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: SignalRow) => r.hospital_name ?? "—" },
    { key: "signal_type", header: "Type", render: (r: SignalRow) => r.signal_type ?? "—" },
    { key: "signal_strength", header: "Strength", render: (r: SignalRow) => r.signal_strength ?? "—" },
    { key: "estimated_value_rupees", header: "Est. Value", render: (r: SignalRow) => fmtRupees(r.estimated_value_rupees) },
    { key: "observed_at", header: "Observed", render: (r: SignalRow) => fmtDate(r.observed_at) },
    { key: "expires_at", header: "Expires", render: (r: SignalRow) => fmtDate(r.expires_at) },
    { key: "source", header: "Source", render: (r: SignalRow) => r.source ?? "—" },
  ];

  const budgetColumns: Column<BudgetRow>[] = [
    { key: "budget_month", header: "Budget Month", render: (r: BudgetRow) => (r.budget_month && r.budget_month >= 1 && r.budget_month <= 12) ? MONTHS[r.budget_month - 1] : "—" },
    { key: "hospital_count", header: "Hospitals", render: (r: BudgetRow) => String(r.hospital_count ?? 0) },
    { key: "total_budget_authority_rupees", header: "Total Authority", render: (r: BudgetRow) => fmtRupees(r.total_budget_authority_rupees) },
  ];

  return (
    <div style={{ padding: "24px", maxWidth: "1400px", margin: "0 auto" }}>
      <div style={{ marginBottom: "24px" }}>
        <h1 style={{ fontSize: "28px", fontWeight: 700, marginBottom: "8px" }}>
          Hospital Procurement Intelligence
        </h1>
        <p style={{ color: "#666", fontSize: "14px" }}>
          Per-hospital decision-maker map, procurement officer preferences, budget timing, and active buying signals.
        </p>
      </div>

      {errorMsg ? (
        <div style={{ padding: "12px", background: "#fee", border: "1px solid #f99", borderRadius: "6px", marginBottom: "16px" }}>
          {errorMsg}
        </div>
      ) : null}

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "12px", marginBottom: "24px" }}>
        <div style={{ padding: "16px", background: "#f8f9fb", borderRadius: "8px", border: "1px solid #e5e7eb" }}>
          <div style={{ fontSize: "12px", color: "#666", textTransform: "uppercase" }}>Hospitals Tracked</div>
          <div style={{ fontSize: "24px", fontWeight: 700, marginTop: "4px" }}>{intel.length}</div>
        </div>
        <div style={{ padding: "16px", background: "#f8f9fb", borderRadius: "8px", border: "1px solid #e5e7eb" }}>
          <div style={{ fontSize: "12px", color: "#666", textTransform: "uppercase" }}>Active Signals</div>
          <div style={{ fontSize: "24px", fontWeight: 700, marginTop: "4px" }}>{signals.length}</div>
          <div style={{ fontSize: "11px", color: "#888", marginTop: "2px" }}>
            {confirmedCount} confirmed · {strongCount} strong
          </div>
        </div>
        <div style={{ padding: "16px", background: "#f8f9fb", borderRadius: "8px", border: "1px solid #e5e7eb" }}>
          <div style={{ fontSize: "12px", color: "#666", textTransform: "uppercase" }}>Pipeline Value</div>
          <div style={{ fontSize: "24px", fontWeight: 700, marginTop: "4px" }}>{fmtRupees(totalSignalValue)}</div>
        </div>
      </div>

      <section style={{ marginBottom: "32px" }}>
        <h2 style={{ fontSize: "18px", fontWeight: 600, marginBottom: "12px" }}>Hospital intel overview</h2>
        <DataTable<IntelRow>
          columns={intelColumns}
          rows={intel}
          rowKey={(r: any, i: number) => String(r.id ?? r.hospital_org_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: "32px" }}>
        <h2 style={{ fontSize: "18px", fontWeight: 600, marginBottom: "12px" }}>Active procurement signals</h2>
        <DataTable<SignalRow>
          columns={signalColumns}
          rows={signals}
          rowKey={(r: any, i: number) => String(r.id ?? r.signal_id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: "18px", fontWeight: 600, marginBottom: "12px" }}>Budget timing windows</h2>
        <DataTable<BudgetRow>
          columns={budgetColumns}
          rows={budgetWindows}
          rowKey={(r: any, i: number) => String(r.id ?? r.budget_month ?? i)}
        />
      </section>
    </div>
  );
}
