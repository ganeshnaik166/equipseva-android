import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime } from "@/lib/format";
import { VerifyActions } from "./VerifyActions";

export const metadata = { title: "Onboarding — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type PendingEngineer = {
  user_id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  verification_status: string | null;
  experience_years: number | null;
  service_radius_km: number | null;
  city: string | null;
  state: string | null;
  certificates: unknown;
  aadhaar_verified: boolean | null;
  created_at: string;
};

export default async function OnboardingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("admin_pending_engineers");
  if (error) throw new Error(`admin_pending_engineers: ${error.message}`);
  const rows = (data ?? []) as PendingEngineer[];

  const aadhaarVerified = rows.filter((r) => r.aadhaar_verified === true).length;
  const overdue7d = rows.filter(
    (r) => Date.now() - new Date(r.created_at).getTime() > 7 * 86400 * 1000,
  ).length;

  const cols: Column<PendingEngineer>[] = [
    {
      key: "when",
      header: "Submitted",
      render: (r) => {
        const ageMs = Date.now() - new Date(r.created_at).getTime();
        const overdue = ageMs > 24 * 3600 * 1000;
        return (
          <span
            title={r.created_at}
            className={
              overdue ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"
            }
          >
            {formatRelativeTime(r.created_at)}
          </span>
        );
      },
    },
    {
      key: "name",
      header: "Name",
      render: (r) => (
        <Link
          href={`/engineers/${r.user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {r.full_name ?? "(unnamed)"}
        </Link>
      ),
    },
    {
      key: "email",
      header: "Email",
      render: (r) => <span className="text-xs">{r.email ?? "—"}</span>,
    },
    {
      key: "phone",
      header: "Phone",
      render: (r) => <span className="text-xs">{r.phone ?? "—"}</span>,
    },
    {
      key: "where",
      header: "Where",
      render: (r) => (
        <span className="text-xs">
          {[r.city, r.state].filter(Boolean).join(", ") || "—"} ·{" "}
          <span className="text-[var(--color-muted)]">
            {r.service_radius_km != null ? `${r.service_radius_km} km` : "—"}
          </span>
        </span>
      ),
    },
    {
      key: "exp",
      header: "Exp",
      render: (r) => (r.experience_years != null ? `${r.experience_years}y` : "—"),
    },
    {
      key: "aadhaar",
      header: "Aadhaar",
      render: (r) =>
        r.aadhaar_verified ? (
          <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs text-[var(--color-ok)]">
            verified
          </span>
        ) : (
          <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs">pending</span>
        ),
    },
    {
      key: "docs",
      header: "Certificates",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">view</summary>
          <pre className="mt-1 max-w-md overflow-auto text-xs">
            {JSON.stringify(r.certificates ?? [], null, 2)}
          </pre>
        </details>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span className="rounded bg-yellow-100 px-1.5 py-0.5 text-xs text-[var(--color-warn)]">
          {r.verification_status ?? "pending"}
        </span>
      ),
    },
    {
      key: "act",
      header: "Action",
      render: (r) => <VerifyActions userId={r.user_id} />,
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">
          Engineer KYC queue{" "}
          <span className="text-[var(--color-muted)]">({rows.length})</span>
        </h1>
        <span className="text-xs text-[var(--color-muted)]">
          oldest first via admin_pending_engineers
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Total pending" value={formatNumber(rows.length)} />
          <StatCard
            label="Aadhaar verified"
            value={formatNumber(aadhaarVerified)}
            subtext={
              rows.length > 0 ? `${Math.round((aadhaarVerified / rows.length) * 100)}%` : undefined
            }
            tone="ok"
          />
          <StatCard
            label="Overdue (>7d)"
            value={formatNumber(overdue7d)}
            tone={overdue7d > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="SLA target"
            value="4–24h"
            subtext="founder review window"
          />
        </div>
      </section>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.user_id}
        emptyMessage="No pending engineers — onboarding queue is empty."
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Approve writes <code>verification_status=&apos;verified&apos;</code> via
        <code> admin_set_engineer_verification</code>. Reject moves status to{" "}
        <code>&apos;rejected&apos;</code> with per-doc rejection flags + reason. Both paths log
        to <code>founder_action_log</code> for forensic trail.
      </section>
    </div>
  );
}
