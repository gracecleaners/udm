import { Badge } from "@/components/ui/badge";
import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { dateTimeText } from "@/components/curation/cells";
import type { ResourceConfig } from "@/lib/curation";

/**
 * The roster is read-only by design. `StudentDirectoryView` exposes identity,
 * the staff flag and two counts of public ministry work — it has no write
 * routes at all, because staff status is not a licence to edit or read a
 * student’s discipleship record.
 */
const config: ResourceConfig = {
  endpoint: "admin/students/",
  singular: "Account",
  plural: "Accounts",
  description:
    "Everyone with an account. What each student reads, bookmarks, notes and prays stays private to them: this list carries no part of it.",
  ordering: "-created_at",
  searchPlaceholder: "Search names or email addresses",
  columns: [
    {
      header: "Account",
      cell: (row) => (
        <>
          <strong>{String(row.display_name)}</strong>
          <span className="console-cell-sub">{String(row.email)}</span>
        </>
      ),
    },
    {
      header: "Role",
      cell: (row) => (
        <Badge variant={row.is_superuser ? "default" : row.is_staff ? "secondary" : "outline"}>
          {row.is_superuser ? "Superuser" : row.is_staff ? "Ministry staff" : "Student"}
        </Badge>
      ),
    },
    { header: "Groups led", cell: (row) => String(row.groups_led ?? 0) },
    { header: "Events organised", cell: (row) => String(row.events_organized ?? 0) },
    { header: "Status", cell: (row) => (row.is_active ? "Active" : "Disabled") },
    { header: "Joined", cell: (row) => dateTimeText(row.created_at) },
  ],
  fields: [],
  deletable: false,
};

export default function Students() {
  return <ResourceScreen config={config} />;
}
