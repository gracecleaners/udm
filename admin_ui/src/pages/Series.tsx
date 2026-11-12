import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, type ResourceConfig } from "@/lib/curation";

/**
 * The app's Devotions tab is this table: a two-column grid of covers, and each
 * cover opens the series' published days in reading order. A series with no
 * published day is hidden from students rather than shown as an empty folder,
 * so days are filed against it from the Devotions screen.
 */
const config: ResourceConfig = {
  endpoint: "admin/devotion-series/",
  singular: "Series",
  plural: "Devotional series",
  description:
    "Read-through sets like The Book of James or Christmas. Cover art is loaded from a URL the ministry hosts; "
    + "a series stays hidden until it is Live and has at least one published day.",
  state: datedPublishState,
  localized: ["title", "description"],
  ordering: "order",
  searchPlaceholder: "Search titles or descriptions",
  columns: [
    {
      header: "Series",
      cell: (row) => (
        <>
          <strong>{String(row.title)}</strong>
          <span className="console-cell-sub">{ellipsis(row.description, 90)}</span>
        </>
      ),
    },
    { header: "Days", cell: (row) => countText(row.day_count, "day") },
    { header: "Grid position", cell: (row) => String(row.order) },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Publish date", cell: (row) => dateText(row.publish_at) },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "title", label: "Title", type: "text", required: true },
    {
      name: "description",
      label: "Description",
      type: "textarea",
      help: "Shown under the title when a reader opens the series.",
    },
    {
      name: "cover_image_url",
      label: "Cover image URL",
      type: "text",
      placeholder: "https://…",
      help: "A full https:// URL. Until one is set the app draws the title’s initials on a gold tile.",
    },
    {
      name: "order",
      label: "Position in the grid",
      type: "number",
      default: 1,
      help: "Lowest first. Two series sharing a position keep the order they were created in.",
    },
    {
      name: "publish_at",
      label: "Publish date",
      type: "datetime",
      nullable: true,
      help: "A future date schedules the series; setting it to Live from the list clears the date.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning:
    "The days stay and keep every reader’s progress, but they lose this series and become one-off readings. Delete it?",
};

export default function Series() {
  return <ResourceScreen config={config} />;
}
