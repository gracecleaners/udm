import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, type ResourceConfig } from "@/lib/curation";

/**
 * The Learn tab is this table, in this order. A shelf with no published
 * recording is hidden from students rather than shown as a tile that opens on
 * nothing — the same rule the guides follow — so recordings are filed against
 * it from the Media recordings screen.
 */
const config: ResourceConfig = {
  endpoint: "admin/media-collections/",
  singular: "Shelf",
  plural: "Media shelves",
  description:
    "SOMA, Uliza, the podcast — the shelves of teaching recordings the Learn tab opens on. "
      + "A shelf reaches students only when it is Live and holds at least one published recording.",
  state: datedPublishState,
  localized: ["title", "description"],
  ordering: "order",
  searchPlaceholder: "Search shelf titles or descriptions",
  columns: [
    {
      header: "Shelf",
      cell: (row) => (
        <>
          <strong>{String(row.title)}</strong>
          <span className="console-cell-sub">{ellipsis(row.description, 90)}</span>
        </>
      ),
    },
    { header: "Recordings", cell: (row) => countText(row.item_count, "recording", "recordings") },
    { header: "Position", cell: (row) => String(row.order) },
    {
      header: "Artwork",
      cell: (row) =>
        row.image_url
          ? <span className="console-cell-sub">Uploaded</span>
          : <span className="console-cell-sub">Plain tile</span>,
    },
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
      help: "The word on the tile, so it is the name students already use for it.",
    },
    {
      name: "description",
      label: "Description",
      type: "textarea",
      help: "The line under the title, which tells a student what they will find on the shelf.",
    },
    {
      name: "order",
      label: "Position in the Learn tab",
      type: "number",
      default: 1,
      help: "Lowest first. Two shelves sharing a position keep the order they were created in.",
    },
    {
      name: "image",
      label: "Shelf artwork",
      type: "image",
      help: "The picture on the tile. Left empty, the Learn tab draws a plain tile with the shelf’s initial.",
    },
    {
      name: "publish_at",
      label: "Publish date",
      type: "datetime",
      nullable: true,
      help: "A future date schedules the shelf; setting it to Live from the list clears the date.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning:
    "Its recordings go with it, along with every student’s note and place in them. Delete the shelf?",
};

export default function MediaCollections() {
  return <ResourceScreen config={config} />;
}
