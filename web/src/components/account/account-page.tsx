"use client";

import {
  Bell,
  CalendarDays,
  Heart,
  History,
  KeyRound,
  Loader2,
  LogOut,
  Mail,
  Scale,
  Trash2,
} from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  type FormEvent,
  useRef,
  type ReactNode,
  useEffect,
  useState,
  useSyncExternalStore,
} from "react";

import { deleteMyAccount } from "@/app/account-actions";
import { useAccount } from "@/components/account/account-provider";
import { PropertyCard } from "@/components/property-card";
import { readRecent } from "@/lib/account/recent";
import { compareHref, maxCompare } from "@/lib/compare";
import {
  bookingStatusLabel,
  enquiryStatusLabel,
  visitStatusLabel,
} from "@/lib/account/status";
import type { PropertyCardData } from "@/lib/data";
import { normalizeIndianMobile } from "@/lib/enquiry";
import { formatRupees } from "@/lib/format";
import { formatSlot, formatVisitDate } from "@/lib/site-visit";
import { browserSupabase } from "@/lib/supabase/browser";

type RequestProperty = {
  code: string;
  title: string;
  slug: string | null;
  availability: string;
} | null;
type MyRequests = {
  enquiries: {
    reference: string;
    created_at: string;
    status: string;
    message: string | null;
    property: RequestProperty;
  }[];
  bookings: {
    reference: string;
    created_at: string;
    status: string;
    agreed_price: number | null;
    booking_amount: number | null;
    amount_received: number | null;
    property: RequestProperty;
  }[];
  site_visits: {
    reference: string;
    created_at: string;
    status: string;
    visit_date: string;
    slot: string;
    visitors: number;
    property: RequestProperty;
  }[];
};

const noSubscribe = () => () => {};
/** "?linked=2" after sign-in: how many earlier requests joined the account. */
const useLinked = () =>
  useSyncExternalStore(
    noSubscribe,
    () =>
      Number(new URLSearchParams(window.location.search).get("linked") ?? 0),
    () => 0,
  );

async function loadCards(ids: string[]): Promise<PropertyCardData[]> {
  if (ids.length === 0) return [];
  const { data } = await browserSupabase()
    .from("public_properties")
    .select("*")
    .in("id", ids);
  const byId = new Map(
    (data as PropertyCardData[] | null)?.map((p) => [p.id, p]) ?? [],
  );
  return ids
    .map((id) => byId.get(id))
    .filter((p): p is PropertyCardData => Boolean(p));
}

