import shenyf.p5engine.core.*;
import shenyf.p5engine.ui.*;

P5Engine engine;
UIManager ui;
SketchUiCoordinator sketchUi;

PImage sourceImg;
PImage resultImg;
String statusText = "点击【选择图片】加载 PNG";

Label lblStatusRef;
Label lblInfoRef;
Button btnSaveRef;

void settings() {
  size(640, 480);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  engine = P5Engine.create(this);
  engine.setApplicationTitle("CursorMaker - 光标制作工具");

  ui = new UIManager(this);
  ui.attach();
  sketchUi = new SketchUiCoordinator(this, ui);

  buildUi();

  // Auto-load default cursor for demo
  autoLoadDefault();
}

void autoLoadDefault() {
  String defaultPath = sketchPath("../TowerDefenseMin2/cur/cursor.png");
  java.io.File f = new java.io.File(defaultPath);
  if (f.exists()) {
    sourceImg = loadImage(defaultPath);
    if (sourceImg != null) {
      statusText = "已加载: cursor.png (" + sourceImg.width + "x" + sourceImg.height + ")";
      processImage();
      String outPath = sketchPath("../TowerDefenseMin2/cur/cursor_optimized.png");
      if (resultImg != null) {
        resultImg.save(outPath);
        statusText = "已自动保存到: cur/cursor_optimized.png";
      }
    }
  }
}

void buildUi() {
  Panel root = ui.getRoot();

  Window win = new Window("main_win");
  win.setBounds(20, 20, 600, 440);
  win.setTitle("CursorMaker - 光标制作工具");
  win.setMovable(false);
  win.setResizable(false);
  root.add(win);

  Panel panel = new Panel("main_panel");
  panel.setBounds(0, 0, 600, 440);
  panel.setLayoutManager(new AbsoluteLayout());
  win.add(panel);

  // Status label
  Label lblStatus = new Label("lbl_status");
  lblStatus.setText(statusText);
  lblStatus.setBounds(20, 20, 560, 30);
  lblStatus.setTextAlign(PApplet.LEFT);
  panel.add(lblStatus);
  lblStatusRef = lblStatus;

  // Source info
  Label lblInfo = new Label("lbl_info");
  lblInfo.setText("");
  lblInfo.setBounds(20, 55, 560, 24);
  lblInfo.setTextColor(0xFF8899AA);
  panel.add(lblInfo);
  lblInfoRef = lblInfo;

  // Select button
  Button btnSelect = new Button("btn_select");
  btnSelect.setLabel("选择图片");
  btnSelect.setBounds(20, 90, 120, 36);
  btnSelect.setAction(() -> selectInput("选择 PNG 图片", "onFileSelected"));
  panel.add(btnSelect);

  // Save button
  Button btnSave = new Button("btn_save");
  btnSave.setLabel("保存光标");
  btnSave.setBounds(160, 90, 120, 36);
  btnSave.setEnabled(false);
  btnSave.setAction(() -> {
    if (resultImg != null) {
      selectOutput("保存光标 PNG", "onSaveSelected");
    }
  });
  panel.add(btnSave);
  btnSaveRef = btnSave;

  // Result image display (native Processing draw via custom component)
  ImagePreview preview = new ImagePreview("img_preview");
  preview.setBounds(20, 140, 560, 280);
  panel.add(preview);
}

// Callback for selectInput
void onFileSelected(File selection) {
  if (selection == null) return;
  sourceImg = loadImage(selection.getAbsolutePath());
  if (sourceImg == null) {
    statusText = "加载失败: " + selection.getName();
    return;
  }
  statusText = "已加载: " + selection.getName() + "  (" + sourceImg.width + "x" + sourceImg.height + ")";
  processImage();
}

// Callback for selectOutput
void onSaveSelected(File selection) {
  if (selection == null || resultImg == null) return;
  String path = selection.getAbsolutePath();
  if (!path.toLowerCase().endsWith(".png")) {
    path += ".png";
  }
  resultImg.save(path);
  statusText = "已保存: " + path;
}

void processImage() {
  if (sourceImg == null) return;

  sourceImg.loadPixels();

  // Find bounding box of non-transparent pixels
  int minX = sourceImg.width, minY = sourceImg.height;
  int maxX = -1, maxY = -1;

  for (int y = 0; y < sourceImg.height; y++) {
    for (int x = 0; x < sourceImg.width; x++) {
      int idx = y * sourceImg.width + x;
      int a = (sourceImg.pixels[idx] >> 24) & 0xFF;
      if (a > 10) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0) {
    statusText = "错误: 图片完全透明";
    resultImg = null;
    return;
  }

  int cropW = maxX - minX + 1;
  int cropH = maxY - minY + 1;

  // Crop
  PImage cropped = createImage(cropW, cropH, ARGB);
  cropped.copy(sourceImg, minX, minY, cropW, cropH, 0, 0, cropW, cropH);

  // Resize to 32x32 (or 48x48 if original is large)
  int targetSize = (cropW > 100 || cropH > 100) ? 48 : 32;
  resultImg = createImage(targetSize, targetSize, ARGB);
  resultImg.copy(cropped, 0, 0, cropW, cropH, 0, 0, targetSize, targetSize);

  statusText = "裁剪完成: " + cropW + "x" + cropH + " -> " + targetSize + "x" + targetSize;
}

void draw() {
  background(14, 18, 34);
  engine.update();
  sketchUi.renderFrame();

  // Update UI state each frame
  if (lblStatusRef != null) lblStatusRef.setText(statusText);
  if (btnSaveRef != null) btnSaveRef.setEnabled(resultImg != null);
  if (lblInfoRef != null && resultImg != null) {
    lblInfoRef.setText("输出尺寸: " + resultImg.width + " x " + resultImg.height + "  (热点: 0,0)");
  }
}

// Custom component to draw the result image in UI
static class ImagePreview extends UIComponent {
  ImagePreview(String id) { super(id); }

  @Override
  public void paint(PApplet applet, Theme theme) {
    float ax = getAbsoluteX();
    float ay = getAbsoluteY();
    float w = getWidth();
    float h = getHeight();

    // Draw checkerboard background
    applet.noStroke();
    int cs = 16;
    for (int y = 0; y < h; y += cs) {
      for (int x = 0; x < w; x += cs) {
        boolean dark = ((x / cs) + (y / cs)) % 2 == 0;
        applet.fill(dark ? 0xFF2A3045 : 0xFF353B50);
        applet.rect(ax + x, ay + y, cs, cs);
      }
    }

    CursorMaker app = (CursorMaker) P5Engine.getInstance().getApplet();
    if (app.resultImg != null) {
      float scale = Math.min(w / app.resultImg.width, h / app.resultImg.height);
      float drawW = app.resultImg.width * scale;
      float drawH = app.resultImg.height * scale;
      float drawX = ax + (w - drawW) * 0.5f;
      float drawY = ay + (h - drawH) * 0.5f;
      applet.image(app.resultImg, drawX, drawY, drawW, drawH);

      // Draw hotspot indicator
      applet.stroke(0xFFFF4444);
      applet.strokeWeight(2);
      applet.noFill();
      applet.line(drawX - 4, drawY, drawX + 4, drawY);
      applet.line(drawX, drawY - 4, drawX, drawY + 4);
    } else {
      applet.fill(0xFF8899AA);
      applet.textAlign(PApplet.CENTER, PApplet.CENTER);
      applet.textSize(16);
      applet.text("预览区", ax + w * 0.5f, ay + h * 0.5f);
    }
  }
}
