import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, type ResourceConfig } from "@/lib/curation";
import { devotionsConfig } from "@/pages/Devotions";

/**
 * The app's Devotions tab is this table: a two-column grid of covers, and each
 * cover opens the series' published readings in order. Staff can manage those
 * readings directly from the series row so the parent relationship is clear.
 */
const config: ResourceConfig = {
  endpoint: "admin/devotion-series/",
  singular: "Series",
  plural: "Devotional series",
  description:
    "Create a series cover first, then use Manage readings on that row to add its optional Introduction and numbered days. Both the series and its readings need to be live before students see them.",
  state: datedPublishState,
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
    { header: "Readings", cell: (row) => countText(row.day_count, "reading") },
    { header: "Display order", cell: (row) => String(row.order) },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Publish date", cell: (row) => dateText(row.publish_at) },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  child: (row) => ({
    label: "Manage readings",
    title: () => `Readings · ${String(row.title)}`,
    config: {
      ...devotionsConfig,
      singular: "Reading",
      plural: "Series readings",
      description:
        "These readings are automatically filed under this series. Leave Day blank for the Introduction; number the remaining days from 1 upward.",
      fixedParent: {
        name: "series",
        value: String(row.id),
        label: String(row.title),
      },
      parentFilter: undefined,
      columns: devotionsConfig.columns.filter((column) => column.header !== "Reading order"),
      fields: devotionsConfig.fields?.filter(
        (field) => !["series", "author", "excerpt"].includes(field.name),
      ),
      deleteWarning: "Delete this reading from the series? Reader progress for this reading will also be removed.",
    },
  }),
  fields: [
    { name: "title", label: "Series name", type: "text", required: true },
    {
      name: "description",
      label: "Series overview",
      type: "textarea",
      help: "A short overview shown at the top of this series’ reading list.",
    },
    { name: "image", label: "Series cover image", type: "image", help: "Artwork for this series’ card in the mobile Devotions tab." },
    { name: "image_link", label: "Cover image URL (optional)", type: "text", placeholder: "https://…", help: "Use this when you do not have an image file to upload. Uploaded artwork takes priority." },
    {
      name: "order",
      label: "Display order",
      type: "number",
      default: 1,
      help: "Lower numbers appear earlier in the mobile Devotions grid.",
    },
    {
      name: "publish_at",
      label: "Publish or schedule date",
      type: "datetime",
      nullable: true,
      help: "Leave blank to publish now when you set the status to Live. A future date schedules the series.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning:
    "Deleting a series unfiles its readings; they will no longer appear in this series for students. Delete it?",
};

export default function Series() {
  return <ResourceScreen config={config} />;
}
