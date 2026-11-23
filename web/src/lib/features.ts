/**
 * Features switched off for launch to keep the first months simple and inside
 * the free plans (decision 132). The code, pages and database stay; turning a
 * feature back on is `true` here plus a deploy (and the matching switch in
 * admin/lib/core/features.dart).
 *
 * customerAccounts: sign in with an emailed code, saved land (hearts),
 *   My account, customer updates. Off: none of it shows, /account is "not
 *   found", and pages don't check for a signed-in customer.
 * bookings: "Request to book" (needs a customer account). Off: no link,
 *   /book/<code> is "not found".
 */
export const features = {
  customerAccounts: false,
  bookings: false,
} as const;
