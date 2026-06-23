import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer service handover cleanliness checklist — r2408" };
export const dynamic = "force-dynamic";

type HandoverRow = {
  id: string;
  customer_user_id: string;
  engineer_user_id: string | null;
  equipment_model: string;
  serial_no: string | null;
  site_label: string | null;
  shift_label: string;
  handover_started_at: string;
  handover_completed_at: string | null;
  exterior_clean: boolean;
  interior_clean: boolean;
  consumables_restocked: boolean;
  cables_organized: boolean;
  calibration_verified: boolean;
  logs_signed: boolean;
  hazards_cleared: boolean;
  total_checks: number;
  passed_checks: number;
  overall_status: string;
  customer_signoff_at: string | null;
  customer_satisfaction: number | null;
  customer_comment: string | null;
  notes: string | null;
  pass_pct: number | null;
  minutes_elapsed: number;
  is_open: boolean;
};

type ShiftRow = {
  shift_label: string;
  total_handovers: number;
  open_handovers: number;
  passed_handovers: number;
  failed_handovers: number;
  disputed_handovers: number;
  avg_pass_pct: number | null;
  avg_minutes: number | null;
  avg_satisfaction: number | null;
  last_handover_at: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 16).replace("T", " ");
  } catch {
    return "—";
  }
}

function statusBadge(status: string): string {
  if (status === "passed") return "text-emerald-700";
  if (status === "failed") return "text-red-700 font-semibold";
  if (status === "disputed") return "text-red-700 font-semibold";
  if (status === "pending") return "text-amber-700";
  return "";
}

function passPctBadge(pct: number | null): string {
  if (pct === null) return "text-gray-500";
  if (pct >= 100) return "text-emerald-700 font-semibold";
  if (pct >= 85) return "text-emerald-700";
  if (pct >= 60) return "text-amber-700";
  return "text-red-700 font-semibold";
}

function satBadge(score: number | null): string {
  if (score === null) return "text-gray-500";
  if (score >= 4) return "text-emerald-700";
  if (score === 3) return "text-amber-700";
  return "text-red-700";
}

function checkMark(v: boolean): string {
  return v ? "Y" : "-";
}

