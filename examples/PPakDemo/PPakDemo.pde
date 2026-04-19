/**
 * PPakDemo - PPAK Library Test Sketch
 *
 * Tests the shenyf.p5engine.resource.ppak library.
 *
 * Usage:
 * 1. Run this sketch in Processing
 * 2. Create data/data.ppak using tools/ppak/ppak_pack.py (optional, falls back to data/ dir)
 * 3. Press 1: Images | 2: Video | SPACE: Music | C: Cache | T: Temp
 */

import shenyf.p5engine.resource.ppak.*;
import ddf.minim.*;
import processing.video.*;

PPak ppak;
Minim minim;
AudioPlayer bgMusic;
PImage soldier, enemy, rockDamage;
PFont chineseFont;
Movie myVideo;

void setup() {
  size(800, 600);
  frameRate(60);

  println("=== PPak Demo ===");

  ppak = PPak.getInstance();
  ppak.init(this);

  if (!ppak.isReady()) {
    println("WARNING: PPAK not found or invalid, using data/ fallback");
  } else {
    println("PPak ready! Files in package: " + ppak.count());
  }

  println("Loading resources...");

  soldier = ppak.image("data/Mask_3x_Soldier.png");
  enemy = ppak.image("data/Mask_3x_Saboteur.png");
  rockDamage = ppak.image("data/Mask_3x_RockDamage.png");
  chineseFont = ppak.font("data/Text.ttf", 32);

  println("Images loaded: soldier=" + (soldier != null && soldier.width > 1) + " enemy=" + (enemy != null && enemy.width > 1));
  println("Font loaded: " + (chineseFont != null));

  minim = new Minim(this);
  String bgmFile = ppak.audioFile("data/begin.mp3");
  if (bgmFile != null) {
    bgMusic = minim.loadFile(bgmFile);
    if (bgMusic != null) {
      bgMusic.loop();
      println("Audio loaded and playing!");
    } else {
      println("Audio failed to load");
    }
  } else {
    println("Audio file not found");
  }

  println("Loading video...");
  String videoPath = ppak.moviePath("data/video.mp4");
  if (videoPath != null) {
    myVideo = new Movie(this, videoPath);
    myVideo.loop();
    println("Video loaded and playing!");
  } else {
    println("Video file not found");
  }

  if (chineseFont != null) {
    textFont(chineseFont);
  }

  println("=== Test Complete ===");
}

int displayMode = 1;

void draw() {
  background(30, 40, 60);

  textAlign(CENTER, CENTER);
  textSize(48);
  fill(255);
  text("PPak Test", width/2, 50);

  if (displayMode == 0) {
    drawImageDemo();
  } else if (displayMode == 1) {
    drawVideoDemo();
  }

  textSize(16);
  fill(150);
  text("Press 1: Images | 2: Video | SPACE: Music | C: Cache | T: Temp", width/2, height - 30);
  text("shenyf.p5engine.resource.ppak v1.0.0", width/2, height - 15);
}

void drawImageDemo() {
  textSize(20);
  fill(200);
  text("Image Loading Test", width/2, 110);

  int y = 180;

  if (soldier != null && soldier.width > 1) {
    image(soldier, width/2 - 150, y, 64, 64);
    fill(255);
    textSize(16);
    text("Soldier", width/2 - 150, y + 80);
  }

  if (enemy != null && enemy.width > 1) {
    image(enemy, width/2, y, 64, 64);
    fill(255);
    textSize(16);
    text("Enemy", width/2, y + 80);
  }

  if (rockDamage != null && rockDamage.width > 1) {
    image(rockDamage, width/2 + 150, y, 64, 64);
    fill(255);
    textSize(16);
    text("RockDamage", width/2 + 150, y + 80);
  }

  fill(100, 200, 255);
  textSize(32);
  text("中文字体测试 Chinese Font", width/2, 350);

  fill(255, 100, 100);
  textSize(24);
  text("Score: 12345  HP: 5", width/2, 400);
}

void drawVideoDemo() {
  textSize(20);
  fill(200);
  text("Video Playing Test", width/2, 110);

  if (myVideo != null) {
    myVideo.read();
    image(myVideo, width/2 - 160, 150, 320, 180);

    fill(100, 200, 255);
    textSize(16);
    text("Video: " + (myVideo.isPlaying() ? "Playing" : "Paused/Stopped") +
         " | Time: " + String.format("%.1f", myVideo.time()) + "s", width/2, 340);
  } else {
    fill(100);
    textSize(16);
    text("Video: Not loaded", width/2, 240);
  }

  textSize(16);
  text("Video controls: SPACE - pause/resume, V - stop, L - loop", width/2, 370);
}

boolean musicPlaying = true;

void keyPressed() {
  if (key == '1') {
    displayMode = 0;
    println("Switched to Image Demo");
  } else if (key == '2') {
    displayMode = 1;
    println("Switched to Video Demo");
  } else if (key == ' ') {
    if (bgMusic != null) {
      if (musicPlaying) {
        bgMusic.pause();
        musicPlaying = false;
        println("Music paused");
      } else {
        bgMusic.loop();
        musicPlaying = true;
        println("Music resumed");
      }
    }
    if (myVideo != null) {
      if (myVideo.isPlaying()) {
        myVideo.pause();
        println("Video paused");
      } else {
        myVideo.play();
        println("Video resumed");
      }
    }
  } else if (key == 'v' || key == 'V') {
    if (myVideo != null) {
      myVideo.stop();
      println("Video stopped");
    }
  } else if (key == 'l' || key == 'L') {
    if (myVideo != null) {
      myVideo.loop();
      println("Video looping");
    }
  } else if (key == 'c' || key == 'C') {
    ppak.clearCache();
    println("Cache cleared!");
  } else if (key == 't' || key == 'T') {
    ppak.clearTempFiles();
    println("Temp files cleared!");
  }
}

void stop() {
  if (ppak != null) {
    ppak.cleanup();
  }
  if (bgMusic != null) {
    bgMusic.close();
  }
  if (minim != null) {
    minim.stop();
  }
  if (myVideo != null) {
    myVideo.dispose();
  }
  super.stop();
}