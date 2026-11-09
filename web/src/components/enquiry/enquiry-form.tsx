"use client";

import { CheckCircle2, Loader2, MessageCircle } from "lucide-react";
import { useActionState, useRef, useState } from "react";

import { submitEnquiry } from "@/app/enquiry-actions";
import { usePrefill } from "@/components/account/use-prefill";
import { Turnstile } from "@/components/enquiry/turnstile";
import { contactMethods, type EnquiryFields, type EnquiryState } from "@/lib/enquiry";

const initial: EnquiryState = { status: "idle" };
const siteKey = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ?? "";

type Props = {
  propertyId?: string;
  propertyCode?: string;
  source: "property_page" | "contact_page";
  defaultMessage?: string;
  whatsappHref?: string | null;
  idPrefix: string;
};

/**
 * Sends the form; if the server can't be reached (no signal, server down),
 * keeps what was typed and says so instead of failing the whole page.
 * Sending again is safe: the same double-submit key goes with it.
 */
async function sendOrExplain(previous: EnquiryState, form: FormData): Promise<EnquiryState> {
  try {
    return await submitEnquiry(previous, form);
  } catch {
    const values: Partial<Record<EnquiryFields, string>> = {};
    for (const name of ["name", "phone", "email", "preferredContact", "message"] as const) {
      values[name] = String(form.get(name) ?? "");
    }
    return {
      status: "error",
      message: "We couldn't send your enquiry — please check your internet connection and press send again. Your details are still here.",
      fieldErrors: {},
      values,
    };
  }
}

/** Enquiry form. A new form (new idempotency key) after each sent enquiry. */
export function EnquiryForm(props: Props) {
  const [round, setRound] = useState(0);
  return <EnquiryFormRound key={round} {...props} onAnother={() => setRound((value) => value + 1)} />;
}

