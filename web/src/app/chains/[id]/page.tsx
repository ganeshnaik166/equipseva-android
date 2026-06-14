import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { InviteForm } from "./InviteForm";

type ChainKpis = {
  member_count: number | null;
  jobs_open: number | null;
  jobs_completed_window: number | null;
  jobs_disputed_window: number | null;
  amc_active: number | null;
  amc_pending_payment: number | null;
  total_escrow_held_rupees: number | null;
  open_dispute_packs: number | null;
};

type PerSite = {
  hospital_user_id: string;
  site_label: string | null;
  jobs_open: number | null;
  jobs_completed_window: number | null;
  jobs_disputed_window: number | null;
  amc_active: number | null;
  escrow_held_rupees: number | null;
};

export const metadata = { title: "Chain detail — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type ChainRow = {
  id: string;
  name: string;
  billing_gstin: string | null;
  primary_admin_user_id: string;
  primary_admin_email: string | null;
  status: string;
  member_count: number | null;
  pending_invite_count: number | null;
  contracted_at: string | null;
  created_at: string;
};

type Membership = {
  id: string;
  hospital_user_id: string;
  member_role: string;
  site_label: string | null;
  joined_at: string;
};

type Invite = {
  id: string;
  invited_email: string;
  site_label: string | null;
  status: string;
  expires_at: string;
  created_at: string;
};

type AuditRow = {
  id: string;
  op_name: string;
  outcome: string | null;
  reason: string | null;
  created_at: string;
};

