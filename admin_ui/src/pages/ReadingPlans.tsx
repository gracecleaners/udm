import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, countText, dateTimeText } from "@/components/curation/cells";
import { simplePublishState, type ResourceConfig } from "@/lib/curation";

const assignments = (planId: string, planTitle: string): ResourceConfig => ({
  endpoint: `admin/reading-plans/${planId}/assignments/`,
  singular: "Reading",
  plural: "Readings",
  description: `Day-by-day passages for “${planTitle}”. The API files each one under this plan.`,
  ordering: "day",
  localized: ["reference"],
  searchPlaceholder: "Search references",
  columns: [
    { header: "Day", cell: (row) => <strong>{String(row.day)}</strong> },
    { header: "Passage", cell: (row) => String(row.reference) },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "day", label: "Day", type: "number", required: true, help: "One reading per day; a duplicate is refused." },
    {
      name: "reference",
      label: "Passage",
      type: "text",
      required: true,
      help: "Written the way the reader should see it, for example “Genesis 1-2; Psalm 1”.",
    },
  ],
  deleteWarning: "Readers’ completion marks for this day go with it. Delete it?",
});

const config: ResourceConfig = {
  endpoint: "admin/reading-plans/",
  singular: "Reading plan",
  plural: "Reading plans",
  description: "Guided scripture plans. A plan with no readings shows students nothing, so add days after creating it.",
  state: simplePublishState,
  localized: ["title", "description"],
  searchPlaceholder: "Search plan titles",
  columns: [
    {
      header: "Plan",
      cell: (row) => (
        <>
          <strong>{String(row.title)}</strong>
          <span className="console-cell-sub">{String(row.description || "No description yet")}</span>
        </>
      ),
    },
    { header: "Readings", cell: (row) => countText(row.assignment_count, "day") },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "title", label: "Title", type: "text", required: true },
    { name: "description", label: "Description", type: "textarea", help: "Why a student would start this plan." },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  child: (row) => ({
    label: "Readings",
    title: () => `Readings — ${String(row.title)}`,
    config: assignments(String(row.id), String(row.title)),
  }),
  deleteWarning: "Every day in this plan and each reader’s progress through them will be deleted. Delete it?",
};

export default function ReadingPlans() {
  return <ResourceScreen config={config} />;
}
