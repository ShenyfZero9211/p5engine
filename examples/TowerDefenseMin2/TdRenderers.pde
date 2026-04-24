/**
 * Render Components for world layer (renderLayer < 100).
 * Drawn inside SceneViewport's off-screen buffer via p5engine renderer.
 */

static class WorldBgRenderer extends RendererComponent {
    protected void renderShape(PGraphics g) {
        LevelDef lv = TdGameWorld.level;
        if (lv == null) return;

        // Grid
        g.stroke(TdTheme.BORDER);
        g.strokeWeight(1);
        g.noFill();
        for (int gx = 0; gx <= lv.worldW; gx += TdConfig.GRID) {
            g.line(gx, 0, gx, lv.worldH);
        }
        for (int gy = 0; gy <= lv.worldH; gy += TdConfig.GRID) {
            g.line(0, gy, lv.worldW, gy);
        }

        // Path with glow
        if (lv.pathPoints != null && lv.pathPoints.length > 1) {
            float t = (System.currentTimeMillis() % 2000) / 2000f;
            // Outer glow
            g.stroke(0xFF4A9EFF);
            g.strokeWeight(18);
            g.strokeCap(PApplet.ROUND);
            g.strokeJoin(PApplet.ROUND);
            for (int i = 1; i < lv.pathPoints.length; i++) {
                g.line(lv.pathPoints[i-1].x, lv.pathPoints[i-1].y,
                       lv.pathPoints[i].x, lv.pathPoints[i].y);
            }
            // Inner core
            g.stroke(0xFF88CCFF);
            g.strokeWeight(8);
            for (int i = 1; i < lv.pathPoints.length; i++) {
                g.line(lv.pathPoints[i-1].x, lv.pathPoints[i-1].y,
                       lv.pathPoints[i].x, lv.pathPoints[i].y);
            }
            // Animated dash — draw from endpoint toward startpoint so that
            // drawn = -offset (negative) keeps dashes visible at segment joints
            // while the visual flow still moves toward the path endpoint.
            g.stroke(0xFFFFFFFF);
            g.strokeWeight(3);
            float dashLen = 40;
            float gapLen = 60;
            float cycle = dashLen + gapLen;
            float offset = t * cycle;
            for (int i = 1; i < lv.pathPoints.length; i++) {
                Vector2 a = lv.pathPoints[i-1];
                Vector2 b = lv.pathPoints[i];
                float segLen = PApplet.dist(a.x, a.y, b.x, b.y);
                // Reverse direction: b -> a, so negative drawn still produces
                // visible dashes near the joint and the pattern flows toward b
                float rdx = (a.x - b.x) / segLen;
                float rdy = (a.y - b.y) / segLen;
                float drawn = -offset;
                while (drawn < segLen) {
                    float start = PApplet.max(0, drawn);
                    float end = PApplet.min(segLen, drawn + dashLen);
                    if (end > start) {
                        g.line(b.x + rdx * start, b.y + rdy * start,
                               b.x + rdx * end, b.y + rdy * end);
                    }
                    drawn += cycle;
                }
            }
        }

        // Base — pulsing blue core with rotating ring
        float time = System.currentTimeMillis() / 1000f;
        float pulse = 1 + 0.15f * PApplet.sin(time * 3);
        g.noStroke();
        // Outer glow
        g.fill(0xFF4A9EFF, 60);
        g.ellipse(lv.basePos.x, lv.basePos.y, 48 * pulse, 48 * pulse);
        // Core
        g.fill(0xFF4A9EFF);
        g.ellipse(lv.basePos.x, lv.basePos.y, 20, 20);
        g.fill(0xFFFFFFFF);
        g.ellipse(lv.basePos.x, lv.basePos.y, 8, 8);
        // Rotating ring
        g.noFill();
        g.stroke(0xFF88CCFF, 180);
        g.strokeWeight(2);
        g.pushMatrix();
        g.translate(lv.basePos.x, lv.basePos.y);
        g.rotate(time * 1.5f);
        g.arc(0, 0, 36, 36, 0, PApplet.PI * 1.3f);
        g.popMatrix();

        // Exit — red X mark
        g.noStroke();
        g.fill(0xFFFF4444, 80);
        g.ellipse(lv.exitPos.x, lv.exitPos.y, 28, 28);
        g.stroke(0xFFFF4444);
        g.strokeWeight(3);
        float ex = 6;
        g.line(lv.exitPos.x - ex, lv.exitPos.y - ex, lv.exitPos.x + ex, lv.exitPos.y + ex);
        g.line(lv.exitPos.x + ex, lv.exitPos.y - ex, lv.exitPos.x - ex, lv.exitPos.y + ex);

        // Spawn — orange pulsing dot
        float sp = 1 + 0.2f * PApplet.sin(time * 4);
        g.noStroke();
        g.fill(0xFFFF8C42, 100);
        g.ellipse(lv.spawnPos.x, lv.spawnPos.y, 20 * sp, 20 * sp);
        g.fill(0xFFFF8C42);
        g.ellipse(lv.spawnPos.x, lv.spawnPos.y, 10, 10);
    }
}

static class EnemyRenderer extends RendererComponent {
    Enemy enemy;
    EnemyRenderer(Enemy enemy) { this.enemy = enemy; }

