/**
 * Defense Grid–inspired HUD: dark translucent panels, cyan borders, orange hover accent.
 * Delegates uncommon widgets to {@link DefaultTheme} after applying {@link TdUiFonts}.
 */
static final class TdSciFiTheme implements Theme {

  private final DefaultTheme base = new DefaultTheme();
  private float currentAlpha = 1.0f;

  @Override
  public void setCurrentAlpha(float alpha) {
    this.currentAlpha = alpha;
  }

  private int ca(PApplet g, int r, int gr, int b) {
    return g.color(r, gr, b, (int)(255 * currentAlpha));
  }
  private int ca(PApplet g, int r, int gr, int b, int a) {
    return g.color(r, gr, b, (int)(a * currentAlpha));
  }

  private static void font(PApplet g) {
    if (TdUiFonts.UI_FONT != null) {
      g.textFont(TdUiFonts.UI_FONT);
    }
  }

  @Override
  public void drawPanel(PApplet g, float x, float y, float w, float h, boolean focused) {
    font(g);
    g.pushStyle();
    g.noStroke();
    g.fill(ca(g, 10, 18, 34, 218));
    g.rect(x, y, w, h);
    int border = focused ? ca(g, 72, 220, 255) : ca(g, 70, 140, 168);
    g.stroke(border);
    g.strokeWeight(1);
    g.noFill();
    g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
    g.popStyle();
  }

  @Override
  public void drawButton(PApplet g, float x, float y, float w, float h, String label, boolean hover, boolean pressed, boolean disabled) {
    font(g);
    g.pushStyle();
    int fillBg = disabled ? ca(g, 28, 28, 32, 200)
      : (pressed ? ca(g, 24, 48, 72, 240) : (hover ? ca(g, 18, 36, 58, 235) : ca(g, 14, 24, 44, 228)));
    g.noStroke();
    g.fill(fillBg);
    g.rect(x, y, w, h);
    int strokeCol = disabled ? ca(g, 80, 90, 100)
      : (hover || pressed ? ca(g, 255, 130, 55) : ca(g, 72, 190, 215));
    g.stroke(strokeCol);
    g.strokeWeight(hover ? 2 : 1);
    g.noFill();
    g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
    int tx = disabled ? ca(g, 140, 145, 155) : (hover ? ca(g, 255, 248, 235) : ca(g, 232, 238, 245));
    g.fill(tx);
    g.textAlign(PApplet.CENTER, PApplet.CENTER);
    float ts = Math.max(13f, Math.min(17f, h * 0.48f));
    g.textSize(ts);
    g.text(label != null ? label : "", x + w * 0.5f, y + h * 0.5f);
    g.popStyle();
  }

  @Override
  public void drawLabel(PApplet g, float x, float y, float w, float h, String text, boolean disabled, int textAlign) {
    font(g);
    g.pushStyle();
    g.fill(disabled ? ca(g, 130, 135, 145) : ca(g, 255, 135, 70));
    g.noStroke();
    boolean centerTitle = text != null && text.startsWith("p5engine");
    float ts = Math.max(13f, Math.min(22f, h * 0.55f));
    g.textSize(ts);
    if (centerTitle) {
      g.textAlign(PApplet.CENTER, PApplet.CENTER);
      g.text(text, x + w * 0.5f, y + h * 0.5f);
    } else if (text != null && text.indexOf('\n') >= 0) {
      // 多行文本：使用文本框模式，在限定宽高内自动换行
      g.textAlign(textAlign, PApplet.TOP);
      g.textLeading(ts * 1.25f);
      g.text(text, x + 4, y + 4, w - 8, h - 8);
    } else {
      g.textAlign(textAlign, PApplet.CENTER);
      float tx;
      if (textAlign == PApplet.LEFT) {
        tx = x + 6;
      } else if (textAlign == PApplet.RIGHT) {
        tx = x + w - 6;
      } else {
        tx = x + w * 0.5f;
      }
      g.text(text != null ? text : "", tx, y + h * 0.5f);
    }
    g.popStyle();
  }

