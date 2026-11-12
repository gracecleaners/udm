import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, type ResourceConfig } from "@/lib/curation";

/**
 * The home screen's "Find resources on" list is this table, in this order. A
 * guide with no published step is hidden from students rather than shown as a
 * row that opens on nothing, so steps are filed against it from the Resource
 * steps screen — the same pairing the Devotions grid uses.
 */
const config: ResourceConfig = {
  endpoint: "admin/resource-topics/",
  singular: "Guide",
  plural: "Resource guides",
  description:
    "One guided answer to a question a student actually asks — Receive Christ, Prayer, The Bible. "
      + "A guide reaches the home list only when it is Live and has at least one published step.",
  state: datedPublishState,
  localized: ["title", "summary"],
  ordering: "order",
  searchPlaceholder: "Search guide titles or summaries",
  columns: [
    {
      header: "Guide",
      cell: (row) => (
        <>
          <strong>{String(row.title)}</strong>
          <span className="console-cell-sub">{ellipsis(row.summary, 90)}</span>
        </>
      ),
    },
    { header: "Steps", cell: (row) => countText(row.step_count, "step") },
    { header: "List position", cell: (row) => String(row.order) },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Publish date", cell: (row) => dateText(row.publish_at) },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    {
      name: "title",
      label: "Title",
      type: "text",
      required: true,
      help: "The row a student taps, so it reads as the question they arrived with.",
    },
    {
      name: "summary",
      label: "Summary",
      type: "textarea",
      help: "Shown above the step list when the guide opens.",
    },
    {
      name: "order",
      label: "Position in the list",
      type: "number",
      default: 1,
      help: "Lowest first. Two guides sharing a position keep the order they were created in.",
    },
    {
      name: "publish_at",
      label: "Publish date",
      type: "datetime",
      nullable: true,
      help: "A future date schedules the guide; setting it to Live from the list clears the date.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  // Students hold progress against these steps, so deleting a guide is the one
  // action the console asks about twice.
  deleteWarning:
    "Its steps are deleted with it, along with every reader’s progress on them. Delete the guide?",
};

export default function ResourceGuides() {
  return <ResourceScreen config={config} />;
}
