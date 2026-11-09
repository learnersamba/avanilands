"use client";

import { Search } from "lucide-react";
import type { FormEvent, ReactNode } from "react";
import { useRef } from "react";

import type { FilterOptions } from "@/components/listing/filter-labels";
import { facingLabels } from "@/lib/format";
import { facings, type ListingFilters, parseListingParams } from "@/lib/listing";

const budgetSteps = [
  { value: 1000000, label: "₹10 L" },
  { value: 2500000, label: "₹25 L" },
  { value: 5000000, label: "₹50 L" },
  { value: 7500000, label: "₹75 L" },
  { value: 10000000, label: "₹1 Cr" },
  { value: 20000000, label: "₹2 Cr" },
  { value: 50000000, label: "₹5 Cr" },
];

const roadWidths = [20, 30, 40, 60, 80];

const unitOptions = [
  { value: "sq_yd", label: "sq yd" },
  { value: "sq_ft", label: "sq ft" },
  { value: "cent", label: "cents" },
  { value: "gunta", label: "guntas" },
  { value: "acre", label: "acres" },
];

/** The filters as they are in the form right now. */
export function readFilterForm(form: HTMLFormElement, current: ListingFilters): ListingFilters {
  const read = parseListingParams(new URLSearchParams(new FormData(form) as unknown as Record<string, string>));
  return { ...read, sort: current.sort, page: 1 };
}

/**
 * Every filter as a plain GET form to /land (works without JavaScript).
 * `onChange` receives the new filters: immediately for clicks and choices,
 * and when a typed field is left or Enter is pressed.
 */
