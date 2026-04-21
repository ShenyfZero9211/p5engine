/**
 * TweenDemo — p5engine Tween 动画功能验证示例
 * 
 * 展示效果：
 * 1. UI Panel 从透明淡入（延迟1秒，持续2秒）
 * 2. 蓝色方块左右往返平移（无限循环）
 * 3. 橙色圆形每2秒缩放弹跳一次
 * 4. 绿色指针持续旋转
 * 5. 点击按钮触发 alpha 脉冲动画
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.ui.*;

P5Engine engine;
UIManager ui;
Scene scene;

GameObject box;
GameObject circle;
GameObject pointer;

Panel panel;
Button pulseBtn;
Label infoLabel;

float nextCircleBounce = 2.0f;

void settings() {
  size(800, 600, P2D);
  smooth(8);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  engine = P5Engine.create(this, P5Config.defaults().logToFile(true));
  engine.getDebugOverlay().toggle(); // 默认开启调试 overlay

  ui = new UIManager(this);
  ui.attach();

  scene = engine.createScene("Demo");
  engine.getSceneManager().loadScene("Demo");

  // ===== UI =====
  panel = new Panel("panel");
  panel.setBounds(20, 20, 260, 280);
  panel.setPaintBackground(true);
  ui.getRoot().add(panel);

  infoLabel = new Label("info");
  infoLabel.setText("Tween Demo\n1. Panel fade-in (delay 1s)\n2. Box moves back & forth\n3. Circle bounces every 2s\n4. Pointer keeps rotating\n5. Click button for pulse");
  infoLabel.setBounds(30, 30, 240, 120);
  panel.add(infoLabel);

  pulseBtn = new Button("pulse");
  pulseBtn.setLabel("Click to Pulse");
  pulseBtn.setBounds(30, 180, 200, 40);
  pulseBtn.setAction(() -> triggerPulse());
  panel.add(pulseBtn);

  // ===== GameObjects =====
  box = GameObject.create("box");
  box.getTransform().setPosition(100, 480);
  scene.addGameObject(box);

  circle = GameObject.create("circle");
  circle.getTransform().setPosition(400, 480);
  circle.getTransform().setScale(0.01f, 0.01f);
  scene.addGameObject(circle);

  pointer = GameObject.create("pointer");
  pointer.getTransform().setPosition(650, 480);
  scene.addGameObject(pointer);

  // ===== 启动 Tween =====
  TweenManager tm = engine.getTweenManager();

  // 1. 面板淡入
  panel.setAlpha(0f);
  tm.toAlpha(panel, 1f, 2.0f)
    .ease(Ease::outQuad)
    .delay(1.0f)
    .start();

  // 2. 方块左右往返平移
  tm.toPosition(box, new Vector2(700, 480), 2.5f)
    .ease(Ease::inOutSine)
    .yoyo(true)
    .repeat(-1)
    .start();

  // 4. 指针持续旋转（50秒转50圈）
  tm.toRotation(pointer, (float) Math.toRadians(360f * 50f), 50f)
    .ease(Ease::linear)
    .start();
}

void draw() {
  background(14, 18, 30);
  engine.update();

  renderGameObjects();

  ui.update(engine.getGameTime().getDeltaTime());
  ui.render();
  engine.renderDebugOverlay();

  // 定时触发圆形弹跳
  float t = engine.getGameTime().getTotalTime();
  if (t >= nextCircleBounce) {
    nextCircleBounce = t + 2.0f;
    triggerCircleBounce();
  }

  // 每 1 秒打印一次状态，验证 Tween 是否在工作
  if (frameCount % 60 == 0) {
    println("[TweenDemo] t=" + nf(t, 1, 2)
      + " | Panel alpha=" + nf(panel.getAlpha(), 1, 2)
      + " | Box x=" + nf(box.getTransform().getPosition().x, 1, 1)
      + " | Circle scale=" + nf(circle.getTransform().getScale().x, 1, 2)
      + " | Pointer rot=" + nf(degrees(pointer.getTransform().getRotation()), 1, 1));
  }
}

void renderGameObjects() {
  pushStyle();

  // 绘制方块
  Vector2 bp = box.getTransform().getPosition();
  fill(100, 200, 255);
  noStroke();
  rectMode(CENTER);
  rect(bp.x, bp.y, 40, 40);

  // 绘制圆形
  Vector2 cp = circle.getTransform().getPosition();
  Vector2 cs = circle.getTransform().getScale();
  fill(255, 130, 80);
  ellipse(cp.x, cp.y, 50 * cs.x, 50 * cs.y);

  // 绘制指针
  Vector2 pp = pointer.getTransform().getPosition();
  float pr = pointer.getTransform().getRotation();
  pushMatrix();
  translate(pp.x, pp.y);
  rotate(pr);
  fill(80, 220, 120);
  noStroke();
  rectMode(CENTER);
  rect(25, 0, 50, 4);
  ellipse(0, 0, 12, 12);
  popMatrix();

  popStyle();
}

void triggerCircleBounce() {
  TweenManager tm = engine.getTweenManager();
  circle.getTransform().setScale(0.01f, 0.01f);
  tm.toScale(circle, new Vector2(1.5f, 1.5f), 0.6f)
    .ease(Ease::outBack)
    .start();
}

void triggerPulse() {
  TweenManager tm = engine.getTweenManager();
  pulseBtn.setAlpha(1f);
  tm.toAlpha(pulseBtn, 0.3f, 0.2f)
    .ease(Ease::outQuad)
    .yoyo(true)
    .repeat(1)
    .start();
}
