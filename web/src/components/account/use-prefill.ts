"use client";

import { type RefObject, useEffect } from "react";

import { useAccount } from "@/components/account/account-provider";

/**
 * Fills a form's name / mobile / email boxes from the signed-in customer's
 * profile, once it has loaded, without touching anything already typed.
 */
export function usePrefill(form: RefObject<HTMLFormElement | null>) {
  const { user, profile } = useAccount();
  useEffect(() => {
    const element = form.current;
    if (!element || !user) return;
    const values: Record<string, string | null | undefined> = {
      name: profile?.full_name,
      phone: profile?.phone,
      email: user.email,
    };
    for (const [name, value] of Object.entries(values)) {
      const input = element.elements.namedItem(name);
      if (value && input instanceof HTMLInputElement && input.value === "")
        input.value = value;
    }
  }, [form, user, profile]);
}