/** "My account": profile, saved land, enquiries and visits, recently viewed. */
export function AccountPage() {
  const router = useRouter();
  const { ready, user, saved, signOut } = useAccount();
  const linked = useLinked();
  const leaving = useRef(false);
  // Bumped to load the requests again (e.g. after withdrawing a booking).
  const [version, setVersion] = useState(0);
  const [requests, setRequests] = useState<MyRequests | null>(null);
  const [savedCards, setSavedCards] = useState<PropertyCardData[] | null>(null);
  const [recentCards, setRecentCards] = useState<PropertyCardData[]>([]);

  useEffect(() => {
    // Not when signing out or deleting on purpose: they go to the home page.
    if (ready && !user && !leaving.current)
      router.replace("/account/sign-in?next=/account");
  }, [ready, user, router]);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    void (async () => {
      const { data } = await browserSupabase().rpc("my_requests");
      if (!cancelled)
        setRequests(
          (data as MyRequests | null) ?? {
            enquiries: [],
            site_visits: [],
            bookings: [],
          },
        );
    })();
    void loadCards(readRecent()).then(
      (cards) => !cancelled && setRecentCards(cards),
    );
    return () => {
      cancelled = true;
    };
  }, [user, version]);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    void loadCards([...saved]).then(
      (cards) => !cancelled && setSavedCards(cards),
    );
    return () => {
      cancelled = true;
    };
  }, [user, saved]);

  if (!ready || !user) {
    return (
      <p className="py-20 text-center text-muted">Loading your account…</p>
    );
  }

  return (
    <div className="space-y-10">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-serif text-3xl text-forest sm:text-4xl">
            My account
          </h1>
          <p className="mt-1 text-ink/70">{user.email}</p>
        </div>
        <button
          type="button"
          onClick={async () => {
            leaving.current = true;
            await signOut();
            router.replace("/");
          }}
          className="inline-flex items-center gap-2 rounded-lg border border-forest/30 px-4 py-2.5 text-sm font-semibold text-forest hover:bg-forest/5"
        >
          <LogOut className="h-4 w-4" aria-hidden /> Sign out
        </button>
      </div>

      {linked > 0 && (
        <p
          role="status"
          className="rounded-xl bg-available/10 px-4 py-3 text-sm text-ink"
        >
          Welcome! We found {linked} earlier{" "}
          {linked === 1 ? "request" : "requests"} you sent with this email and
          added {linked === 1 ? "it" : "them"} below.
        </p>
      )}

      <div className="grid gap-8 lg:grid-cols-[1fr_360px]">
        <div className="space-y-8">
          <UpdatesSection />

          {requests && requests.bookings.length > 0 && (
            <Section icon={<KeyRound />} title="Bookings">
              <ul className="divide-y divide-line">
                {requests.bookings.map((booking) => (
                  <BookingRow
                    key={booking.reference}
                    booking={booking}
                    onChanged={() => setVersion((value) => value + 1)}
                  />
                ))}
              </ul>
            </Section>
          )}

          <Section icon={<CalendarDays />} title="Site visits">
            {requests === null ? (
              <Loading />
            ) : requests.site_visits.length === 0 ? (
              <Empty>
                No site visits yet. Book one from any property page.
              </Empty>
            ) : (
              <ul className="divide-y divide-line">
                {requests.site_visits.map((visit) => (
                  <li
                    key={visit.reference}
                    className="flex flex-wrap items-start justify-between gap-3 py-3"
                  >
                    <div>
                      <p className="font-semibold">
                        {formatVisitDate(visit.visit_date, true)},{" "}
                        {formatSlot(visit.slot)}
                      </p>
                      <PropertyLine property={visit.property} />
                      <p className="text-xs text-muted">
                        {visit.reference} · {visit.visitors}{" "}
                        {visit.visitors === 1 ? "person" : "people"}
                      </p>
                    </div>
                    <StatusPill {...visitStatusLabel(visit.status)} />
                  </li>
                ))}
              </ul>
            )}
          </Section>

          <Section icon={<Mail />} title="Enquiries">
            {requests === null ? (
              <Loading />
            ) : requests.enquiries.length === 0 ? (
              <Empty>No enquiries yet.</Empty>
            ) : (
              <ul className="divide-y divide-line">
                {requests.enquiries.map((enquiry) => (
                  <li
                    key={enquiry.reference}
                    className="flex flex-wrap items-start justify-between gap-3 py-3"
                  >
                    <div className="min-w-0">
                      {enquiry.property ? (
                        <PropertyLine property={enquiry.property} strong />
                      ) : (
                        <p className="font-semibold">General enquiry</p>
                      )}
                      {enquiry.message && (
                        <p className="mt-1 line-clamp-2 text-sm text-ink/70">
                          “{enquiry.message}”
                        </p>
                      )}
                      <p className="text-xs text-muted">
                        {enquiry.reference} ·{" "}
                        {new Intl.DateTimeFormat("en-IN", {
                          day: "numeric",
                          month: "short",
                          year: "numeric",
                        }).format(new Date(enquiry.created_at))}
                      </p>
                    </div>
                    <StatusPill {...enquiryStatusLabel(enquiry.status)} />
                  </li>
                ))}
              </ul>
            )}
          </Section>
        </div>

        <ProfileCard />
      </div>

      <Section icon={<Heart />} title="Saved land">
        {savedCards === null ? (
          <Loading />
        ) : savedCards.length === 0 ? (
          <Empty>Tap the heart on any property to save it here.</Empty>
        ) : (
          <>
            {savedCards.length >= 2 && (
              <Link
                href={compareHref(
                  savedCards.slice(0, maxCompare).map((p) => p.code),
                )}
                className="mb-4 inline-flex items-center gap-2 text-sm font-semibold text-forest underline"
              >
                <Scale className="h-4 w-4" aria-hidden />
                {savedCards.length > maxCompare
                  ? `Compare the first ${maxCompare} saved`
                  : "Compare these side by side"}
              </Link>
            )}
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {savedCards.map((property) => (
                <PropertyCard key={property.id} property={property} />
              ))}
            </div>
          </>
        )}
      </Section>

      {recentCards.length > 0 && (
        <Section
          icon={<History />}
          title="Recently viewed"
          note="Kept on this device only."
        >
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {recentCards.slice(0, 6).map((property) => (
              <PropertyCard key={property.id} property={property} />
            ))}
          </div>
        </Section>
      )}

      <DeleteAccount
        onLeave={() => {
          leaving.current = true;
        }}
      />
    </div>
  );
}

