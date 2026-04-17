import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function normalizeAbsoluteUrl(input: string): string {
  const trimmed = input.trim();
  const parsed = new URL(trimmed);

  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new Error(`Invalid URL protocol for '${trimmed}'. Use http or https.`);
  }

  parsed.hash = "";
  return parsed.toString();
}

function normalizeBaseUrl(input: string): string {
  const normalized = normalizeAbsoluteUrl(input);
  return normalized.replace(/\/+$/, "");
}

function buildKowriUrl(baseUrl: string, path: string): string {
  const base = new URL(baseUrl);
  return new URL(path, base).toString();
}

function isLocalDevOrigin(hostname: string): boolean {
  return hostname === "localhost" || hostname === "127.0.0.1";
}

function isSchoolOrigin(hostname: string): boolean {
  return hostname === "ghschools.edu.gh" || hostname.endsWith(".ghschools.edu.gh");
}

function isAllowedOrigin(originHeader: string | null): boolean {
  if (!originHeader || originHeader === "null") return true;

  let parsedOrigin: URL;
  try {
    parsedOrigin = new URL(originHeader);
  } catch {
    return false;
  }

  if (isLocalDevOrigin(parsedOrigin.hostname) || isSchoolOrigin(parsedOrigin.hostname)) {
    return true;
  }

  const configured = Deno.env.get("KOWRI_ALLOWED_ORIGINS")?.trim();
  if (!configured) {
    return false;
  }

  const allowedEntries = configured.split(",").map((o) => o.trim()).filter(Boolean);

  return allowedEntries.some((entry) => {
    if (entry === originHeader) return true;

    if (entry.includes("*")) {
      const safePattern = entry
        .replace(/[.+?^${}()|[\]\\]/g, "\\$&")
        .replace(/\*/g, ".*");
      const re = new RegExp(`^${safePattern}$`, "i");
      return re.test(originHeader);
    }

    return false;
  });
}

function buildWebhookUrl(supabaseUrl: string): string {
  const configured = Deno.env.get("KOWRI_WEBHOOK_URL")?.trim();
  const base = configured && configured !== ""
    ? configured
    : `${supabaseUrl}/functions/v1/kowri-webhook`;

  const normalized = normalizeAbsoluteUrl(base);
  const token = Deno.env.get("KOWRI_WEBHOOK_TOKEN")?.trim();
  if (!token) {
    return normalized;
  }

  const url = new URL(normalized);
  url.searchParams.set("token", token);
  return url.toString();
}

function toIntlGhanaMsisdn(input: string): string {
  const digits = input.replace(/\D/g, "");
  if (digits.startsWith("233") && digits.length === 12) return digits;
  if (digits.startsWith("0") && digits.length === 10) return `233${digits.slice(1)}`;
  if (digits.length === 9) return `233${digits}`;
  return digits;
}

function newTxnId(): string {
  return `${Date.now()}${Math.floor(Math.random() * 10000)}`;
}

async function callKowri(url: string, appId: string, body: Record<string, unknown>) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      appId,
    },
    body: JSON.stringify(body),
  });

  const raw = await response.text();
  let data: any = null;
  try {
    data = raw ? JSON.parse(raw) : null;
  } catch {
    data = null;
  }

  return { response, raw, data };
}

