/**
 * Enquiry form rules, shared by the form and the server action.
 * The database checks the same things again (submit_enquiry).
 */
import { z } from "zod";

export const contactMethods = {
  phone: "Phone call",
  whatsapp: "WhatsApp",
  email: "Email",
} as const;
export type ContactMethod = keyof typeof contactMethods;

/** "+91 98765 43210", "098765 43210", "9876543210" → "9876543210"; null if not an Indian mobile. */
export function normalizeIndianMobile(input: string): string | null {
  let digits = input.replace(/\D/g, "");
  if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(2);
  else if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(1);
  return /^[6-9]\d{9}$/.test(digits) ? digits : null;
}

const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max, `Keep it under ${max} characters.`)
    .transform((value) => (value === "" ? null : value));

export const enquirySchema = z
  .object({
    name: z.string().trim().min(2, "Please enter your name.").max(80, "Please shorten your name."),
    phone: z
      .string()
      .trim()
      .transform((value, context) => {
        const phone = normalizeIndianMobile(value);
        if (!phone) {
          context.addIssue({ code: "custom", message: "Enter a 10-digit Indian mobile number." });
          return z.NEVER;
        }
        return phone;
      }),
    email: z
      .string()
      .trim()
      .max(254)
      .refine((value) => value === "" || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value), "Enter a valid email or leave it empty.")
      .transform((value) => (value === "" ? null : value.toLowerCase())),
    preferredContact: z.enum(["phone", "whatsapp", "email"]).default("phone"),
    message: optionalText(1000),
    propertyId: z
      .string()
      .uuid()
      .nullable()
      .or(z.literal("").transform(() => null)),
    source: z.enum(["property_page", "contact_page"]),
    idempotencyKey: z.string().uuid(),
  })
  .refine((value) => value.preferredContact !== "email" || value.email !== null, {
    message: "Add your email if you'd like us to reply by email.",
    path: ["email"],
  });

export type EnquiryInput = z.infer<typeof enquirySchema>;

export type EnquiryFields = "name" | "phone" | "email" | "preferredContact" | "message";

/** What the form shows after sending. Typed values come back so nothing is lost on an error. */
export type EnquiryState =
  | { status: "idle" }
  | { status: "sent"; reference: string; duplicate: boolean }
  | {
      status: "error";
      message: string;
      fieldErrors: Partial<Record<EnquiryFields, string>>;
      values: Partial<Record<EnquiryFields, string>>;
    };

/** Database error keys (submit_enquiry) → sentences for the visitor. */
export function explainSubmitError(message: string): { message: string; field?: EnquiryFields } {
  if (message.includes("invalid_phone")) return { message: "Enter a 10-digit Indian mobile number.", field: "phone" };
  if (message.includes("rate_limited")) {
    return {
      message: "We've already received several enquiries from you in the last hour. We'll be in touch soon — or call us now.",
    };
  }
  if (message.includes("property_unavailable")) {
    return { message: "Sorry — this property has just been sold or withdrawn. Ask us about similar land below." };
  }
  return { message: "We couldn't send your enquiry just now. Please try again, or call or WhatsApp us." };
}