export default async function FounderHandoverCleanlinessChecklistPage() {
  const sb = await getSupabaseServerClient();
  const [handoverRes, shiftRes] = await Promise.all([
    sb.rpc("list_handovers_r2408"),
    sb.rpc("shift_handover_summary_r2408"),
  ]);

  if (handoverRes.error) throw new Error(`list_handovers_r2408: ${handoverRes.error.message}`);
  if (shiftRes.error) throw new Error(`shift_handover_summary_r2408: ${shiftRes.error.message}`);

  const handovers = (handoverRes.data ?? []) as HandoverRow[];
  const shifts = (shiftRes.data ?? []) as ShiftRow[];

  const totalCount = handovers.length;
  const openCount = handovers.filter((h) => h.is_open).length;
  const passedCount = handovers.filter((h) => h.overall_status === "passed").length;
  const failedCount = handovers.filter((h) => h.overall_status === "failed").length;
  const disputedCount = handovers.filter((h) => h.overall_status === "disputed").length;
  const avgPassPct =
    totalCount === 0
      ? 0
      : Math.round(
          (handovers.reduce((a, h) => a + (h.pass_pct ?? 0), 0) / totalCount) * 10,
        ) / 10;
  const satScores = handovers
    .map((h) => h.customer_satisfaction)
    .filter((s): s is number => typeof s === "number");
  const avgSat =
    satScores.length === 0
      ? 0
      : Math.round((satScores.reduce((a, s) => a + s, 0) / satScores.length) * 10) / 10;

  const handoverColumns: Column<HandoverRow>[] = [
    {
      key: "equipment_model",
      header: "Equipment",
      render: (r: any) => (
        <div>
          <div className="font-medium">{r.equipment_model}</div>
          <div className="text-xs text-gray-500">{r.serial_no ?? "—"}</div>
        </div>
      ),
    },
    {
      key: "site_label",
      header: "Site / Shift",
      render: (r: any) => (
        <div>
          <div>{r.site_label ?? "—"}</div>
          <div className="text-xs text-gray-500">{r.shift_label}</div>
        </div>
      ),
    },
    {
      key: "overall_status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.overall_status)}>{r.overall_status}</span>,
    },
    {
      key: "passed_checks",
      header: "Checks",
      render: (r: any) => (
        <span className={passPctBadge(r.pass_pct)}>
          {String(r.passed_checks)}/{String(r.total_checks)} ({r.pass_pct === null ? "—" : `${r.pass_pct}%`})
        </span>
      ),
    },
    {
      key: "exterior_clean",
      header: "Ext",
      render: (r: any) => checkMark(r.exterior_clean),
    },
    {
      key: "interior_clean",
      header: "Int",
      render: (r: any) => checkMark(r.interior_clean),
    },
    {
      key: "consumables_restocked",
      header: "Cons",
      render: (r: any) => checkMark(r.consumables_restocked),
    },
    {
      key: "cables_organized",
      header: "Cbl",
      render: (r: any) => checkMark(r.cables_organized),
    },
    {
      key: "calibration_verified",
      header: "Cal",
      render: (r: any) => checkMark(r.calibration_verified),
    },
    {
      key: "logs_signed",
      header: "Log",
      render: (r: any) => checkMark(r.logs_signed),
    },
    {
      key: "hazards_cleared",
      header: "Haz",
      render: (r: any) => checkMark(r.hazards_cleared),
    },
    {
      key: "minutes_elapsed",
      header: "Mins",
      render: (r: any) => String(r.minutes_elapsed),
    },
    {
      key: "handover_started_at",
      header: "Started",
      render: (r: any) => fmtDate(r.handover_started_at),
    },
    {
      key: "customer_satisfaction",
      header: "CSAT",
      render: (r: any) => (
        <span className={satBadge(r.customer_satisfaction)}>
          {r.customer_satisfaction === null ? "—" : `${r.customer_satisfaction}/5`}
        </span>
      ),
    },
  ];

  const shiftColumns: Column<ShiftRow>[] = [
    {
      key: "shift_label",
      header: "Shift",
      render: (r: any) => <span className="font-medium">{r.shift_label}</span>,
    },
    { key: "total_handovers", header: "Total", render: (r: any) => String(r.total_handovers) },
    {
      key: "open_handovers",
      header: "Open",
      render: (r: any) => (
        <span className={r.open_handovers > 0 ? "text-amber-700 font-medium" : "text-gray-500"}>
          {String(r.open_handovers)}
        </span>
      ),
    },
    {
      key: "passed_handovers",
      header: "Passed",
      render: (r: any) => <span className="text-emerald-700">{String(r.passed_handovers)}</span>,
    },
    {
      key: "failed_handovers",
      header: "Failed",
      render: (r: any) => (
        <span className={r.failed_handovers > 0 ? "text-red-700 font-medium" : "text-gray-500"}>
          {String(r.failed_handovers)}
        </span>
      ),
    },
    {
      key: "disputed_handovers",
      header: "Disputed",
      render: (r: any) => (
        <span className={r.disputed_handovers > 0 ? "text-red-700 font-medium" : "text-gray-500"}>
          {String(r.disputed_handovers)}
        </span>
      ),
    },
    {
      key: "avg_pass_pct",
      header: "Avg pass %",
      render: (r: any) => (
        <span className={passPctBadge(r.avg_pass_pct)}>
          {r.avg_pass_pct === null ? "—" : `${r.avg_pass_pct}%`}
        </span>
      ),
    },
    {
      key: "avg_minutes",
      header: "Avg mins",
      render: (r: any) => (r.avg_minutes === null ? "—" : String(r.avg_minutes)),
    },
    {
      key: "avg_satisfaction",
      header: "Avg CSAT",
      render: (r: any) => (
        <span className={satBadge(r.avg_satisfaction)}>
          {r.avg_satisfaction === null ? "—" : `${r.avg_satisfaction}/5`}
        </span>
      ),
    },
    {
      key: "last_handover_at",
      header: "Last",
      render: (r: any) => fmtDate(r.last_handover_at),
    },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer service handover cleanliness checklist — r2408</h1>
        <p className="mt-1 text-xs text-gray-500">
          When shift changes, the outgoing engineer walks the customer through a 7-point cleanliness &amp; readiness
          checklist (exterior &amp; interior cleanliness, consumables, cable management, calibration, signed logs,
          hazards cleared). Customer signs off &amp; rates 1..5. Pass &lt; 100% =&gt; surface here so we catch
          handover-failure patterns before they become NPS drag.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total</div>
          <div className="mt-1 text-lg font-semibold">{totalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{openCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Passed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{passedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Failed</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{failedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Disputed</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{disputedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg pass %</div>
          <div className="mt-1 text-lg font-semibold">{avgPassPct}%</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg CSAT</div>
          <div className="mt-1 text-lg font-semibold">{avgSat === 0 ? "—" : `${avgSat}/5`}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All handovers</h2>
        <p className="text-xs text-gray-500">
          Open-first then newest-first. Check columns: Ext = exterior clean, Int = interior clean, Cons = consumables
          restocked, Cbl = cables organized, Cal = calibration verified, Log = logs signed, Haz = hazards cleared.
          Pass &gt;= 100% green, &gt;= 85% green-lite, &gt;= 60% amber, &lt; 60% red. CSAT &gt;= 4 green, = 3 amber,
          &lt;= 2 red.
        </p>
        <DataTable
          rows={handovers}
          columns={handoverColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No service handovers logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Shift roll-up</h2>
        <p className="text-xs text-gray-500">
          By shift bucket — surfaces which shift (morning / afternoon / night) has weakest handover hygiene. High
          failed + disputed =&gt; retrain that shift&apos;s engineers or rotate supervisor coverage.
        </p>
        <DataTable
          rows={shifts}
          columns={shiftColumns}
          rowKey={(r: any, i: number) => String(r.shift_label ?? i)}
          emptyMessage="No shift data yet."
        />
      </section>
    </div>
  );
}
