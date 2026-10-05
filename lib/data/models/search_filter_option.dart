/// One refinement chip offered by a search.
///
/// [value] is InnerTube's opaque `params` for that choice *in the context it
/// was listed in*, so picking a second chip means re-listing the options
/// rather than merging two strings.
class SearchFilterOption {
  final String value;
  final String label;
  final String? iconHint;

  const SearchFilterOption({
    required this.value,
    required this.label,
    this.iconHint,
  });
}