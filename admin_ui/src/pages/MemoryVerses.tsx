import { useQuery } from "@tanstack/react-query";
import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { listPage, simplePublishState, type ResourceConfig, type Row } from "@/lib/curation";

/**
 * Which translations may be quoted is a licensing decision the server makes
 * (`UDM_MEMORY_VERSE_TRANSLATIONS`), so the console reads the allowed codes back
 * from an existing row rather than hard-coding them. With no rows yet the field
 * falls back to free text, and the API still refuses an unlicensed code.
 */
function useAllowedCodes(): string[] | null {
  const query = useQuery({
    queryKey: ["memory-verse-codes"],
    queryFn: async () => {
      const page = await listPage<Row>("admin/memory-verses/", { page: 1 });
      const codes = page.results[0]?.allowed_translation_codes;
      return Array.isArray(codes) ? codes.map(String) : [];
    },
    staleTime: 10 * 60_000,
  });
  return query.data ?? null;
}

/**
 * One row serves both jobs the app has: the home feed's memory verse card (the
 * dated window, rotated deterministically) and the memorization drill (`prompt`
 * plus each student's own progress). Either the text is a synced verse, and that
 * translation's licence and attribution govern it, or it is a stored copy with
 * its own attribution — which is how a deployment features a verse whose
 * translation has not been imported.
 */
function buildConfig(codes: string[] | null): ResourceConfig {
  const synced = "Only used when no synced verse is picked above.";
  return {
    endpoint: "admin/memory-verses/",
    singular: "Memory verse",
    plural: "Memory verses",
    description:
      "Verses students hide in their heart. The home feed rotates the published ones whose window covers today, "
      + "the same verse for every reader on a given day.",
    state: simplePublishState,
    localized: ["reference", "text", "attribution", "prompt"],
    searchPlaceholder: "Search prompts or verse text",
    columns: [
      {
        header: "Verse",
        cell: (row) => (
          <>
            <strong>{String(row.display_reference)}</strong>
            <span className="console-cell-sub">{ellipsis(row.display_text, 100)}</span>
          </>
        ),
      },
      {
        header: "Source",
        cell: (row) => (
          <>
            {String(row.display_translation ?? "—")}
            <span className="console-cell-sub">
              {row.verse ? "synced scripture" : ellipsis(row.display_attribution, 60)}
            </span>
          </>
        ),
      },
      {
        header: "Window",
        cell: (row) => `${row.start_date ? dateText(row.start_date) : "any"} → ${row.end_date ? dateText(row.end_date) : "any"}`,
      },
      { header: "Prompt", cell: (row) => ellipsis(row.prompt, 70) },
      { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
      { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
    ],
    fields: [
      {
        name: "verse",
        label: "Synced scripture",
        type: "verse",
        nullable: true,
        readOnlyOnEdit: true,
        show: (row) => `${String(row.display_reference)} — ${ellipsis(row.display_text, 90)}`,
        help: "Search the verses the sync already stored and pick one. Its text, reference, licence and attribution are then read from it, and one memory verse per scripture row is the limit.",
      },
      {
        name: "reference",
        label: "Reference",
        type: "text",
        help: `${synced} For example “John 3:16”. Either pick a verse or write this and the text.`,
      },
      {
        name: "text",
        label: "Verse text",
        type: "textarea",
        help: `${synced} Public-domain or licensed wording only — the app never scrapes scripture.`,
      },
      codes?.length
        ? {
            name: "translation_code",
            label: "Translation",
            type: "select",
            options: codes.map((code) => ({ value: code, label: code.toUpperCase() })),
            help: `${synced} The list comes from the server’s licensing settings.`,
          }
        : {
            name: "translation_code",
            label: "Translation code",
            type: "text",
            help: `${synced} No memory verse exists yet, so the licensed list is unknown. The API refuses a code it does not allow.`,
          },
      {
        name: "attribution",
        label: "Attribution",
        type: "text",
        help: `${synced} The copyright line readers see. Public-domain translations still need their wording.`,
      },
      {
        name: "prompt",
        label: "Recall prompt",
        type: "text",
        help: "The line that asks the reader to fill in the verse.",
      },
      {
        name: "start_date",
        label: "From",
        type: "date",
        nullable: true,
        help: "Blank means eligible from any date.",
      },
      {
        name: "end_date",
        label: "To",
        type: "date",
        nullable: true,
        help: "Blank means it never expires. The end date cannot precede the start date.",
      },
      { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
    ],
    deleteWarning: "Everyone’s progress on this verse, including review counts, is deleted with it. Delete it?",
  };
}

export default function MemoryVerses() {
  return <ResourceScreen config={buildConfig(useAllowedCodes())} />;
}
