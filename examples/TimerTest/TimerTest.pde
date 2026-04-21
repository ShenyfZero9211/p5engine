/**
 * TimerTest — p5engine timer system demo.
 * Visual tests for delay, interval, pulse, sequence, pause/resume, progress queries.
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.time.*;
import shenyf.p5engine.tween.*;

P5Engine engine;

Timer delayTimer;
PulseTimer pulseTimer;
Sequence sequence;

int pulseFires = 0;
int intervalTicks = 0;
boolean delayDone = false;
float testStartTime = 0;

// Visual FX arrays
ArrayList<Spark> sparks = new ArrayList<Spark>();
ArrayList<IntervalBlink> blinks = new ArrayList<IntervalBlink>();

class Spark {
  float x, y, born;
  Spark(float x, float y) { this.x = x; this.y = y; this.born = millis(); }
  void draw() {
    float age = (millis() - born) / 300.0f;
    if (age >= 1) return;
    float r = 30 * (1 - age);
    noFill();
    stroke(255, 200, 80, 255 * (1 - age));
    strokeWeight(3);
    ellipse(x, y, r * 2, r * 2);
  }
}

class IntervalBlink {
  float x, y, born;
  IntervalBlink(float x, float y) { this.x = x; this.y = y; this.born = millis(); }
  void draw() {
    float age = (millis() - born) / 400.0f;
    if (age >= 1) return;
    fill(160, 120, 255, 255 * (1 - age));
    noStroke();
    rect(x, y, 20, 20, 4);
  }
}

void settings() {
  size(800, 600, P2D);
  smooth(8);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  engine = P5Engine.create(this, P5Config.defaults().logToFile(true));
  restartTest();
}

void restartTest() {
  pulseFires = 0;
  intervalTicks = 0;
  delayDone = false;
  sparks.clear();
  blinks.clear();
  testStartTime = millis() / 1000.0f;
  println("\n========== Test Restart ==========");

  // 1. Delay
  delayTimer = engine.getScheduler().delay(3.0f, () -> {
    println("[Delay] Action fired after 3s");
    delayDone = true;
  });
  delayTimer.onStart(() -> println("[Delay] onStart"))
           .onComplete(() -> println("[Delay] onComplete"));

  // 2. Interval
  engine.getScheduler().interval(1.0f, 3, () -> {
    intervalTicks++;
    blinks.add(new IntervalBlink(500 + intervalTicks * 40, 260));
    println("[Interval] tick #" + intervalTicks);
  });

  // 3. Pulse
  pulseTimer = engine.getScheduler().pulse(2.0f, 0.4f, () -> {
    pulseFires++;
    sparks.add(new Spark(random(550, 750), random(330, 420)));
    println("[Pulse] fire #" + pulseFires);
  });
  pulseTimer.onComplete(() -> println("[Pulse] onComplete"));

  // 4. Sequence
  UIComponent dummy = new Panel("seq_dummy");
  dummy.setAlpha(0f);
  sequence = engine.getScheduler().sequence()
    .wait(0.5f)
    .run(() -> println("[Sequence] step 1"))
    .tween(engine.getTweenManager().toAlpha(dummy, 1.0f, 1.0f)
           .ease(shenyf.p5engine.tween.Ease::outQuad))
    .wait(0.3f)
    .run(() -> println("[Sequence] step 3"))
    .tween(engine.getTweenManager().toAlpha(dummy, 0.0f, 0.5f)
           .ease(shenyf.p5engine.tween.Ease::inQuad))
    .run(() -> println("[Sequence] step 5 done"));
  sequence.start();
}

void draw() {
  background(14, 18, 30);
  engine.update();

  // Clean up dead FX
  sparks.removeIf(s -> millis() - s.born > 350);
  blinks.removeIf(b -> millis() - b.born > 450);

  int x = 20, y = 30;
  textSize(16);
  fill(255);
  text("Timer System Test — [Space] restart  [+/-] timeScale  [P/R] pause/resume", x, y);
  y += 40;

  // ═══════════════════════════════════════════════
  // 1. Delay (3s)
  // ═══════════════════════════════════════════════
  float dp = delayTimer != null ? delayTimer.getProgress() : 1f;
  boolean dDone = delayTimer != null && delayTimer.isCompleted();
  drawProgressBar(x, y, 360, "Delay (3s)", dp,
    dDone ? color(60, 160, 60) : color(80, 180, 255));
  y += 22;
  text(String.format("  remaining: %.2fs  |  done: %s",
    delayTimer != null ? delayTimer.getRemainingTime() : 0f,
    delayDone ? "YES" : "no"), x, y);
  y += 42;

  // ═══════════════════════════════════════════════
  // 2. Interval (1s x 3)
  // ═══════════════════════════════════════════════
  float ip = intervalTicks / 3.0f;
  drawProgressBar(x, y, 360, "Interval (1s x 3)", ip, color(160, 120, 255));
  y += 22;
  text(String.format("  ticks: %d / 3", intervalTicks), x, y);
  y += 42;

  // ═══════════════════════════════════════════════
  // 3. Pulse (2s, every 0.4s)
  // ═══════════════════════════════════════════════
  float pp = pulseTimer != null ? pulseTimer.getProgress() : 1f;
  boolean pDone = pulseTimer != null && pulseTimer.isCompleted();
  drawProgressBar(x, y, 360, "Pulse (2s, 0.4s interval)", pp,
    pDone ? color(60, 160, 60) : color(255, 180, 80));
  y += 22;
  text(String.format("  fires: %d  |  remaining: %.2fs",
    pulseFires, pulseTimer != null ? pulseTimer.getRemainingTime() : 0f), x, y);
  y += 42;

  // ═══════════════════════════════════════════════
  // 4. Sequence (wait + tween + wait + tween)
  // ═══════════════════════════════════════════════
  float sp = sequence != null ? sequence.getProgress() : 1f;
  boolean sDone = sequence != null && sequence.isCompleted();
  drawProgressBar(x, y, 360, "Sequence (5 steps)", sp,
    sDone ? color(60, 160, 60) : color(120, 200, 120));
  y += 22;
  text(String.format("  step: %d / 5  |  completed: %s",
    sDone ? 5 : (int)(sp * 5) + 1,
    sDone ? "YES" : "no"), x, y);
  y += 50;

  // ═══════════════════════════════════════════════
  // Visual FX area (right side)
  // ═══════════════════════════════════════════════
  for (IntervalBlink b : blinks) b.draw();
  for (Spark s : sparks) s.draw();

  // Sequence orb
  float orbAlpha = sDone ? 80 : (150 + 105 * sin(frameCount * 0.1f));
  noStroke();
  fill(120, 200, 120, orbAlpha);
  ellipse(600, 480, 40, 40);

  // ═══════════════════════════════════════════════
  // Global status
  // ═══════════════════════════════════════════════
  textSize(14);
  fill(200);
  text(String.format("Timers: %d  |  Pulses: %d  |  Sequences: %d  |  timeScale: %.2f  |  elapsed: %.1fs",
    engine.getScheduler().getTimerCount(),
    engine.getScheduler().getPulseTimerCount(),
    engine.getScheduler().getSequenceCount(),
    engine.getGameTime().getTimeScale(),
    millis() / 1000.0f - testStartTime), x, y);

  // Auto-restart
  boolean allDone = (delayTimer == null || delayTimer.isCompleted())
                 && (pulseTimer == null || pulseTimer.isCompleted())
                 && (sequence == null || sequence.isCompleted())
                 && engine.getScheduler().getTimerCount() == 0;
  if (allDone && millis() / 1000.0f - testStartTime > 6.5f) {
    restartTest();
  }
}

/** Unified progress bar renderer. */
void drawProgressBar(int x, int y, int labelW, String label, float progress, int fillC) {
  fill(255);
  textSize(16);
  text(label, x, y);
  int bx = x + labelW;
  int bw = 300;
  noStroke();
  fill(40, 50, 70);
  rect(bx, y - 12, bw, 16, 4);
  fill(fillC);
  rect(bx, y - 12, bw * constrain(progress, 0, 1), 16, 4);
  // percentage text inside bar
  fill(255);
  textSize(12);
  text(String.format("%.0f%%", progress * 100), bx + 4, y);
}

void keyPressed() {
  if (key == ' ') restartTest();
  if (key == 'p' || key == 'P') {
    if (delayTimer != null) delayTimer.pause();
    if (pulseTimer != null) pulseTimer.pause();
    println("[Input] Paused");
  }
  if (key == 'r' || key == 'R') {
    if (delayTimer != null) delayTimer.resume();
    if (pulseTimer != null) pulseTimer.resume();
    println("[Input] Resumed");
  }
  if (key == '=' || key == '+') {
    float s = min(2.0f, engine.getGameTime().getTimeScale() + 0.25f);
    engine.getGameTime().setTimeScale(s);
    println("[Input] timeScale = " + s);
  }
  if (key == '-') {
    float s = max(0.25f, engine.getGameTime().getTimeScale() - 0.25f);
    engine.getGameTime().setTimeScale(s);
    println("[Input] timeScale = " + s);
  }
}
