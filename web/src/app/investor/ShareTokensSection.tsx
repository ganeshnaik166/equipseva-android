"use client";

import { useState, useTransition } from "react";
import {
  mintInvestorShareToken,
  revokeInvestorShareToken,
} from "@/app/actions/investor";

type TokenRow = {
  id: string;
  label: string;
  status: string;
  expires_at: string;
  max_views: number;
  view_count: number;
  revoked_at: string | null;
  revoke_reason: string | null;
  created_at: string;
};

export function ShareTokensSection({ tokens }: { tokens: TokenRow[] }) {
  const [pending, startTransition] = useTransition();
  const [label, setLabel] = useState("");
  const [days, setDays] = useState(7);
  const [views, setViews] = useState(50);
  const [minted, setMinted] = useState<{ url: string; raw: string; expiresAt: string } | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function onMint(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setMinted(null);
    startTransition(async () => {
      const res = await mintInvestorShareToken({
        label,
        expiresInDays: days,
        maxViews: views,
      });
      if (res.ok) {
        setMinted({ url: res.shareUrl, raw: res.rawToken, expiresAt: res.expiresAt });
        setLabel("");
      } else {
        setErr(res.error);
      }
    });
  }

  function onRevoke(tokenId: string) {
    startTransition(async () => {
      const reason = window.prompt("Revoke reason (min 5 chars)") ?? "";
      if (reason.trim().length < 5) return;
      const res = await revokeInvestorShareToken(tokenId, reason.trim());
      if (!res.ok) setErr(res.error);
    });
  }

  return (
    <section className="space-y-4 rounded border border-[var(--color-border)] bg-white p-4 print:hidden">
      <h2 className="text-sm font-semibold">Investor share links (token-gated public)</h2>
      <p className="text-xs text-[var(--color-muted)]">
        Mint a sanitized public link to share with VCs. Recipient sees only GMV / jobs /
        engineers / AMC / top verticals — no PII, no transaction ids.
      </p>

      <form onSubmit={onMint} className="flex flex-wrap items-end gap-3">
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Label</span>
          <input
            type="text"
            required
            minLength={3}
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            className="mt-1 w-72 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="e.g. Tata AIG meeting"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Expiry (days)</span>
          <input
            type="number"
            min={1}
            max={90}
            value={days}
            onChange={(e) => setDays(Number.parseInt(e.target.value || "7", 10))}
            className="mt-1 w-24 rounded border border-[var(--color-border)] px-2 py-1 text-sm tabular-nums"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Max views</span>
          <input
            type="number"
            min={1}
            max={1000}
            value={views}
            onChange={(e) => setViews(Number.parseInt(e.target.value || "50", 10))}
            className="mt-1 w-24 rounded border border-[var(--color-border)] px-2 py-1 text-sm tabular-nums"
          />
        </label>
        <button
          type="submit"
          disabled={pending}
          className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm font-medium text-white disabled:opacity-50"
        >
          {pending ? "Minting…" : "Mint share link"}
        </button>
        {err && <span className="text-sm text-[var(--color-danger)]">{err}</span>}
      </form>

      {minted && (
        <div className="rounded border border-[var(--color-ok)] bg-green-50 p-3 text-sm">
          <div className="font-medium">Share link minted</div>
          <div className="mt-1 break-all font-mono text-xs">{minted.url || minted.raw}</div>
          <div className="mt-1 text-xs text-[var(--color-muted)]">
            Expires {new Date(minted.expiresAt).toLocaleString()}. The raw token is shown
            ONCE — copy now. Server stores only the SHA-256 hash.
          </div>
        </div>
      )}

      {tokens.length > 0 && (
        <div className="overflow-x-auto rounded border border-[var(--color-border)] bg-white">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] bg-gray-50 text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="px-3 py-2 font-medium">Label</th>
                <th className="px-3 py-2 font-medium">Status</th>
                <th className="px-3 py-2 font-medium">Views</th>
                <th className="px-3 py-2 font-medium">Expires</th>
                <th className="px-3 py-2 font-medium">Created</th>
                <th className="px-3 py-2 font-medium">Action</th>
              </tr>
            </thead>
            <tbody>
              {tokens.map((t) => (
                <tr key={t.id} className="border-b border-[var(--color-border)] last:border-0">
                  <td className="px-3 py-2">{t.label}</td>
                  <td className="px-3 py-2">
                    <span
                      className={`rounded px-1.5 py-0.5 text-xs ${
                        t.status === "active"
                          ? "bg-green-100 text-[var(--color-ok)]"
                          : t.status === "revoked"
                            ? "bg-red-100 text-[var(--color-danger)]"
                            : "bg-gray-100"
                      }`}
                    >
                      {t.status}
                    </span>
                  </td>
                  <td className="px-3 py-2 tabular-nums">
                    {t.view_count} / {t.max_views}
                  </td>
                  <td className="px-3 py-2 text-xs">
                    {new Date(t.expires_at).toLocaleString()}
                  </td>
                  <td className="px-3 py-2 text-xs">
                    {new Date(t.created_at).toLocaleString()}
                  </td>
                  <td className="px-3 py-2">
                    {t.status === "active" ? (
                      <button
                        type="button"
                        onClick={() => onRevoke(t.id)}
                        disabled={pending}
                        className="rounded border border-[var(--color-danger)] px-1.5 py-0.5 text-xs text-[var(--color-danger)] hover:bg-red-50 disabled:opacity-50"
                      >
                        Revoke
                      </button>
                    ) : (
                      <span className="text-xs text-[var(--color-muted)]">
                        {t.revoke_reason ?? "—"}
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
