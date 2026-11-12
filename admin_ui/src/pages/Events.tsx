import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, dateTimeText, ellipsis } from "@/components/curation/cells";
import { campusOptions, eventState, memberOptions, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/events/",
  singular: "Event",
  plural: "Events",
  description:
    "Conferences, crusades and campus nights. Only Published events reach the student app, and a cancelled one keeps its registration list for the record.",
  state: eventState,
  localized: ["title", "description", "location"],
  parentFilter: { name: "campus", label: "Campus", optionsFrom: campusOptions },
  searchPlaceholder: "Search events, venues or campuses",
  columns: [
    {
      header: "Event",
      cell: (row) => (
        <>
          <strong>{String(row.title)}</strong>
          <span className="console-cell-sub">{[row.campus_name, row.location].filter(Boolean).join(" · ")}</span>
        </>
      ),
    },
    { header: "Starts", cell: (row) => `${dateTimeText(row.starts_at)} ${String(row.timezone ?? "")}` },
    { header: "Organiser", cell: (row) => ellipsis(row.organizer_name, 30) },
    { header: "Registered", cell: (row) => `${row.registration_count ?? 0}${row.capacity ? ` / ${row.capacity}` : ""}` },
    { header: "State", cell: (row) => <StateBadge state={String(row.status ?? "draft")} /> },
  ],
  fields: [
    { name: "title", label: "Title", type: "text", required: true },
    { name: "description", label: "Description", type: "textarea" },
    {
      name: "campus",
      label: "Campus",
      type: "select",
      nullable: true,
      optionsFrom: campusOptions,
      show: (row) => String(row.campus_name ?? ""),
      help: "None lists the event as ministry-wide rather than on one campus.",
    },
    {
      name: "organizer",
      label: "Organiser",
      type: "select",
      nullable: true,
      optionsFrom: memberOptions,
      show: (row) => String(row.organizer_name ?? ""),
      help: "The contact students see. Chosen from registered accounts, first 200 listed.",
    },
    { name: "starts_at", label: "Starts", type: "datetime", required: true },
    { name: "ends_at", label: "Ends", type: "datetime", nullable: true, help: "Must be after the start; the API enforces it." },
    {
      name: "timezone",
      label: "Time zone",
      type: "text",
      default: "UTC",
      help: "An IANA name such as “Africa/Kampala”. Dates shown to students follow it.",
    },
    { name: "location", label: "Venue", type: "text" },
    {
      name: "online_url",
      label: "Online link",
      type: "text",
      help: "HTTPS only. Leave blank for an in-person event.",
    },
    { name: "capacity", label: "Capacity", type: "number", nullable: true, help: "Blank means unlimited." },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning: "Registrations students made for this event are deleted with it. Delete it?",
};

export default function Events() {
  return <ResourceScreen config={config} />;
}
