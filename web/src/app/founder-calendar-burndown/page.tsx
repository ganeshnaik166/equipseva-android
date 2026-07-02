import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Calendar burndown — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  amc_contracts_renewal_due_30d: number;
  amc_contracts_renewal_due_90d: number;
  amc_contracts_overdue: number;
  vendor_contracts_expiring_30d: number;
  compliance_docs_renewal_due_30d: number;
  board_meetings_scheduled_30d: number;
  board_action_items_due_30d: number;
  board_action_items_overdue: number;
  postmortem_actions_due_30d: number;
  postmortem_actions_overdue: number;
  hiring_target_due_30d: number;
  investor_followups_due_30d: number;
  equipment_warranties_expiring_30d: number;
  decisions_revisit_due_30d: number;
  total_overdue: number;
  total_due_next_30d: number;
  generated_at: string;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const t = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${t}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function FounderCalendarBurndownPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const { data, error } = await sb.rpc("founder_calendar_burndown_summary");
  if (error) throw new Error(`calendar_burndown: ${error.message}`);
  const s = (data?.[0] ?? null) as Summary | null;

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Calendar burndown ★ all due-dated obligations</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Aggregator across every due-date column in the founder console: AMC renewals, vendor contracts, compliance docs, board agenda + action items, postmortem actions, hiring deadlines, investor follow-ups, equipment warranties, decision revisits.
        </p>
      </header>

      {s ? (
        <>
          <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <Card label="Total overdue" value={formatNumber(s.total_overdue)} tone={s.total_overdue > 0 ? "danger" : "ok"} />
            <Card label="Total due next 30d" value={formatNumber(s.total_due_next_30d)} tone={s.total_due_next_30d > 20 ? "warn" : undefined} />
            <Card label="AMC renewals 30d" value={formatNumber(s.amc_contracts_renewal_due_30d)} tone={s.amc_contracts_renewal_due_30d > 0 ? "warn" : "ok"} />
            <Card label="AMC renewals 90d" value={formatNumber(s.amc_contracts_renewal_due_90d)} />
            <Card label="AMC overdue" value={formatNumber(s.amc_contracts_overdue)} tone={s.amc_contracts_overdue > 0 ? "danger" : "ok"} />
            <Card label="Vendor contracts 30d" value={formatNumber(s.vendor_contracts_expiring_30d)} />
            <Card label="Compliance docs 30d" value={formatNumber(s.compliance_docs_renewal_due_30d)} tone={s.compliance_docs_renewal_due_30d > 0 ? "warn" : "ok"} />
            <Card label="Board meetings 30d" value={formatNumber(s.board_meetings_scheduled_30d)} />
            <Card label="Board actions 30d" value={formatNumber(s.board_action_items_due_30d)} />
            <Card label="Board actions overdue" value={formatNumber(s.board_action_items_overdue)} tone={s.board_action_items_overdue > 0 ? "danger" : "ok"} />
            <Card label="Postmortem actions 30d" value={formatNumber(s.postmortem_actions_due_30d)} />
            <Card label="Postmortem overdue" value={formatNumber(s.postmortem_actions_overdue)} tone={s.postmortem_actions_overdue > 0 ? "danger" : "ok"} />
            <Card label="Hiring deadlines 30d" value={formatNumber(s.hiring_target_due_30d)} />
            <Card label="Investor followups 30d" value={formatNumber(s.investor_followups_due_30d)} tone={s.investor_followups_due_30d > 0 ? "warn" : undefined} />
            <Card label="Equipment warranties 30d" value={formatNumber(s.equipment_warranties_expiring_30d)} />
            <Card label="Decisions revisit 30d" value={formatNumber(s.decisions_revisit_due_30d)} />
          </section>

          <p className="text-xs text-[var(--color-muted)]">
            Generated {new Date(s.generated_at).toLocaleString("en-IN")}. Pair with /founder-tier-1-home (r1320) for the priority queue + /founder-action-items-cockpit (r1338) for action-item rollup.
          </p>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
