import type { ReactNode } from "react";
import { api } from "@/lib/api";

/** A DRF `PageNumberPagination` body, as the console receives it. */
export interface Page<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export type Row = Record<string, unknown>;

export interface Option {
  value: string;
  label: string;
  disabled?: boolean;
}

/**
 * Foreign-key pickers need every row, but the API fixes pages at 20 and does
 * not accept `page_size`, so the console walks the pages itself. The cap keeps
 * a mistyped endpoint from turning one dropdown into a hundred requests.
 */
const MAX_OPTION_PAGES = 10;

export interface ListParams {
  page?: number;
  search?: string;
  ordering?: string;
  params?: Record<string, string | number | undefined>;
}

export async function listPage<T extends Row>(endpoint: string, params: ListParams = {}): Promise<Page<T>> {
  const { data } = await api.get<Page<T>>(endpoint, {
    params: {
      page: params.page || 1,
      ...(params.search ? { search: params.search } : {}),
      ...(params.ordering ? { ordering: params.ordering } : {}),
      ...params.params,
    },
  });
  return data;
}

export async function listAll<T extends Row>(endpoint: string, params: Omit<ListParams, "page"> = {}): Promise<T[]> {
  const rows: T[] = [];
  for (let page = 1; page <= MAX_OPTION_PAGES; page += 1) {
    const body = await listPage<T>(endpoint, { ...params, page });
    rows.push(...body.results);
    if (!body.next || rows.length >= body.count) break;
  }
  return rows;
}

export const detailUrl = (endpoint: string, id: string) => `${endpoint}${id}/`;

export async function createItem(endpoint: string, body: Row): Promise<Row> {
  const { data } = await api.post(endpoint, body);
  return data;
}

/**
 * Curation writes are always partial. Resending a whole object would let a form
 * that opened minutes ago overwrite a change a colleague made in between.
 */
export async function patchItem(endpoint: string, id: string, body: Row): Promise<Row> {
  const { data } = await api.patch(detailUrl(endpoint, id), body);
  return data;
}

export async function deleteItem(endpoint: string, id: string): Promise<void> {
  await api.delete(detailUrl(endpoint, id));
}

/**
 * A cover goes up as its own multipart write, because a form that mixes a file
 * with JSON would have to encode one inside the other. The text of a row is
 * saved first and the picture after it, so a refused upload leaves the wording
 * intact rather than losing both.
 *
 * The JSON content type the shared client defaults to has to be taken off this
 * request: with it set, axios turns the form into JSON before it leaves the
 * page, and the API answers that no file was submitted.
 */
export async function uploadFiles(endpoint: string, id: string, files: Record<string, File>): Promise<Row> {
  const form = new FormData();
  for (const [name, file] of Object.entries(files)) form.append(name, file);
  const { data } = await api.patch(detailUrl(endpoint, id), form, {
    headers: { "Content-Type": null },
  });
  return data;
}

// Row state --------------------------------------------------------------

/**
 * There is no publish *action* on the API. `publish_state` is read-only and is
 * derived from `is_published` and `publish_at`, so every state control on a
 * console row PATCHes those two fields and nothing else.
 */
export interface StateSpec {
  current: (row: Row) => string | null;
  options: Option[];
  patch: (value: string, row: Row) => Row;
  /** Why a state cannot be set from the row (it needs a date from the form). */
  note?: string;
}

const PUBLISH_OPTIONS: Option[] = [
  { value: "draft", label: "Draft" },
  // Read-only here: a scheduled row is a date, so it is set in the edit form.
  { value: "scheduled", label: "Scheduled", disabled: true },
  { value: "live", label: "Live" },
];

const readPublishState = (row: Row) =>
  typeof row.publish_state === "string" ? row.publish_state : null;

/** Devotions and articles: publishing now also clears a queued date. */
export const datedPublishState: StateSpec = {
  current: readPublishState,
  options: PUBLISH_OPTIONS,
  note: "Scheduled rows are set by giving them a future date in the form.",
  patch: (value) =>
    value === "live" ? { is_published: true, publish_at: null } : { is_published: value === "draft" ? false : true },
};

/** Plans and memory verses only carry `is_published`. */
export const simplePublishState: StateSpec = {
  current: readPublishState,
  options: PUBLISH_OPTIONS.filter((option) => option.value !== "scheduled"),
  patch: (value) => ({ is_published: value === "live" }),
};

/** Campus records: shown to students or hidden, with no schedule. */
export const activeState: StateSpec = {
  current: (row) => (typeof row.is_active === "boolean" ? (row.is_active ? "active" : "inactive") : null),
  options: [
    { value: "active", label: "Active" },
    { value: "inactive", label: "Hidden" },
  ],
  patch: (value) => ({ is_active: value === "active" }),
};