export function FilterForm({
  filters,
  options,
  onChange,
  idPrefix,
  footer,
}: {
  filters: ListingFilters;
  options: FilterOptions;
  onChange: (next: ListingFilters) => void;
  idPrefix: string;
  footer?: ReactNode;
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const changed = () => formRef.current && onChange(readFilterForm(formRef.current, filters));
  const typed = (target: EventTarget) =>
    target instanceof HTMLInputElement && (target.type === "text" || target.type === "number" || target.type === "search");

  const label = "mb-2 block text-sm font-semibold text-ink";
  const field = "w-full rounded-lg border border-line bg-white px-3 py-2.5 text-sm focus:border-forest focus:outline-none";
  const check = "flex cursor-pointer items-center gap-2.5 py-1.5 text-sm";
  const availabilityValue = filters.availability.join(",");

  return (
    <form
      ref={formRef}
      action="/land"
      method="get"
      onSubmit={(event: FormEvent) => {
        event.preventDefault();
        changed();
      }}
      onChange={(event) => {
        if (!typed(event.target)) changed();
      }}
      onBlur={(event) => {
        if (typed(event.target)) changed();
      }}
      className="space-y-7"
    >
      {filters.sort !== "newest" && <input type="hidden" name="sort" value={filters.sort} />}

      <div>
        <label htmlFor={`${idPrefix}-q`} className={label}>
          Search
        </label>
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" aria-hidden />
          <input
            id={`${idPrefix}-q`}
            name="q"
            type="search"
            defaultValue={filters.q}
            maxLength={100}
            placeholder="Place, locality or code"
            className={`${field} pl-9`}
          />
        </div>
      </div>

      <fieldset>
        <legend className={label}>Property type</legend>
        {options.types.map((type) => (
          <label key={type.id} className={check}>
            <input
              type="checkbox"
              name="type"
              value={type.seo_slug}
              defaultChecked={filters.types.includes(type.seo_slug)}
              className="h-4 w-4 accent-forest"
            />
            {type.name}
          </label>
        ))}
      </fieldset>

      <fieldset>
        <legend className={label}>Location</legend>
        {options.locations.map((location) => (
          <label key={location.id} className={check}>
            <input
              type="checkbox"
              name="city"
              value={location.slug}
              defaultChecked={filters.cities.includes(location.slug)}
              className="h-4 w-4 accent-forest"
            />
            <span className="flex-1">{location.city}</span>
            <span className="text-xs text-muted">{location.count}</span>
          </label>
        ))}
      </fieldset>

      <fieldset>
        <legend className={label}>Budget</legend>
        <div className="grid grid-cols-2 gap-2">
          <select name="min" defaultValue={filters.min ?? ""} aria-label="Minimum budget" className={field}>
            <option value="">No min</option>
            {budgetSteps.map((step) => (
              <option key={step.value} value={step.value}>{step.label}</option>
            ))}
          </select>
          <select name="max" defaultValue={filters.max ?? ""} aria-label="Maximum budget" className={field}>
            <option value="">No max</option>
            {budgetSteps.map((step) => (
              <option key={step.value} value={step.value}>{step.label}</option>
            ))}
          </select>
        </div>
      </fieldset>

      <fieldset>
        <legend className={label}>Area</legend>
        <div className="grid grid-cols-[1fr_1fr_auto] gap-2">
          <input
            name="area_min"
            type="number"
            min={0}
            step="any"
            inputMode="decimal"
            defaultValue={filters.areaMin ?? ""}
            placeholder="Min"
            aria-label="Minimum area"
            className={field}
          />
          <input
            name="area_max"
            type="number"
            min={0}
            step="any"
            inputMode="decimal"
            defaultValue={filters.areaMax ?? ""}
            placeholder="Max"
            aria-label="Maximum area"
            className={field}
          />
          <select name="unit" defaultValue={filters.unit} aria-label="Area unit" className={`${field} w-24`}>
            {unitOptions.map((unit) => (
              <option key={unit.value} value={unit.value}>{unit.label}</option>
            ))}
          </select>
        </div>
      </fieldset>

      <div>
        <label htmlFor={`${idPrefix}-road`} className={label}>
          Road width
        </label>
        <select id={`${idPrefix}-road`} name="road" defaultValue={filters.road ?? ""} className={field}>
          <option value="">Any road</option>
          {roadWidths.map((width) => (
            <option key={width} value={width}>{width} ft or wider</option>
          ))}
        </select>
      </div>

      <fieldset>
        <legend className={label}>Facing</legend>
        <div className="grid grid-cols-2 gap-x-3">
          {facings.map((facing) => (
            <label key={facing} className={check}>
              <input
                type="checkbox"
                name="facing"
                value={facing}
                defaultChecked={filters.facings.includes(facing)}
                className="h-4 w-4 accent-forest"
              />
              {facingLabels[facing]}
            </label>
          ))}
        </div>
      </fieldset>

      {options.amenities.length > 0 && (
        <details open={filters.amenities.length > 0} className="group">
          <summary className={`${label} flex cursor-pointer items-center justify-between`}>
            Amenities
            <span className="text-xs font-normal text-muted group-open:hidden">Show</span>
          </summary>
          <fieldset>
          <legend className="sr-only">Amenities</legend>
          {options.amenities.map((amenity) => (
            <label key={amenity.id} className={check}>
              <input
                type="checkbox"
                name="amenity"
                value={amenity.id}
                defaultChecked={filters.amenities.includes(amenity.id)}
                className="h-4 w-4 accent-forest"
              />
              {amenity.name}
            </label>
          ))}
          </fieldset>
        </details>
      )}

      <fieldset>
        <legend className={label}>Show</legend>
        {[
          { value: "", label: "Available and reserved" },
          { value: "available", label: "Available only" },
          { value: "available,reserved,sold", label: "Include sold land" },
        ].map((option) => (
          <label key={option.label} className={check}>
            <input
              type="radio"
              name="avail"
              value={option.value}
              defaultChecked={availabilityValue === option.value}
              className="h-4 w-4 accent-forest"
            />
            {option.label}
          </label>
        ))}
        <label className={`${check} mt-2`}>
          <input type="checkbox" name="approved" value="1" defaultChecked={filters.approved} className="h-4 w-4 accent-forest" />
          Approved layouts only
        </label>
      </fieldset>

      {footer}
      {/* Pressing Enter in a field needs a submit button in the form. */}
      <button type="submit" className="sr-only">
        Apply filters
      </button>
      {/* Without JavaScript the changes can't apply by themselves, so show the button. */}
      <noscript>
        <button type="submit" className="w-full rounded-lg bg-forest px-4 py-3 text-sm font-semibold text-white">
          Apply filters
        </button>
      </noscript>
    </form>
  );
}
