// Public route — NO requireFounder. The token in the URL is the auth.
// We use a fresh anon-only Supabase client (no caller JWT) so the RPC's
// own anon GRANT lets this work without exposing other founder data.

import { createClient } from "@supabase/supabase-js";

export const metadata = { title: "EquipSeva — Investor brief" };
export const dynamic = "force-dynamic";

type Row = {
  generated_at: string;
  gmv_7d_rupees: number;
  gmv_wow_pct: number;
  completed_jobs_7d: number;
  active_engineers_30d: number;
  amc_contracts_active: number;
  total_escrow_held_rupees: number;
  top_verticals: { type: string; gmv: number }[] | null;
};

const inrShort = (n: number) => {
  if (n >= 1_00_00_000) return `₹${(n / 1_00_00_000).toFixed(1)}Cr`;
  if (n >= 1_00_000) return `₹${(n / 1_00_000).toFixed(1)}L`;
  if (n >= 1_000) return `₹${(n / 1_000).toFixed(1)}k`;
  return `₹${n}`;
};

export default async function PublicInvestorBriefPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;

  // Anon client — no auth cookie. The RPC's own GRANT to anon + token
  // validation is the security boundary.
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { auth: { persistSession: false } },
  );

  const { data, error } = await supabase.rpc("read_investor_brief_via_token", {
    p_raw_token: token,
    p_user_agent: "next/share",
  });

  if (error || !data) {
    const msg =
      error?.message?.toLowerCase() ?? "unknown";
    let title = "Brief unavailable";
    let detail = "This link is no longer valid.";
    if (msg.includes("expired")) {
      title = "This link has expired";
      detail = "Request a fresh link from the founder.";
    } else if (msg.includes("revoked")) {
      title = "This link has been revoked";
      detail = "Contact the founder for an updated link.";
    } else if (msg.includes("view_cap") || msg.includes("exhausted")) {
      title = "View limit reached";
      detail = "This link has hit its view cap. Request a fresh one.";
    } else if (msg.includes("not_found") || msg.includes("invalid")) {
      title = "Invalid link";
      detail = "Double-check the URL, or request a fresh one.";
    }
    return (
      <div className="mx-auto mt-16 max-w-md rounded border border-[var(--color-border)] bg-white p-6">
        <h1 className="text-lg font-semibold">{title}</h1>
        <p className="mt-2 text-sm text-[var(--color-muted)]">{detail}</p>
      </div>
    );
  }

  const row: Row = Array.isArray(data) ? data[0] : data;
  const verticals = row.top_verticals ?? [];
  const generatedDate = new Date(row.generated_at).toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    dateStyle: "long",
    timeStyle: "short",
  });

  return (
    <div className="space-y-10 pb-12">
      <header className="space-y-1">
        <p className="text-xs uppercase tracking-widest text-[var(--color-muted)]">
          EquipSeva · Investor brief
        </p>
        <h1 className="text-3xl font-semibold tracking-tight">
          India&rsquo;s biomedical equipment service network.
        </h1>
        <p className="max-w-3xl text-sm text-[var(--color-muted)]">
          Two-sided marketplace: hospitals post repair + AMC contracts, vetted engineers
          bid, escrowed payments + NABH-grade evidence settle every job. Numbers below
          are live and sanitized — no engineer names, no hospital identifiers, no
          transaction ids.
        </p>
        <p className="text-xs text-[var(--color-muted)]">Generated {generatedDate} IST</p>
      </header>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
          Traction — last 7 days
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              GMV (7d)
            </div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">
              {inrShort(row.gmv_7d_rupees ?? 0)}
            </div>
            <div className="mt-1 text-xs text-[var(--color-muted)]">
              {row.gmv_wow_pct >= 0 ? "+" : ""}
              {row.gmv_wow_pct.toFixed(1)}% WoW
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              Completed jobs
            </div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">
              {row.completed_jobs_7d}
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              Active engineers (30d)
            </div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">
              {row.active_engineers_30d}
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              AMC active
            </div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">
              {row.amc_contracts_active}
            </div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
          Trust capital
        </h2>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
            Escrow held
          </div>
          <div className="mt-1 text-2xl font-semibold tabular-nums">
            {inrShort(row.total_escrow_held_rupees ?? 0)}
          </div>
          <p className="mt-1 text-xs text-[var(--color-muted)]">
            Float held in escrow until job signoff. Working-capital proxy.
          </p>
        </div>
      </section>

      {verticals.length > 0 && (
        <section>
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">
            Top verticals — last 90 days
          </h2>
          <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
            {verticals.map((v) => (
              <div
                key={v.type}
                className="rounded border border-[var(--color-border)] bg-white p-4"
              >
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
                  {v.type}
                </div>
                <div className="mt-1 text-2xl font-semibold tabular-nums">
                  {inrShort(v.gmv ?? 0)}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      <footer className="border-t border-[var(--color-border)] pt-6 text-xs text-[var(--color-muted)]">
        Numbers are live, generated at request time from production. Detailed view + audit
        trail available via founder console (not included in this share).
      </footer>
    </div>
  );
}
