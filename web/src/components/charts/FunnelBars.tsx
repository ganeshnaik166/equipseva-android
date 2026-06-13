"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

export type FunnelDatum = {
  ordinal: number;
  step_label: string;
  unique_users: number | null;
  conversion_pct: number | null;
};

export function FunnelBars({ data, accent = "#0d7b45" }: { data: FunnelDatum[]; accent?: string }) {
  if (data.length === 0) return null;
  const formatted = data.map((d) => ({
    ...d,
    label: `${d.ordinal}. ${d.step_label}`,
    users: d.unique_users ?? 0,
    pct: d.conversion_pct ?? 0,
  }));

  return (
    <div className="h-64 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={formatted}
          layout="vertical"
          margin={{ top: 8, right: 48, bottom: 8, left: 8 }}
        >
          <CartesianGrid stroke="#eee" strokeDasharray="3 3" horizontal={false} />
          <XAxis type="number" tick={{ fontSize: 11 }} />
          <YAxis
            type="category"
            dataKey="label"
            width={180}
            tick={{ fontSize: 11 }}
            interval={0}
          />
          <Tooltip
            cursor={{ fill: "rgba(0,0,0,0.04)" }}
            formatter={(value, _name, item) => {
              const pct = ((item as { payload?: { pct?: number } })?.payload?.pct) ?? 0;
              return [`${value} users (${pct.toFixed(1)}%)`, "Reached"];
            }}
          />
          <Bar dataKey="users" radius={[0, 4, 4, 0]}>
            {formatted.map((_, i) => (
              <Cell key={i} fill={accent} fillOpacity={1 - i * 0.12} />
            ))}
            <LabelList
              dataKey="pct"
              position="right"
              formatter={(v) => {
                const n = typeof v === "number" ? v : 0;
                return `${n.toFixed(0)}%`;
              }}
              style={{ fontSize: 11, fill: "#444" }}
            />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
