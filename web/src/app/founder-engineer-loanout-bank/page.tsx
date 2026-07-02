import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder engineer loanout bank — r1788" };
export const dynamic = "force-dynamic";

type InventoryRow = {
  id: string;
  equipment_name: string;
  equipment_type: string;
  total_units: number;
  currently_out: number;
  available_units: number;
  condition: string;
  status: string;
  notes: string | null;
  created_at: string;
};

type CheckoutRow = {
  id: string;
  inventory_id: string;
  equipment_name: string;
  equipment_type: string;
  engineer_user_id: string;
  engineer_email: string | null;
  checked_out_at: string;
  expected_return_at: string;
  returned_at: string | null;
  status: string;
  days_out: number;
};

type TopBorrowedRow = {
  inventory_id: string;
  equipment_name: string;
  equipment_type: string;
  total_checkouts: number;
  active_checkouts: number;
  overdue_checkouts: number;
  total_units: number;
  currently_out: number;
};

type OverdueRow = {
  id: string;
  inventory_id: string;
  equipment_name: string;
  engineer_user_id: string;
  engineer_email: string | null;
  checked_out_at: string;
  expected_return_at: string;
  days_overdue: number;
  status: string;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function statusBadge(status: string): string {
  if (status === "available") return "text-emerald-700";
  if (status === "limited") return "text-amber-700";
  if (status === "out_of_stock") return "text-red-700";
  if (status === "checked_out") return "text-blue-700";
  if (status === "overdue") return "text-red-700";
  if (status === "returned") return "text-emerald-700";
  if (status === "lost") return "text-red-800";
  return "";
}

function conditionBadge(c: string): string {
  if (c === "new") return "text-emerald-700";
  if (c === "good") return "text-emerald-600";
  if (c === "fair") return "text-amber-700";
  if (c === "poor") return "text-red-700";
  return "";
}

export default async function FounderEngineerLoanoutBankPage() {
  const sb = await getSupabaseServerClient();
  const [invRes, chkRes, topRes, ovdRes] = await Promise.all([
    sb.rpc("list_loanout_inventory_r1788"),
    sb.rpc("list_loanout_checkouts_r1788"),
    sb.rpc("top_borrowed_loanout_items_r1788"),
    sb.rpc("overdue_loanout_checkouts_r1788"),
  ]);

  if (invRes.error) throw new Error(`list_loanout_inventory_r1788: ${invRes.error.message}`);
  if (chkRes.error) throw new Error(`list_loanout_checkouts_r1788: ${chkRes.error.message}`);
  if (topRes.error) throw new Error(`top_borrowed_loanout_items_r1788: ${topRes.error.message}`);
  if (ovdRes.error) throw new Error(`overdue_loanout_checkouts_r1788: ${ovdRes.error.message}`);

  const inventory = (invRes.data ?? []) as InventoryRow[];
  const checkouts = (chkRes.data ?? []) as CheckoutRow[];
  const topBorrowed = (topRes.data ?? []) as TopBorrowedRow[];
  const overdue = (ovdRes.data ?? []) as OverdueRow[];

  const totalSku = inventory.length;
  const totalUnits = inventory.reduce((a, r) => a + (r.total_units ?? 0), 0);
  const outUnits = inventory.reduce((a, r) => a + (r.currently_out ?? 0), 0);
  const availableUnits = inventory.reduce((a, r) => a + (r.available_units ?? 0), 0);
  const outOfStockSku = inventory.filter((r) => r.status === "out_of_stock").length;
  const overdueCount = overdue.length;

  const inventoryColumns: Column<InventoryRow>[] = [
    { key: "equipment_name", header: "Equipment", render: (r: any) => <span className="font-medium">{r.equipment_name}</span> },
    { key: "equipment_type", header: "Type", render: (r: any) => r.equipment_type },
    { key: "total_units", header: "Total", render: (r: any) => String(r.total_units) },
    { key: "currently_out", header: "Out", render: (r: any) => String(r.currently_out) },
    { key: "available_units", header: "Avail", render: (r: any) => String(r.available_units) },
    { key: "condition", header: "Condition", render: (r: any) => <span className={conditionBadge(r.condition)}>{r.condition}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
    { key: "created_at", header: "Added", render: (r: any) => fmtDate(r.created_at) },
  ];

  const checkoutColumns: Column<CheckoutRow>[] = [
    { key: "equipment_name", header: "Equipment", render: (r: any) => <span className="font-medium">{r.equipment_name}</span> },
    { key: "equipment_type", header: "Type", render: (r: any) => r.equipment_type },
    { key: "engineer_email", header: "Engineer", render: (r: any) => r.engineer_email ?? "—" },
    { key: "checked_out_at", header: "Out", render: (r: any) => fmtDate(r.checked_out_at) },
    { key: "expected_return_at", header: "Due", render: (r: any) => fmtDate(r.expected_return_at) },
    { key: "returned_at", header: "Returned", render: (r: any) => fmtDate(r.returned_at) },
    { key: "days_out", header: "Days", render: (r: any) => String(r.days_out) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
  ];

  const topBorrowedColumns: Column<TopBorrowedRow>[] = [
    { key: "equipment_name", header: "Equipment", render: (r: any) => <span className="font-medium">{r.equipment_name}</span> },
    { key: "equipment_type", header: "Type", render: (r: any) => r.equipment_type },
    { key: "total_checkouts", header: "Total checkouts", render: (r: any) => String(r.total_checkouts) },
    { key: "active_checkouts", header: "Active", render: (r: any) => String(r.active_checkouts) },
    { key: "overdue_checkouts", header: "Overdue", render: (r: any) => <span className={r.overdue_checkouts > 0 ? "text-red-700 font-medium" : ""}>{String(r.overdue_checkouts)}</span> },
    { key: "currently_out", header: "Out / Total", render: (r: any) => `${r.currently_out} / ${r.total_units}` },
  ];

  const overdueColumns: Column<OverdueRow>[] = [
    { key: "equipment_name", header: "Equipment", render: (r: any) => <span className="font-medium">{r.equipment_name}</span> },
    { key: "engineer_email", header: "Engineer", render: (r: any) => r.engineer_email ?? "—" },
    { key: "checked_out_at", header: "Out", render: (r: any) => fmtDate(r.checked_out_at) },
    { key: "expected_return_at", header: "Due", render: (r: any) => fmtDate(r.expected_return_at) },
    { key: "days_overdue", header: "Days overdue", render: (r: any) => <span className="text-red-700 font-medium">{String(r.days_overdue)}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder engineer loanout bank — r1788</h1>
        <p className="mt-1 text-xs text-gray-500">
          Central bank of tools & equipment loanable across engineers. Checkout, return, and track overdue items.
          Use this to right-size inventory: items with high total checkouts & recurring overdues are buy-more
          candidates.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">SKUs</div>
          <div className="mt-1 text-lg font-semibold">{totalSku}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total units</div>
          <div className="mt-1 text-lg font-semibold">{totalUnits}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Out</div>
          <div className="mt-1 text-lg font-semibold text-blue-700">{outUnits}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Available</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{availableUnits}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Out of stock SKUs</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{outOfStockSku}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Overdue checkouts</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{overdueCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Inventory</h2>
        <p className="text-xs text-gray-500">
          Full bank of loanable equipment. Status flips to limited when half the units are out, and to out_of_stock
          when none remain.
        </p>
        <DataTable
          rows={inventory}
          columns={inventoryColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No equipment in the loanout bank yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Recent checkouts</h2>
        <p className="text-xs text-gray-500">
          Last 200 checkouts across all engineers. Days = duration in days between checkout & return (or now).
        </p>
        <DataTable
          rows={checkouts}
          columns={checkoutColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No checkouts logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top borrowed items</h2>
        <p className="text-xs text-gray-500">
          Ranked by total checkout count. High demand items with low total units are the first buy-more candidates.
        </p>
        <DataTable
          rows={topBorrowed}
          columns={topBorrowedColumns}
          rowKey={(r: any, i: number) => String(r.inventory_id ?? i)}
          emptyMessage="No checkout history yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Overdue checkouts</h2>
        <p className="text-xs text-gray-500">
          Items past their expected return date and not yet returned. Reach out to the engineer or mark lost if the
          item cannot be recovered.
        </p>
        <DataTable
          rows={overdue}
          columns={overdueColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No overdue checkouts."
        />
      </section>
    </div>
  );
}
