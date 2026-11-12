import { ResourceScreen } from "@/components/curation/ResourceScreen";
import { StateBadge, dateText, dateTimeText, durationText, ellipsis } from "@/components/curation/cells";
import { datedPublishState, mediaShelfOptions, type ResourceConfig } from "@/lib/curation";

/**
 * One teaching on one shelf. The video itself stays on YouTube — staff paste
 * the link, the app plays it inline — so this screen writes addresses and
 * wording, never media files, except the optional artwork.
 */
const config: ResourceConfig = {
  endpoint: "admin/media-items/",
  singular: "Recording",
  plural: "Media recordings",
  description:
    "What the Learn tab plays: a recording the ministry put on YouTube, with its write-up underneath. "
      + "Download is offered to students only when a file the ministry hosts is attached here.",
  state: datedPublishState,
  localized: ["title", "excerpt", "body"],
  parentFilter: { name: "collection", label: "Shelf", optionsFrom: mediaShelfOptions },
  searchPlaceholder: "Search titles, authors or write-ups",
  columns: [
    {
      header: "Recording",
      cell: (row) => (
        <>
          <strong>{ellipsis(row.title, 70)}</strong>
          <span className="console-cell-sub">{String(row.author || "No author given")}</span>
        </>
      ),
    },
    {
      header: "Shelf",
      cell: (row) =>
        row.collection_title ? (
          <>
            {String(row.collection_title)}
            <span className="console-cell-sub">{row.order ? `Position ${String(row.order)}` : "Newest first"}</span>
          </>
        ) : (
          <span className="console-cell-sub">No shelf</span>
        ),
    },
    { header: "Length", cell: (row) => durationText(row.duration_seconds) },
    {
      header: "Source",
      cell: (row) => (
        <>
          {row.youtube_url
            ? <span>YouTube</span>
            : <span className="console-cell-sub">No video attached</span>}
          <span className="console-cell-sub">{row.download_url ? "Also a ministry file" : "No download file"}</span>
        </>
      ),
    },
    { header: "State", cell: (row) => <StateBadge state={String(row.publish_state ?? "draft")} /> },
    { header: "Publish date", cell: (row) => dateText(row.publish_at) },
    { header: "Changed", cell: (row) => dateTimeText(row.updated_at) },
  ],
  fields: [
    { name: "title", label: "Title", type: "text", required: true },
    {
      name: "author",
      label: "Author",
      type: "text",
      placeholder: "Edgar Karuma",
      help: "The byline under the title, so students know whose teaching they are opening.",
    },
    {
      name: "collection",
      label: "Shelf",
      type: "select",
      required: true,
      optionsFrom: mediaShelfOptions,
      help: "A recording with no shelf cannot be reached from the Learn tab.",
    },
    {
      name: "order",
      label: "Position on the shelf",
      type: "number",
      nullable: true,
      help: "Lowest first. Left empty, the newest recordings stay at the top of the shelf.",
    },
    {
      name: "excerpt",
      label: "Excerpt",
      type: "textarea",
      help: "The line a student reads before opening the recording.",
    },
    {
      name: "body",
      label: "Write-up",
      type: "textarea",
      wide: true,
      help: "Printed under the player, in paragraphs. This is what stays readable when no video is attached yet.",
    },
    {
      name: "youtube_url",
      label: "YouTube link",
      type: "text",
      placeholder: "https://youtu.be/…",
      help:
        "Paste the address from the YouTube page — watch, youtu.be, shorts, embed or the bare video id. "
          + "The app plays it inside the recording, and plain http is refused.",
    },
    {
      name: "download_url",
      label: "Ministry file",
      type: "text",
      placeholder: "https://…",
      help:
        "Optional https link to a file the ministry distributes itself, such as a sermon mp3. "
          + "Only with a file here does the app offer students a Download button.",
    },
    {
      name: "duration_seconds",
      label: "Length in seconds",
      type: "number",
      nullable: true,
      help: "Total length, so a 15:40 recording is 940. The app prints it as 15:40 and resumes from it.",
    },
    {
      name: "image",
      label: "Artwork",
      type: "image",
      help: "Optional. With none, a YouTube recording shows the thumbnail YouTube already has for it.",
    },
    {
      name: "publish_at",
      label: "Publish date",
      type: "datetime",
      nullable: true,
      help: "A future date schedules the recording; setting it to Live from the list clears the date.",
    },
    { name: "updated_at", label: "Last changed", type: "text", readOnly: true, show: (row) => dateTimeText(row.updated_at) },
  ],
  deleteWarning:
    "The recording goes, along with every student’s note on it and their place in it. Delete it?",
};

export default function MediaItems() {
  return <ResourceScreen config={config} />;
}
