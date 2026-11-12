import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { listAll, listPage, type Row } from "@/lib/curation";

/**
 * Chooses the scripture row a memory verse points at.
 *
 * `MemoryVerse.verse` is a primary key nobody can type, and the console must not
 * invent one: it searches the verses the API actually has, which come from the
 * licensed sync rather than from anything authored here.
 */
export function VersePicker({ value, onChange }: {
  value: string;
  onChange: (verseId: string) => void;
}) {
  const [translation, setTranslation] = useState("");
  const [search, setSearch] = useState("");
  const [chapter, setChapter] = useState("");

  const translationsQ = useQuery({
    queryKey: ["verse-translations"],
    queryFn: async () =>
      (await listAll("admin/translations/", { ordering: "name" }))
        .filter((row) => Number(row.chapter_count) > 0)
        .map((row) => ({ value: String(row.code), label: `${String(row.name)} (${String(row.code)})` })),
    staleTime: 10 * 60_000,
  });

  const searching = translation !== "" && (search.trim() !== "" || chapter.trim() !== "");
  const versesQ = useQuery({
    queryKey: ["verse-match", translation, search, chapter],
    queryFn: () =>
      listPage<Row>("admin/verses/", {
        params: {
          translation,
          ...(search.trim() ? { search: search.trim() } : {}),
          ...(chapter.trim() ? { chapter: chapter.trim() } : {}),
        },
      }),
    enabled: searching,
    staleTime: 60_000,
  });

  const matches = versesQ.data?.results ?? [];
  const total = versesQ.data?.count ?? 0;

  return (
    <div className="console-verse-picker">
      <div className="console-verse-filters">
        <Select value={translation} onValueChange={setTranslation}>
          <SelectTrigger aria-label="Translation">
            <SelectValue placeholder={translationsQ.isLoading ? "Loading translations…" : "Translation…"} />
          </SelectTrigger>
          <SelectContent>
            {(translationsQ.data ?? []).map((option) => (
              <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Input
          aria-label="Book name or verse text"
          placeholder="Book or words, e.g. John or loved"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <Input
          aria-label="Chapter number"
          placeholder="Chapter"
          inputMode="numeric"
          className="console-verse-chapter"
          value={chapter}
          onChange={(event) => setChapter(event.target.value.replace(/\D/g, ""))}
        />
      </div>

      {!translationsQ.isLoading && (translationsQ.data?.length ?? 0) === 0 && (
        <p className="console-field-help">
            No translation in this database has synced verses yet, so a memory verse cannot be created here.
        </p>
      )}
      {translationsQ.isError && (
        <p className="console-field-help console-error">The translation list could not be loaded from the API.</p>
      )}
      {!searching && (translationsQ.data?.length ?? 0) > 0 && (
        <p className="console-field-help">Choose a translation, then search for the verse to store.</p>
      )}
      {searching && versesQ.isFetching && (
        <p className="console-field-help"><Loader2 size={13} className="animate-spin" aria-hidden="true" /> Searching scripture…</p>
      )}
      {searching && !versesQ.isFetching && total === 0 && (
        <p className="console-field-help">Nothing in that translation matches. The console will not invent a verse.</p>
      )}
      {searching && total > 0 && (
        <>
          <Select value={value} onValueChange={onChange}>
            <SelectTrigger aria-label="Verse">
              <SelectValue placeholder={`Pick a verse (${total} match${total === 1 ? "" : "es"})`} />
            </SelectTrigger>
            <SelectContent>
              {matches.map((verse) => (
                <SelectItem key={String(verse.id)} value={String(verse.id)}>
                  {`${String(verse.reference)} — ${String(verse.text).slice(0, 90)}`}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {total > matches.length && (
            <p className="console-field-help">Showing the first {matches.length} of {total}; narrow the search for the rest.</p>
          )}
        </>
      )}
    </div>
  );
}
