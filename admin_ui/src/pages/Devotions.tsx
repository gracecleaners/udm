import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, seriesOptions, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/devotions/",
  singular: "Devotion",
  plural: "Devotions",
  description:
    "One reading. Filed under a series it becomes a numbered day in the Devotions grid; left unfiled it is only "
      + "the daily reading on a student’s home screen. Drafts stay here until you set a row to Live.",
  state: datedPublishState,
  localized: ["title", "excerpt", "body", "reflection_questions", "application", "prayer"],
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
      help: "Day number inside the series. Empty sorts first, which is where an Introduction belongs.",
    },
    {
      name: "scripture_reference",
      label: "Scripture reference",
      type: "text",
      required: true,
      help: "Printed above the reading, for example “John 1:1-13”.",
    },
    { name: "excerpt", label: "Excerpt", type: "textarea", help: "The teaser shown before the reader opens it." },
    { name: "body", label: "Body", type: "textarea", required: true },
    { name: "reflection_questions", label: "Reflection questions", type: "lines", help: "One question per line." },
    { name: "application", label: "Application", type: "textarea" },
    { name: "prayer", label: "Prayer", type: "textarea" },
    {
      name: "memory_scripture_reference",
      label: "Memory scripture",
      type: "text",
      help: "A reference the reader may take as a memory verse.",
    },
    { name: "reading_minutes", label: "Reading time", type: "number", default: 5, help: "Minutes shown to the reader." },
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
  return <ResourceScreen config={config} />;
}
