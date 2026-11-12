import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, YesNo, dateTimeText, ellipsis } from "@/components/curation/cells";
import { activeState, campusOptions, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/fellowships/",
  singular: "Fellowship",
  plural: "Fellowships",
  description:
    "The visible gatherings on a campus. A public fellowship can be found by any student; a private one only by its members.",
  state: activeState,
  localized: ["name", "description", "meeting_schedule"],
  parentFilter: { name: "campus", label: "Campus", optionsFrom: campusOptions },
  searchPlaceholder: "Search fellowships or campuses",
  columns: [
    {
      header: "Fellowship",
      cell: (row) => (
        <>
          <strong>{String(row.name)}</strong>
          <span className="console-cell-sub">{String(row.campus_name ?? "")}</span>
        </>
      ),
    },
    { header: "Meets", cell: (row) => ellipsis(row.meeting_schedule, 60) },
    { header: "Discoverable", cell: (row) => <YesNo value={row.is_public} /> },
    { header: "State", cell: (row) => <StateBadge state={row.is_active ? "active" : "inactive"} /> },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    {
      name: "campus",
      label: "Campus",
      type: "select",
      required: true,
      optionsFrom: campusOptions,
      show: (row) => String(row.campus_name ?? ""),
      help: "Create the campus under Campuses first.",
    },
    { name: "name", label: "Name", type: "text", required: true, help: "Unique on its campus." },
    { name: "description", label: "Description", type: "textarea" },
    {
      name: "meeting_schedule",
      label: "Meeting time",
      type: "text",
      help: "Free text students read as-is, for example “Wednesdays, 18:30, Faculty of Science”.",
    },
    {
      name: "is_public",
      label: "Discoverable by any student",
      type: "switch",
      default: true,
      help: "Off means only people already in it can find it.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning: "Its membership records are deleted with it. Delete the fellowship?",
};

export default function Fellowships() {
  return <ResourceScreen config={config} />;
}