function Section({
  icon,
  title,
  note,
  children,
}: {
  icon: ReactNode;
  title: string;
  note?: string;
  children: ReactNode;
}) {
  return (
    <section
      aria-labelledby={`section-${title}`}
      className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-line"
    >
      <h2
        id={`section-${title}`}
        className="flex items-center gap-2 font-serif text-2xl text-forest [&_svg]:h-5 [&_svg]:w-5 [&_svg]:text-sand"
      >
        {icon} {title}
      </h2>
      {note && <p className="mt-1 text-xs text-muted">{note}</p>}
      <div className="mt-4">{children}</div>
    </section>
  );
}

const Loading = () => <p className="text-sm text-muted">Loading…</p>;
const Empty = ({ children }: { children: ReactNode }) => (
  <p className="text-sm text-muted">{children}</p>
);

function PropertyLine({
  property,
  strong = false,
}: {
  property: RequestProperty;
  strong?: boolean;
}) {
  if (!property) return null;
  const text = `${property.title} (${property.code})`;
  return (
    <p className={strong ? "font-semibold" : "text-sm text-ink/80"}>
      {property.slug ? (
        <Link
          href={`/land/${property.slug}`}
          className="hover:text-forest hover:underline"
        >
          {text}
        </Link>
      ) : (
        text
      )}
    </p>
  );
}

function StatusPill({
  label,
  tone,
}: {
  label: string;
  tone: "waiting" | "active" | "done" | "closed";
}) {
  const colours = {
    waiting: "bg-reserved/10 text-reserved",
    active: "bg-forest/10 text-forest",
    done: "bg-available/10 text-available",
    closed: "bg-sold/10 text-sold",
  };
  return (
    <span
      className={`shrink-0 rounded-full px-3 py-1 text-xs font-semibold ${colours[tone]}`}
    >
      {label}
    </span>
  );
}

function ProfileCard() {
  const { profile, reload } = useAccount();
  const [state, setState] = useState<"idle" | "saving" | "saved">("idle");
  const [error, setError] = useState<string | null>(null);

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const name = String(form.get("name") ?? "").trim();
    const phoneInput = String(form.get("phone") ?? "").trim();
    const phone = phoneInput ? normalizeIndianMobile(phoneInput) : null;
    if (name && (name.length < 2 || name.length > 80))
      return setError("Enter your name (2–80 characters).");
    if (phoneInput && !phone)
      return setError("Enter a 10-digit Indian mobile number.");
    setError(null);
    setState("saving");
    const { error: saveError } = await browserSupabase()
      .from("customer_profiles")
      // The account id comes from the session: customers may change only
      // their name and mobile, never which account a profile belongs to.
      .upsert({ full_name: name || null, phone }, { onConflict: "user_id" });
    if (saveError) {
      setState("idle");
      return setError("We couldn't save your details. Please try again.");
    }
    await reload();
    setState("saved");
  };

  const field =
    "mt-1 w-full rounded-lg border border-line bg-white px-3 py-2.5 text-sm focus:border-forest focus:outline-none";
  return (
    <section
      aria-labelledby="profile-title"
      className="h-fit rounded-2xl bg-white p-6 shadow-sm ring-1 ring-line"
    >
      <h2 id="profile-title" className="font-serif text-2xl text-forest">
        Your details
      </h2>
      <p className="mt-1 text-sm text-muted">
        Filled in for you on enquiry and visit forms.
      </p>
      {/* Keyed so the boxes show the saved values once they load. */}
      <form
        key={`${profile?.full_name}-${profile?.phone}`}
        onSubmit={onSubmit}
        noValidate
        className="mt-4 space-y-3"
      >
        {error && (
          <p
            role="alert"
            className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800"
          >
            {error}
          </p>
        )}
        <label className="block text-sm font-medium">
          Name
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
        <button
          type="submit"
          disabled={state === "saving"}
          className="flex w-full items-center justify-center gap-2 rounded-lg bg-forest px-4 py-2.5 text-sm font-semibold text-white hover:bg-forest-dark disabled:opacity-70"
        >
          {state === "saving" && (
            <Loader2 className="h-4 w-4 animate-spin" aria-hidden />
          )}
          {state === "saved" ? "Saved ✓" : "Save details"}
        </button>
      </form>
      <EmailUpdatesSwitch />
    </section>
  );
}