  @Override
  public void drawSliderTrack(PApplet g, float x, float y, float w, float h, float value01, boolean hover, boolean disabled) {
    font(g);
    g.pushStyle();
    float v = value01;
    if (v < 0) v = 0;
    if (v > 1) v = 1;
    g.noStroke();
    g.fill(ca(g, disabled ? 30 : 18, disabled ? 30 : 26, disabled ? 32 : 40, 220));
    g.rect(x, y + h * 0.35f, w, h * 0.3f);
    g.fill(ca(g, disabled ? 80 : 0, disabled ? 80 : 200, disabled ? 90 : 220, disabled ? 120 : 200));
    g.rect(x, y + h * 0.35f, w * v, h * 0.3f);
    float knobX = x + w * v;
    g.stroke(hover && !disabled ? ca(g, 255, 140, 60) : ca(g, 100, 180, 205));
    g.strokeWeight(1);
    g.fill(ca(g, disabled ? 90 : 220, disabled ? 90 : 240, disabled ? 95 : 255));
    g.ellipse(knobX, y + h * 0.5f, h * 0.55f, h * 0.55f);
    g.popStyle();
  }

  @Override
  public void drawFrame(PApplet g, float x, float y, float w, float h) {
    font(g);
    g.pushStyle();
    base.drawFrame(g, x, y, w, h);
    g.popStyle();
  }

  @Override
  public void drawWindowChrome(PApplet g, float x, float y, float w, float h, float titleH, String title, boolean focused) {
    font(g);
    g.pushStyle();
    g.noStroke();
    g.fill(ca(g, 12, 20, 38, 245));
    g.rect(x, y, w, titleH);
    g.fill(ca(g, 10, 16, 30, 230));
    g.rect(x, y + titleH, w, h - titleH);
    g.stroke(focused ? ca(g, 72, 220, 255) : ca(g, 70, 130, 155));
    g.strokeWeight(1);
    g.noFill();
    g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
    g.fill(ca(g, 255, 125, 55));
    g.textAlign(PApplet.LEFT, PApplet.CENTER);
    g.textSize(Math.min(15f, titleH * 0.55f));
    g.text(title != null ? title : "", x + 8, y + titleH * 0.5f);
    g.popStyle();
  }

  @Override
  public void drawCheckbox(PApplet g, float x, float y, float w, float h, String label, boolean checked, boolean hover, boolean disabled) {
    font(g);
    g.pushStyle();
    base.drawCheckbox(g, x, y, w, h, label, checked, hover, disabled);
    g.popStyle();
  }

  @Override
  public void drawRadio(PApplet g, float x, float y, float w, float h, String label, boolean selected, boolean hover, boolean disabled) {
    font(g);
    g.pushStyle();
    base.drawRadio(g, x, y, w, h, label, selected, hover, disabled);
    g.popStyle();
  }

  @Override
  public void drawTextField(PApplet g, float x, float y, float w, float h, String text, int caretIndex, boolean focused, boolean disabled) {
    font(g);
    g.pushStyle();
    base.drawTextField(g, x, y, w, h, text, caretIndex, focused, disabled);
    g.popStyle();
  }

  @Override
  public void drawScrollBar(PApplet g, float x, float y, float w, float h, float thumbStart, float thumbLen, boolean vertical, boolean hover, boolean disabled) {
    font(g);
    g.pushStyle();
    base.drawScrollBar(g, x, y, w, h, thumbStart, thumbLen, vertical, hover, disabled);
    g.popStyle();
  }

  @Override
  public void drawProgressBar(PApplet g, float x, float y, float w, float h, float value01, boolean disabled) {
    font(g);
    g.pushStyle();
    base.drawProgressBar(g, x, y, w, h, value01, disabled);
    g.popStyle();
  }

  @Override
  public void drawList(PApplet g, float x, float y, float w, float h, java.util.List<String> items, int firstIndex, int selectedIndex, boolean focused, boolean disabled) {
    font(g);
    g.pushStyle();
    base.drawList(g, x, y, w, h, items, firstIndex, selectedIndex, focused, disabled);
    g.popStyle();
  }

  @Override
  public void drawTabHeader(PApplet g, float x, float y, float w, float h, String[] titles, int selected, boolean focused) {
    font(g);
    g.pushStyle();
    base.drawTabHeader(g, x, y, w, h, titles, selected, focused);
    g.popStyle();
  }

  @Override
  public void drawImage(PApplet g, float x, float y, float w, float h, processing.core.PImage img, boolean disabled) {
    g.pushStyle();
    base.drawImage(g, x, y, w, h, img, disabled);
    g.popStyle();
  }
}
