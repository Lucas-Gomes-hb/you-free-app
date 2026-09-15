/// The JavaScript work YouTube requires, as seen by [LocalContentSource].
///
/// Kept free of Flutter imports so the pure-Dart parts of the stack — and the
/// verification script in `tool/` — can be exercised without a WebView.
/// The real implementation is `YoutubeJsEngine`.
abstract class YoutubeJsRuntime {
  /// Loads the player script and returns its signature timestamp.
  Future<int> prepare();

  /// Descrambles a `signatureCipher` `s` value.
  Future<String> solveSignature(String challenge);

  /// Descrambles the throttling `n` parameter.
  Future<String> solveN(String challenge);

  /// Mints a proof-of-origin token bound to [identifier].
  Future<String> mintPoToken(String identifier);
}
