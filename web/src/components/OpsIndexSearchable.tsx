"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

export type OpsLink = { href: string; title: string; desc: string; round: string };
export type OpsSection = { label: string; links: OpsLink[] };

const COLLAPSE_THRESHOLD = 30;
const PREVIEW_COUNT = 24;

const slugify = (label: string) =>
  label.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

export function OpsIndexSearchable({ sections }: { sections: OpsSection[] }) {
  const [q, setQ] = useState("");
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
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

      {!norm && (
        <nav aria-label="Sections" className="flex flex-wrap gap-1.5">
          {sections.map((s) => (
            <a
              key={s.label}
              href={`#${slugify(s.label)}`}
              className="rounded-full border border-[var(--color-border)] bg-white px-2.5 py-0.5 text-[11px] text-[var(--color-muted)] transition-colors hover:border-[var(--color-fg)] hover:text-[var(--color-fg)]"
            >
              {s.label.replace(/ \(\d+\)$/, "")}
              <span className="ml-1 tabular-nums opacity-60">{s.links.length}</span>
            </a>
          ))}
        </nav>
      )}

      {filtered.map((section) => {
        const slug = slugify(section.label);
        const collapsible = !norm && section.links.length > COLLAPSE_THRESHOLD;
        const isExpanded = !collapsible || expanded[slug] === true;
        const visibleLinks = isExpanded ? section.links : section.links.slice(0, PREVIEW_COUNT);
        return (
          <section key={section.label} id={slug} className="scroll-mt-16">
            <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
              {section.label}
            </h2>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
              {visibleLinks.map((link) => (
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
            {collapsible && (
              <button
                type="button"
                onClick={() => setExpanded((e) => ({ ...e, [slug]: !isExpanded }))}
                className="mt-2 rounded border border-[var(--color-border)] bg-white px-3 py-1 text-xs text-[var(--color-muted)] transition-colors hover:border-[var(--color-fg)] hover:text-[var(--color-fg)]"
              >
                {isExpanded
                  ? "Show less"
                  : `Show all ${section.links.length} (${section.links.length - PREVIEW_COUNT} more)`}
              </button>
            )}
          </section>
        );
      })}

      {filtered.length === 0 && norm && (
        <div className="rounded border border-[var(--color-border)] bg-white p-6 text-center text-xs text-[var(--color-muted)]">
          No surfaces match &quot;{q}&quot;.
        </div>
      )}
    </div>
  );
}