function getKowriErrorMessage(call: { data: any; raw: string; response: Response }, fallback: string): string {
  const status = call.response.status;
  const message = call.data?.statusMessage || call.data?.message || call.raw;
  
  if (status === 511 || message.includes("not authorized for")) {
    return `Merchant authorization failed. Please contact support to enable 'debit authorization bypass' for the provided number. (Status: ${status})`;
  }
  
  return message || fallback;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const origin = req.headers.get("origin");
    if (!isAllowedOrigin(origin)) {
      return new Response(JSON.stringify({ error: "Origin not allowed", origin }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabase = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const body = await req.json().catch(() => null);
    if (!body) {
      throw new Error("Request body is empty or invalid JSON");
    }

    if (body.action !== "initiate_payment") {
      throw new Error("Unsupported action");
    }

    const { phone, email, first_name, last_name, amount } = body.payload || {};
    if (!phone) throw new Error("Phone number is required");
    if (!first_name) throw new Error("First name is required");
    if (!last_name) throw new Error("Last name is required");

    const paymentAmount = parseFloat(amount) || 0.5;
    if (paymentAmount < 0.5) {
      throw new Error("Minimum payment amount is GHS 0.50 for MTN MONEY");
    }
    if (paymentAmount > 100000) {
      throw new Error("Maximum payment amount is GHS 100,000");
    }

    const dbEmail = email && email.trim() !== "" ? email.trim() : "";
    const merchantOrderId = `ORD-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    const customerName = `${first_name} ${last_name}`.trim();
    const msisdn = toIntlGhanaMsisdn(String(phone));

    const { error: cacheErr } = await supabase
      .from("payment_cache_for_admission_payments_kowri")
      .insert([
        {
          order_id: merchantOrderId,
          phone,
          email: dbEmail,
          first_name,
          last_name,
          amount: paymentAmount,
        },
      ]);

    if (cacheErr) {
      throw new Error(`Failed to cache payment details: ${cacheErr.message}`);
    }

    const baseUrlRaw = Deno.env.get("KOWRI_BASE_URL");
    const appId = Deno.env.get("KOWRI_APP_ID");
    const appRef = Deno.env.get("KOWRI_APP_REFERENCE");
    const appSecret = Deno.env.get("KOWRI_APP_SECRET");
    const defaultProvider = Deno.env.get("KOWRI_PROVIDER")?.trim() || "MTN_MONEY";
    const serviceCode = Deno.env.get("KOWRI_SERVICE_CODE")?.trim();

    const missingVars: string[] = [];
    if (!baseUrlRaw) missingVars.push("KOWRI_BASE_URL");
    if (!appId) missingVars.push("KOWRI_APP_ID");
    if (!appRef) missingVars.push("KOWRI_APP_REFERENCE");
    if (!appSecret) missingVars.push("KOWRI_APP_SECRET");

    if (missingVars.length > 0) {
      throw new Error(`Missing Kowri Configuration: ${missingVars.join(", ")}`);
    }

    const normalizedBaseUrl = normalizeBaseUrl(baseUrlRaw!);
    const createInvoiceUrl = buildKowriUrl(normalizedBaseUrl, "/webpos/createInvoice");
    const processPaymentUrl = buildKowriUrl(normalizedBaseUrl, "/webpos/processPayment");
    const payNowUrl = buildKowriUrl(normalizedBaseUrl, "/webpos/payNow");
    const webhookUrl = buildWebhookUrl(supabaseUrl);

    const basePayNowBody: Record<string, unknown> = {
      requestId: crypto.randomUUID(),
      appReference: appRef,
      secret: appSecret,
      amount: paymentAmount,
      currency: "GHS",
      customerName,
      customerSegment: "General",
      reference: merchantOrderId,
      transactionId: newTxnId(),
      provider: defaultProvider,
      walletRef: msisdn,
      customerMobile: msisdn,
      metadata: [
        { key: "webhookUrl", value: webhookUrl },
        { key: "orderId", value: merchantOrderId },
      ],
    };
    if (serviceCode) basePayNowBody.serviceCode = serviceCode;

    // Primary route: payNow with trustedNum explicitly set to the mobile number.
    const trustedPayNowBody: Record<string, unknown> = {
      ...basePayNowBody,
      trustedNum: msisdn,
    };

    const trustedPayNowCall = await callKowri(payNowUrl, appId!, trustedPayNowBody);
    if (trustedPayNowCall.response.ok && trustedPayNowCall.data?.success) {
      return new Response(
        JSON.stringify({
          success: true,
          message: `Payment request initiated for GHS ${paymentAmount}.`,
          merchantOrderId,
          amount: paymentAmount,
          flow: "paynow-trusted-primary",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const trustedPayNowErr = getKowriErrorMessage(
      trustedPayNowCall,
      "Unknown trusted payNow error",
    );

    // Fallback 1: createInvoice + processPayment (still passes trustedNum).
    const createInvoiceBody: Record<string, unknown> = {
      requestId: crypto.randomUUID(),
      appReference: appRef,
      secret: appSecret,
      merchantOrderId,
      currency: "GHS",
      amount: paymentAmount,
      reference: msisdn,
      trustedNum: msisdn,
      metadata: [
        { key: "webhookUrl", value: webhookUrl },
        { key: "orderId", value: merchantOrderId },
      ],
    };
    if (serviceCode) createInvoiceBody.serviceCode = serviceCode;

    const invoiceCall = await callKowri(createInvoiceUrl, appId!, createInvoiceBody);
    if (invoiceCall.response.ok && invoiceCall.data?.success) {
      const invoiceNum = invoiceCall.data?.result?.invoiceNum;
      if (invoiceNum) {
        const processPaymentBody: Record<string, unknown> = {
          requestId: crypto.randomUUID(),
          appReference: appRef,
          secret: appSecret,
          invoiceNum,
          transactionId: newTxnId(),
          provider: defaultProvider,
          walletRef: msisdn,
          customerName,
          customerMobile: msisdn,
        };
        if (serviceCode) processPaymentBody.serviceCode = serviceCode;

        const processCall = await callKowri(processPaymentUrl, appId!, processPaymentBody);
        if (processCall.response.ok && processCall.data?.success) {
          return new Response(
            JSON.stringify({
              success: true,
              message: `Payment request initiated for GHS ${paymentAmount}.`,
              merchantOrderId,
              invoiceNum,
              amount: paymentAmount,
              flow: "invoice-process-fallback",
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
      }
    }

    const invoiceErr = getKowriErrorMessage(invoiceCall, "Unknown create invoice error");

    throw new Error(
      `Payment initiation failed. Primary push: ${trustedPayNowErr} (Status: ${trustedPayNowCall.response.status}); Secondary fallback: ${invoiceErr} (Status: ${invoiceCall.response.status})`,
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Function Error Caught:", message);
    return new Response(
      JSON.stringify({ error: message, timestamp: new Date().toISOString() }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
