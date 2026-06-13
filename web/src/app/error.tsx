"use client";

import Link from "next/link";
import { useEffect } from "react";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // eslint-disable-next-line no-console
    console.error(error);
  }, [error]);

  const isFounderGate = error.message?.toLowerCase().includes("not authorized");

  return (
    <div className="mx-auto mt-16 max-w-md rounded border border-[var(--color-border)] bg-white p-6">
      <h1 className="text-lg font-semibold">
        {isFounderGate ? "Not authorized" : "Something went wrong"}
      </h1>
      <p className="mt-2 text-sm text-[var(--color-muted)]">{error.message}</p>
      <div className="mt-4 flex gap-2">
        {isFounderGate ? (
          <Link
            href="/login"
            className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm text-white"
          >
            Sign in with founder email
          </Link>
        ) : (
          <button
            onClick={() => reset()}
            className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm text-white"
          >
            Try again
          </button>
        )}
      </div>
    </div>
  );
}
