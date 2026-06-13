import type { ReactNode } from "react";

export type Column<T> = {
  key: string;
  header: string;
  render: (row: T) => ReactNode;
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
  rowKey: (row: T) => string;
}) {
  if (rows.length === 0) {
    return (
      <div className="rounded border border-dashed border-[var(--color-border)] bg-white p-6 text-center text-sm text-[var(--color-muted)]">
        {emptyMessage}
      </div>
    );
  }
  return (
    <div className="overflow-x-auto rounded border border-[var(--color-border)] bg-white">
      <table className="min-w-full text-sm">
        <thead>
          <tr className="border-b border-[var(--color-border)] bg-gray-50 text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
            {columns.map((c) => (
              <th key={c.key} className="px-3 py-2 font-medium" style={{ width: c.width }}>
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={rowKey(row)} className="border-b border-[var(--color-border)] last:border-0">
              {columns.map((c) => (
                <td key={c.key} className="px-3 py-2 align-top">
                  {c.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
