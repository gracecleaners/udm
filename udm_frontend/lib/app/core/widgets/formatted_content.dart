import 'package:flutter/material.dart';

/// Displays ministry-authored text from the admin editor. Only the small set
/// of formatting tags produced by that editor is interpreted; unsupported
/// markup is shown as plain text, never as executable content.
class FormattedContent extends StatelessWidget {
  const FormattedContent(
    this.content, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String content;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  static final _tokenPattern = RegExp(r'<[^>]*>|[^<]+');
  static final _tagPattern = RegExp(r'^<\s*(/?)\s*([a-zA-Z0-9]+)[^>]*>$');
  static final _blockTags = {'p', 'div', 'h1', 'h2', 'h3', 'h4', 'blockquote', 'ul', 'ol', 'li'};

  String _decode(String value) => value
      .replaceAll('&nbsp;', '\u00a0')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'");

  List<InlineSpan> _spans(TextStyle base) {
    final safeContent = content.replaceAll(
      RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      '',
    );
    final stack = <String>[];
    final spans = <InlineSpan>[];
    var previousWasNewline = true;

    void newline() {
      if (!previousWasNewline && spans.isNotEmpty) spans.add(const TextSpan(text: '\n'));
      previousWasNewline = true;
    }

    for (final match in _tokenPattern.allMatches(safeContent)) {
      final token = match.group(0)!;
      if (!token.startsWith('<')) {
        if (token.isEmpty) continue;
        final weight = stack.any((tag) => {'strong', 'b', 'h1', 'h2', 'h3', 'h4'}.contains(tag))
            ? FontWeight.w700
            : base.fontWeight;
        final italic = stack.any((tag) => {'em', 'i', 'blockquote'}.contains(tag));
        final underline = stack.contains('u');
        final strike = stack.any((tag) => {'s', 'strike', 'del'}.contains(tag));
        final marked = stack.contains('mark');
        final text = _decode(token);
        spans.add(TextSpan(
          text: text,
          style: base.copyWith(
            fontWeight: weight,
            fontStyle: italic ? FontStyle.italic : base.fontStyle,
            decoration: TextDecoration.combine([
              if (underline) TextDecoration.underline,
              if (strike) TextDecoration.lineThrough,
            ]),
            backgroundColor: marked ? const Color(0xFFFFF0A6) : null,
          ),
        ));
        previousWasNewline = text.endsWith('\n');
        continue;
      }

      final parsed = _tagPattern.firstMatch(token);
      if (parsed == null) continue;
      final closing = parsed.group(1) == '/';
      final tag = parsed.group(2)!.toLowerCase();
      if (tag == 'br') {
        spans.add(const TextSpan(text: '\n'));
        previousWasNewline = true;
      } else if (closing) {
        if (_blockTags.contains(tag)) newline();
        final index = stack.lastIndexOf(tag);
        if (index >= 0) stack.removeRange(index, stack.length);
      } else {
        if (_blockTags.contains(tag)) newline();
        if (tag == 'li') {
          spans.add(const TextSpan(text: '•  '));
          previousWasNewline = false;
        }
        if ({'h1', 'h2', 'h3', 'h4'}.contains(tag)) {
          // Headings are bold in the same reading size to preserve the page's
          // typography while retaining the editor's heading hierarchy.
        }
        if (!token.endsWith('/>')) stack.add(tag);
      }
    }
    while (spans.isNotEmpty && spans.last is TextSpan && (spans.last as TextSpan).text == '\n') {
      spans.removeLast();
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.bodyMedium!;
    return Text.rich(
      TextSpan(style: effectiveStyle, children: _spans(effectiveStyle)),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
