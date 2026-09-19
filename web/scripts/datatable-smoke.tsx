// Render smoke test for src/components/DataTable.tsx — proves all three
// column shapes put real values in the cells (the generated accessor/cell
// pages used to render "—" everywhere because `key` was undefined).
import { renderToStaticMarkup } from "react-dom/server";
import { DataTable, type Column } from "../src/components/DataTable";

type Row = { id: string; hospital_name: string; jobs: number; note: string | null };
const rows: Row[] = [
  { id: "a", hospital_name: "Apollo Jubilee Hills", jobs: 12, note: null },
  { id: "b", hospital_name: "KIMS Secunderabad", jobs: 0, note: "" },
];
const columns: Column<Row>[] = [
  { key: "hospital_name", header: "Hospital" },                                   // keyed, default cell
  { key: "jobs", header: "Jobs (render)", render: (r) => `${r.jobs} jobs` },      // keyed + render
  { header: "Hospital (accessor)", accessor: (r) => r.hospital_name },            // generated shape 1
  { header: "Note (accessor)", accessor: (r) => r.note },                         // accessor returning null/""
  { header: "Jobs (cell)", cell: (r, i) => `#${i}:${r.jobs}` },                  // generated shape 2
];
const html = renderToStaticMarkup(<DataTable rows={rows} columns={columns} rowKey={(r) => r.id} />);

function expect(cond: boolean, msg: string) {
  if (!cond) { console.error("FAIL:", msg); process.exitCode = 1; } else { console.log("ok  ", msg); }
}
expect(html.includes("Apollo Jubilee Hills"), "keyed default cell renders row[key]");
expect(html.includes("12 jobs"), "keyed render() is used");
expect((html.match(/Apollo Jubilee Hills/g) || []).length === 2, "accessor column renders the same value again (keyed + accessor)");
expect(html.includes("#0:12") && html.includes("#1:0"), "cell(row, index) receives the row index");
expect((html.match(/—/g) || []).length === 2, "null and empty accessor values render as — (2 cells), nothing else does");
expect(!html.includes("undefined"), "no 'undefined' leaked into the markup");
expect(html.includes("<th") && (html.match(/<th\s/g) || []).length === 5, "5 header cells");
expect(html.includes("2 rows"), "footer row count");
// Empty state unchanged
const empty = renderToStaticMarkup(<DataTable rows={[] as Row[]} columns={columns} rowKey={(r) => r.id} emptyMessage="Nothing yet" />);
expect(empty.includes("Nothing yet"), "empty state message");
console.log(process.exitCode ? "SMOKE FAILED" : "SMOKE PASSED");
