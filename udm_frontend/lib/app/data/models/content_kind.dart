/// Which kind of published item a progress row refers to, matching the API's
/// `kind` choices on `POST /api/v1/progress/`.
enum ContentKind {
  devotional('devotional'),
  article('article'),
  resourceStep('resource_step');

  const ContentKind(this.value);

  final String value;
}
