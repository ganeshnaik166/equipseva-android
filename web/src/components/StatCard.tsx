import Link from "next/link";

export function StatCard({
  label,
  value,
  subtext,
  href,
  tone = "neutral",
}: {
  label: string;
  value: string;
  subtext?: string;
  href?: string;
  tone?: "neutral" | "warn" | "danger" | "ok";
}) {
  const toneClass =
    tone === "danger"
      ? "text-[var(--color-danger)]"
      : tone === "warn"
        ? "text-[var(--color-warn)]"
        : tone === "ok"
          ? "text-[var(--color-ok)]"
          : "text-[var(--color-fg)]";

  const Body = (
    <>
      <div className="text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
        {label}
      </div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${toneClass}`}>{value}</div>
      {subtext && (
        <div className="mt-1 text-xs text-[var(--color-muted)]">{subtext}</div>
      )}
    </>
  );

  const baseClass =
    "block rounded-lg border border-[var(--color-border)] bg-white p-4 transition hover:border-[var(--color-fg)]";

  if (href) {
    return (
      <Link href={href} className={baseClass}>
        {Body}
      </Link>
    );
  }
  return <div className={baseClass}>{Body}</div>;
}
