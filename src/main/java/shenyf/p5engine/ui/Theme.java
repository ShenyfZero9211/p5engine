package shenyf.p5engine.ui;

import processing.core.PApplet;

public interface Theme {

    void drawPanel(PApplet g, float x, float y, float w, float h, boolean focused);

    void drawFrame(PApplet g, float x, float y, float w, float h);

    void drawWindowChrome(PApplet g, float x, float y, float w, float h, float titleH, String title, boolean focused);

    void drawButton(PApplet g, float x, float y, float w, float h, String label, boolean hover, boolean pressed, boolean disabled);

    void drawCheckbox(PApplet g, float x, float y, float w, float h, String label, boolean checked, boolean hover, boolean disabled);

    void drawRadio(PApplet g, float x, float y, float w, float h, String label, boolean selected, boolean hover, boolean disabled);

    void drawLabel(PApplet g, float x, float y, float w, float h, String text, boolean disabled);

    void drawTextField(PApplet g, float x, float y, float w, float h, String text, int caretIndex, boolean focused, boolean disabled);

    void drawSliderTrack(PApplet g, float x, float y, float w, float h, float value01, boolean hover, boolean disabled);

    void drawScrollBar(PApplet g, float x, float y, float w, float h, float thumbStart, float thumbLen, boolean vertical, boolean hover, boolean disabled);

    void drawProgressBar(PApplet g, float x, float y, float w, float h, float value01, boolean disabled);

    void drawList(PApplet g, float x, float y, float w, float h, java.util.List<String> items, int firstIndex, int selectedIndex, boolean focused, boolean disabled);

    void drawTabHeader(PApplet g, float x, float y, float w, float h, String[] titles, int selected, boolean focused);

    void drawImage(PApplet g, float x, float y, float w, float h, processing.core.PImage img, boolean disabled);
}
