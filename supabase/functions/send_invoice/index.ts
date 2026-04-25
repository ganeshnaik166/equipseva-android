// Supabase edge function: send_invoice
//
// Triggered by a Postgres trigger on `spare_part_orders` when payment_status
// flips to 'completed' (see migration 20260425090000). The trigger POSTs a
// Supabase-DB-webhook-shaped payload here. We:
//   1. Verify the x-webhook-secret header against the env value.
//   2. Pull the full order + line items + buyer + seller (admin client).
//   3. Render an HTML invoice.
//   4. Upload the HTML to the `invoices` bucket at `{order_id}.html`.
//   5. Update spare_part_orders.invoice_url with the public path.
//   6. Send the buyer an email via Resend with the HTML inline + a download link.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

interface OrderItemRow {
  spare_part_id: string;
  quantity: number;
  unit_price: number;
  line_total: number;
  spare_part_name: string | null;
}

interface OrderRow {
  id: string;
  order_number: string | null;
  buyer_user_id: string;
  supplier_org_id: string | null;
  total_amount: number;
  subtotal: number;
  gst_amount: number | null;
  shipping_cost: number | null;
  delivery_address_line1: string | null;
  delivery_address_line2: string | null;
  delivery_city: string | null;
  delivery_state: string | null;
  delivery_pincode: string | null;
  payment_status: string;
  created_at: string;
}

const formatRupee = (n: number) =>
  new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(n);

function renderHtml(args: {
  order: OrderRow;
  items: OrderItemRow[];
  buyerName: string;
  buyerEmail: string;
  sellerName: string;
}) {
  const dateStr = new Date(args.order.created_at).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
  const addrLine = [
    args.order.delivery_address_line1,
    args.order.delivery_address_line2,
    args.order.delivery_city,
    args.order.delivery_state,
    args.order.delivery_pincode,
  ]
    .filter(Boolean)
    .join(", ");
  const rows = args.items
    .map(
      (it) => `
        <tr>
          <td style="padding:10px 8px;border-bottom:1px solid #eee;">${escape(it.spare_part_name ?? it.spare_part_id)}</td>
          <td style="padding:10px 8px;border-bottom:1px solid #eee;text-align:center;">${it.quantity}</td>
          <td style="padding:10px 8px;border-bottom:1px solid #eee;text-align:right;">${formatRupee(it.unit_price)}</td>
          <td style="padding:10px 8px;border-bottom:1px solid #eee;text-align:right;">${formatRupee(it.line_total)}</td>
        </tr>`,
    )
    .join("");
  return `<!doctype html>
<html><head><meta charset="utf-8"/><title>EquipSeva Invoice ${escape(args.order.order_number ?? args.order.id)}</title></head>
<body style="margin:0;padding:0;font-family:'Helvetica Neue',Arial,sans-serif;background:#f7f8fa;color:#111418;">
  <table style="width:100%;max-width:680px;margin:24px auto;background:#fff;border:1px solid #e6e8eb;border-radius:14px;overflow:hidden;">
    <tr>
      <td style="background:linear-gradient(135deg,#0B6E4F,#075A40);padding:24px 28px;color:#fff;">
        <div style="font-size:12px;letter-spacing:.5px;opacity:.85;">EQUIPSEVA</div>
        <div style="font-size:22px;font-weight:700;margin-top:4px;">Invoice</div>
        <div style="font-size:13px;opacity:.85;margin-top:4px;">${escape(args.order.order_number ?? args.order.id)} · ${escape(dateStr)}</div>
      </td>
    </tr>
    <tr>
      <td style="padding:20px 28px;">
        <table style="width:100%;font-size:13px;">
          <tr>
            <td style="vertical-align:top;width:50%;">
              <div style="font-weight:600;color:#5f6877;">Billed to</div>
              <div style="font-weight:600;font-size:14px;margin-top:2px;">${escape(args.buyerName)}</div>
              <div style="color:#5f6877;">${escape(args.buyerEmail)}</div>
              <div style="color:#5f6877;margin-top:6px;">${escape(addrLine)}</div>
            </td>
            <td style="vertical-align:top;width:50%;">
              <div style="font-weight:600;color:#5f6877;">From</div>
              <div style="font-weight:600;font-size:14px;margin-top:2px;">${escape(args.sellerName)}</div>
              <div style="color:#5f6877;">EquipSeva Marketplace</div>
            </td>
          </tr>
        </table>
        <table style="width:100%;margin-top:24px;border-collapse:collapse;font-size:13px;">
          <thead>
            <tr style="background:#E6F2ED;">
              <th style="padding:10px 8px;text-align:left;color:#075A40;">Item</th>
              <th style="padding:10px 8px;text-align:center;color:#075A40;">Qty</th>
              <th style="padding:10px 8px;text-align:right;color:#075A40;">Price</th>
              <th style="padding:10px 8px;text-align:right;color:#075A40;">Total</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
        <table style="width:100%;margin-top:18px;font-size:13px;">
          <tr><td style="text-align:right;color:#5f6877;padding:4px 8px;">Subtotal</td><td style="text-align:right;width:120px;padding:4px 8px;">${formatRupee(args.order.subtotal)}</td></tr>
          <tr><td style="text-align:right;color:#5f6877;padding:4px 8px;">GST</td><td style="text-align:right;padding:4px 8px;">${formatRupee(args.order.gst_amount ?? 0)}</td></tr>
          <tr><td style="text-align:right;color:#5f6877;padding:4px 8px;">Shipping</td><td style="text-align:right;padding:4px 8px;">${formatRupee(args.order.shipping_cost ?? 0)}</td></tr>
          <tr><td style="text-align:right;font-weight:700;font-size:15px;padding:8px 8px;border-top:1px solid #e6e8eb;">Total</td><td style="text-align:right;font-weight:700;font-size:15px;padding:8px 8px;border-top:1px solid #e6e8eb;">${formatRupee(args.order.total_amount)}</td></tr>
        </table>
        <div style="margin-top:24px;font-size:12px;color:#5f6877;line-height:1.5;">
          Payment received via Razorpay. Status: <span style="font-weight:600;color:#0B6E4F;text-transform:capitalize;">${escape(args.order.payment_status)}</span>.
          This invoice is generated electronically and is valid without signature.
        </div>
      </td>
    </tr>
  </table>
</body></html>`;
}

