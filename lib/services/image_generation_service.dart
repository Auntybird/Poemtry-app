/// Generates a "Shan Shui" (山水, mountain-water) ink-wash style artwork
/// descriptor for a poem — entirely on-device, for free, with no network
/// call and no API cost.
///
/// Historically this called an external paid image API (and had a bug
/// where it even sent the wrong provider's key). No AI image generation API
/// — Gemini's or otherwise — currently offers a genuinely free tier, so
/// rather than either costing money or silently failing, this now derives a
/// deterministic seed from the poem text and hands it to [ShanshuiArt]
/// (see widgets/shanshui_painter.dart), which paints an abstract ink-wash
/// landscape locally. Same poem always produces the same image; different
/// poems look different.
class ImageGenerationService {
  /// Returns a descriptor string encoding the local art seed, e.g.
  /// "local-art:482913". Never fails, never calls the network — kept as
  /// Future<String?> (rather than a plain sync method) so existing call
  /// sites that `await` this don't need to change.
  Future<String?> generateShanshuiPainting(String poemText) async {
    final seed = poemText.hashCode;
    return 'local-art:$seed';
  }
}