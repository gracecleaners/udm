import { useEffect, useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ChevronLeft, ChevronRight, Loader2, Plus, Search, Trash2, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { VersePicker } from "@/components/curation/VersePicker";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { useAuth } from "@/contexts/AuthContext";
import { extractApiError } from "@/lib/api";
import {
  NONE, createItem, deleteItem, listPage, patchItem, uploadFiles,
  type FieldSpec, type Option, type ResourceConfig, type Row,
} from "@/lib/curation";

const PAGE_SIZE = 20;

function toInputDateTime(value: unknown): string {
  if (typeof value !== "string" || !value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function toInputDate(value: unknown): string {
  return typeof value === "string" && value ? value.slice(0, 10) : "";
}

/** What the API gets for one form field, or `undefined` for "leave it alone". */
function toBodyValue(field: FieldSpec, raw: unknown): unknown {
  const blank = raw === "" || raw === null || raw === undefined;
  if (raw === NONE) return null;
  if (blank) {
    if (field.nullable && field.type !== "switch") return null;
    // Text columns are blank-able on the model, so clearing one is a real edit
    // and has to be sent. A blank date, number or relation means "unchanged".
    if (field.type === "text" || field.type === "textarea") return "";
    if (field.type === "lines") return [];
    if (field.type === "json") return {};
    return undefined;
  }
  switch (field.type) {
    case "number":
      return Number(raw);
    case "switch":
      return Boolean(raw);
    case "datetime": {
      const date = new Date(String(raw));
      if (Number.isNaN(date.getTime())) throw new Error(`${field.label} is not a readable date.`);
      return date.toISOString();
    }
    case "json":
      if (typeof raw !== "string") return raw;
      try {
        return JSON.parse(raw);
      } catch {
        throw new Error(`${field.label} must be valid JSON before this can be saved.`);
      }
    case "lines":
      return typeof raw === "string"
        ? raw.split("\n").map((line) => line.trim()).filter(Boolean)
        : raw;
    default:
      return field.type === "select" || field.type === "verse" ? String(raw) : raw;
  }
}

function seedDraft(field: FieldSpec, row: Row | null): unknown {
  if (field.type === "image") return "";
  if (row === null) {
    if (field.default !== undefined) return field.type === "switch" ? Boolean(field.default) : field.default;
    return field.type === "switch" ? false : "";
  }
  const value = row[field.name];
  if (field.type === "datetime") return toInputDateTime(value);
  if (field.type === "date") return toInputDate(value);
  if (field.type === "json") return value && Object.keys(value as object).length ? JSON.stringify(value, null, 2) : "";
  if (field.type === "lines") return Array.isArray(value) ? value.join("\n") : "";
  if (field.type === "switch") return Boolean(value);
  if (value === null || value === undefined) return "";
  return value;
}

function FieldEditor({
  field, row, value, disabled, onChange,
}: {
  field: FieldSpec;
  row: Row | null;
  value: unknown;
  disabled: boolean;
  onChange: (value: unknown) => void;
}) {
  const source = field.optionsFrom;
  const needsOptions = !disabled && (field.type === "select" || field.type === "verse");
  const optionsQ = useQuery({
    queryKey: ["options", source?.cacheKey ?? "static"],
    queryFn: () => source!.load(),
    enabled: needsOptions && Boolean(source),
    staleTime: 5 * 60_000,
  });

  const options: Option[] = useMemo(
    () => optionsQ.data ?? field.options ?? [],
    [field.options, optionsQ.data],
  );

  // The verse picker is a group of controls, so no single input owns the label.
  const inputId = field.type === "verse" ? undefined : `field-${field.name}`;
  // A writable file field comes back with its URL under the same name plus
  // `_url`, which is the picture the row already carries.
  const currentImage = typeof row?.[`${field.name}_url`] === "string" ? String(row?.[`${field.name}_url`]) : "";

  return (
    <div className={`console-field${field.wide || field.type === "textarea" || field.type === "json" || field.type === "lines" || field.type === "verse" || field.type === "image" ? " console-field-wide" : ""}`}>
      <Label htmlFor={inputId}>
        {field.label}
        {field.required && <span className="console-required" aria-hidden="true"> *</span>}
      </Label>

      {disabled ? (
        <Input
          id={inputId}
          value={field.show && row ? field.show(row) : String(value ?? "")}
          readOnly
          disabled
        />
      ) : (
        <>
          {(field.type === "text" || field.type === "number") && (
            <Input
              id={inputId}
              type={field.type === "number" ? "number" : "text"}
              placeholder={field.placeholder}
              required={field.required}
              value={String(value ?? "")}
              onChange={(event) => onChange(event.target.value)}
            />
          )}
          {(field.type === "date" || field.type === "datetime") && (
            <div className="console-datetime-row">
              <Input
                id={inputId}
                type={field.type === "date" ? "date" : "datetime-local"}
                value={String(value ?? "")}
                onChange={(event) => onChange(event.target.value)}
              />
              {field.nullable && String(value ?? "") !== "" && (
                <Button type="button" size="sm" variant="ghost" onClick={() => onChange(NONE)} aria-label={`Clear ${field.label}`}>
                  <X size={14} aria-hidden="true" />
                </Button>
              )}
            </div>
          )}
          {field.type === "textarea" && (
            <Textarea
              id={inputId}
              rows={5}
              placeholder={field.placeholder}
              value={String(value ?? "")}
              onChange={(event) => onChange(event.target.value)}
            />
          )}
          {(field.type === "json" || field.type === "lines") && (
            <Textarea
              id={inputId}
              rows={field.type === "json" ? 4 : 5}
              placeholder={field.placeholder ?? (field.type === "json" ? "{}" : "One per line")}
              value={String(value ?? "")}
              onChange={(event) => onChange(event.target.value)}
            />
          )}
          {field.type === "switch" && (
            <Switch
              id={inputId}
              checked={Boolean(value)}
              onCheckedChange={(checked) => onChange(checked)}
            />
          )}
          {field.type === "select" && (
            <Select value={String(value ?? "")} onValueChange={onChange} disabled={optionsQ.isLoading}>
              <SelectTrigger id={`field-${field.name}`}>
                <SelectValue placeholder={optionsQ.isLoading ? "Loading…" : "Choose…"} />
              </SelectTrigger>
              <SelectContent>
                {field.nullable && <SelectItem value={NONE}>None</SelectItem>}
                {options.map((option) => (
                  <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
          {field.type === "verse" && (
            <VersePicker value={String(value ?? "")} onChange={(id) => onChange(id)} />
          )}
          {field.type === "image" && (
            <div className="console-image-field">
              {currentImage
                ? <img src={currentImage} alt="" className="console-image-preview" />
                : <span className="console-image-none">No picture yet</span>}
              <Input
                id={inputId}
                type="file"
                accept="image/*"
                onChange={(event) => onChange(event.target.files?.[0] ?? "")}
              />
            </div>
          )}
        </>
      )}

      {optionsQ.isError && field.type === "select" && !disabled && (
        <p className="console-field-help console-error">
          {field.label} could not be loaded from the API, so nothing can be chosen yet.
        </p>
      )}
      {field.help && <p className="console-field-help">{field.help}</p>}
    </div>
  );
}

/**
 * French overrides, one input per field the model marks as localised. The API
 * stores them as `{"fr": {field: text}}` and rejects any field a record does
 * not translate, so the console only offers the fields it was told about.
 */
function LocalizedSection({ fields, values, onChange }: {
  fields: FieldSpec[];
  values: Row;
  onChange: (name: string, text: string) => void;
}) {
  return (
    <div className="console-localized">
      <p className="console-localized-head">
        French overrides. Leave a field blank to keep reading the English text.
      </p>
      {fields.map((field) => {
        const stored = values[field.name];
        const text = Array.isArray(stored) ? stored.join("\n") : String(stored ?? "");
        return (
          <div className={`console-field${field.type !== "text" && field.type !== "number" && field.type !== "select" ? " console-field-wide" : ""}`} key={field.name}>
            <Label htmlFor={`fr-${field.name}`}>{field.label} (fr)</Label>
            {field.type === "text" || field.type === "number" || field.type === "select" ? (
              <Input
                id={`fr-${field.name}`}
                value={text}
                onChange={(event) => onChange(field.name, event.target.value)}
              />
            ) : (
              <Textarea
                id={`fr-${field.name}`}
                rows={4}
                value={text}
                onChange={(event) => onChange(field.name, event.target.value)}
              />
            )}
          </div>
        );
      })}
    </div>
  );
}

const FR = "__fr__";

/**
 * The `translations` payload for a save, or `undefined` when nothing about it
 * moved. Other locales already stored on the row are kept: this form only ever
 * speaks French, and rewriting the whole map would drop a locale it cannot see.
 */
function translationsBody(fields: FieldSpec[], values: Row | undefined, stored: Row | undefined): Row | undefined {
  const cleaned: Row = {};
  for (const field of fields) {
    const text = values?.[field.name];
    if (typeof text !== "string" || !text.trim()) continue;
    cleaned[field.name] = field.type === "lines"
      ? text.split("\n").map((line) => line.trim()).filter(Boolean)
      : text;
  }
  const next: Row = { ...(stored ?? {}) };
  if (Object.keys(cleaned).length) next.fr = cleaned;
  else delete next.fr;
  return JSON.stringify(next) === JSON.stringify(stored ?? {}) ? undefined : next;
}

export function ResourceScreen<T extends Row>({ config }: { config: ResourceConfig<T> }) {
  const queryClient = useQueryClient();
  const { role } = useAuth();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [filterValue, setFilterValue] = useState("");
  const [editing, setEditing] = useState<T | null>(null);
  const [creating, setCreating] = useState(false);
  const [draft, setDraft] = useState<Row>({});
  const [error, setError] = useState("");
  const [childRow, setChildRow] = useState<T | null>(null);

  const debouncedSearch = useDebouncedValue(search, 350);
  const idOf = config.idOf ?? ((row: T) => String(row.id));
  // A control exists only when the API would act on it. On a superuser-only
  // resource a staff account sees the rows and nothing else, rather than a
  // button that fails with a permission error after they press it.
  const writable = config.writableBy !== "superuser" || role === "superuser";
  const creatable = writable && config.creatable !== false && Boolean(config.fields?.length);
  const editable = writable && config.editable !== false && Boolean(config.fields?.length);
  const deletable = writable && config.deletable !== false;
  const hasActions = Boolean(config.child) || (writable && Boolean(config.state || editable || deletable));
  const params = config.parentFilter && filterValue ? { [config.parentFilter.name]: filterValue } : undefined;
  const filterSource = config.parentFilter?.optionsFrom;
  const filtersQ = useQuery({
    queryKey: ["options", filterSource?.cacheKey ?? "no-filter"],
    queryFn: () => filterSource!.load(),
    enabled: Boolean(filterSource),
    staleTime: 5 * 60_000,
  });

  const listQ = useQuery({
    queryKey: ["resource", config.endpoint, page, debouncedSearch, filterValue],
    queryFn: () =>
      listPage<T>(config.endpoint, { page, search: debouncedSearch || undefined, ordering: config.ordering, params }),
  });

  // Leave page 2 behind when a search or filter makes it empty.
  useEffect(() => {
    const total = listQ.data?.count ?? 0;
    if (total > 0 && (page - 1) * PAGE_SIZE >= total) setPage(1);
  }, [listQ.data?.count, page]);

  // A new university has to appear in the campus dropdown on the same visit, so
  // the cached option lists are refreshed with the tables rather than left to
  // their stale time.
  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["resource"] });
    queryClient.invalidateQueries({ queryKey: ["options"] });
  };

  const reset = () => {
    setEditing(null);
    setCreating(false);
    setDraft({});
    setError("");
  };

  const save = useMutation({
    mutationFn: async ({ body, files }: { body: Row; files: Record<string, File> }) => {
      // Text and file are two writes on purpose: a JSON body cannot carry a
      // picture, and a picture should not have to resend wording that did not
      // move. On a new row the API supplies the id the upload is addressed to.
      const row = editing
        ? Object.keys(body).length
          ? await patchItem(config.endpoint, idOf(editing), body)
          : editing
        : await createItem(config.endpoint, body);
      if (Object.keys(files).length) await uploadFiles(config.endpoint, String(row.id), files);
      return row;
    },
    onSuccess: () => { invalidate(); reset(); },
    onError: (err) => setError(extractApiError(err, "The API refused this change.")),
  });

  const stateSave = useMutation({
    mutationFn: async ({ id, body }: { id: string; body: Row }) => patchItem(config.endpoint, id, body),
    onSuccess: invalidate,
    onError: (err) => setError(extractApiError(err, "The API refused that change.")),
  });

  const remove = useMutation({
    mutationFn: (id: string) => deleteItem(config.endpoint, id),
    onSuccess: () => { invalidate(); reset(); },
    onError: (err) => setError(extractApiError(err, "The API refused to delete this.")),
  });

  const rows = listQ.data?.results ?? [];
  const total = listQ.data?.count ?? 0;
  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const localizedFields = useMemo(
    () => (config.localized ?? []).map((name) => (config.fields ?? []).find((field) => field.name === name)).filter(
      (field): field is FieldSpec => Boolean(field),
    ),
    [config.fields, config.localized],
  );

  const buildDraft = (row: T | null): Row => {
    const next: Row = Object.fromEntries((config.fields ?? []).map((field) => [field.name, seedDraft(field, row)]));
    const french = (row?.translations as Row | undefined)?.fr;
    next[FR] = typeof french === "object" && french !== null ? { ...french } as Row : {};
    return next;
  };

  const openEdit = (row: T) => {
    setError("");
    setEditing(row);
    setCreating(false);
    setDraft(buildDraft(row));
  };

  const openCreate = () => {
    setError("");
    setCreating(true);
    setEditing(null);
    setDraft(buildDraft(null));
  };

  const submit = () => {
    setError("");
    const body: Row = {};
    const files: Record<string, File> = {};
    for (const field of config.fields ?? []) {
      const locked = field.readOnly || (field.readOnlyOnEdit && editing);
      if (locked) continue;
      const raw = draft[field.name];
      if (field.type === "image") {
        // A chosen picture travels as a file, never as JSON.
        if (raw instanceof File) files[field.name] = raw;
        continue;
      }
      let value: unknown;
      try {
        value = toBodyValue(field, raw);
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : `“${field.label}” could not be sent as written.`);
        return;
      }
      if (value === undefined) continue;
      body[field.name] = value;
    }
    if (localizedFields.length) {
      const translations = translationsBody(localizedFields, draft[FR] as Row | undefined, editing?.translations as Row | undefined);
      if (translations) body.translations = translations;
    }
    if (creating) {
      const missing = (config.fields ?? []).find((field) => {
        if (!field.required || field.readOnly) return false;
        const raw = draft[field.name];
        return raw === "" || raw === null || raw === undefined || raw === NONE;
      });
      if (missing) {
        setError(`${missing.label} is required.`);
        return;
      }
    }
    if (!Object.keys(body).length && !Object.keys(files).length) {
      setError("Nothing changed, so nothing was sent.");
      return;
    }
    save.mutate({ body, files });
  };

  return (
    <div className="console-page">
      <header className="console-page-head">
        <div>
          <h1>{config.plural}</h1>
          <p>{config.description}</p>
        </div>
        {creatable && (
          <Button size="sm" onClick={openCreate}>
            <Plus size={15} aria-hidden="true" /> New {config.singular.toLowerCase()}
          </Button>
        )}
      </header>

      <div className="console-toolbar">
        <label className="console-search">
          <Search size={16} aria-hidden="true" />
          <span className="sr-only">Search {config.plural}</span>
          <Input
            value={search}
            onChange={(event) => { setSearch(event.target.value); setPage(1); }}
            placeholder={config.searchPlaceholder ?? `Search ${config.plural.toLowerCase()}`}
          />
        </label>
        {config.parentFilter && (
          <label className="console-filter">
            <span>{config.parentFilter.label}</span>
            <Select value={filterValue || NONE} onValueChange={(next) => { setFilterValue(next === NONE ? "" : next); setPage(1); }}>
              <SelectTrigger className="console-filter-select" aria-label={`Filter ${config.plural} by ${config.parentFilter.label.toLowerCase()}`}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={NONE}>All</SelectItem>
                {(filtersQ.data ?? []).map((option) => (
                  <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </label>
        )}
      </div>

      {error && <p className="console-error" role="alert">{error}</p>}

      {!writable && (
        <p className="console-note">
          Read-only on your account. A platform admin changes these records, so this screen lists and searches them
          without offering a button the API would refuse.
        </p>
      )}

      <div className="console-panel console-panel-table">
        {listQ.isLoading ? (
          <p className="console-empty"><Loader2 size={15} className="animate-spin" aria-hidden="true" /> Loading…</p>
        ) : listQ.isError ? (
          <p className="console-error" role="alert">
            These {config.plural.toLowerCase()} could not be loaded. The console will not guess at them.
          </p>
        ) : rows.length === 0 ? (
          <p className="console-empty">
            {debouncedSearch || filterValue
              ? <>Nothing matched the current search or filter.</>
              : <>No {config.plural.toLowerCase()} yet. Staff add them here, so an empty list is honest.</>}
          </p>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                {config.columns.map((column) => (
                  <TableHead key={column.header}>{column.header}</TableHead>
                ))}
                {hasActions && <TableHead className="console-col-actions">Actions</TableHead>}
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((row) => {
                const id = idOf(row);
                const state = config.state?.current(row) ?? null;
                return (
                  <TableRow key={id}>
                    {config.columns.map((column) => (
                      <TableCell key={column.header} className={`console-cell`}>
                        {column.cell(row)}
                      </TableCell>
                    ))}
                    {hasActions && (
                    <TableCell className="console-col-actions">
                      <div className="console-row-actions">
                        {writable && config.state && state && (
                          <Select
                            value={state}
                            onValueChange={(next) => stateSave.mutate({ id, body: config.state!.patch(next, row) })}
                            disabled={stateSave.isPending}
                          >
                            <SelectTrigger className="console-state-select" aria-label={`Status for ${id}`}>
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {config.state.options.map((option) => (
                                <SelectItem key={option.value} value={option.value} disabled={option.disabled}>
                                  {option.label}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        )}
                        {config.child && (
                          <Button size="sm" variant="outline" onClick={() => setChildRow(row)}>
                            {config.child(row).label}
                          </Button>
                        )}
                        {editable && <Button size="sm" variant="ghost" onClick={() => openEdit(row)}>Edit</Button>}
                        {deletable && (
                          <Button
                            size="sm"
                            variant="ghost"
                            className="console-delete"
                            onClick={() => {
                              if (window.confirm(config.deleteWarning ?? `Delete this ${config.singular.toLowerCase()}? This cannot be undone.`)) {
                                remove.mutate(id);
                              }
                            }}
                          >
                            <Trash2 size={15} aria-hidden="true" />
                          </Button>
                        )}
                      </div>
                    </TableCell>
                    )}
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}

        <div className="console-pager">
          <span>{listQ.data ? `${total} ${config.plural.toLowerCase()}` : "…"}</span>
          <div>
            <Button size="icon" variant="outline" disabled={page <= 1} onClick={() => setPage((n) => n - 1)} aria-label="Previous page">
              <ChevronLeft size={15} aria-hidden="true" />
            </Button>
            <Badge variant="secondary" className="console-page-number">{page} / {pageCount}</Badge>
            <Button size="icon" variant="outline" disabled={page >= pageCount} onClick={() => setPage((n) => n + 1)} aria-label="Next page">
              <ChevronRight size={15} aria-hidden="true" />
            </Button>
          </div>
        </div>
        {config.state?.note && <p className="console-note">{config.state.note}</p>}
      </div>

      <Dialog open={creating || editing !== null} onOpenChange={(open) => { if (!open) reset(); }}>
        <DialogContent className="console-form-dialog">
          <DialogHeader>
            <DialogTitle>{editing ? `Edit ${config.singular.toLowerCase()}` : `New ${config.singular.toLowerCase()}`}</DialogTitle>
            <DialogDescription>
              Only the fields you can change are sent. Anything the API computes is shown but never written back.
            </DialogDescription>
          </DialogHeader>

          <div className="console-form-grid">
            {(config.fields ?? []).map((field) => {
              const locked = field.readOnly || (field.readOnlyOnEdit && Boolean(editing));
              return (
                <FieldEditor
                  key={field.name}
                  field={field}
                  row={editing}
                  disabled={locked}
                  value={draft[field.name]}
                  onChange={(value) => setDraft((current) => ({ ...current, [field.name]: value }))}
                />
              );
            })}
            {localizedFields.length > 0 && (
              <LocalizedSection
                fields={localizedFields}
                values={(draft[FR] as Row | undefined) ?? {}}
                onChange={(name, text) => setDraft((current) => ({
                  ...current,
                  [FR]: { ...(current[FR] as Row | undefined), [name]: text },
                }))}
              />
            )}
          </div>

          {(error || save.isError) && (
            <p className="console-error" role="alert">{error || extractApiError(save.error, "The API refused this change.")}</p>
          )}

          <DialogFooter>
            <Button variant="ghost" onClick={reset}>Cancel</Button>
            <Button onClick={submit} disabled={save.isPending}>
              {save.isPending
                ? <><Loader2 size={15} className="animate-spin" aria-hidden="true" /> Saving…</>
                : "Save"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={childRow !== null} onOpenChange={(open) => { if (!open) setChildRow(null); }}>
        <DialogContent className="console-child-dialog">
          {childRow && config.child && (
            <>
              <DialogHeader>
                <DialogTitle>{config.child(childRow).title(childRow)}</DialogTitle>
                <DialogDescription>
                  These {config.child(childRow).config.plural.toLowerCase()} belong to the{" "}
                  {config.singular.toLowerCase()} above; the API files them under it automatically.
                </DialogDescription>
              </DialogHeader>
              <ResourceScreen config={config.child(childRow).config} />
            </>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
