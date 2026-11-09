import {
  BadgeCheck,
  FileCheck2,
  Handshake,
  MapPinned,
  Ruler,
  ShieldCheck,
  Stamp,
  Users,
  type LucideIcon,
} from "lucide-react";

/** Icon names used in src/content/site.ts. */
export const contentIcons: Record<string, LucideIcon> = {
  shield: ShieldCheck,
  stamp: Stamp,
  handshake: Handshake,
  map: MapPinned,
  badge: BadgeCheck,
  file: FileCheck2,
  ruler: Ruler,
  users: Users,
};
