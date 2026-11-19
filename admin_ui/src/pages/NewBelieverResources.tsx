import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/new-believer-resources/",
  singular: "New Believer resource",
  plural: "New Believer resources",
  description:
    "Standalone introductions for someone new to faith: foundational ideas to understand first. These resources are not devotions and do not belong to a Resource Guide.",
  state: datedPublishState,
  ordering: "order",
  searchPlaceholder: "Search resource titles or scripture",
  columns: [
    {
      header: "Resource",
      cell: (row) => (
        <>
          <strong>{String(row.title)}</strong>
          <span className="console-cell-sub">{ellipsis(row.excerpt, 90)}</span>
        </>
      ),
    },
    { header: "Position", cell: (row) => String(row.order) },
    { header: "Scripture", cell: (row) => String(row.scripture_reference ?? "—") },
    { header: "Length", cell: (row) => countText(row.reading_minutes, "min") },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Publish date", cell: (row) => dateText(row.publish_at) },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "title", label: "Title", type: "text", required: true },
    { name: "author", label: "Author", type: "text", placeholder: "UDM Ministry Team" },
    { name: "order", label: "Position", type: "number", default: 1, help: "Lowest first." },
    { name: "scripture_reference", label: "Scripture reference", type: "text" },
    { name: "excerpt", label: "Introduction", type: "textarea", help: "A short preview shown in the app." },
    { name: "body", label: "Resource content", type: "textarea", required: true, wide: true },
    { name: "reading_minutes", label: "Reading time", type: "number", default: 5 },
    {
      name: "image",
      label: "Cover image",
      type: "image",
      help: "Optional artwork shown with this introduction resource.",
    },
    { name: "image_link", label: "Or use an image URL", type: "text", placeholder: "https://…" },
    {
      name: "video_url",
      label: "Video URL",
      type: "text",
      placeholder: "https://…",
      help: "Optional secure link to a ministry teaching.",
    },
    {
      name: "publish_at",
      label: "Publish date",
      type: "datetime",
      nullable: true,
      help: "A future date schedules this resource.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning: "This introduction resource and its reader progress will be deleted. Delete it?",
};

export default function NewBelieverResources() {
  return <ResourceScreen config={config} />;
}
