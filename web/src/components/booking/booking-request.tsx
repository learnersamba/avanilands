"use client";

import { CheckCircle2, Loader2, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { type FormEvent, useRef, useState } from "react";

import { useAccount } from "@/components/account/account-provider";
import { normalizeIndianMobile } from "@/lib/enquiry";
import { formatRupees } from "@/lib/format";
import { mediaUrl } from "@/lib/media";
import { browserSupabase } from "@/lib/supabase/browser";

type Property = {
  id: string;
  code: string;
  title: string;
  slug: string;
  price: number | null;
  place: string;
  thumb: string | null;
};

const steps = [
  "Our team calls you to go over the price and answer questions.",
  "Our management approves the booking — the land is then reserved for you.",
  "You pay the booking amount; we call you from our official number with how to pay.",
  "We prepare the documents, and the sale is registered.",
];

/** Signed-in customers ask to book a property; the team takes it from there. */
export function BookingRequest({ property }: { property: Property }) {
  const { ready, user, profile, reload } = useAccount();
  const key = useRef<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<{
    reference: string;
    again: boolean;
  } | null>(null);
  const needsProfile = !profile?.full_name || !profile?.phone;

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const supabase = browserSupabase();
    setError(null);
    if (needsProfile) {
      const name = String(form.get("name") ?? "").trim();
      const phone = normalizeIndianMobile(String(form.get("phone") ?? ""));
      if (name.length < 2) return setError("Please enter your name.");
      if (!phone) return setError("Enter a 10-digit Indian mobile number.");
      setBusy(true);
      const { error: profileError } = await supabase
        .from("customer_profiles")
        .upsert({ full_name: name, phone }, { onConflict: "user_id" });
      if (profileError) {
        setBusy(false);
        return setError("We couldn't save your details. Please try again.");
      }
      await reload();
    }
    setBusy(true);
    key.current ??= crypto.randomUUID();
    try {
      const { data, error: requestError } = await supabase.rpc(
        "request_booking",
        {
          p_property_id: property.id,
          p_message: String(form.get("message") ?? "").trim() || null,
          p_idempotency_key: key.current,
        },
      );
      if (requestError) {
        const message = requestError.message;
        setError(
          message.includes("property_unavailable")
            ? `Sorry — ${property.code} was just reserved or sold. Ask us about similar land.`
            : message.includes("rate_limited")
              ? "You've sent several booking requests today. Our team will call you; or call us now."
              : message.includes("profile_incomplete")
                ? "Please add your name and mobile number first."
                : "Something went wrong on our side. Please try again, or call us.",
        );
        return;
      }
      const result = data as { reference: string; already_requested?: boolean };
      setDone({
        reference: result.reference,
        again: result.already_requested === true,
      });
    } catch {
      setError(
        "We couldn't reach our server. Check your connection and press the button again.",
      );
    } finally {
      setBusy(false);
    }
  };

  const field =
    "mt-1 w-full rounded-lg border border-line bg-white px-3 py-2.5 text-sm focus:border-forest focus:outline-none";

  return (
    <div>
      <p className="text-sm text-muted">
        <Link href={`/land/${property.slug}`} className="hover:text-forest">
          ← Back to {property.code}
        </Link>
      </p>
      <h1 className="mt-2 font-serif text-3xl text-forest sm:text-4xl">
        Request to book
      </h1>

      <div className="mt-6 flex gap-4 rounded-2xl bg-white p-4 shadow-sm ring-1 ring-line">
        {property.thumb ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={mediaUrl(property.thumb)}
            alt=""
            width={160}
            height={120}
            className="h-24 w-32 rounded-lg object-cover"
          />
        ) : null}
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-muted">
            {property.code}
          </p>
          <p className="font-serif text-xl text-ink">{property.title}</p>
          <p className="text-sm text-ink/70">{property.place}</p>
          <p className="mt-1 font-semibold text-forest">
            {property.price ? formatRupees(property.price) : "Price on request"}
          </p>
        </div>
      </div>

      <div className="mt-8 grid gap-8 md:grid-cols-[1fr_280px]">
        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-line">
          {!ready ? (
            <p className="text-sm text-muted">Loading…</p>
          ) : !user ? (
            <div>
              <p className="font-semibold">
                Please sign in to request a booking.
              </p>
              <p className="mt-1 text-sm text-ink/70">
                It takes a minute with a code sent to your email, and lets you
                follow the booking in My account.
              </p>
              <Link
                href={`/account/sign-in?next=${encodeURIComponent(`/book/${property.code}`)}`}
                className="mt-4 inline-flex rounded-lg bg-forest px-5 py-3 text-sm font-semibold text-white hover:bg-forest-dark"
              >
                Sign in to continue
              </Link>
            </div>
          ) : done ? (
            <div role="status">
              <CheckCircle2 className="h-8 w-8 text-available" aria-hidden />
              <p className="mt-3 font-serif text-xl text-forest">
                {done.again
                  ? "You've already asked to book this property"
                  : "Booking request sent"}
              </p>
              <p className="mt-1 text-sm">
                Reference <strong>{done.reference}</strong>. Our team will call
                you soon. You can follow it in{" "}
                <Link
                  href="/account"
                  className="font-semibold text-forest underline"
                >
                  My account
                </Link>
                .
              </p>
            </div>
          ) : (
            <form onSubmit={onSubmit} noValidate className="space-y-3">
              {error && (
                <p
                  role="alert"
                  className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800"
                >
                  {error}
                </p>
              )}
              {needsProfile && (
                <>
                  <label className="block text-sm font-medium">
                    Your name
                    <input
                      name="name"
                      autoComplete="name"
                      maxLength={80}
                      defaultValue={profile?.full_name ?? ""}
                      className={field}
                    />
                  </label>
                  <label className="block text-sm font-medium">
                    Mobile number
                    <input
                      name="phone"
                      type="tel"
                      inputMode="tel"
                      autoComplete="tel-national"
                      defaultValue={profile?.phone ?? ""}
                      className={field}
                    />
                  </label>
                </>
              )}
              {!needsProfile && (
                <p className="text-sm text-ink/80">
                  We&apos;ll call <strong>{profile?.full_name}</strong> on{" "}
                  <strong>+91 {profile?.phone}</strong>.{" "}
                  <Link href="/account" className="text-forest underline">
                    Change
                  </Link>
                </p>
              )}
              <label className="block text-sm font-medium">
                Anything we should know?{" "}
                <span className="font-normal text-muted">(optional)</span>
                <textarea
                  name="message"
                  rows={3}
                  maxLength={1000}
                  placeholder="e.g. I visited last Saturday; I'll pay through a home loan"
                  className={field}
                />
              </label>
              <button
                type="submit"
                disabled={busy}
                className="flex w-full items-center justify-center gap-2 rounded-lg bg-forest px-4 py-3 text-sm font-semibold text-white hover:bg-forest-dark disabled:opacity-70"
              >
                {busy && (
                  <Loader2 className="h-4 w-4 animate-spin" aria-hidden />
                )}
                Request to book {property.code}
              </button>
              <p className="text-xs text-muted">
                No payment now. This is a request; nothing is final until our
                team approves it.
              </p>
            </form>
          )}
        </div>

        <aside className="space-y-4 text-sm">
          <div>
            <h2 className="font-semibold text-ink">What happens next</h2>
            <ol className="mt-2 list-decimal space-y-2 pl-5 text-ink/80">
              {steps.map((step) => (
                <li key={step}>{step}</li>
              ))}
            </ol>
          </div>
          <p className="flex gap-2 rounded-xl bg-sand-light p-3 text-ink/80">
            <ShieldCheck className="h-5 w-5 shrink-0 text-forest" aria-hidden />
            We never send payment details by email or SMS, or ask you to pay
            into a personal account.
          </p>
        </aside>
      </div>
    </div>
  );
}
