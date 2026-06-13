"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

export type CohortDatum = {
  cohort_month: string;
  cohort_size: number | null;
  retained_30d: number | null;
  retained_60d: number | null;
  retained_90d: number | null;
  retained_180d: number | null;
};

export function CohortBars({ data }: { data: CohortDatum[] }) {
  if (data.length === 0) return null;
  const formatted = data
    .slice()
    .sort((a, b) => a.cohort_month.localeCompare(b.cohort_month))
    .map((d) => {
      const size = d.cohort_size ?? 0;
      const pct = (v: number | null) => (size > 0 && v != null ? (v / size) * 100 : 0);
      return {
        month: d.cohort_month.slice(2), // YY-MM
        d30: pct(d.retained_30d),
        d60: pct(d.retained_60d),
        d90: pct(d.retained_90d),
        d180: pct(d.retained_180d),
      };
    });

  return (
    <div className="h-64 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={formatted} margin={{ top: 8, right: 24, bottom: 8, left: 8 }}>
          <CartesianGrid stroke="#eee" strokeDasharray="3 3" />
          <XAxis dataKey="month" tick={{ fontSize: 11 }} />
          <YAxis
            tick={{ fontSize: 11 }}
            tickFormatter={(v) => `${v}%`}
            domain={[0, 100]}
          />
          <Tooltip formatter={(v) => `${typeof v === "number" ? v.toFixed(1) : v}%`} />
          <Legend wrapperStyle={{ fontSize: 11 }} />
          <Bar dataKey="d30" fill="#0d7b45" name="30d" />
          <Bar dataKey="d60" fill="#15803d" name="60d" />
          <Bar dataKey="d90" fill="#65a30d" name="90d" />
          <Bar dataKey="d180" fill="#a3a3a3" name="180d" />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
