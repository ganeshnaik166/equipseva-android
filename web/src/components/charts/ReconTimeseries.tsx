"use client";

import {
  Bar,
  CartesianGrid,
  ComposedChart,
  Legend,
  Line,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

export type ReconDatum = {
  run_date: string;
  rzp_total_inflow_rupees: number | null;
  cf_total_outflow_rupees: number | null;
  gst_owed_rupees: number | null;
  anomaly_count: number | null;
};

const inrShort = (n: number) => {
  if (n >= 1_00_00_000) return `₹${(n / 1_00_00_000).toFixed(1)}Cr`;
  if (n >= 1_00_000) return `₹${(n / 1_00_000).toFixed(1)}L`;
  if (n >= 1_000) return `₹${(n / 1_000).toFixed(1)}k`;
  return `₹${n}`;
};

export function ReconTimeseries({ data }: { data: ReconDatum[] }) {
  if (data.length === 0) return null;
  // Recharts wants oldest → newest left → right.
  const sorted = [...data].sort((a, b) => a.run_date.localeCompare(b.run_date));
  const formatted = sorted.map((d) => ({
    date: d.run_date.slice(5), // MM-DD
    rzp: d.rzp_total_inflow_rupees ?? 0,
    cf: d.cf_total_outflow_rupees ?? 0,
    gst: d.gst_owed_rupees ?? 0,
    anomalies: d.anomaly_count ?? 0,
  }));
  return (
    <div className="h-72 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <ComposedChart data={formatted} margin={{ top: 16, right: 32, bottom: 8, left: 8 }}>
          <CartesianGrid stroke="#eee" strokeDasharray="3 3" />
          <XAxis dataKey="date" tick={{ fontSize: 11 }} />
          <YAxis
            yAxisId="money"
            tick={{ fontSize: 11 }}
            tickFormatter={(v) => inrShort(Number(v))}
          />
          <YAxis
            yAxisId="anom"
            orientation="right"
            allowDecimals={false}
            tick={{ fontSize: 11 }}
          />
          <Tooltip
            formatter={(value, name) => {
              const v = typeof value === "number" ? value : 0;
              const n = String(name);
              if (n === "anomalies") return [v, "Anomalies"];
              return [
                inrShort(v),
                n === "rzp" ? "Razorpay in" : n === "cf" ? "Cashfree out" : "GST owed",
              ];
            }}
          />
          <Legend wrapperStyle={{ fontSize: 11 }} />
          <Bar yAxisId="anom" dataKey="anomalies" fill="#b91c1c" />
          <Line yAxisId="money" type="monotone" dataKey="rzp" stroke="#0d7b45" strokeWidth={2} dot={false} />
          <Line yAxisId="money" type="monotone" dataKey="cf" stroke="#b45309" strokeWidth={2} dot={false} />
          <Line yAxisId="money" type="monotone" dataKey="gst" stroke="#6b7280" strokeDasharray="4 4" strokeWidth={1.5} dot={false} />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
}
