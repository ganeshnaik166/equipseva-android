// Shim: hundreds of generated founder pages import "@/components/ui/DataTable",
// but the component lives at "@/components/DataTable". Re-export to keep both
// paths valid without touching 683 pages.
export { DataTable } from "../DataTable";
export type { Column } from "../DataTable";