/** "Email me when saved land changes" — saved straight away. */
function EmailUpdatesSwitch() {
  const { profile, reload } = useAccount();
  // Shown switched at once; the saved value takes over after loading.
  const [pending, setPending] = useState<boolean | null>(null);
  const on = pending ?? profile?.email_updates ?? true;
  return (
    <label className="mt-5 flex items-start gap-3 border-t border-line pt-4 text-sm">
      <input
        type="checkbox"
        checked={on}
        disabled={pending !== null}
        onChange={async (event) => {
          const next = event.target.checked;
          setPending(next);
          await browserSupabase()
            .from("customer_profiles")
            .upsert({ email_updates: next }, { onConflict: "user_id" });
          await reload();
          setPending(null);
        }}
        className="mt-0.5 h-4 w-4 accent-forest"
      />
      <span>
        <span className="font-medium">Email me when saved land changes</span>
        <span className="block text-muted">
          Price changes, reserved, sold or available again. You always see them
          under Updates.
        </span>
      </span>
    </label>
  );
}

type Update = {
  isNew?: boolean;
  id: number;
  kind: string;
  title: string;
  body: string | null;
  link: string | null;
  created_at: string;
  read_at: string | null;
};

/** Latest updates; the new ones are marked, then counted as read. */
function UpdatesSection() {
  const { user, unread, refreshUnread } = useAccount();
  const [updates, setUpdates] = useState<Update[] | null>(null);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    void (async () => {
      const supabase = browserSupabase();
      const { data } = await supabase
        .from("notifications")
        .select("id, kind, title, body, link, created_at, read_at")
        .order("created_at", { ascending: false })
        .limit(30);
      if (cancelled) return;
      const rows = (data ?? []) as Update[];
      // Marked "new" when unread at load; stays marked until the page is left.
      setUpdates((previous) =>
        rows.map((row) => ({
          ...row,
          isNew:
            !row.read_at ||
            Boolean(previous?.find((p) => p.id === row.id)?.isNew),
        })),
      );
      if (rows.some((row) => !row.read_at)) {
        await supabase
          .from("notifications")
          .update({ read_at: new Date().toISOString() })
          .is("read_at", null);
        await refreshUnread();
      }
    })();
    return () => {
      cancelled = true;
    };
    // `unread` going up means something new arrived: load again.
  }, [user, unread, refreshUnread]);

  return (
    <Section icon={<Bell />} title="Updates">
      {updates === null ? (
        <Loading />
      ) : updates.length === 0 ? (
        <Empty>
          Nothing yet. Updates about your enquiries, visits, bookings and saved
          land appear here.
        </Empty>
      ) : (
        <ul className="divide-y divide-line">
          {updates.map((update) => {
            const content = (
              <>
                <span className="flex items-center gap-2 font-semibold">
                  {update.isNew && (
                    <span className="rounded-full bg-red-600 px-2 py-0.5 text-[10px] font-bold uppercase text-white">
                      New
                    </span>
                  )}
                  {update.title}
                </span>
                {update.body && (
                  <span className="mt-0.5 block text-sm text-ink/75">
                    {update.body}
                  </span>
                )}
                <span className="mt-0.5 block text-xs text-muted">
                  {new Intl.DateTimeFormat("en-IN", {
                    day: "numeric",
                    month: "short",
                    hour: "numeric",
                    minute: "2-digit",
                  }).format(new Date(update.created_at))}
                </span>
              </>
            );
            return (
              <li key={update.id} className="py-3">
                {update.link && update.link !== "/account" ? (
                  <Link href={update.link} className="block hover:text-forest">
                    {content}
                  </Link>
                ) : (
                  <div>{content}</div>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </Section>
  );
}

function DeleteAccount({ onLeave }: { onLeave: () => void }) {
  const router = useRouter();
  const { signOut } = useAccount();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  return (
    <section className="rounded-2xl border border-red-200 p-6">
      <h2 className="font-semibold text-ink">Delete account</h2>
      <p className="mt-1 text-sm text-ink/70">
        Removes your details and saved land. Enquiries and visits you sent stay
        with our team so we can still reply to them.
      </p>
      {!open ? (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-red-700 underline"
        >
          <Trash2 className="h-4 w-4" aria-hidden /> Delete my account
        </button>
      ) : (
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <p className="text-sm font-semibold text-red-800">
            This can&apos;t be undone. Delete your account?
          </p>
          <button
            type="button"
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              const result = await deleteMyAccount().catch(() => ({
                ok: false as const,
                message: "We couldn't reach our server. Please try again.",
              }));
              if (!result.ok) {
                setBusy(false);
                return setError(result.message);
              }
              onLeave();
              await signOut("local"); // the account and its sessions are already gone
              router.replace("/");
            }}
            className="rounded-lg bg-red-700 px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
          >
            {busy ? "Deleting…" : "Yes, delete it"}
          </button>
          <button
            type="button"
            onClick={() => setOpen(false)}
            className="text-sm text-muted underline"
          >
            Keep my account
          </button>
          {error && (
            <p role="alert" className="w-full text-sm text-red-800">
              {error}
            </p>
          )}
        </div>
      )}
    </section>
  );
}

function BookingRow({
  booking,
  onChanged,
}: {
  booking: MyRequests["bookings"][number];
  onChanged: () => void;
}) {
  const status = bookingStatusLabel(booking.status);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const canWithdraw =
    booking.status === "requested" || booking.status === "pending_approval";
  return (
    <li className="py-3">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <PropertyLine property={booking.property} strong />
          <p className="text-xs text-muted">{booking.reference}</p>
        </div>
        <StatusPill label={status.label} tone={status.tone} />
      </div>
      {status.next && <p className="mt-2 text-sm text-ink/75">{status.next}</p>}
      <dl className="mt-2 flex flex-wrap gap-x-6 gap-y-1 text-sm">
        {booking.agreed_price != null && (
          <div>
            <dt className="inline text-muted">Agreed price: </dt>
            <dd className="inline font-semibold">
              {formatRupees(booking.agreed_price)}
            </dd>
          </div>
        )}
        {booking.booking_amount != null && (
          <div>
            <dt className="inline text-muted">Booking amount: </dt>
            <dd className="inline font-semibold">
              {formatRupees(booking.booking_amount)}
            </dd>
          </div>
        )}
        {booking.amount_received != null && (
          <div>
            <dt className="inline text-muted">Received: </dt>
            <dd className="inline font-semibold">
              {formatRupees(booking.amount_received)}
            </dd>
          </div>
        )}
      </dl>
      {canWithdraw && (
        <button
          type="button"
          disabled={busy}
          onClick={async () => {
            if (
              !window.confirm(`Withdraw booking request ${booking.reference}?`)
            )
              return;
            setBusy(true);
            const { error: cancelError } = await browserSupabase().rpc(
              "cancel_my_booking",
              {
                p_reference: booking.reference,
              },
            );
            setBusy(false);
            if (cancelError) return setError(cancelError.message);
            onChanged();
          }}
          className="mt-2 text-sm text-muted underline disabled:opacity-60"
        >
          Withdraw request
        </button>
      )}
      {error && (
        <p role="alert" className="mt-1 text-sm text-red-800">
          {error}
        </p>
      )}
    </li>
  );
}
