"use client";

import { CalendarCheck2, Loader2, MessageCircle } from "lucide-react";
import { useActionState, useRef, useState, useSyncExternalStore } from "react";

import { submitSiteVisit } from "@/app/site-visit-actions";
import { usePrefill } from "@/components/account/use-prefill";
import { Turnstile } from "@/components/enquiry/turnstile";
import {
  availableVisitDates,
  formatSlot,
  formatVisitDate,
  type SiteVisitFields,
  type SiteVisitState,
  todayInIndia,
  type VisitSettings,
} from "@/lib/site-visit";

const initial: SiteVisitState = { status: "idle" };
const siteKey = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ?? "";

type Props = {
  propertyId: string;
  propertyCode: string;
  settings: VisitSettings;
  whatsappHref?: string | null;
  idPrefix: string;
};

/** If the server can't be reached, keep what was typed and say so. */
async function sendOrExplain(previous: SiteVisitState, form: FormData): Promise<SiteVisitState> {
  try {
    return await submitSiteVisit(previous, form);
  } catch {
    const values: Partial<Record<SiteVisitFields, string>> = {};
    for (const name of ["name", "phone", "email", "visitDate", "slot", "visitors", "message"] as const) {
      values[name] = String(form.get(name) ?? "");
    }
    return {
      status: "error",
      message: "We couldn't send your request — please check your internet connection and press send again. Your details are still here.",
      fieldErrors: {},
      values,
    };
  }
}

// "Today" is only known in the browser (the page itself is cached), so the
// list of days appears once the page is running.
const noSubscribe = () => () => {};
const useToday = () => useSyncExternalStore(noSubscribe, () => todayInIndia(), () => null);

/** Site visit booking. A new form (new idempotency key) after each request. */
export function SiteVisitForm(props: Props) {
  const [round, setRound] = useState(0);
  return <SiteVisitFormRound key={round} {...props} onAnother={() => setRound((value) => value + 1)} />;
}

