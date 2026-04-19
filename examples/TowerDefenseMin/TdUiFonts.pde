/**
 * CJK-safe UI font for P2D: default bitmap font often has no Chinese glyphs.
 * Also registers the font on {@link UIManager} so {@code render()} applies it every frame.
 */
static final class TdUiFonts {

  static PFont UI_FONT;

  private TdUiFonts() {
  }

  static void init(TowerDefenseMin p, UIManager ui) {
    String[] names = {
      "Microsoft YaHei UI",
      "Microsoft YaHei",
      "SimHei",
      "PingFang SC",
      "SimSun",
      "Dialog",
      "SansSerif"
    };
    UI_FONT = null;
    for (String n : names) {
      try {
        PFont f = p.createFont(n, 18, true);
        if (f != null) {
          UI_FONT = f;
          println("[TowerDefenseMin] UI font: " + n);
          break;
        }
      } catch (RuntimeException ignored) {
      }
    }
    if (UI_FONT == null) {
      String[] list = PFont.list();
      if (list != null && list.length > 0) {
        UI_FONT = p.createFont(list[0], 16);
        println("[TowerDefenseMin] UI font fallback: " + list[0]);
      }
    }
    if (ui != null) {
      ui.setUiFont(UI_FONT);
    }
    if (UI_FONT != null) {
      p.textFont(UI_FONT);
    }
  }

  static void ensureFont(PApplet p) {
    if (UI_FONT != null) {
      p.textFont(UI_FONT);
    }
  }
}