function escape(s: string) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  const expectedSecret = Deno.env.get("INVOICE_WEBHOOK_SECRET");
  const incomingSecret = req.headers.get("x-webhook-secret");
  if (!expectedSecret || incomingSecret !== expectedSecret) {
    return bad("unauthenticated", "bad webhook secret", 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return bad("server_error", "edge function not configured", 500);
  }

  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const resendFrom = Deno.env.get("RESEND_FROM") ?? "invoices@equipseva.com";

  let payload: { record?: { id?: string } };
  try {
    payload = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }
  const orderId = payload.record?.id;
  if (!orderId) return bad("bad_request", "missing record.id");

  const admin = createClient(supabaseUrl, serviceKey);

  const { data: order, error: orderErr } = await admin
    .from("spare_part_orders")
    .select(
      "id, order_number, buyer_user_id, supplier_org_id, total_amount, subtotal, gst_amount, shipping_cost, delivery_address_line1, delivery_address_line2, delivery_city, delivery_state, delivery_pincode, payment_status, created_at",
    )
    .eq("id", orderId)
    .maybeSingle();
  if (orderErr || !order) return bad("order_not_found", orderErr?.message ?? "missing", 404);

  const { data: items } = await admin
    .from("spare_part_order_items")
    .select("spare_part_id, quantity, unit_price, line_total, spare_part_name")
    .eq("order_id", orderId);

  const { data: buyer } = await admin
    .from("profiles")
    .select("full_name, email")
    .eq("id", order.buyer_user_id)
    .maybeSingle();

  const { data: seller } = order.supplier_org_id
    ? await admin.from("organizations").select("name").eq("id", order.supplier_org_id).maybeSingle()
    : { data: null };

  const html = renderHtml({
    order: order as OrderRow,
    items: (items ?? []) as OrderItemRow[],
    buyerName: buyer?.full_name ?? "EquipSeva customer",
    buyerEmail: buyer?.email ?? "",
    sellerName: seller?.name ?? "EquipSeva seller",
  });

  // Upload to Storage (invoices bucket).
  const path = `${orderId}.html`;
  const upload = await admin.storage
    .from("invoices")
    .upload(path, new Blob([html], { type: "text/html" }), { upsert: true, contentType: "text/html" });
  if (upload.error) {
    return bad("server_error", `upload_failed: ${upload.error.message}`, 500);
  }

  const { data: signed } = await admin.storage
    .from("invoices")
    .createSignedUrl(path, 60 * 60 * 24 * 30); // 30 day signed URL

  const invoiceUrl = signed?.signedUrl ?? null;

  await admin
    .from("spare_part_orders")
    .update({ invoice_url: invoiceUrl })
    .eq("id", orderId);

  // Email via Resend (best-effort — never fail the webhook if email errors).
  if (resendApiKey && buyer?.email) {
    try {
      await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${resendApiKey}`,
        },
        body: JSON.stringify({
          from: resendFrom,
          to: [buyer.email],
          subject: `EquipSeva Invoice ${order.order_number ?? order.id}`,
          html,
        }),
      });
    } catch (e) {
      console.error("resend send failed", e);
    }
  }

  return json(200, { ok: true, invoice_url: invoiceUrl });
});