    protected void renderShape(PGraphics g) {
        if (enemy == null || enemy.hp <= 0) return;

        float x = enemy.pos.x;
        float y = enemy.pos.y;
        float r = enemy.radius;
        float dir = 0;
        if (enemy.path != null) {
            Vector2 d = enemy.path.direction(enemy.pathDistance);
            if (d != null) dir = PApplet.atan2(d.y, d.x);
        }

        g.pushMatrix();
        g.translate(x, y);
        g.rotate(dir);

        // Glow
        g.noStroke();
        if (enemy.state == EnemyState.MOVE_TO_BASE) {
            g.fill(0xFFFF4444, 60);
        } else if (enemy.state == EnemyState.FLEE) {
            g.fill(0xFFFF8C42, 60);
        } else {
            g.fill(0xFF4A9EFF, 60);
        }
        g.ellipse(0, 0, r * 2.8f, r * 2.8f);

        // Body — arrow shape
        if (enemy.state == EnemyState.MOVE_TO_BASE) {
            g.fill(0xFFFF6666);
        } else if (enemy.state == EnemyState.FLEE) {
            g.fill(0xFFFFAA44);
        } else {
            g.fill(0xFF66CCFF);
        }
        g.beginShape();
        g.vertex(r * 1.2f, 0);
        g.vertex(-r * 0.6f, -r * 0.7f);
        g.vertex(-r * 0.3f, 0);
        g.vertex(-r * 0.6f, r * 0.7f);
        g.endShape(PApplet.CLOSE);

        g.popMatrix();

        // HP bar (screen-aligned)
        float barW = r * 2.4f;
        float barH = 5;
        float barX = x - barW * 0.5f;
        float barY = y - r - 12;
        g.noStroke();
        g.fill(0xFF222222, 200);
        g.rect(barX - 1, barY - 1, barW + 2, barH + 2, 2);
        g.fill(0xFF333333);
        g.rect(barX, barY, barW, barH, 2);
        float hpPct = enemy.maxHp > 0 ? enemy.hp / enemy.maxHp : 0;
        int hpColor = hpPct > 0.5f ? 0xFF44FF66 : (hpPct > 0.25f ? 0xFFFFCC44 : 0xFFFF4444);
        g.fill(hpColor);
        g.rect(barX, barY, barW * hpPct, barH, 2);
    }
}

static class TowerRenderer extends RendererComponent {
    Tower tower;
    TowerRenderer(Tower tower) { this.tower = tower; }

    protected void renderShape(PGraphics g) {
        if (tower == null) return;
        float size = TdConfig.GRID * 0.75f;
        float half = size * 0.5f;
        float x = tower.worldX;
        float y = tower.worldY;
        int c = tower.def.iconColor;
        float time = System.currentTimeMillis() / 1000f;

        // Range indicator (very subtle)
        if (tower.built) {
            g.noFill();
            g.stroke(c & 0x40FFFFFF);
            g.strokeWeight(1);
            g.ellipse(x, y, tower.def.range * 2, tower.def.range * 2);
        }

        // Build animation
        if (!tower.built) {
            float prog = tower.buildProgress / tower.def.buildTime;
            float pulse = 1 + 0.15f * PApplet.sin(time * 8);
            g.noStroke();
            g.fill(0xFF444444, 180);
            g.rect(x - half, y - half, size, size, 4);
            g.fill(c, 120);
            g.rect(x - half, y - half, size * prog, size, 4);
            // Building pulse
            g.noFill();
            g.stroke(c, 150);
            g.strokeWeight(2);
            g.rect(x - half * pulse, y - half * pulse, size * pulse, size * pulse, 4);
            return;
        }

        // Tower shadow
        g.noStroke();
        g.fill(0xFF000000, 60);
        g.rect(x - half + 3, y - half + 3, size, size, 4);

        // Tower body by type
        g.noStroke();
        g.fill(c);
        switch (tower.def.type) {
            case MG:
                g.rect(x - half, y - half, size, size, 3);
                g.fill(0xFFFFFFFF, 120);
                g.rect(x - half + 4, y - half + 4, size - 8, 4, 1);
                break;
            case MISSILE:
                g.ellipse(x, y, size, size);
                g.fill(0xFFFFFFFF, 120);
                g.ellipse(x, y, size * 0.4f, size * 0.4f);
                break;
            case LASER:
                g.pushMatrix();
                g.translate(x, y);
                g.rotate(PApplet.PI / 4);
                g.rect(-half, -half, size, size, 3);
                g.popMatrix();
                g.fill(0xFFFFFFFF, 120);
                g.ellipse(x, y, size * 0.3f, size * 0.3f);
                break;
            case SLOW:
                drawHexagon(g, x, y, half * 0.9f);
                g.fill(0xFFFFFFFF, 120);
                g.ellipse(x, y, size * 0.35f, size * 0.35f);
                break;
        }
    }

    private void drawHexagon(PGraphics g, float cx, float cy, float r) {
        g.beginShape();
        for (int i = 0; i < 6; i++) {
            float a = PApplet.TWO_PI / 6 * i - PApplet.PI / 2;
            g.vertex(cx + PApplet.cos(a) * r, cy + PApplet.sin(a) * r);
        }
        g.endShape(PApplet.CLOSE);
    }
}

static class BulletRenderer extends RendererComponent {
    Bullet bullet;
    BulletRenderer(Bullet bullet) { this.bullet = bullet; }

    protected void renderShape(PGraphics g) {
        if (bullet == null || bullet.dead) return;

        float x = bullet.pos.x;
        float y = bullet.pos.y;

        // Trail
        g.noStroke();
        g.fill(0xFFFFFF00, 60);
        g.ellipse(x - bullet.vel.x * 0.02f, y - bullet.vel.y * 0.02f, 5, 5);
        g.fill(0xFFFFFF00, 120);
        g.ellipse(x - bullet.vel.x * 0.01f, y - bullet.vel.y * 0.01f, 3, 3);

        // Core
        g.fill(0xFFFFFFFF);
        g.ellipse(x, y, 4, 4);
    }
}
