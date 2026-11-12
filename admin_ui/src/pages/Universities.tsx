import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateTimeText } from "@/components/curation/cells";
import { activeState, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/universities/",
  singular: "University",
  plural: "Universities",
  description: "The institutions this ministry works with. Campuses, groups and events are all filed under one.",
  state: activeState,
  localized: ["name", "country", "city"],
  searchPlaceholder: "Search universities by name, city or country",
  columns: [
    {
      header: "University",
      cell: (row) => (
        <>
          <strong>{String(row.name)}</strong>
          <span className="console-cell-sub">{[row.city, row.country].filter(Boolean).join(", ")}</span>
        </>
      ),
    },
    { header: "Country", cell: (row) => String(row.country) },
    { header: "Campuses", cell: (row) => countText(row.campus_count, "campus", "campuses") },
    { header: "State", cell: (row) => <StateBadge state={row.is_active ? "active" : "inactive"} /> },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "name", label: "Name", type: "text", required: true, help: "Stored once: a duplicate name is refused." },
    { name: "country", label: "Country", type: "text", required: true },
    { name: "city", label: "City", type: "text" },
    {
      name: "website",
      label: "Website",
      type: "text",
      help: "Full link including https://. The API refuses anything else.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning: "Its campuses go with it, and every group, fellowship and event filed under them. Delete the university?",
};

export default function Universities() {
  return <ResourceScreen config={config} />;
}
