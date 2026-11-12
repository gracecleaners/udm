import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, dateTimeText, ellipsis } from "@/components/curation/cells";
import { activeState, universityOptions, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/campuses/",
  singular: "Campus",
  plural: "Campuses",
  description:
    "The place a student fellowship actually meets. Groups, fellowships and events are filtered by campus in the student app.",
  state: activeState,
  localized: ["name", "location"],
  parentFilter: { name: "university", label: "University", optionsFrom: universityOptions },
  searchPlaceholder: "Search campuses or universities",
  columns: [
    {
      header: "Campus",
      cell: (row) => (
        <>
          <strong>{String(row.name)}</strong>
          <span className="console-cell-sub">{String(row.university_name ?? "")}</span>
        </>
      ),
    },
    { header: "Location", cell: (row) => ellipsis(row.location, 60) },
    { header: "Fellowships", cell: (row) => String(row.fellowship_count ?? 0) },
    { header: "Groups", cell: (row) => String(row.group_count ?? 0) },
    { header: "Events", cell: (row) => String(row.event_count ?? 0) },
    { header: "State", cell: (row) => <StateBadge state={row.is_active ? "active" : "inactive"} /> },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    {
      name: "university",
      label: "University",
      type: "select",
      required: true,
      optionsFrom: universityOptions,
      show: (row) => String(row.university_name ?? ""),
      help: "Add the university under Universities first; the console only lists what the API has.",
    },
    { name: "name", label: "Campus name", type: "text", required: true, help: "Unique within its university." },
    { name: "location", label: "Where it meets", type: "text" },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning: "Its fellowships and groups are deleted with it, and events lose their campus. Delete the campus?",
};

export default function Campuses() {
  return <ResourceScreen config={config} />;
}
