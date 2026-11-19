import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, seriesOptions, type ResourceConfig } from "@/lib/curation";

export const devotionsConfig: ResourceConfig = {
  endpoint: "admin/devotions/",
  singular: "Devotion",
  plural: "Devotions",
  description:
    "Add a daily home devotion or a one-off reading here. To build a series, open Devotional series and choose Manage readings so each reading is attached to the right series.",
  state: datedPublishState,
  searchPlaceholder: "Search titles, references or authors",
  parentFilter: { name: "series", label: "Series", optionsFrom: seriesOptions },
  columns: [
    {
      header: "Devotion",
      cell: (row) => (
        <>
          <strong>{String(row.title)}</strong>
          <span className="console-cell-sub">{ellipsis(row.author, 60)}</span>
        </>
      ),
    },
    {
      header: "Reading order",
      cell: (row) =>
        row.series_title ? (
          <>
            {String(row.series_title)}
            <span className="console-cell-sub">{row.day ? `Day ${String(row.day)}` : "Introduction"}</span>
          </>
        ) : (
          <span className="console-cell-sub">One-off reading</span>
        ),
    },
    { header: "Scripture", cell: (row) => String(row.scripture_reference ?? "—") },
    {
      header: "Cover",
      cell: (row) => (
        <span className="console-cell-sub">{row.image_url ? "Picture set" : "Brand tile"}</span>
      ),
    },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Publish date", cell: (row) => dateText(row.publish_at) },
    { header: "Length", cell: (row) => countText(row.reading_minutes, "min") },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "title", label: "Title", type: "text", required: true },
    { name: "author", label: "Author", type: "text", placeholder: "UDM Devotions Team" },
    {
      name: "series",
      label: "Series",
      type: "select",
      nullable: true,
      optionsFrom: seriesOptions,
      help: "Which Devotions grid this day belongs to. Empty means a one-off reading that only the home feed shows.",
    },
    {
      name: "day",
      label: "Day",
      type: "number",
      nullable: true,
      help: "Leave blank for the Introduction. Number the remaining readings in the order readers should follow.",
    },
    {
      name: "scripture_reference",
      label: "Scripture reference",
      type: "text",
      help: "Optional for the Introduction. Example: “John 1:1-13”.",
    },
    { name: "scripture_text", label: "Scripture passage", type: "textarea", help: "The quoted Bible passage shown before the reflection. Rich formatting is supported." },
    { name: "excerpt", label: "Home preview", type: "textarea", help: "Short optional text shown in the home feed. For older readings, this also appears as Scripture if the Scripture passage is empty." },
    { name: "body", label: "Reflection and teaching", type: "textarea", required: true, help: "The main reading. Use paragraphs and rich formatting for a comfortable devotional flow." },
    { name: "reflection_questions", label: "Reflection questions", type: "lines", help: "One question per line." },
    { name: "application", label: "Application", type: "textarea", help: "Optional practical response after the reflection." },
    { name: "prayer", label: "Closing prayer", type: "textarea", help: "Optional closing prayer, displayed with an italic devotional style." },
    {
      name: "memory_scripture_reference",
      label: "Memory scripture",
      type: "text",
      help: "A reference the reader may take as a memory verse.",
    },
    { name: "reading_minutes", label: "Reading time", type: "number", default: 5, help: "Minutes shown to the reader." },
    {
      name: "image",
      label: "Cover image",
      type: "image",
      help: "Optional artwork shown with the reading. Uploading a picture replaces the one on the server.",
    },
    {
      name: "image_link",
      label: "Or paste an image link",
      type: "text",
      placeholder: "https://…",
      help: "For a picture the ministry already hosts elsewhere. An uploaded file wins when both are set.",
    },
    {
      name: "publish_at",
      label: "Publish date",
      type: "datetime",
      nullable: true,
      help: "A future date schedules the row; setting it to Live from the list clears the date.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
};

export default function Devotions() {
  return <ResourceScreen config={devotionsConfig} />;
}
