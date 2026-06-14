"use client";

import { useState, useTransition } from "react";
import { revokeChainInvite } from "@/app/actions/chains";

export function RevokeInviteButton({
  inviteId,
  chainId,
}: {
  inviteId: string;
  chainId: string;
}) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (done) return <span className="text-xs text-[var(--color-muted)]">revoked</span>;

  function trigger() {
    setErr(null);
    startTransition(async () => {
      const reason = window.prompt("Revoke reason (optional)") ?? "";
      const res = await revokeChainInvite(inviteId, chainId, reason.trim());
      if (res.ok) setDone(true);
      else setErr(res.error);
    });
  }

  return (
    <div className="flex items-center gap-1.5">
      <button
        type="button"
        disabled={pending}
        onClick={trigger}
        className="rounded border border-[var(--color-danger)] px-1.5 py-0.5 text-xs text-[var(--color-danger)] hover:bg-red-50 disabled:opacity-50"
      >
        Revoke
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
