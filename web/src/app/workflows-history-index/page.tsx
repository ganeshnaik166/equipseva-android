import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Workflows history index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type W = {
  task_id: string;
  kind: "Design" | "Audit";
  scope: string;
  agents: number;
  tokens_k: number;
  duration_s: number;
  outcome: string;
  rounds: string;
};

const WORKFLOWS: W[] = [
  { task_id: "w3gkpbc6w", kind: "Audit",  scope: "16 founder RPCs (r992-r1154)",         agents: 7, tokens_k: 0,   duration_s: 0,   outcome: "23 confirmed bugs · fed r1163 sweep",                rounds: "r1163" },
  { task_id: "wyhr52otu", kind: "Design", scope: "6 untapped domains",                     agents: 7, tokens_k: 345, duration_s: 175, outcome: "6 designs · referrals/chains/supervised/notifications/signups-funnel/spot-audits", rounds: "r1180-r1185" },
  { task_id: "wf2f5z89h", kind: "Audit",  scope: "6 batch-1 RPCs",                         agents: 6, tokens_k: 252, duration_s: 97,  outcome: "0 bugs · all clean",                                  rounds: "—" },
  { task_id: "wk1njvfff", kind: "Design", scope: "6 more untapped",                        agents: 7, tokens_k: 444, duration_s: 321, outcome: "6 designs (skipped trust-pulse dupe)",                rounds: "r1197-r1201" },
  { task_id: "wxq6jth6i", kind: "Design", scope: "6 finance + regulatory + marketplace",   agents: 7, tokens_k: 404, duration_s: 323, outcome: "6 designs (workflow agents wrote files; cleanup needed)", rounds: "r1202-r1207" },
  { task_id: "ws4nf361d", kind: "Audit",  scope: "22 RPCs r1197-r1218",                    agents: 24, tokens_k: 1060, duration_s: 347, outcome: "3 bugs · CRITICAL amc_pool_ledger doesn't exist · fed r1230 sweep", rounds: "r1230" },
  { task_id: "wwqe1qwrs", kind: "Design", scope: "6 untapped batch 4",                     agents: 7, tokens_k: 356, duration_s: 215, outcome: "6 designs · chat-moderation/onboarding-velocity/dsr-sla/consent/founder-followups/throughput-hourly", rounds: "r1213-r1218" },
  { task_id: "wos16xp6o", kind: "Design", scope: "6 real-time + capacity domains",         agents: 7, tokens_k: 386, duration_s: 499, outcome: "6 designs · engineer-availability/razorpay/email/checkpoints/regional-city/repair-types", rounds: "r1220-r1225" },
  { task_id: "wwc5rgoqp", kind: "Audit",  scope: "6 batch-5 RPCs",                         agents: 10, tokens_k: 449, duration_s: 251, outcome: "4 bugs · CRITICAL profiles.city + HIGHs repair_jobs.kind enum · fed r1237 sweep", rounds: "r1237" },
  { task_id: "wcrg2jxpp", kind: "Design", scope: "6 fraud/integrity/cart-abandonment",     agents: 7, tokens_k: 325, duration_s: 263, outcome: "6 designs · collusion/dupe/promo/device-integrity/equipment-pm/cart", rounds: "r1231-r1236" },
  { task_id: "w9f46jxo3", kind: "Audit",  scope: "6 batch-6 RPCs",                         agents: 7, tokens_k: 276, duration_s: 122, outcome: "0 real bugs · 1 forward-compat note (keep)",          rounds: "—" },
  { task_id: "w899xh587", kind: "Design", scope: "6 comms/compliance/counterfeit-defense", agents: 7, tokens_k: 303, duration_s: 162, outcome: "6 designs · phone-otp/bonded-parts/virtual-call/pre-visit/tds/dpdp-grievance", rounds: "r1238-r1243" },
  { task_id: "w3d2w4swi", kind: "Audit",  scope: "6 batch-7 RPCs",                         agents: 6, tokens_k: 253, duration_s: 110, outcome: "0 bugs · all clean",                                  rounds: "—" },
  { task_id: "wlx035lgv", kind: "Design", scope: "6 attendance/renewal/cash/buyer-kyc/catalog/refund-queue", agents: 7, tokens_k: 330, duration_s: 174, outcome: "6 designs (shipping)",                                rounds: "r1256-r1261" },
];

const totalDesign = WORKFLOWS.filter(w => w.kind === "Design").length;
const totalAudit = WORKFLOWS.filter(w => w.kind === "Audit").length;
const totalTokens = WORKFLOWS.reduce((s, w) => s + w.tokens_k, 0);

export default async function WorkflowsHistoryIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Workflows history index ★ r1255</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">Ultracode workflow ledger · {WORKFLOWS.length} ridden ({totalDesign} design + {totalAudit} audit) · ~{(totalTokens/1000).toFixed(1)}M agent-tokens spent</p>
      </header>

      <section>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                <th className="py-2 pr-3">Task ID</th>
                <th className="py-2 pr-3">Kind</th>
                <th className="py-2 pr-3">Scope</th>
                <th className="py-2 pr-3 tabular-nums">Agents</th>
                <th className="py-2 pr-3 tabular-nums">Tokens (k)</th>
                <th className="py-2 pr-3 tabular-nums">Wall (s)</th>
                <th className="py-2 pr-3">Outcome</th>
                <th className="py-2">Rounds</th>
              </tr>
            </thead>
            <tbody>
              {WORKFLOWS.map((w) => (
                <tr key={w.task_id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 font-mono text-xs">{w.task_id}</td>
                  <td className="py-2 pr-3">
                    <span className={`inline-block text-[10px] font-medium uppercase tracking-wider ${w.kind === "Audit" ? "text-[var(--color-danger)]" : "text-[var(--color-info)]"}`}>{w.kind}</span>
                  </td>
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{w.scope}</td>
                  <td className="py-2 pr-3 tabular-nums text-xs">{w.agents}</td>
                  <td className="py-2 pr-3 tabular-nums text-xs">{w.tokens_k}</td>
                  <td className="py-2 pr-3 tabular-nums text-xs">{w.duration_s}</td>
                  <td className="py-2 pr-3 text-xs">{w.outcome}</td>
                  <td className="py-2 text-xs font-mono">{w.rounds}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Pattern: {totalDesign} design workflows surfaced ~{totalDesign * 6} new founder surfaces. {totalAudit} audit workflows caught 26+ confirmed prod bugs that would have 500-errored at first execution. Audit-to-design ratio currently 1:{(totalDesign/totalAudit).toFixed(1)} — every design batch ships paired with an audit batch as standard ops.
      </p>
    </div>
  );
}
