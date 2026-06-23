import type { ReactNode } from "react";

export type Column<T> = {
  key: string;
  header: string;
  render: (row: T, index: number) => ReactNode;
  width?: string;
};

export function DataTable<T>({
  columns,
  rows,
  emptyMessage = "No rows.",
  rowKey,
}: {
  columns: Column<T>[];
  rows: T[];
  emptyMessage?: string;
  rowKey: (row: T, index: number) => string;
}) {
  if (rows.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-[var(--color-border)] bg-white/50 p-8 text-center text-sm text-[var(--color-muted)]">
        <span className="opacity-60">∅</span> {emptyMessage}
      </div>
    );
  }
  return (
    <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-white shadow-sm ring-1 ring-black/[0.02]">
      <table className="min-w-full text-sm">
        <thead className="sticky top-0 z-10 bg-gradient-to-b from-gray-50 to-gray-100/80 backdrop-blur">
          <tr className="border-b-2 border-[var(--color-border)] text-left text-[11px] uppercase tracking-wider text-[var(--color-muted)]">
            {columns.map((c) => (
              <th key={c.key} className="px-3 py-2.5 font-semibold" style={{ width: c.width }}>
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr
              key={rowKey(row, i)}
              className="border-b border-[var(--color-border)] last:border-0 odd:bg-white even:bg-gray-50/30 hover:bg-emerald-50/40 transition-colors"
            >
              {columns.map((c) => (
                <td key={c.key} className="px-3 py-2.5 align-top text-[var(--color-fg)]">
                  {c.render(row, i)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan={columns.length} className="bg-gray-50/60 px-3 py-1.5 text-right text-[11px] text-[var(--color-muted)]">
              {rows.length} {rows.length === 1 ? "row" : "rows"}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
  );
}