export default async function ChainDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireFounder();
  const { id } = await params;
  const supabase = await getSupabaseServerClient();

  const [chainsRes, membersRes, invitesRes, auditRes, kpisRes, perSiteRes] = await Promise.all([
    supabase.rpc("founder_list_hospital_chains", { p_status: null, p_limit: 500 }),
    supabase
      .from("hospital_chain_memberships")
      .select("id, hospital_user_id, member_role, site_label, joined_at")
      .eq("chain_id", id)
      .order("joined_at", { ascending: true }),
    supabase
      .from("hospital_chain_invites")
      .select("id, invited_email, site_label, status, expires_at, created_at")
      .eq("chain_id", id)
      .order("created_at", { ascending: false }),
    supabase
      .from("founder_action_log")
      .select("id, op_name, outcome, reason, created_at")
      .eq("target_row_id", id)
      .order("created_at", { ascending: false })
      .limit(20),
    supabase.rpc("chain_kpis", { p_chain_id: id, p_days: 30 }),
    supabase.rpc("chain_per_site_summary", { p_chain_id: id, p_days: 30 }),
  ]);

  if (chainsRes.error)
    throw new Error(`founder_list_hospital_chains: ${chainsRes.error.message}`);

  const chain = ((chainsRes.data ?? []) as ChainRow[]).find((r) => r.id === id);
  const members = (membersRes.error ? [] : (membersRes.data ?? [])) as Membership[];
  const invites = (invitesRes.error ? [] : (invitesRes.data ?? [])) as Invite[];
  const audit = (auditRes.error ? [] : (auditRes.data ?? [])) as AuditRow[];
  const kpis: ChainKpis = kpisRes.error
    ? ({} as ChainKpis)
    : ((Array.isArray(kpisRes.data) ? kpisRes.data[0] : kpisRes.data) ?? ({} as ChainKpis));
  const perSite = (perSiteRes.error ? [] : (perSiteRes.data ?? [])) as PerSite[];

  if (!chain) {
    return (
      <div className="space-y-3">
        <h1 className="text-xl font-semibold">Chain not found</h1>
        <p className="text-sm text-[var(--color-muted)]">
          No row in <code>founder_list_hospital_chains</code> matches <code>{id}</code>.
        </p>
        <Link
          href="/chains"
          className="inline-block rounded border border-[var(--color-border)] px-3 py-1 text-sm hover:bg-gray-50"
        >
          ← back to chains
        </Link>
      </div>
    );
  }

  const pendingInvites = invites.filter(
    (i) => i.status === "pending" && new Date(i.expires_at).getTime() > Date.now(),
  );

  const memberCols: Column<Membership>[] = [
    {
      key: "hosp",
      header: "Hospital",
      render: (m) => (
        <Link
          href={`/hospitals/${m.hospital_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {shortId(m.hospital_user_id)}
        </Link>
      ),
    },
    {
      key: "role",
      header: "Role",
      render: (m) => (
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${
            m.member_role === "admin"
              ? "bg-[var(--color-accent)] text-white"
              : "bg-gray-100"
          }`}
        >
          {m.member_role}
        </span>
      ),
    },
    {
      key: "label",
      header: "Site label",
      render: (m) => <span className="text-xs">{m.site_label ?? "—"}</span>,
    },
    {
      key: "joined",
      header: "Joined",
      render: (m) => formatRelativeTime(m.joined_at),
    },
  ];

  const inviteCols: Column<Invite>[] = [
    { key: "email", header: "Email", render: (i) => i.invited_email },
    {
      key: "label",
      header: "Site label",
      render: (i) => <span className="text-xs">{i.site_label ?? "—"}</span>,
    },
    {
      key: "status",
      header: "Status",
      render: (i) => {
        const expired = new Date(i.expires_at).getTime() < Date.now();
        const cls =
          i.status === "accepted"
            ? "bg-green-100 text-[var(--color-ok)]"
            : i.status === "revoked"
              ? "bg-gray-100"
              : expired
                ? "bg-red-100 text-[var(--color-danger)]"
                : "bg-yellow-100 text-[var(--color-warn)]";
        return (
          <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>
            {expired && i.status === "pending" ? "expired" : i.status}
          </span>
        );
      },
    },
    {
      key: "expires",
      header: "Expires",
      render: (i) => formatRelativeTime(i.expires_at),
    },
    {
      key: "created",
      header: "Sent",
      render: (i) => formatRelativeTime(i.created_at),
    },
  ];

  const auditCols: Column<AuditRow>[] = [
    { key: "when", header: "When", render: (r) => formatRelativeTime(r.created_at) },
    { key: "op", header: "Operation", render: (r) => <code className="text-xs">{r.op_name}</code> },
    { key: "outcome", header: "Outcome", render: (r) => r.outcome ?? "—" },
    { key: "reason", header: "Reason", render: (r) => <span className="text-xs">{r.reason ?? "—"}</span> },
  ];

  return (
    <div className="space-y-6">
      <header>
        <Link
          href="/chains"
          className="text-xs text-[var(--color-muted)] hover:text-[var(--color-fg)]"
        >
          ← chains
        </Link>
        <h1 className="mt-1 text-xl font-semibold">{chain.name}</h1>
        <p className="text-xs text-[var(--color-muted)]">
          chain_id <code>{chain.id}</code> · status{" "}
          <span
            className={`rounded px-1.5 py-0.5 text-xs ${
              chain.status === "active"
                ? "bg-green-100 text-[var(--color-ok)]"
                : "bg-gray-100"
            }`}
          >
            {chain.status}
          </span>
        </p>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Members" value={formatNumber(members.length)} />
          <StatCard
            label="Pending invites"
            value={formatNumber(pendingInvites.length)}
            tone={pendingInvites.length > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Primary admin"
            value={chain.primary_admin_email ?? shortId(chain.primary_admin_user_id)}
            href={`/hospitals/${chain.primary_admin_user_id}`}
          />
          <StatCard
            label="Created"
            value={formatRelativeTime(chain.created_at)}
            subtext={chain.contracted_at ? "contracted" : undefined}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Chain activity — last 30 days
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Open repair jobs" value={formatNumber(kpis.jobs_open)} />
          <StatCard
            label="Completed (30d)"
            value={formatNumber(kpis.jobs_completed_window)}
          />
          <StatCard
            label="Disputes opened (30d)"
            value={formatNumber(kpis.jobs_disputed_window)}
            tone={(kpis.jobs_disputed_window ?? 0) > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Open dispute packs"
            value={formatNumber(kpis.open_dispute_packs)}
            href="/vault"
            tone={(kpis.open_dispute_packs ?? 0) > 0 ? "warn" : "ok"}
          />
          <StatCard label="AMC active" value={formatNumber(kpis.amc_active)} />
          <StatCard
            label="AMC pending payment"
            value={formatNumber(kpis.amc_pending_payment)}
            tone={(kpis.amc_pending_payment ?? 0) > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Escrow held"
            value={formatRupees(kpis.total_escrow_held_rupees)}
          />
          <StatCard
            label="Members"
            value={formatNumber(kpis.member_count)}
          />
        </div>
      </section>

      {perSite.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">Per-site breakdown</h2>
          <div className="overflow-x-auto rounded border border-[var(--color-border)] bg-white">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] bg-gray-50 text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                  <th className="px-3 py-2 font-medium">Site</th>
                  <th className="px-3 py-2 font-medium">Open jobs</th>
                  <th className="px-3 py-2 font-medium">Completed (30d)</th>
                  <th className="px-3 py-2 font-medium">Disputed (30d)</th>
                  <th className="px-3 py-2 font-medium">AMC active</th>
                  <th className="px-3 py-2 font-medium">Escrow held</th>
                </tr>
              </thead>
              <tbody>
                {perSite.map((s) => (
                  <tr key={s.hospital_user_id} className="border-b border-[var(--color-border)] last:border-0">
                    <td className="px-3 py-2">
                      <Link
                        href={`/hospitals/${s.hospital_user_id}`}
                        className="text-[var(--color-accent)] hover:underline"
                      >
                        {s.site_label ?? shortId(s.hospital_user_id)}
                      </Link>
                    </td>
                    <td className="px-3 py-2">{formatNumber(s.jobs_open)}</td>
                    <td className="px-3 py-2">{formatNumber(s.jobs_completed_window)}</td>
                    <td className="px-3 py-2">
                      <span
                        className={
                          (s.jobs_disputed_window ?? 0) > 0
                            ? "font-medium text-[var(--color-warn)]"
                            : "text-[var(--color-muted)]"
                        }
                      >
                        {formatNumber(s.jobs_disputed_window)}
                      </span>
                    </td>
                    <td className="px-3 py-2">{formatNumber(s.amc_active)}</td>
                    <td className="px-3 py-2">{formatRupees(s.escrow_held_rupees)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">Invite a new site</h2>
        <InviteForm chainId={chain.id} />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Members <span className="text-[var(--color-muted)]">({members.length})</span>
        </h2>
        <DataTable
          columns={memberCols}
          rows={members}
          rowKey={(m) => m.id}
          emptyMessage="No members yet — the primary admin is auto-added when the chain is registered."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Invites <span className="text-[var(--color-muted)]">({invites.length})</span>
        </h2>
        <DataTable
          columns={inviteCols}
          rows={invites}
          rowKey={(i) => i.id}
          emptyMessage="No invites yet."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Audit log <span className="text-[var(--color-muted)]">({audit.length})</span>
        </h2>
        <DataTable
          columns={auditCols}
          rows={audit}
          rowKey={(r) => r.id}
          emptyMessage="No founder actions targeting this chain yet."
        />
      </section>
    </div>
  );
}
