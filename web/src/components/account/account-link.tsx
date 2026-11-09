"use client";

import { CircleUserRound, LogIn } from "lucide-react";
import Link from "next/link";

import { useAccount } from "@/components/account/account-provider";

/** Header: "Sign in" for guests, "My account" once signed in (with new updates). */
export function AccountLink() {
  const { ready, user, profile, unread } = useAccount();
  if (!ready) return <span className="inline-block h-10 w-10" aria-hidden />;
  const label = user
    ? (profile?.full_name?.split(" ")[0] ?? "My account")
    : "Sign in";
  const ariaLabel = !user
    ? "Sign in"
    : unread > 0
      ? `My account, ${unread} new ${unread === 1 ? "update" : "updates"}`
      : "My account";
  return (
    <Link
      href={user ? "/account" : "/account/sign-in"}
      className="inline-flex h-10 items-center gap-2 rounded-lg px-2 text-sm font-semibold text-forest hover:bg-forest/5"
      aria-label={ariaLabel}
    >
      <span className="relative">
        {user ? (
          <CircleUserRound className="h-5 w-5" aria-hidden />
        ) : (
          <LogIn className="h-5 w-5" aria-hidden />
        )}
        {unread > 0 && (
          <span
            className="absolute -right-1.5 -top-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-600 px-1 text-[10px] font-bold text-white"
            aria-hidden
          >
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </span>
      <span className="hidden sm:inline">{label}</span>
    </Link>
  );
}
