import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, dateTimeText, ellipsis } from "@/components/curation/cells";
import { activeState, campusOptions, memberOptions, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/groups/",
  singular: "Group",
  plural: "Groups",
  description:
    "Discipleship groups: the small circles students meet in week to week. Membership counts here are approved members only.",
  state: activeState,
  localized: ["name", "description", "group_type"],
  parentFilter: { name: "campus", label: "Campus", optionsFrom: campusOptions },
  searchPlaceholder: "Search groups, types or campuses",
  columns: [
    {
      header: "Group",
      cell: (row) => (
        <>
          <strong>{String(row.name)}</strong>
          <span className="console-cell-sub">{[row.campus_name, row.group_type].filter(Boolean).join(" · ")}</span>
        </>
      ),
    },
    { header: "Leader", cell: (row) => ellipsis(row.leader_name, 40) },
    {
      header: "Members",
      cell: (row) => `${row.member_count ?? 0}${row.capacity ? ` / ${row.capacity}` : ""}`,
    },
    { header: "Visibility", cell: (row) => (row.visibility === "private" ? "Members only" : "Discoverable") },
    { header: "State", cell: (row) => <StateBadge state={row.is_active ? "active" : "inactive"} /> },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "name", label: "Name", type: "text", required: true },
    {
      name: "campus",
      label: "Campus",
      type: "select",
      nullable: true,
      optionsFrom: campusOptions,
      show: (row) => String(row.campus_name ?? ""),
      help: "None puts the group outside the campus directory; students then find it only by invitation.",
    },
    { name: "group_type", label: "Type", type: "text", help: "For example “New believers”, “Leadership”, “Prayer”." },
    { name: "description", label: "Description", type: "textarea" },
    {
      name: "leader",
      label: "Leader",
      type: "select",
      nullable: true,
      optionsFrom: memberOptions,
      show: (row) => String(row.leader_name ?? ""),
      help: "Chosen from registered accounts — the roster lists the first 200. Leadership can be left empty and filled in later.",
    },
    {
      name: "visibility",
      label: "Visibility",
      type: "select",
      default: "public",
      options: [
        { value: "public", label: "Discoverable" },
        { value: "private", label: "Members only" },
      ],
    },
    {
      name: "capacity",
      label: "Capacity",
      type: "number",
      nullable: true,
      help: "Blank means no limit. A full group stops accepting join requests.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning: "Its memberships are deleted; prayer requests the group received stay, without a group. Delete it?",
};

export default function Groups() {
  return <ResourceScreen config={config} />;
}
