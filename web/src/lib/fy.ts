/**
 * Indian fiscal year helpers. FY runs April 1 → March 31, named as
 * "2026-27" for the year that begins on 2026-04-01.
 */
export function currentFiscalYear(date: Date = new Date()): string {
  const utc = new Date(date.toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
  const year = utc.getFullYear();
  const month = utc.getMonth(); // 0 = Jan
  const startYear = month >= 3 ? year : year - 1;
  const endYear = (startYear + 1) % 100;
  return `${startYear}-${endYear.toString().padStart(2, "0")}`;
}

export function currentFiscalQuarter(date: Date = new Date()): number {
  const utc = new Date(date.toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
  const month = utc.getMonth(); // 0-indexed
  // Apr-Jun=Q1, Jul-Sep=Q2, Oct-Dec=Q3, Jan-Mar=Q4
  if (month >= 3 && month <= 5) return 1;
  if (month >= 6 && month <= 8) return 2;
  if (month >= 9 && month <= 11) return 3;
  return 4;
}
