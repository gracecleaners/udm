import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, YesNo, ellipsis } from "@/components/curation/cells";
import { activeState, type ResourceConfig } from "@/lib/curation";

const config: ResourceConfig = {
  endpoint: "admin/translations/",
  singular: "Translation",
  plural: "Bible translations",
  description:
    "Scripture records arrive from the licensed sync and from the repository’s scripts, never from a form. "
    + "Showing or hiding an edition is a licensing call, so a platform admin makes it and ministry staff read the result. "
    + "Deleting one would take its verses — and every bookmark and note a student made in them — with it, so deletion "
    + "stays in Django Admin, which lists that collateral first.",
  state: activeState,
  writableBy: "superuser",
  deletable: false,
  searchPlaceholder: "Search names, codes or licences",
  columns: [
    {
      header: "Translation",
      cell: (row) => (
        <>
          <strong>{String(row.name)}</strong>
          <span className="console-cell-sub">{String(row.code)}</span>
        </>
      ),
    },
    {
      header: "Licence",
      cell: (row) => (
        <>
          {String(row.license_name)}
          <span className="console-cell-sub">{ellipsis(row.attribution, 80)}</span>
        </>
      ),
    },
    { header: "Coverage", cell: (row) => `${row.book_count} books · ${row.chapter_count} chapters` },
    { header: "Offline", cell: (row) => <YesNo value={row.offline_allowed} /> },
    { header: "Source", cell: (row) => (row.source_provider ? String(row.source_provider) : "synced locally") },
    { header: "State", cell: (row) => <StateBadge state={row.is_active ? "active" : "inactive"} /> },
  ],
  fields: [],
};

export default function Translations() {
  return <ResourceScreen config={config} />;
}
