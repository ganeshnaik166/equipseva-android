"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

export type DisputeTrendDatum = {
  month_at: string;
  completed_jobs: number | null;
  disputed_jobs: number | null;
  dispute_rate_pct: number | null;
};

export function DisputeTrend({ data }: { data: DisputeTrendDatum[] }) {
  if (data.length === 0) return null;
  const formatted = data
    .slice()
    .sort((a, b) => a.month_at.localeCompare(b.month_at))
    .map((d) => ({
      month: d.month_at.slice(2, 7), // YY-MM
      rate: d.dispute_rate_pct ?? 0,
      completed: d.completed_jobs ?? 0,
    }));
  return (
    <div className="h-56 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={formatted} margin={{ top: 8, right: 24, bottom: 8, left: 8 }}>
          <defs>
            <linearGradient id="rateGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#0d7b45" stopOpacity={0.4} />
              <stop offset="100%" stopColor="#0d7b45" stopOpacity={0.05} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke="#eee" strokeDasharray="3 3" />
          <XAxis dataKey="month" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => `${v}%`} />
          <Tooltip formatter={(v) => `${typeof v === "number" ? v.toFixed(2) : v}%`} />
          <Area
            type="monotone"
            dataKey="rate"
            stroke="#0d7b45"
            strokeWidth={2}
            fill="url(#rateGradient)"
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
