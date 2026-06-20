import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

type Kpi = { label: string; value: string };

export const dynamic = "force-dynamic";

async function safeRpc<T = any>(sb: any, name: string, args: any = {}): Promise<T[]> {
  try {
    const { data, error } = await sb.rpc(name, args);
    if (error) return [];
    return (data as T[]) ?? [];
  } catch {
    return [];
  }
}

function fmtNum(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return v.toLocaleString("en-IN");
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return v.toFixed(1) + "%";
}

function fmtDays(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return v.toFixed(1) + "d";
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  try { await sb.rpc("log_founder_inv_v2_viewed", { p_scope: "page" }); } catch {}

  const funnel = await safeRpc<any>(sb, "rpc_founder_inv_v2_funnel_counts");
  const conv   = await safeRpc<any>(sb, "rpc_founder_inv_v2_stage_conversion");
  const cohort = await safeRpc<any>(sb, "rpc_founder_inv_v2_cohort_cycle_time");
  const active = await safeRpc<any>(sb, "rpc_founder_inv_v2_active_investors");
  const events = await safeRpc<any>(sb, "rpc_founder_inv_v2_recent_events", { p_limit: 100 });

  const stageCount = (s: string): number => {
    const row = funnel.find((r: any) => r.stage === s);
    return row ? Number(row.n ?? 0) : 0;
  };
  const stagePct = (s: string): any => {
    const row = funnel.find((r: any) => r.stage === s);
    return row ? row.conversion_pct : null;
  };
  const convPct = (from: string, to: string): any => {
    const row = conv.find((r: any) => r.from_stage === from && r.to_stage === to);
    return row ? row.conv_pct : null;
  };

  const totalActive = active.length;
  const totalWired  = stageCount("wired");
  const totalSigned = stageCount("signed");
  const totalTS     = stageCount("term_sheet");
  const sumCheck = active.reduce((acc: number, r: any) => acc + (Number(r.check_size_inr_lakhs) || 0), 0);
  const avgCycleAll = cohort.length
    ? cohort.reduce((a: number, r: any) => a + (Number(r.avg_days_tl_to_wired) || 0), 0) / cohort.length
    : null;

  const kpis: Kpi[] = [
    { label: "Target list",        value: fmtNum(stageCount("target_list")) },
    { label: "Contacted",          value: fmtNum(stageCount("contacted")) },
    { label: "Met",                value: fmtNum(stageCount("met")) },
    { label: "DD",                 value: fmtNum(stageCount("dd")) },
    { label: "Term sheet",         value: fmtNum(totalTS) },
    { label: "Signed",             value: fmtNum(totalSigned) },
    { label: "Wired",              value: fmtNum(totalWired) },
    { label: "Active investors",   value: fmtNum(totalActive) },
    { label: "% reach contacted",  value: fmtPct(stagePct("contacted")) },
    { label: "% reach met",        value: fmtPct(stagePct("met")) },
    { label: "% reach DD",         value: fmtPct(stagePct("dd")) },
    { label: "% reach term sheet", value: fmtPct(stagePct("term_sheet")) },
    { label: "% reach signed",     value: fmtPct(stagePct("signed")) },
    { label: "% reach wired",      value: fmtPct(stagePct("wired")) },
    { label: "Pipeline value (₹L)",value: fmtNum(sumCheck) },
    { label: "Avg cycle TL→wired", value: fmtDays(avgCycleAll) },
  ];

  const funnelCols: Column<any>[] = [
    { key: "stage",           header: "Stage",          render: (r: any) => r.stage ?? "—" },
    { key: "n",               header: "Count",          render: (r: any) => fmtNum(r.n) },
    { key: "conversion_pct",  header: "% of top",       render: (r: any) => fmtPct(r.conversion_pct) },
  ];

  const convCols: Column<any>[] = [
    { key: "from_stage", header: "From",        render: (r: any) => r.from_stage ?? "—" },
    { key: "to_stage",   header: "To",          render: (r: any) => r.to_stage ?? "—" },
    { key: "n_from",     header: "N from",      render: (r: any) => fmtNum(r.n_from) },
    { key: "n_to",       header: "N to",        render: (r: any) => fmtNum(r.n_to) },
    { key: "conv_pct",   header: "Conversion",  render: (r: any) => fmtPct(r.conv_pct) },
  ];

  const cohortCols: Column<any>[] = [
    { key: "cohort_label",            header: "Cohort",            render: (r: any) => r.cohort_label ?? "—" },
    { key: "n",                       header: "N",                 render: (r: any) => fmtNum(r.n) },
    { key: "avg_days_tl_to_signed",   header: "TL→signed (avg d)", render: (r: any) => fmtDays(r.avg_days_tl_to_signed) },
    { key: "avg_days_signed_to_wired",header: "Signed→wired (avg d)", render: (r: any) => fmtDays(r.avg_days_signed_to_wired) },
    { key: "avg_days_tl_to_wired",    header: "TL→wired (avg d)",  render: (r: any) => fmtDays(r.avg_days_tl_to_wired) },
  ];

  const activeCols: Column<any>[] = [
    { key: "investor_name",         header: "Investor",     render: (r: any) => r.investor_name ?? "—" },
    { key: "firm",                  header: "Firm",         render: (r: any) => r.firm ?? "—" },
    { key: "current_stage",         header: "Stage",        render: (r: any) => r.current_stage ?? "—" },
    { key: "cohort_label",          header: "Cohort",       render: (r: any) => r.cohort_label ?? "—" },
    { key: "check_size_inr_lakhs",  header: "Check (₹L)",   render: (r: any) => fmtNum(r.check_size_inr_lakhs) },
    { key: "days_in_stage",         header: "Days in stage",render: (r: any) => fmtDays(r.days_in_stage) },
  ];

  const eventCols: Column<any>[] = [
    { key: "occurred_at",  header: "When",     render: (r: any) => r.occurred_at ? new Date(r.occurred_at).toLocaleString() : "—" },
    { key: "investor_name",header: "Investor", render: (r: any) => r.investor_name ?? "—" },
    { key: "from_stage",   header: "From",     render: (r: any) => r.from_stage ?? "—" },
    { key: "to_stage",     header: "To",       render: (r: any) => r.to_stage ?? "—" },
    { key: "note",         header: "Note",     render: (r: any) => r.note ?? "—" },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: "0 auto" }}>
      <header style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 12, color: "#888" }}>Capital · r1519</div>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: "4px 0" }}>
          Investor pipeline funnel v2
        </h1>
        <p style={{ color: "#666", margin: 0 }}>
          Extended funnel target_list {">"} contacted {">"} met {">"} DD {">"} term sheet {">"} signed {">"} wired.
          Per-stage conversion {"&"} per-cohort cycle time.
        </p>
      </header>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))",
          gap: 12,
          marginBottom: 24,
        }}
      >
        {kpis.map((k) => (
          <div key={k.label} style={{ border: "1px solid #e5e5e5", borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, color: "#888", textTransform: "uppercase" }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value ?? "—"}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Funnel — reach by stage</h2>
        <DataTable rows={funnel} columns={funnelCols} rowKey={(r: any) => r.stage} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Step-to-step conversion</h2>
        <DataTable rows={conv} columns={convCols} rowKey={(r: any) => r.from_stage + "_" + r.to_stage} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Cycle time by cohort</h2>
        <DataTable rows={cohort} columns={cohortCols} rowKey={(r: any) => r.cohort_label} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Active investors</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent stage events</h2>
        <DataTable rows={events} columns={eventCols} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
