/**
 * ImageLab — p5engine image viewer + light editor (stress test sketch).
 * Uses: P5Engine (time), UIManager (toolbar + PPak list), optional PPak images.
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.resource.ppak.*;

import java.io.File;

final int TOOLBAR_H = 52;
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

Panel toolbar;
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

void settings() {
  size(960, 720);
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
  root.setLayoutManager(new BorderLayout());

  toolbar = new Panel("toolbar");
  toolbar.setLayoutManager(new FlowLayout(8, 6, false));
  toolbar.setPaintBackground(true);

  Button bOpen = new Button("btn_open");
  bOpen.setLabel("Open…");
  bOpen.setSize(92, CTRL_H);
  bOpen.setAction(() -> selectInput("Choose image", "onFileSelected"));
  toolbar.add(bOpen);

  Button bFit = new Button("btn_fit");
  bFit.setLabel("Fit");
  bFit.setSize(56, CTRL_H);
  bFit.setAction(() -> fitToView());
  toolbar.add(bFit);

  Button b100 = new Button("btn_100");
  b100.setLabel("1:1");
  b100.setSize(52, CTRL_H);
  b100.setAction(() -> {
    viewScale = 1;
    syncZoomSlider();
  });
  toolbar.add(b100);

  Button bSave = new Button("btn_save");
  bSave.setLabel("Export PNG…");
  bSave.setSize(124, CTRL_H);
  bSave.setAction(() -> selectOutput("Save composite PNG", "onSaveSelected"));
  toolbar.add(bSave);

  Button bUndo = new Button("btn_undo");
  bUndo.setLabel("Undo");
  bUndo.setSize(64, CTRL_H);
  bUndo.setAction(() -> undoOnce());
  toolbar.add(bUndo);

  zoomSlider = new Slider("zoom_sl");
  zoomSlider.setSize(150, CTRL_H);
  zoomSlider.setValue(scaleToSlider(viewScale));
  toolbar.add(zoomSlider);

  brushSlider = new Slider("brush_sl");
  brushSlider.setSize(120, CTRL_H);
  brushSlider.setValue(0.12f);
  toolbar.add(brushSlider);

  rbBrush = new RadioButton("rb_brush");
  rbBrush.setGroupId("tool");
  rbBrush.setLabel("Brush");
  rbBrush.setSize(96, CTRL_H);
  rbBrush.setSelected(true);
  toolbar.add(rbBrush);

  rbEraser = new RadioButton("rb_eraser");
  rbEraser.setGroupId("tool");
  rbEraser.setLabel("Eraser");
  rbEraser.setSize(100, CTRL_H);
  toolbar.add(rbEraser);

  lblPath = new Label("lbl_path");
  lblPath.setText(currentPath);
  lblPath.setSize(220, CTRL_H);
  toolbar.add(lblPath);

  toolbar.setSize(width, TOOLBAR_H);
  root.add(toolbar, BorderLayout.NORTH);

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
    westStrip.setSize(WEST_W, max(280, height - TOOLBAR_H - 24));
    root.add(westStrip, BorderLayout.WEST);
  }

  root.invalidateLayout();
}

void draw() {
  if (width != lastW || height != lastH) {
    lastW = width;
    lastH = height;
    toolbar.setSize(width, TOOLBAR_H);
    if (westStrip != null) {
      westStrip.setSize(WEST_W, max(280, height - TOOLBAR_H - 24));
    }
    ui.getRoot().invalidateLayout();
  }

  handlePpakListSelection();
  readZoomFromSlider();

  background(34);

  float west = ppakReady ? WEST_W : 0;
  float cx = west + (width - west) * 0.5f;
  float cy = TOOLBAR_H + (height - TOOLBAR_H) * 0.5f;

  drawImageStack(cx, cy);

  engine.update();
  ui.update(engine.getGameTime().getDeltaTime());
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
  // clip(x,y,w,h) 在 Processing 里会按当前 imageMode 解释；上一帧末尾若仍为 CENTER，
  // 这里会被当成「中心+宽高」导致裁剪框错位（只露一条等异常）。见 PGraphics.clip。
  pushStyle();
  imageMode(CORNER);
  clip(west, TOOLBAR_H, width - west, height - TOOLBAR_H);
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
  PImage img = loadImage(f.getAbsolutePath());
  if (img != null) {
    currentPath = f.getAbsolutePath();
    baseImage = img.get();
    lastPpakSelection = -1;
    rebuildEditLayer();
    fitToView();
    lblPath.setText(shorten(currentPath, 48));
    ui.getRoot().invalidateLayout();
  }
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
  float vh = height - TOOLBAR_H;
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
  return my >= TOOLBAR_H && mx >= west && mx < width && my < height;
}

void mousePressed() {
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
  if (mouseX < west || mouseY < TOOLBAR_H) return;
  float c = e.getCount();
  viewScale *= (1f + c * 0.1f);
  viewScale = constrain(viewScale, 0.05f, 20f);
  syncZoomSlider();
}

void paintAt(int sx, int sy, boolean first) {
  float west = ppakReady ? WEST_W : 0;
  float cx = west + (width - west) * 0.5f;
  float cy = TOOLBAR_H + (height - TOOLBAR_H) * 0.5f;
  float lx = (sx - cx - viewPanX) / viewScale;
  float ly = (sy - cy - viewPanY) / viewScale;
  float bx = lx + baseImage.width * 0.5f;
  float by = ly + baseImage.height * 0.5f;
  if (bx < 0 || by < 0 || bx >= baseImage.width || by >= baseImage.height) return;

  editLayer.beginDraw();
  float r = getBrushRadius();
  if (rbEraser != null && rbEraser.isSelected()) {
    // 当前 Processing 核心 PConstants 无 blendMode(ERASE)，见 D:\Processing\src\core\...\PConstants.java
    eraseCircleTransparentOnPGraphics(editLayer, bx, by, r);
  } else {
    editLayer.blendMode(BLEND);
    editLayer.noStroke();
    editLayer.fill(255, 60, 80, 140);
    editLayer.ellipse(bx, by, r * 2, r * 2);
  }
  editLayer.endDraw();
}

/** 在已有 beginDraw 的 PGraphics 上把圆内像素改为全透明（替代不存在的 ERASE 混合模式）。 */
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
