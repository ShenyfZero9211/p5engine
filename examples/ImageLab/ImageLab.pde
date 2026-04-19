/**
 * ImageLab — p5engine image viewer + light editor (stress test sketch).
 * Uses: P5Engine (time), UIManager (menu bar + tool strip + PPak list), optional PPak images.
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.resource.ppak.*;

import java.io.File;

final int MENU_BAR_H = 24;
final int TOOL_STRIP_H = 40;
final int TOP_CHROME_VGAP = 2;
final int TOP_CHROME_H = MENU_BAR_H + TOP_CHROME_VGAP + TOOL_STRIP_H;
final int WEST_W = 200;
final float CTRL_H = 36;
final int UNDO_MAX = 24;

P5Engine engine;
UIManager ui;

PImage baseImage;
PGraphics editLayer;
String currentPath = "(no file)";

float viewPanX, viewPanY;
float viewScale = 1f;
boolean panning;
float panAnchorX, panAnchorY;

ArrayList<PGraphics> undoStack = new ArrayList<PGraphics>();

Panel topChrome;
MenuBar mainMenu;
Panel toolStrip;
Panel westStrip;
Slider zoomSlider;
Slider brushSlider;
Label lblPath;
List ppakList;
boolean ppakReady;
int lastPpakSelection = -1;
int lastW, lastH;

RadioButton rbBrush;
RadioButton rbEraser;

// Merged into one class ImageLab: keep a single settings method in this folder (one .pde or merge tabs).

void settings() {
  // P2D + min pixelDensity 2: on some Windows setups displayDensity() stays 1 at 125%/150% scale;
  // default JAVA2D can still look soft. Offscreen edit/snap layers stay JAVA2D below.
  // smooth() must live here with P2D (not in setup): otherwise the preprocessor injects a second settings().
  size(960, 720, P2D);
  smooth(8);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  surface.setTitle("ImageLab (p5engine)");

  engine = P5Engine.create(this);
  ui = new UIManager(this);
  ui.attach();

  initPpak();
  buildUi();
  lastW = width;
  lastH = height;
}

void initPpak() {
  ppakReady = false;
  File local = new File(sketchPath("data/data.ppak"));
  if (local.exists()) {
    PPak.getInstance().init(this);
  } else {
    File alt = new File(sketchPath("../PPakDemo/data/data.ppak"));
    if (alt.exists()) {
      PPak.getInstance().init(this, alt.getAbsolutePath());
    } else {
      println("[ImageLab] No data.ppak (tried data/data.ppak and ../PPakDemo/data/data.ppak)");
      return;
    }
  }
  ppakReady = PPak.getInstance().isReady();
  if (ppakReady) {
    println("[ImageLab] PPak ready, entries=" + PPak.getInstance().count());
  }
}

void buildUi() {
  Panel root = ui.getRoot();
  root.removeAllChildren();
  root.setLayoutManager(null);

  topChrome = new Panel("top_chrome");
  topChrome.setLayoutManager(new BorderLayout());
  topChrome.setPaintBackground(true);
  topChrome.setZOrder(40);

  mainMenu = new MenuBar("imagelab_menu");
  mainMenu.setSize(width, MENU_BAR_H);
  Menu mFile = mainMenu.addMenu("File");
  mFile.addItem("Open…", () -> selectInput("Choose image", "onFileSelected"));
  mFile.addItem("Export PNG…", () -> selectOutput("Save composite PNG", "onSaveSelected"));
  Menu mEdit = mainMenu.addMenu("Edit");
  mEdit.addItem("Undo", () -> undoOnce());
  mEdit.addItem("Redo", () -> {
  }, false);
  Menu mView = mainMenu.addMenu("View");
  mView.addItem("Fit on screen", () -> fitToView());
  mView.addItem("Actual pixels (1:1)", () -> {
    viewScale = 1;
    syncZoomSlider();
  });

  topChrome.add(mainMenu, BorderLayout.NORTH);

  toolStrip = new Panel("tool_strip");
  toolStrip.setLayoutManager(new FlowLayout(8, 6, false));
  toolStrip.setPaintBackground(true);

  Button bFit = new Button("btn_fit");
  bFit.setLabel("Fit");
  bFit.setSize(56, CTRL_H);
  bFit.setAction(() -> fitToView());
  toolStrip.add(bFit);

  Button b100 = new Button("btn_100");
  b100.setLabel("1:1");
  b100.setSize(52, CTRL_H);
  b100.setAction(() -> {
    viewScale = 1;
    syncZoomSlider();
  });
  toolStrip.add(b100);

  zoomSlider = new Slider("zoom_sl");
  zoomSlider.setSize(150, CTRL_H);
  zoomSlider.setValue(scaleToSlider(viewScale));
  toolStrip.add(zoomSlider);

  brushSlider = new Slider("brush_sl");
  brushSlider.setSize(120, CTRL_H);
  brushSlider.setValue(0.12f);
  toolStrip.add(brushSlider);

  rbBrush = new RadioButton("rb_brush");
  rbBrush.setGroupId("tool");
  rbBrush.setLabel("Brush");
  rbBrush.setSize(96, CTRL_H);
  rbBrush.setSelected(true);
  toolStrip.add(rbBrush);

  rbEraser = new RadioButton("rb_eraser");
  rbEraser.setGroupId("tool");
  rbEraser.setLabel("Eraser");
  rbEraser.setSize(100, CTRL_H);
  toolStrip.add(rbEraser);

  lblPath = new Label("lbl_path");
  lblPath.setText(currentPath);
  lblPath.setSize(220, CTRL_H);
  toolStrip.add(lblPath);

  topChrome.add(toolStrip, BorderLayout.CENTER);

  topChrome.setSize(width, TOP_CHROME_H);
  root.add(topChrome);

  westStrip = null;
  if (ppakReady) {
    westStrip = new Panel("west");
    westStrip.setLayoutManager(new BorderLayout());
    westStrip.setPaintBackground(true);

    Label lw = new Label("lbl_ppak");
    lw.setText("PPak images");
    lw.setSize(WEST_W - 8, 28);
    westStrip.add(lw, BorderLayout.NORTH);

    ppakList = new List("ppak_list");
    String[] all = PPak.getInstance().list();
    if (all != null) {
      for (String p : all) {
        String lower = p.toLowerCase();
        if (lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
          ppakList.addItem(p);
        }
      }
    }

    ScrollPane sp = new ScrollPane("ppak_scroll");
    sp.getViewport().setLayoutManager(null);
    sp.getViewport().add(ppakList);
    ppakList.setBounds(4, 4, WEST_W - 12, 4000);

    westStrip.add(sp, BorderLayout.CENTER);
    westStrip.setSize(WEST_W, max(280, height - TOP_CHROME_H - 24));
    westStrip.setZOrder(0);
    root.add(westStrip);
  }

  root.invalidateLayout();
}

void draw() {
  if (width != lastW || height != lastH) {
    lastW = width;
    lastH = height;
    topChrome.setSize(width, TOP_CHROME_H);
    if (westStrip != null) {
      westStrip.setSize(WEST_W, max(280, height - TOP_CHROME_H - 24));
    }
    ui.getRoot().invalidateLayout();
  }

  handlePpakListSelection();
  readZoomFromSlider();

  background(34);

  float west = ppakReady ? WEST_W : 0;
  float cx = west + (width - west) * 0.5f;
  float cy = TOP_CHROME_H + (height - TOP_CHROME_H) * 0.5f;

  drawImageStack(cx, cy);

  engine.update();
  ui.update(engine.getGameTime().getDeltaTime());
  topChrome.setBounds(0, 0, width, TOP_CHROME_H);
  if (westStrip != null) {
    westStrip.setBounds(0, TOP_CHROME_H, WEST_W, height - TOP_CHROME_H);
  }
  topChrome.layout(this);
  if (westStrip != null) {
    westStrip.layout(this);
  }
  ui.render();
}

void readZoomFromSlider() {
  if (zoomSlider == null) return;
  viewScale = sliderToScale(zoomSlider.getValue());
}

float getBrushRadius() {
  if (brushSlider == null) return 10f;
  return 2f + brushSlider.getValue() * 48f;
}

float scaleToSlider(float sc) {
  float t = (sc - 0.05f) / (8f - 0.05f);
  return constrain(t, 0, 1);
}

float sliderToScale(float v) {
  return 0.05f + constrain(v, 0, 1) * (8f - 0.05f);
}

void syncZoomSlider() {
  if (zoomSlider != null) {
    zoomSlider.setValue(scaleToSlider(viewScale));
  }
}

void drawImageStack(float cx, float cy) {
  if (baseImage == null) {
    fill(120);
    textAlign(CENTER, CENTER);
    text("Open an image or pick from PPak list", cx, cy);
    return;
  }

  float west = ppakReady ? WEST_W : 0;
  pushStyle();
  imageMode(CORNER);
  clip(west, TOP_CHROME_H, width - west, height - TOP_CHROME_H);
  pushMatrix();
  translate(cx + viewPanX, cy + viewPanY);
  scale(viewScale);
  imageMode(CENTER);
  image(baseImage, 0, 0);
  if (editLayer != null) {
    image(editLayer, 0, 0);
  }
  popMatrix();
  noClip();
  popStyle();
}

void handlePpakListSelection() {
  if (!ppakReady || ppakList == null) return;
  int sel = ppakList.getSelectedIndex();
  if (sel < 0 || sel == lastPpakSelection) return;
  lastPpakSelection = sel;
  String path = ppakList.getItems().get(sel);
  PImage img = PPak.getInstance().image(path);
  if (img != null && img.width > 1 && img.height > 1) {
    currentPath = "[PPak] " + path;
    baseImage = img.get();
    rebuildEditLayer();
    fitToView();
    lblPath.setText(shorten(currentPath, 48));
    ui.getRoot().invalidateLayout();
  }
}

void onFileSelected(File f) {
  if (f == null) return;
  String path = f.getAbsolutePath();
  PImage img = loadImage(path);
  if (img == null) {
    println("[ImageLab] loadImage returned null: " + path);
    return;
  }
  if (img.width < 1 || img.height < 1) {
    println("[ImageLab] loadImage unusable size " + img.width + "x" + img.height + ": " + path);
    return;
  }
  currentPath = path;
  baseImage = img.get();
  lastPpakSelection = -1;
  rebuildEditLayer();
  fitToView();
  lblPath.setText(shorten(currentPath, 48));
  ui.getRoot().invalidateLayout();
}

void onSaveSelected(File f) {
  if (f == null || baseImage == null) return;
  String path = f.getAbsolutePath();
  if (!path.toLowerCase().endsWith(".png")) {
    path = path + ".png";
  }
  PGraphics out = createGraphics(baseImage.width, baseImage.height, JAVA2D);
  out.beginDraw();
  out.image(baseImage, 0, 0);
  if (editLayer != null) {
    out.image(editLayer, 0, 0);
  }
  out.endDraw();
  out.save(path);
  println("[ImageLab] Saved " + path);
}

String shorten(String s, int max) {
  if (s == null) return "";
  if (s.length() <= max) return s;
  return s.substring(0, max - 3) + "...";
}

void rebuildEditLayer() {
  undoStack.clear();
  if (baseImage == null) {
    editLayer = null;
    return;
  }
  editLayer = createGraphics(baseImage.width, baseImage.height, JAVA2D);
  editLayer.beginDraw();
  editLayer.clear();
  editLayer.endDraw();
}

void fitToView() {
  if (baseImage == null) return;
  float west = ppakReady ? WEST_W : 0;
  float vw = width - west;
  float vh = height - TOP_CHROME_H;
  float sx = vw / (float) baseImage.width;
  float sy = vh / (float) baseImage.height;
  viewScale = constrain(min(sx, sy) * 0.92f, 0.05f, 8f);
  viewPanX = viewPanY = 0;
  syncZoomSlider();
}

void pushUndoSnapshot() {
  if (editLayer == null) return;
  PGraphics snap = createGraphics(editLayer.width, editLayer.height, JAVA2D);
  snap.beginDraw();
  snap.image(editLayer, 0, 0);
  snap.endDraw();
  undoStack.add(snap);
  while (undoStack.size() > UNDO_MAX) {
    undoStack.remove(0);
  }
}

void undoOnce() {
  if (undoStack.isEmpty() || editLayer == null) return;
  PGraphics snap = undoStack.remove(undoStack.size() - 1);
  editLayer.beginDraw();
  editLayer.image(snap, 0, 0);
  editLayer.endDraw();
}

boolean overCanvas(int mx, int my) {
  float west = ppakReady ? WEST_W : 0;
  return my >= TOP_CHROME_H && mx >= west && mx < width && my < height;
}

void mousePressed() {
  if (mainMenu != null && mainMenu.closePopupsIfClickOutside(mouseX, mouseY)) {
    return;
  }

  if (!overCanvas(mouseX, mouseY)) return;
  if (mouseButton == CENTER || (mouseButton == LEFT && keyPressed && key == ' ')) {
    panning = true;
    panAnchorX = mouseX - viewPanX;
    panAnchorY = mouseY - viewPanY;
    return;
  }
  if (mouseButton == LEFT && baseImage != null && editLayer != null) {
    pushUndoSnapshot();
    paintAt(mouseX, mouseY, true);
  }
}

void mouseDragged() {
  if (panning) {
    viewPanX = mouseX - panAnchorX;
    viewPanY = mouseY - panAnchorY;
    return;
  }
  if (mouseButton == LEFT && baseImage != null && editLayer != null && overCanvas(mouseX, mouseY)) {
    paintAt(mouseX, mouseY, false);
  }
}

void mouseReleased() {
  panning = false;
}

void mouseWheel(MouseEvent e) {
  float west = ppakReady ? WEST_W : 0;
  if (mouseX < west || mouseY < TOP_CHROME_H) return;
  float c = e.getCount();
  viewScale *= (1f + c * 0.1f);
  viewScale = constrain(viewScale, 0.05f, 20f);
  syncZoomSlider();
}

void paintAt(int sx, int sy, boolean first) {
  float west = ppakReady ? WEST_W : 0;
  float cx = west + (width - west) * 0.5f;
  float cy = TOP_CHROME_H + (height - TOP_CHROME_H) * 0.5f;
  float lx = (sx - cx - viewPanX) / viewScale;
  float ly = (sy - cy - viewPanY) / viewScale;
  float bx = lx + baseImage.width * 0.5f;
  float by = ly + baseImage.height * 0.5f;
  if (bx < 0 || by < 0 || bx >= baseImage.width || by >= baseImage.height) return;

  editLayer.beginDraw();
  float r = getBrushRadius();
  if (rbEraser != null && rbEraser.isSelected()) {
    eraseCircleTransparentOnPGraphics(editLayer, bx, by, r);
  } else {
    editLayer.blendMode(BLEND);
    editLayer.noStroke();
    editLayer.fill(255, 60, 80, 140);
    editLayer.ellipse(bx, by, r * 2, r * 2);
  }
  editLayer.endDraw();
}

void eraseCircleTransparentOnPGraphics(PGraphics g, float cx, float cy, float rad) {
  g.loadPixels();
  int w = g.width;
  int h = g.height;
  int x0 = max(0, (int) floor(cx - rad - 1));
  int x1 = min(w - 1, (int) ceil(cx + rad + 1));
  int y0 = max(0, (int) floor(cy - rad - 1));
  int y1 = min(h - 1, (int) ceil(cy + rad + 1));
  float r2 = rad * rad;
  int transparent = color(0, 0, 0, 0);
  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      float dx = x + 0.5f - cx;
      float dy = y + 0.5f - cy;
      if (dx * dx + dy * dy <= r2) {
        g.pixels[y * w + x] = transparent;
      }
    }
  }
  g.updatePixels();
}
