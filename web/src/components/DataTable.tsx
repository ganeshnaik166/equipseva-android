import type { ReactNode } from "react";

// Three column shapes coexist in the founder console. The canonical one is
// keyed; the other two are what several hundred generated pages were written
// against. They all have to be first-class here: a column without `key` used
// to fall through to `row[undefined]`, so every cell on those pages rendered
// as "—" while the type errors that would have flagged it sat unread in a red
// CI run. Supporting the shapes in the component fixes the pages in place.

/** Canonical: `key` addresses `row[key]` (and is the React key); `render` overrides the cell. */
type KeyedColumn<T> = {
  key: string;
  header: string;
  render?: (row: T, index: number) => ReactNode;
  width?: string;
};

/** Generated-page shape: the cell is whatever `accessor` returns for the row. */
type AccessorColumn<T> = {
  header: string;
  accessor: (row: T) => ReactNode;
  key?: string;
  width?: string;
};

/** Generated-page shape: `cell` is a full cell renderer, like `render`. */
type CellColumn<T> = {
  header: string;
  cell: (row: T, index: number) => ReactNode;
  key?: string;
  width?: string;
};

export type Column<T> = KeyedColumn<T> | AccessorColumn<T> | CellColumn<T>;

function formatValue(v: unknown): ReactNode {
  if (v === null || v === undefined || v === "") return "—";
  if (typeof v === "object") return v as ReactNode;
  return String(v);
}

function defaultCell<T>(row: T, key: string): ReactNode {
  return formatValue((row as Record<string, unknown>)[key]);
}

function columnKey<T>(c: Column<T>, index: number): string {
  // Headers can repeat within one table, so the position disambiguates.
  return c.key ?? `${c.header}#${index}`;
}

function cellContent<T>(c: Column<T>, row: T, rowIndex: number): ReactNode {
  if ("render" in c && c.render) return c.render(row, rowIndex);
  if ("cell" in c) return c.cell(row, rowIndex);
  if ("accessor" in c) return formatValue(c.accessor(row));
  return defaultCell(row, c.key);
}

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
            {columns.map((c, ci) => (
              <th key={columnKey(c, ci)} className="px-3 py-2.5 font-semibold" style={{ width: c.width }}>
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
              {columns.map((c, ci) => (
                <td key={columnKey(c, ci)} className="px-3 py-2.5 align-top text-[var(--color-fg)]">
                  {cellContent(c, row, i)}
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
