"use client";

import { Loader2 } from "lucide-react";
import { useRouter, useSearchParams } from "next/navigation";
import { type FormEvent, useEffect, useState } from "react";

import { useAccount } from "@/components/account/account-provider";
import { safeNext } from "@/lib/account/paths";
import { browserSupabase } from "@/lib/supabase/browser";

const emailPattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** Email → 6-digit code → signed in. New emails get an account automatically. */
export function SignInForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));
  const saveId = params.get("save");
  const { ready, user, reload } = useAccount();
  const [step, setStep] = useState<"email" | "code">("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resendAt, setResendAt] = useState(0);
  const [now, setNow] = useState(0); // set when a code is sent (not while rendering)

  // Already signed in (e.g. pressed Back): carry on.
  useEffect(() => {
    if (ready && user && step === "email") router.replace(next);
  }, [ready, user, step, next, router]);

  useEffect(() => {
    if (step !== "code") return;
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [step]);

  const sendCode = async () => {
    const address = email.trim().toLowerCase();
    if (!emailPattern.test(address)) {
      setError("Enter a valid email address.");
      return;
    }
    setBusy(true);
    setError(null);
    const { error: sendError } = await browserSupabase().auth.signInWithOtp({
      email: address,
      options: { shouldCreateUser: true },
    });
    setBusy(false);
    if (sendError) {
      setError(
        sendError.status === 429
          ? "Too many codes asked for. Please wait a few minutes and try again."
          : "We couldn't send the code. Check the address and try again.",
      );
      return;
    }
    setEmail(address);
    setCode("");
    setStep("code");
    setResendAt(Date.now() + 60_000);
    setNow(Date.now());
  };

  const verify = async () => {
    const token = code.replace(/\D/g, "");
    if (token.length !== 6) {
      setError("Enter the 6-digit code from the email.");
      return;
    }
    setBusy(true);
    setError(null);
    const supabase = browserSupabase();
    const { error: verifyError } = await supabase.auth.verifyOtp({
      email,
      token,
      type: "email",
    });
    if (verifyError) {
      setBusy(false);
      setError("That code didn't work. Check it, or send a new one.");
      return;
    }
    // Earlier enquiries and visits sent with this email join the account.
    const { data: linked } = await supabase.rpc("link_my_guest_requests");
    if (saveId)
      await supabase.from("saved_properties").insert({ property_id: saveId });
    await reload();
    const target = new URL(next, window.location.origin);
    if (
      typeof linked === "number" &&
      linked > 0 &&
      target.pathname === "/account"
    ) {
      target.searchParams.set("linked", String(linked));
    }
    router.replace(target.pathname + target.search + target.hash);
  };

  const onSubmit = (event: FormEvent) => {
    event.preventDefault();
    void (step === "email" ? sendCode() : verify());
  };

  const field =
    "mt-1 w-full rounded-lg border border-line bg-white px-3 py-2.5 text-sm focus:border-forest focus:outline-none";
  const wait = Math.max(0, Math.ceil((resendAt - now) / 1000));

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-4">
      {error && (
        <p
          role="alert"
          className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800"
        >
          {error}
        </p>
      )}
      {step === "email" ? (
        <label className="block text-sm font-medium">
          Email
          <input
            type="email"
            name="email"
            autoComplete="email"
            inputMode="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            className={field}
          />
        </label>
      ) : (
        <>
          <p className="text-sm text-ink/80" role="status">
            We sent a 6-digit code to{" "}
            <strong className="font-semibold">{email}</strong>. It can take a
            minute; check spam too.
          </p>
          <label className="block text-sm font-medium">
            Code
            <input
              name="code"
              autoComplete="one-time-code"
              inputMode="numeric"
              maxLength={6}
              required
              value={code}
              onChange={(event) =>
                setCode(event.target.value.replace(/\D/g, "").slice(0, 6))
              }
              className={`${field} text-center text-2xl tracking-[0.5em]`}
            />
          </label>
        </>
      )}
      <button
        type="submit"
        disabled={busy}
        className="flex w-full items-center justify-center gap-2 rounded-lg bg-forest px-4 py-3 text-sm font-semibold text-white hover:bg-forest-dark disabled:opacity-70"
      >
        {busy && <Loader2 className="h-4 w-4 animate-spin" aria-hidden />}
        {step === "email" ? "Email me a code" : "Sign in"}
      </button>
      {step === "code" && (
        <div className="flex flex-wrap justify-between gap-2 text-sm">
          <button
            type="button"
            className="text-muted underline"
            onClick={() => setStep("email")}
          >
            Use a different email
          </button>
          <button
            type="button"
            className="text-forest underline disabled:text-muted disabled:no-underline"
            disabled={wait > 0 || busy}
            onClick={() => void sendCode()}
          >
            {wait > 0 ? `Send a new code in ${wait}s` : "Send a new code"}
          </button>
        </div>
      )}
    </form>
  );
}