/** Events own a `status` field, so their state is a plain field write. */
export const eventState: StateSpec = {
  current: (row) => (typeof row.status === "string" ? row.status : null),
  options: [
    { value: "draft", label: "Draft" },
    { value: "published", label: "Published" },
    { value: "cancelled", label: "Cancelled" },
  ],
  patch: (value) => ({ status: value }),
};

// Screen configuration ---------------------------------------------------

export interface FieldSpec {
  name: string;
  label: string;
  type: "text" | "textarea" | "number" | "select" | "switch" | "datetime" | "date" | "json" | "lines" | "verse" | "image";
  help?: string;
  placeholder?: string;
  options?: Option[];
  /** Loaded the first time the field is shown, then cached by this key. */
  optionsFrom?: { cacheKey: string; load: () => Promise<Option[]> };
  /** Never sent: the API owns it. Rendered so staff can see what they are editing. */
  readOnly?: boolean;
  /** Writable when creating, fixed afterwards. */
  readOnlyOnEdit?: boolean;
  /** Label to show instead of a raw primary key on a locked relation. */
  show?: (row: Row) => string;
  required?: boolean;
  /** Blank means NULL rather than "leave this alone". */
  nullable?: boolean;
  /** Starting value for a new row, mirroring the model's own default. */
  default?: string | number | boolean;
  wide?: boolean;
}

export interface Column<T extends Row> {
  header: string;
  cell: (row: T) => ReactNode;
}

export interface ChildScreen<T extends Row> {
  label: string;
  title: (row: T) => string;
  config: ResourceConfig;
}

export interface ResourceConfig<T extends Row = Row> {
  endpoint: string;
  singular: string;
  plural: string;
  description: string;
  columns: Column<T>[];
  fields?: FieldSpec[];
  /**
   * Field names this model accepts French overrides for, straight from the
   * API's `localized_fields`. Any other name is rejected on write.
   */
  localized?: string[];
  /**
   * Which console role the API takes writes from. Defaults to `"staff"` because
   * that is what every curation endpoint checks. A `"superuser"` resource is
   * still listed and searchable for staff — reading is their monitoring job —
   * but the console then renders no control the API would refuse.
   */
  writableBy?: "staff" | "superuser";
  state?: StateSpec;
  child?: (row: T) => ChildScreen<T>;
  /** One dropdown above the table, sent as a query parameter (parent scoping). */
  parentFilter?: { name: string; label: string; optionsFrom: { cacheKey: string; load: () => Promise<Option[]> } };
  creatable?: boolean;
  editable?: boolean;
  deletable?: boolean;
  deleteWarning?: string;
  searchPlaceholder?: string;
  ordering?: string;
  idOf?: (row: T) => string;
}

export const NONE = "__none__";

// Option loaders ---------------------------------------------------------

export function rowsToOptions(rows: Row[], label: (row: Row) => string): Option[] {
  return rows.map((row) => ({ value: String(row.id), label: label(row) }));
}

export function fkOptions(
  endpoint: string,
  label: (row: Row) => string,
  params?: Record<string, string>,
): { cacheKey: string; load: () => Promise<Option[]> } {
  return {
    cacheKey: `options:${endpoint}:${JSON.stringify(params ?? {})}`,
    load: async () => rowsToOptions(await listAll(endpoint, { params }), label),
  };
}

export const campusOptions = fkOptions("admin/campuses/", (row) =>
  `${String(row.name)} — ${String(row.university_name ?? "")}`.trim(),
);

export const universityOptions = fkOptions("admin/universities/", (row) =>
  `${String(row.name)} — ${String(row.country ?? "")}`.trim(),
);

/** Only accounts the console can name; leaders and organisers are chosen from these. */
export const memberOptions = fkOptions("admin/students/", (row) => `${String(row.display_name)} <${String(row.email)}>`);

/** The Devotions grid in the app is this list, so the console files days against it. */
export const seriesOptions = fkOptions("admin/devotion-series/", (row) => `${String(row.title)} (${String(row.day_count ?? 0)} days)`, {
  ordering: "order",
});

/** The home "Find resources on" list is this table, so steps are filed against it. */
export const topicOptions = fkOptions("admin/resource-topics/", (row) => `${String(row.title)} (${String(row.step_count ?? 0)} steps)`, {
  ordering: "order",
});

/** The Learn tab is this table, so recordings are filed against a shelf. */
export const mediaShelfOptions = fkOptions("admin/media-collections/", (row) =>
  `${String(row.title)} (${String(row.item_count ?? 0)} recordings)`, { ordering: "order" },
);
