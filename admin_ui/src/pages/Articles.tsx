import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateText, dateTimeText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/articles/",
  singular: "Article",
  plural: "Articles",
  description: "Longer teaching and testimony pieces. Only Live rows reach the app’s reading list.",
  state: datedPublishState,
  localized: ["title", "excerpt", "body", "category"],
  searchPlaceholder: "Search titles, categories or authors",
  columns: [
    {
      header: "Article",
      cell: (row) => (
        <>
          <strong>{String(row.title)}</strong>
          <span className="console-cell-sub">{ellipsis(row.author, 60)}</span>
        </>
      ),
    },
    { header: "Category", cell: (row) => String(row.category || "—") },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Publish date", cell: (row) => dateText(row.publish_at) },
    { header: "Length", cell: (row) => countText(row.reading_minutes, "min") },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "title", label: "Title", type: "text", required: true },
    { name: "author", label: "Author", type: "text" },
    {
      name: "category",
      label: "Category",
      type: "text",
      help: "Free text. Students filter the reading list on this exact word, so keep spellings consistent.",
    },
    { name: "excerpt", label: "Excerpt", type: "textarea" },
    { name: "body", label: "Body", type: "textarea", required: true },
    { name: "reading_minutes", label: "Reading time", type: "number", default: 5 },
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

export default function Articles() {
  return <ResourceScreen config={config} />;
}
