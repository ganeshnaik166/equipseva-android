"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

export type OpsLink = { href: string; title: string; desc: string; round: string };
export type OpsSection = { label: string; links: OpsLink[] };

export function OpsIndexSearchable({ sections }: { sections: OpsSection[] }) {
  const [q, setQ] = useState("");
  const norm = q.trim().toLowerCase();

  const filtered = useMemo(() => {
    if (!norm) return sections;
    return sections
      .map((s) => ({
        ...s,
        links: s.links.filter((l) =>
          l.title.toLowerCase().includes(norm) ||
          l.desc.toLowerCase().includes(norm) ||
          l.href.toLowerCase().includes(norm) ||
          l.round.toLowerCase().includes(norm) ||
          s.label.toLowerCase().includes(norm)
        ),
      }))
      .filter((s) => s.links.length > 0);
  }, [sections, norm]);

  const totalLinks = sections.reduce((n, s) => n + s.links.length, 0);
  const shownLinks = filtered.reduce((n, s) => n + s.links.length, 0);

  return (
    <div className="space-y-6">
      <div className="sticky top-0 z-10 -mx-2 bg-[var(--color-bg)] px-2 py-2">
        <div className="flex items-baseline gap-3">
          <input
            type="search"
            placeholder="Filter… (title, desc, route, round)"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="w-full max-w-md rounded border border-[var(--color-border)] bg-white px-3 py-1.5 text-sm focus:border-[var(--color-fg)] focus:outline-none"
            autoFocus
          />
          <span className="text-xs tabular-nums text-[var(--color-muted)]">
            {norm ? `${shownLinks}/${totalLinks}` : `${totalLinks} surfaces`}
          </span>
        </div>
      </div>

      {filtered.map((section) => (
        <section key={section.label}>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            {section.label}
          </h2>
          <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
            {section.links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="rounded border border-[var(--color-border)] bg-white p-3 transition-colors hover:border-[var(--color-fg)]"
              >
                <div className="flex items-baseline justify-between">
                  <h3 className="text-sm font-semibold">{link.title}</h3>
                  <span className="text-[10px] text-[var(--color-muted)]">{link.round}</span>
                </div>
                <p className="mt-1 text-xs text-[var(--color-muted)]">{link.desc}</p>
              </Link>
            ))}
          </div>
        </section>
      ))}

      {filtered.length === 0 && norm && (
        <div className="rounded border border-[var(--color-border)] bg-white p-6 text-center text-xs text-[var(--color-muted)]">
          No surfaces match &quot;{q}&quot;.
        </div>
      )}
    </div>
  );
}
