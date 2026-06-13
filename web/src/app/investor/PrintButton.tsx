"use client";

export function PrintButton() {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="rounded border border-[var(--color-border)] bg-white px-2 py-1 text-xs hover:bg-gray-50"
    >
      Print / Save as PDF
    </button>
  );
}
