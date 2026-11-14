/// One verse lifted out of a chapter so it can be read, kept, sized and sent
/// on its own screen.
///
/// It travels as a route argument rather than being looked up again: the app
/// already has the text in hand, the reference came from the server, and a
/// second request would only be able to say the same thing more slowly.
class VerseFocus {
  const VerseFocus({
    required this.reference,
    required this.text,
    this.verseId = '',
    this.translationCode = '',
    this.attribution = '',
  });

  /// The stored row's own id. Empty for a verse the router answered from an
  /// outside version, which cannot be bookmarked or annotated.
  final String verseId;

  /// As the server wrote it — book, chapter and verse together.
  final String reference;
  final String text;
  final String translationCode;

  /// The license line the translation carries, shown so a kept verse still
  /// says where its words came from.
  final String attribution;

  /// Only a stored verse can be kept privately, so the detail screen reads
  /// this before offering a bookmark or a note at all.
  bool get isKeppable => verseId.isNotEmpty;
}
