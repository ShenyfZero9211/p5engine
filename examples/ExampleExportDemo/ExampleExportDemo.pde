void setup() {
  size(640, 360, P2D);
  background(30);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(32);
}

void draw() {
  background(12, 24, 48);
  fill(255);
  text("Example Export Demo", width/2, height/2 - 20);
  fill(100, 200, 255);
  ellipse(width/2, height/2 + 50, 80 + 30 * sin(frameCount * 0.05), 80 + 30 * sin(frameCount * 0.05));
}
