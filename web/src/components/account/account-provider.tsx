"use client";

import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import { browserSupabase } from "@/lib/supabase/browser";

export type CustomerProfile = {
  full_name: string | null;
  phone: string | null;
  email_updates: boolean;
};

type AccountState = {
  /** False until the browser has checked for a session. */
  ready: boolean;
  user: { id: string; email: string | null } | null;
  profile: CustomerProfile | null;
  saved: ReadonlySet<string>;
  /** Unread notifications (updates), kept live. */
  unread: number;
  refreshUnread: () => Promise<void>;
  /** Saves or removes a property. Guests get "sign-in". */
  toggleSave: (
    propertyId: string,
  ) => Promise<"saved" | "removed" | "sign-in" | "error">;
  reload: () => Promise<void>;
  /** "local" only forgets this browser's session (e.g. after deleting the account). */
  signOut: (scope?: "global" | "local") => Promise<void>;
};

const AccountContext = createContext<AccountState | null>(null);

/**
 * The signed-in customer, in the browser only: pages stay cached for
 * everyone, and personal bits (header link, saved hearts, pre-filled forms)
 * fill in once the page is running.
 */
export function AccountProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [user, setUser] = useState<AccountState["user"]>(null);
  const [profile, setProfile] = useState<CustomerProfile | null>(null);
  const [saved, setSaved] = useState<ReadonlySet<string>>(new Set());
  const [unread, setUnread] = useState(0);

  const refreshUnread = useCallback(async () => {
    const { count } = await browserSupabase()
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .is("read_at", null);
    setUnread(count ?? 0);
  }, []);

  const loadFor = useCallback(async (userId: string | null) => {
    if (!userId) {
      setProfile(null);
      setSaved(new Set());
      return;
    }
    const supabase = browserSupabase();
    const [profileResult, savedResult] = await Promise.all([
      supabase
        .from("customer_profiles")
        .select("full_name, phone, email_updates")
        .maybeSingle(),
      supabase.from("saved_properties").select("property_id"),
    ]);
    setProfile((profileResult.data as CustomerProfile | null) ?? null);
    setSaved(
      new Set(
        (savedResult.data ?? []).map(
          (row: { property_id: string }) => row.property_id,
        ),
      ),
    );
  }, []);

  useEffect(() => {
    const supabase = browserSupabase();
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      const next = session?.user
        ? { id: session.user.id, email: session.user.email ?? null }
        : null;
      setUser((current) => (current?.id === next?.id ? current : next));
      setReady(true);
      // Outside the auth callback (Supabase advises against awaiting inside it).
      setTimeout(() => void loadFor(next?.id ?? null), 0);
    });
    return () => data.subscription.unsubscribe();
  }, [loadFor]);

  // New updates arrive live while the site is open (row rules: only theirs).
  useEffect(() => {
    if (!user) return;
    const supabase = browserSupabase();
    const channel = supabase
      .channel(`notifications-${user.id}`)
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "notifications",
          filter: `user_id=eq.${user.id}`,
        },
        () => void refreshUnread(),
      )
      // First count once connected, then on every change.
      .subscribe((status) => {
        if (status === "SUBSCRIBED") void refreshUnread();
      });
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [user, refreshUnread]);

  const toggleSave = useCallback<AccountState["toggleSave"]>(
    async (propertyId) => {
      if (!user) return "sign-in";
      const supabase = browserSupabase();
      const isSaved = saved.has(propertyId);
      const { error } = isSaved
        ? await supabase
            .from("saved_properties")
            .delete()
            .eq("property_id", propertyId)
        : await supabase
            .from("saved_properties")
            .insert({ property_id: propertyId });
      if (error && error.code !== "23505") return "error"; // 23505: already saved in another tab
      setSaved((current) => {
        const next = new Set(current);
        if (isSaved) next.delete(propertyId);
        else next.add(propertyId);
        return next;
      });
      return isSaved ? "removed" : "saved";
    },
    [user, saved],
  );

  const value = useMemo<AccountState>(
    () => ({
      ready,
      user,
      profile,
      saved,
      unread: user ? unread : 0,
      refreshUnread,
      toggleSave,
      // Asks for the session itself: right after signing in, `user` here may
      // not have caught up yet.
      reload: async () => {
        const { data } = await browserSupabase().auth.getSession();
        await loadFor(data.session?.user.id ?? null);
      },
      signOut: async (scope = "global") => {
        await browserSupabase().auth.signOut({ scope });
      },
    }),
    [ready, user, profile, saved, unread, refreshUnread, toggleSave, loadFor],
  );
  return (
    <AccountContext.Provider value={value}>{children}</AccountContext.Provider>
  );
}

export function useAccount(): AccountState {
  const value = useContext(AccountContext);
  if (!value) throw new Error("useAccount must be used inside AccountProvider");
  return value;
}
