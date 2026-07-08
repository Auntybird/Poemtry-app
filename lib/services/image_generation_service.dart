/// Generates a "Shan Shui" (山水, mountain-water) ink-wash style artwork
/// descriptor for a poem — entirely on-device, for free, with no network
/// call and no API cost.
///
/// No AI image generation API — Gemini's or otherwise — currently offers a
/// genuinely free tier, so rather than either costing money or silently
/// failing, this derives a deterministic seed from the poem text and hands
/// it to [ShanshuiArt] (see widgets/shanshui_painter.dart), which paints an
/// abstract ink-wash landscape locally. Same poem always produces the same
/// image; different poems produce visibly different compositions, palettes,
/// and layouts.
class ImageGenerationService {
  /// Returns a descriptor string encoding the local art seed, e.g.
  /// "local-art:482913". Never fails, never calls the network — kept as
  /// Future<String?> (rather than a plain sync method) so existing call
  /// sites that `await` this don't need to change.
  Future<String?> generateShanshuiPainting(String poemText) async {
    return 'local-art:${deriveSeed(poemText)}';
  }

  /// Combines hashCode with text length for a bit more spread — helps avoid
  /// two different-but-similar-length poems landing on the same hash.
  /// Kept as a static method so StorageService's backfill migration can use
  /// the exact same formula for older entries.
  static int deriveSeed(String text) => (text.hashCode ^ text.length).abs();
}