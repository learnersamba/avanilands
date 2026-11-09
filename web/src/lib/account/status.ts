/** How a customer sees the team's statuses (plainer than the staff words). */
type Tone = "waiting" | "active" | "done" | "closed";

export function enquiryStatusLabel(status: string): {
  label: string;
  tone: Tone;
} {
  switch (status) {
    case "new":
      return { label: "Received", tone: "waiting" };
    case "contacted":
    case "follow_up":
      return { label: "We're in touch", tone: "active" };
    case "interested":
      return { label: "In progress", tone: "active" };
    case "converted":
      return { label: "Completed", tone: "done" };
    default:
      return { label: "Closed", tone: "closed" };
  }
}

export function visitStatusLabel(status: string): {
  label: string;
  tone: Tone;
} {
  switch (status) {
    case "requested":
      return { label: "Waiting for confirmation", tone: "waiting" };
    case "confirmed":
      return { label: "Confirmed", tone: "active" };
    case "completed":
      return { label: "Visited", tone: "done" };
    case "no_show":
      return { label: "Missed", tone: "closed" };
    default:
      return { label: "Cancelled", tone: "closed" };
  }
}

export function bookingStatusLabel(status: string): {
  label: string;
  tone: Tone;
  next: string;
} {
  switch (status) {
    case "requested":
      return {
        label: "Request received",
        tone: "waiting",
        next: "Our team will call you to go over the price and next steps.",
      };
    case "pending_approval":
      return {
        label: "Being approved",
        tone: "waiting",
        next: "Your booking is with our management for approval.",
      };
    case "approved":
      return {
        label: "Approved — reserved for you",
        tone: "active",
        next: "We'll call you about the booking amount.",
      };
    case "payment_pending":
      return {
        label: "Booking amount due",
        tone: "active",
        next: "Our team will call from our official number with how to pay. Never pay into a personal account.",
      };
    case "reserved":
      return {
        label: "Reserved — payment received",
        tone: "active",
        next: "We're preparing the documents for registration.",
      };
    case "completed":
      return {
        label: "Sale completed",
        tone: "done",
        next: "Congratulations on your land!",
      };
    default:
      return { label: "Cancelled", tone: "closed", next: "" };
  }
}
