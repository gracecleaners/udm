import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, topicOptions, type ResourceConfig } from "@/lib/curation";

/**
 * One part of a guided answer. The app works through these in the order staff
 * number them, and an unnumbered step is read first — that is where a guide's
 * starting point belongs.
 */
const config: ResourceConfig = {
  endpoint: "admin/resource-steps/",
  singular: "Step",
  plural: "Resource steps",
  description:
    "A step is one screen of a guide: the teaching, the verse it stands on, and the video the ministry chose "
      + "to attach. Nothing plays inside the app, so an empty video link means the reader sees no Watch control.",
  state: datedPublishState,
  localized: ["title", "excerpt", "body"],
  searchPlaceholder: "Search titles, references or authors",
  parentFilter: { name: "topic", label: "Guide", optionsFrom: topicOptions },
  columns: [
    {
      header: "Step",
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
        row.topic_title ? (
          <>
            {String(row.topic_title)}
            <span className="console-cell-sub">{row.order ? `Step ${String(row.order)}` : "Starting point"}</span>
          </>
        ) : (
          <span className="console-cell-sub">No guide</span>
        ),
    },
    { header: "Scripture", cell: (row) => String(row.scripture_reference ?? "—") },
    {
      header: "Video",
      cell: (row) => (row.video_url ? ellipsis(row.video_url, 46) : <span className="console-cell-sub">None</span>),
    },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Publish date", cell: (row) => dateText(row.publish_at) },
    { header: "Length", cell: (row) => countText(row.reading_minutes, "min") },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "title", label: "Title", type: "text", required: true },
    { name: "author", label: "Author", type: "text", placeholder: "UDM Ministry Team" },
    {
      name: "topic",
      label: "Guide",
      type: "select",
      required: true,
      optionsFrom: topicOptions,
      help: "Which guide this belongs to. A step cannot be reached without one.",
    },
    {
      name: "order",
      label: "Step number",
      type: "number",
      nullable: true,
      help: "Position inside the guide. Empty sorts first, which is where a starting point belongs.",
    },
    {
      name: "scripture_reference",
      label: "Scripture reference",
      type: "text",
      help: "Printed above the reading, for example “Acts 17:27-28”.",
    },
    { name: "excerpt", label: "Excerpt", type: "textarea", help: "The line the reader sees before opening the step." },
    { name: "body", label: "Body", type: "textarea", required: true, wide: true },
    {
      name: "video_url",
      label: "Video URL",
      type: "text",
      placeholder: "https://…",
      help:
        "A full https:// link the ministry hosts; the app opens it in the device’s browser and stores nothing. "
          + "Plain http is refused.",
    },
    { name: "reading_minutes", label: "Reading time", type: "number", default: 5, help: "Minutes shown to the reader." },
    {
      name: "publish_at",
      label: "Publish date",
      type: "datetime",
      nullable: true,
      help: "A future date schedules the step; setting it to Live from the list clears the date.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning: "The step goes, along with every reader’s progress on it. Delete it?",
};

export default function ResourceSteps() {
  return <ResourceScreen config={config} />;
}
