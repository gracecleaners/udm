import { Badge } from "@/components/ui/badge";
import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { dateTimeText } from "@/components/curation/cells";
import { capabilitiesText, type ConsoleCapability } from "@/services/authService";
import type { ResourceConfig, StateSpec } from "@/lib/curation";

/**
 * The same two flags the rest of the console switches on, named for people
 * rather than content: suspending keeps an account and its password until
 * somebody returns, which is not the same act as deleting one.
 */
const accessState: StateSpec = {
  current: (row) => (typeof row.is_active === "boolean" ? (row.is_active ? "active" : "inactive") : null),
  options: [
    { value: "active", label: "Can sign in" },
    { value: "inactive", label: "Suspended" },
  ],
  patch: (value) => ({ is_active: value === "active" }),
};

/**
 * The console accounts the platform owner opens for the ministry team.
 *
 * Every row here signs in as staff: it curates content, reads the roster and
 * works the prayer queue, and cannot publish a Bible translation or open
 * another account — the API refuses those with the same list this page was
 * built from. The owner's own superuser rows are not listed, because nothing
 * on this screen is allowed to change or remove one.
 */
const config: ResourceConfig = {
  endpoint: "admin/accounts/",
  singular: "Staff account",
  plural: "Staff accounts",
  description:
    "Who may sign in to this console. A staff account curates content and watches the system; it cannot publish a Bible translation or open another account.",
  writableBy: "superuser",
  state: accessState,
  searchPlaceholder: "Search staff by name or email address",
  columns: [
    {
      header: "Staff member",
      cell: (row) => (
        <>
          <strong>{String(row.display_name)}</strong>
          <span className="console-cell-sub">{String(row.email)}</span>
        </>
      ),
    },
    {
      // Spoken back from the API's own list rather than a second copy of the
      // rules, so this column cannot claim an access the routes refuse.
      header: "May reach",
      cell: (row) => (
        <span className="console-cell-sub">{capabilitiesText(row.capabilities as ConsoleCapability[] | undefined)}</span>
      ),
    },
    {
      header: "Console access",
      cell: (row) => (
        <Badge variant={row.is_active ? "default" : "outline"}>
          {row.is_active ? "Can sign in" : "Suspended"}
        </Badge>
      ),
    },
    { header: "Opened", cell: (row) => dateTimeText(row.created_at) },
  ],
  fields: [
    {
      name: "email",
      label: "Email",
      type: "text",
      required: true,
      help: "The address they sign in with. It cannot already belong to another account.",
    },
    { name: "display_name", label: "Name", type: "text", help: "Shown in their console header." },
    {
      name: "password",
      label: "Password",
      type: "password",
      help: "Set it once when opening the account. Leave it empty when editing to keep the one they already have.",
    },
    { name: "created_at", label: "Opened", type: "text", readOnly: true, show: (row) => dateTimeText(row.created_at) },
  ],
  deleteWarning:
    "Their console access ends at once. Groups and events they led keep their rows but lose their named leader. Delete this staff account?",
};

export default function StaffAccounts() {
  return <ResourceScreen config={config} />;
}