function SiteVisitFormRound({ propertyId, propertyCode, settings, whatsappHref, idPrefix, onAnother }: Props & { onAnother: () => void }) {
  const [state, action, pending] = useActionState(sendOrExplain, initial);
  const formRef = useRef<HTMLFormElement>(null);
  usePrefill(formRef);
  const idempotencyKey = useRef<string | null>(null);
  const keyInput = useRef<HTMLInputElement>(null);
  const [token, setToken] = useState<string | null>(siteKey ? null : "dev");
  const [tokenWait, setTokenWait] = useState(false);
  const [checkAttempt, setCheckAttempt] = useState(0);
  const today = useToday();
  const dates = today ? availableVisitDates(settings, today) : [];

  if (state.status === "sent") {
    return (
      <div role="status" className="rounded-xl bg-available/10 p-5 text-ink">
        <CalendarCheck2 className="h-8 w-8 text-available" aria-hidden />
        <p className="mt-3 font-serif text-xl text-forest">
          {state.alreadyBooked ? "You already have a visit request" : "Visit requested — we'll call to confirm"}
        </p>
        <p className="mt-1 text-sm">
          {formatVisitDate(state.visitDate, true)}, {formatSlot(state.slot)} · reference{" "}
          <strong className="font-semibold">{state.reference}</strong>.
          {state.alreadyBooked
            ? " Our team will contact you about it. To change the time, call or WhatsApp us."
            : " The visit is confirmed once our team calls you."}
        </p>
        {whatsappHref && (
          <a
            href={whatsappHref}
            target="_blank"
            rel="noopener"
            className="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-forest hover:underline"
          >
            <MessageCircle className="h-4 w-4" aria-hidden /> Questions? WhatsApp us
          </a>
        )}
        <button type="button" onClick={onAnother} className="mt-4 block text-sm text-muted underline">
          Book another visit
        </button>
      </div>
    );
  }

  const error = state.status === "error" ? state : null;
  const values = error?.values ?? {};
  const field = "mt-1 w-full rounded-lg border bg-white px-3 py-2.5 text-sm focus:border-forest focus:outline-none";
  const border = (name: SiteVisitFields) => (error?.fieldErrors[name] ? "border-red-600" : "border-line");
  const errorId = (name: SiteVisitFields) => `${idPrefix}-${name}-error`;
  const fieldError = (name: SiteVisitFields) =>
    error?.fieldErrors[name] ? (
      <span id={errorId(name)} className="mt-1 block text-xs text-red-700">
        {error.fieldErrors[name]}
      </span>
    ) : null;
  const describedBy = (name: SiteVisitFields) => (error?.fieldErrors[name] ? errorId(name) : undefined);

  return (
    <form
      ref={formRef}
      action={action}
      noValidate
      onSubmit={(event) => {
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
    >
      <input type="hidden" name="propertyId" value={propertyId} />
      <input ref={keyInput} type="hidden" name="idempotencyKey" defaultValue="" />

      {error && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
          {error.message}
        </p>
      )}

      <label className="block text-sm font-medium">
        Day
        <select
          name="visitDate"
          required
          defaultValue={values.visitDate ?? ""}
          disabled={!today}
          aria-invalid={Boolean(error?.fieldErrors.visitDate)}
          aria-describedby={describedBy("visitDate")}
          className={`${field} ${border("visitDate")}`}
        >
          <option value="" disabled>
            {today ? (dates.length ? "Choose a day" : "No days available — please call us") : "Loading days…"}
          </option>
          {dates.map((date) => (
            <option key={date} value={date}>
              {formatVisitDate(date)}
            </option>
          ))}
        </select>
        {fieldError("visitDate")}
      </label>

      <fieldset aria-describedby={describedBy("slot")}>
        <legend className="text-sm font-medium">Time</legend>
        <div className="mt-1 flex flex-wrap gap-2">
          {settings.visit_slots.map((slot) => (
            <label
              key={slot}
              className="flex cursor-pointer items-center gap-2 rounded-lg border border-line px-3 py-2 text-sm has-[:checked]:border-forest has-[:checked]:bg-forest/5"
            >
              <input
                type="radio"
                name="slot"
                value={slot}
                defaultChecked={values.slot === slot}
                className="h-4 w-4 accent-forest"
              />
              {formatSlot(slot)}
            </label>
          ))}
        </div>
        {fieldError("slot")}
      </fieldset>

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
      <div className="grid grid-cols-[1fr_6rem] gap-3">
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
          People
          <input
            name="visitors"
            type="number"
            inputMode="numeric"
            min={1}
            max={20}
            defaultValue={values.visitors ?? "1"}
            aria-invalid={Boolean(error?.fieldErrors.visitors)}
            aria-describedby={describedBy("visitors")}
            className={`${field} ${border("visitors")}`}
          />
          {fieldError("visitors")}
        </label>
      </div>
      <label className="block text-sm font-medium">
        Email <span className="font-normal text-muted">(optional, for the confirmation)</span>
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
      <label className="block text-sm font-medium">
        Message <span className="font-normal text-muted">(optional)</span>
        <textarea
          name="message"
          rows={2}
          maxLength={1000}
          defaultValue={values.message}
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
        disabled={pending || !today || dates.length === 0}
        className="flex w-full items-center justify-center gap-2 rounded-lg bg-forest px-4 py-3 text-sm font-semibold text-white hover:bg-forest-dark disabled:opacity-70"
      >
        {pending && <Loader2 className="h-4 w-4 animate-spin" aria-hidden />}
        {pending ? "Sending…" : `Request a visit to ${propertyCode}`}
      </button>
      {tokenWait && !token && (
        <p className="text-xs text-muted" role="status">
          Checking you&apos;re not a robot… press send again in a moment.
        </p>
      )}
      <p className="text-xs text-muted">Free, no obligation. Our team calls to confirm the time and meeting point.</p>
    </form>
  );
}