function EnquiryFormRound({
  propertyId,
  propertyCode,
  source,
  defaultMessage,
  whatsappHref,
  idPrefix,
  onAnother,
}: Props & { onAnother: () => void }) {
  const [state, action, pending] = useActionState(sendOrExplain, initial);
  const formRef = useRef<HTMLFormElement>(null);
  usePrefill(formRef);
  // One key per form, made on the first send (not while rendering, which also
  // happens on the server): sending twice can never make two enquiries.
  const idempotencyKey = useRef<string | null>(null);
  const keyInput = useRef<HTMLInputElement>(null);
  const [token, setToken] = useState<string | null>(siteKey ? null : "dev");
  const [tokenWait, setTokenWait] = useState(false);
  // Restarting the bot check (new widget) if it got stuck, e.g. after the
  // connection dropped: it never recovers on its own.
  const [checkAttempt, setCheckAttempt] = useState(0);

  if (state.status === "sent") {
    return (
      <div role="status" className="rounded-xl bg-available/10 p-5 text-ink">
        <CheckCircle2 className="h-8 w-8 text-available" aria-hidden />
        <p className="mt-3 font-serif text-xl text-forest">Thank you — we&apos;ve got your enquiry</p>
        <p className="mt-1 text-sm">
          Your reference is <strong className="font-semibold">{state.reference}</strong>. Our team will contact you
          soon.
        </p>
        {whatsappHref && (
          <a
            href={whatsappHref}
            target="_blank"
            rel="noopener"
            className="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-forest hover:underline"
          >
            <MessageCircle className="h-4 w-4" aria-hidden /> Need a faster reply? WhatsApp us
          </a>
        )}
        <button type="button" onClick={onAnother} className="mt-4 block text-sm text-muted underline">
          Send another enquiry
        </button>
      </div>
    );
  }

  const error = state.status === "error" ? state : null;
  const values = error?.values ?? {};
  const field = "mt-1 w-full rounded-lg border bg-white px-3 py-2.5 text-sm focus:border-forest focus:outline-none";
  const border = (name: keyof NonNullable<typeof error>["fieldErrors"]) =>
    error?.fieldErrors[name] ? "border-red-600" : "border-line";
  const fieldError = (name: keyof NonNullable<typeof error>["fieldErrors"]) =>
    error?.fieldErrors[name] ? (
      <span id={`${idPrefix}-${name}-error`} className="mt-1 block text-xs text-red-700">
        {error.fieldErrors[name]}
      </span>
    ) : null;
  const describedBy = (name: keyof NonNullable<typeof error>["fieldErrors"]) =>
    error?.fieldErrors[name] ? `${idPrefix}-${name}-error` : undefined;

  return (
    <form
      ref={formRef}
      action={action}
      noValidate
      onSubmit={(event) => {
        // Wait for the bot check instead of sending without it.
        if (!token) {
          event.preventDefault();
          if (tokenWait) setCheckAttempt((value) => value + 1);
          setTokenWait(true);
          return;
        }
        idempotencyKey.current ??= crypto.randomUUID();
        keyInput.current!.value = idempotencyKey.current;
      }}
      className="space-y-3"
      aria-describedby={error ? `${idPrefix}-form-error` : undefined}
    >
      <input type="hidden" name="propertyId" value={propertyId ?? ""} />
      <input type="hidden" name="source" value={source} />
      <input ref={keyInput} type="hidden" name="idempotencyKey" defaultValue="" />

      {error && (
        <p id={`${idPrefix}-form-error`} role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
          {error.message}
        </p>
      )}

      <label className="block text-sm font-medium">
        Your name
        <input
          name="name"
          autoComplete="name"
          required
          maxLength={80}
          defaultValue={values.name}
          aria-invalid={Boolean(error?.fieldErrors.name)}
          aria-describedby={describedBy("name")}
          className={`${field} ${border("name")}`}
        />
        {fieldError("name")}
      </label>
      <label className="block text-sm font-medium">
        Mobile number
        <input
          name="phone"
          type="tel"
          inputMode="tel"
          autoComplete="tel-national"
          required
          placeholder="10-digit mobile"
          defaultValue={values.phone}
          aria-invalid={Boolean(error?.fieldErrors.phone)}
          aria-describedby={describedBy("phone")}
          className={`${field} ${border("phone")}`}
        />
        {fieldError("phone")}
      </label>
      <label className="block text-sm font-medium">
        Email <span className="font-normal text-muted">(optional)</span>
        <input
          name="email"
          type="email"
          autoComplete="email"
          maxLength={254}
          defaultValue={values.email}
          aria-invalid={Boolean(error?.fieldErrors.email)}
          aria-describedby={describedBy("email")}
          className={`${field} ${border("email")}`}
        />
        {fieldError("email")}
      </label>
      <fieldset>
        <legend className="text-sm font-medium">How should we contact you?</legend>
        <div className="mt-1 flex flex-wrap gap-x-4 gap-y-1">
          {Object.entries(contactMethods).map(([value, label]) => (
            <label key={value} className="flex items-center gap-2 py-1 text-sm">
              <input
                type="radio"
                name="preferredContact"
                value={value}
                defaultChecked={(values.preferredContact ?? "phone") === value}
                className="h-4 w-4 accent-forest"
              />
              {label}
            </label>
          ))}
        </div>
      </fieldset>
      <label className="block text-sm font-medium">
        Message <span className="font-normal text-muted">(optional)</span>
        <textarea
          name="message"
          rows={3}
          maxLength={1000}
          defaultValue={values.message ?? defaultMessage}
          aria-invalid={Boolean(error?.fieldErrors.message)}
          className={`${field} ${border("message")}`}
        />
        {fieldError("message")}
      </label>

      {siteKey && (
        <Turnstile
          key={checkAttempt}
          siteKey={siteKey}
          resetSignal={state}
          onToken={(value) => {
            setToken(value);
            if (value) setTokenWait(false);
          }}
        />
      )}

      <button
        type="submit"
        disabled={pending}
        className="flex w-full items-center justify-center gap-2 rounded-lg bg-forest px-4 py-3 text-sm font-semibold text-white hover:bg-forest-dark disabled:opacity-70"
      >
        {pending && <Loader2 className="h-4 w-4 animate-spin" aria-hidden />}
        {pending ? "Sending…" : propertyCode ? `Send enquiry about ${propertyCode}` : "Send enquiry"}
      </button>
      {tokenWait && !token && (
        <p className="text-xs text-muted" role="status">
          Checking you&apos;re not a robot… press send again in a moment.
        </p>
      )}
      <p className="text-xs text-muted">We use your details only to reply to this enquiry.</p>
    </form>
  );
}
