import {
  type BookingEmailData,
  type BookingEvent,
  customerBookingEmail,
  salesBookingEmail,
} from "@/lib/booking-emails";
import { getSiteSettings } from "@/lib/data";
import { sendEmail } from "@/lib/email";
import { env } from "@/lib/env";
import { secretMatches } from "@/lib/secret";
import { serverEnv } from "@/lib/server-env";
import { createAdminClient } from "@/lib/supabase/admin";

const events: BookingEvent[] = [
  "requested",
  "pending_approval",
  "approved",
  "payment_pending",
  "reserved",
  "completed",
  "cancelled",
];

/**
 * Called by the database (private.notify_booking_change) at every booking
 * step: emails sales about new website requests and the customer at each step.
 * Body: {"id": "<booking id>", "event": "approved"}; header x-revalidate-secret.
 */
export async function POST(request: Request) {
  if (
    !secretMatches(
      request.headers.get("x-revalidate-secret"),
      serverEnv().REVALIDATE_SECRET,
    )
  ) {
    return Response.json({ error: "Not allowed" }, { status: 401 });
  }
  let body: { id?: unknown; event?: unknown };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return Response.json({ error: "Expected JSON" }, { status: 400 });
  }
  const event = events.find((name) => name === body.event);
  if (
    !event ||
    typeof body.id !== "string" ||
    !/^[0-9a-f-]{36}$/i.test(body.id)
  ) {
    return Response.json({ error: "Expected id and event" }, { status: 400 });
  }

  const admin = createAdminClient();
  const [{ data: booking }, { data: notify }, settings] = await Promise.all([
    admin
      .from("bookings")
      .select(
        "reference, name, phone, email, message, source, agreed_price, booking_amount, amount_received, received_on, cancelled_reason, property:properties(code, title, slug)",
      )
      .eq("id", body.id)
      .maybeSingle(),
    admin
      .from("site_settings")
      .select("sales_notify_emails")
      .eq("id", 1)
      .single(),
    getSiteSettings(),
  ]);
  if (!booking)
    return Response.json({ error: "Unknown booking" }, { status: 404 });
  const b = booking as unknown as {
    reference: string;
    name: string;
    phone: string;
    email: string | null;
    message: string | null;
    source: string;
    agreed_price: number | null;
    booking_amount: number | null;
    amount_received: number | null;
    received_on: string | null;
    cancelled_reason: string | null;
    property: { code: string; title: string; slug: string | null };
  };
  const data: BookingEmailData = {
    reference: b.reference,
    name: b.name,
    phone: b.phone,
    email: b.email,
    message: b.message,
    agreedPrice: b.agreed_price,
    bookingAmount: b.booking_amount,
    amountReceived: b.amount_received,
    receivedOn: b.received_on,
    cancelledReason: b.cancelled_reason,
    property: {
      code: b.property.code,
      title: b.property.title,
      url: `${env.siteUrl}/land/${b.property.slug ?? ""}`,
    },
    companyName: settings.company_name,
    companyPhone: settings.phone,
    adminUrl: process.env.ADMIN_URL ?? null,
  };

  const sent: string[] = [];
  if (event === "requested" && b.source === "website") {
    const salesTo = (notify?.sales_notify_emails as string[] | undefined)
      ?.length
      ? (notify!.sales_notify_emails as string[])
      : [process.env.SALES_NOTIFY_EMAIL].filter((value): value is string =>
          Boolean(value),
        );
    if (await sendEmail(salesTo, salesBookingEmail(data), b.email))
      sent.push("sales");
  }
  // Bookings the team starts get no "we received your request" email.
  const customerEmail =
    event === "requested" && b.source !== "website"
      ? null
      : customerBookingEmail(data, event);
  if (
    customerEmail &&
    b.email &&
    (await sendEmail([b.email], customerEmail, settings.email))
  )
    sent.push("customer");
  return Response.json({ sent });
}
