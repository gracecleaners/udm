import { useEffect, useRef } from "react";
import {
  Bold, Heading2, Italic, List, ListOrdered, Quote, RemoveFormatting, Strikethrough, Underline,
} from "lucide-react";

const ALLOWED = new Set([
  "P", "DIV", "BR", "STRONG", "B", "EM", "I", "U", "S", "STRIKE", "DEL", "UL", "OL", "LI",
  "H1", "H2", "H3", "H4", "BLOCKQUOTE", "SUB", "SUP", "MARK",
]);

function cleanHtml(value: string): string {
  const parsed = new DOMParser().parseFromString(value, "text/html");
  const cleanNode = (node: Node): string => {
    if (node.nodeType === Node.TEXT_NODE) return node.textContent ?? "";
    if (!(node instanceof HTMLElement)) return "";
    const children = Array.from(node.childNodes).map(cleanNode).join("");
    if (!ALLOWED.has(node.tagName)) return children;
    const tag = node.tagName.toLowerCase();
    return tag === "br" ? "<br>" : `<${tag}>${children}</${tag}>`;
  };
  return Array.from(parsed.body.childNodes).map(cleanNode).join("");
}

const actions = [
  { title: "Bold", icon: Bold, command: "bold" },
  { title: "Italic", icon: Italic, command: "italic" },
  { title: "Underline", icon: Underline, command: "underline" },
  { title: "Strikethrough", icon: Strikethrough, command: "strikeThrough" },
  { title: "Heading", icon: Heading2, command: "formatBlock", value: "<h2>" },
  { title: "Bulleted list", icon: List, command: "insertUnorderedList" },
  { title: "Numbered list", icon: ListOrdered, command: "insertOrderedList" },
  { title: "Quote", icon: Quote, command: "formatBlock", value: "<blockquote>" },
  { title: "Clear formatting", icon: RemoveFormatting, command: "removeFormat" },
];

export function RichTextEditor({
  value, onChange, disabled, placeholder,
}: {
  value: string;
  onChange: (value: string) => void;
  disabled?: boolean;
  placeholder?: string;
}) {
  const editor = useRef<HTMLDivElement>(null);
  const initial = useRef(cleanHtml(value));

  useEffect(() => {
    if (editor.current) editor.current.innerHTML = initial.current;
  }, []);

  const run = (command: string, commandValue?: string) => {
    editor.current?.focus();
    document.execCommand(command, false, commandValue);
    if (editor.current) onChange(cleanHtml(editor.current.innerHTML));
  };

  return (
    <div className="console-rich-editor">
      <div className="console-rich-toolbar" role="toolbar" aria-label="Text formatting">
        {actions.map(({ title, icon: Icon, command, value: commandValue }) => (
          <button
            key={title}
            type="button"
            title={title}
            aria-label={title}
            disabled={disabled}
            onMouseDown={(event) => event.preventDefault()}
            onClick={() => run(command, commandValue)}
          >
            <Icon size={16} aria-hidden="true" />
          </button>
        ))}
      </div>
      <div
        ref={editor}
        className="console-rich-content"
        contentEditable={!disabled}
        suppressContentEditableWarning
        data-placeholder={placeholder ?? "Write your text…"}
        onInput={(event) => onChange(cleanHtml(event.currentTarget.innerHTML))}
      />
      <p className="console-field-help">Select text, then use the toolbar for bold, italics, headings, lists, and more.</p>
    </div>
  );
}
