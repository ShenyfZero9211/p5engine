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

        // Path with glow — draw all routes (new multi-path format) or legacy pathPoints
        float t = (System.currentTimeMillis() % 2000) / 2000f;
        Vector2[][] routesToDraw = null;
        if (lv.paths != null && lv.paths.length > 0) {
            routesToDraw = new Vector2[lv.paths.length][];
            for (int r = 0; r < lv.paths.length; r++) {
                routesToDraw[r] = lv.paths[r].path.points;
            }
        } else if (lv.pathPoints != null && lv.pathPoints.length > 1) {
            routesToDraw = new Vector2[][]{ lv.pathPoints };
        }
        if (routesToDraw != null) {
            for (Vector2[] pts : routesToDraw) {
                if (pts == null || pts.length < 2) continue;
                // Outer glow
                g.stroke(0xFF4A9EFF, 100);
                g.strokeWeight(14);
                g.strokeCap(PApplet.ROUND);
                g.strokeJoin(PApplet.ROUND);
                for (int i = 1; i < pts.length; i++) {
                    g.line(pts[i-1].x, pts[i-1].y, pts[i].x, pts[i].y);
                }
                // Inner core
                g.stroke(0xFF88CCFF, 120);
                g.strokeWeight(6);
                for (int i = 1; i < pts.length; i++) {
                    g.line(pts[i-1].x, pts[i-1].y, pts[i].x, pts[i].y);
                }
                // Animated dash
                g.stroke(0xFFFFFFFF, 160);
                g.strokeWeight(2);
                float dashLen = 40;
                float gapLen = 60;
                float cycle = dashLen + gapLen;
                float offset = t * cycle;
                for (int i = 1; i < pts.length; i++) {
                    Vector2 a = pts[i-1];
                    Vector2 b = pts[i];
                    float segLen = PApplet.dist(a.x, a.y, b.x, b.y);
                    if (segLen <= 0) continue;
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

        // Multi-path endpoints: render each route's start and end if distinct from global
        if (lv.paths != null && lv.paths.length > 0) {
            for (PathRoute pr : lv.paths) {
                if (pr.path == null || pr.path.points == null || pr.path.points.length < 2) continue;
                Vector2 start = pr.path.points[0];
                Vector2 end = pr.path.points[pr.path.points.length - 1];

                // Render route start if different from global spawnPos
                if (start.distance(lv.spawnPos) > 20f) {
                    g.noStroke();
                    g.fill(0xFFFF8C42, 100);
                    g.ellipse(start.x, start.y, 20 * sp, 20 * sp);
                    g.fill(0xFFFF8C42);
                    g.ellipse(start.x, start.y, 10, 10);
                }

                // Render route end if different from global exitPos and basePos
                boolean isBase = end.distance(lv.basePos) <= 20f;
                boolean isGlobalExit = end.distance(lv.exitPos) <= 20f;
                if (!isBase && !isGlobalExit) {
                    g.noStroke();
                    g.fill(0xFFFF4444, 80);
                    g.ellipse(end.x, end.y, 28, 28);
                    g.stroke(0xFFFF4444);
                    g.strokeWeight(3);
                    float ex2 = 6;
                    g.line(end.x - ex2, end.y - ex2, end.x + ex2, end.y + ex2);
                    g.line(end.x + ex2, end.y - ex2, end.x - ex2, end.y + ex2);
                }
            }
        }
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
        if (enemy.gameObject != null) {
            dir = enemy.gameObject.getTransform().getRotation();
        } else if (enemy.activeRoute != null && enemy.activeRoute.path != null) {
            Vector2 d = enemy.activeRoute.path.direction(enemy.routeProgress);
            if (d != null) dir = PApplet.atan2(d.y, d.x);
        }

        g.pushMatrix();
        g.translate(x, y);
        g.rotate(dir);

        // Glow — red by default, gold when carrying orbs
        g.noStroke();
        if (enemy.orbsCarried > 0) {
            g.fill(0xFFFFDD00, 80);
        } else {
            g.fill(0xFFFF4444, 60);
        }
        g.ellipse(0, 0, r * 2.8f, r * 2.8f);

        // Body — red by default, gold only when carrying orbs
        int bodyColor = enemy.orbsCarried > 0 ? 0xFFFFDD00 : 0xFFFF6666;
        if (enemy.hitFlashTimer > 0) {
            float flashAlpha = enemy.hitFlashTimer / 0.15f;
            g.fill(0xFFFFFFFF, (int)(255 * flashAlpha));
        } else {
            g.fill(bodyColor);
        }
        g.noStroke();
        g.beginShape();
        g.vertex(r * 1.2f, 0);
        g.vertex(-r * 0.6f, -r * 0.7f);
        g.vertex(-r * 0.3f, 0);
        g.vertex(-r * 0.6f, r * 0.7f);
        g.endShape(PApplet.CLOSE);

        // Tier outline stroke
        if (enemy.enemyDef != null) {
            int tier = enemy.enemyDef.key.charAt(enemy.enemyDef.key.length() - 1) - '0';
            g.noFill();
            if (tier == 2) {
                g.stroke(0xFFC0C0C0);
                g.strokeWeight(2);
                g.beginShape();
                g.vertex(r * 1.2f, 0);
                g.vertex(-r * 0.6f, -r * 0.7f);
                g.vertex(-r * 0.3f, 0);
                g.vertex(-r * 0.6f, r * 0.7f);
                g.endShape(PApplet.CLOSE);
            } else if (tier == 3) {
                g.stroke(0xFFD4A017);
                g.strokeWeight(2);
                g.beginShape();
                g.vertex(r * 1.2f, 0);
                g.vertex(-r * 0.6f, -r * 0.7f);
                g.vertex(-r * 0.3f, 0);
                g.vertex(-r * 0.6f, r * 0.7f);
                g.endShape(PApplet.CLOSE);
            } else if (tier == 4) {
                g.stroke(0xFFFFD700);
                g.strokeWeight(2);
                // inner outline
                g.beginShape();
                g.vertex(r * 1.2f, 0);
                g.vertex(-r * 0.6f, -r * 0.7f);
                g.vertex(-r * 0.3f, 0);
                g.vertex(-r * 0.6f, r * 0.7f);
                g.endShape(PApplet.CLOSE);
                // outer outline (20% larger, thinner, semi-transparent)
                float o = 1.35f;
                g.strokeWeight(1);
                g.stroke(255, 215, 0, 140);
                g.beginShape();
                g.vertex(r * 1.2f * o, 0);
                g.vertex(-r * 0.6f * o, -r * 0.7f * o);
                g.vertex(-r * 0.3f * o, 0);
                g.vertex(-r * 0.6f * o, r * 0.7f * o);
                g.endShape(PApplet.CLOSE);
            }
        }

        // Orb capacity indicator — small dots behind body
        if (enemy.enemyDef != null && enemy.enemyDef.orbCapacity > 1) {
            g.noStroke();
            float dotR = 2.5f;
            float spacing = 7f;
            float startY = -(enemy.enemyDef.orbCapacity - 1) * spacing * 0.5f;
            for (int i = 0; i < enemy.enemyDef.orbCapacity; i++) {
                int dotColor = (i < enemy.orbsCarried) ? 0xFFFFD700 : 0xFF888888;
                g.fill(dotColor, 200);
                g.ellipse(-r * 0.8f, startY + i * spacing, dotR * 2, dotR * 2);
            }
        }

        g.popMatrix();

        // Render status effects (hit marks) in world space
        for (EnemyStatusEffect se : enemy.statusEffects) {
            se.render(g, x, y, r);
        }
    }
}

/**
 * Renders HP bars for all enemies on top of everything else (world layer 99).
 */
static class EnemyHpBarRenderer extends RendererComponent {
    protected void renderShape(PGraphics g) {
        for (Enemy e : TdGameWorld.enemies) {
            if (e == null || e.hp <= 0 || e.hp >= e.maxHp) continue;

            float x = e.pos.x;
            float y = e.pos.y;
            float r = e.radius;
            float barW = r * 2.4f;
            float barH = 5;
            float barX = x - barW * 0.5f;
            float barY = y - r - 12;

            g.noStroke();
            g.fill(0xFF222222, 200);
            g.rect(barX - 1, barY - 1, barW + 2, barH + 2, 2);
            g.fill(0xFF333333);
            g.rect(barX, barY, barW, barH, 2);
            float hpPct = e.maxHp > 0 ? e.hp / e.maxHp : 0;
            int hpColor = hpPct > 0.5f ? 0xFF44FF66 : (hpPct > 0.25f ? 0xFFFFCC44 : 0xFFFF4444);
            g.fill(hpColor);
            g.rect(barX, barY, barW * hpPct, barH, 2);
        }
    }
}

static class TowerRenderer extends RendererComponent {
    Tower tower;
    TowerRenderer(Tower tower) { this.tower = tower; }

    protected void renderShape(PGraphics g) {
        if (tower == null) return;
        float size = TdConfig.GRID * 0.75f;
        if (tower.def.type == TowerType.LASER) size *= 0.75f;
        float half = size * 0.5f;
        float x = tower.worldX;
        float y = tower.worldY;
        int c = tower.def.iconColor;
        float time = System.currentTimeMillis() / 1000f;
        float fade = tower.sellFade;

        // Range indicator (shown when building or manually toggled)
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        boolean shouldShowRange = app.showTowerRanges || app.buildMode != TdBuildMode.NONE;
        if (tower.built && shouldShowRange) {
            g.noFill();
            g.stroke(c & 0x40FFFFFF, (int)(255 * fade));
            g.strokeWeight(1);
            g.ellipse(x, y, tower.def.range * 2, tower.def.range * 2);
        }

        // Build animation
        if (!tower.built) {
            float prog = tower.buildProgress / tower.def.buildTime;
            float pulse = 1 + 0.15f * PApplet.sin(time * 8);
            g.noStroke();
            g.fill(0xFF444444, (int)(180 * fade));
            g.rect(x - half, y - half, size, size, 4);
            g.fill(c, (int)(120 * fade));
            g.rect(x - half, y - half, size * prog, size, 4);
            // Building pulse
            g.noFill();
            g.stroke(c, (int)(150 * fade));
            g.strokeWeight(2);
            g.rect(x - half * pulse, y - half * pulse, size * pulse, size * pulse, 4);
            return;
        }

        // Tower shadow
        g.noStroke();
        g.fill(0xFF000000, (int)(60 * fade));
        g.rect(x - half + 3, y - half + 3, size, size, 4);

        // Tower body by type
        g.noStroke();
        g.fill(c, (int)(255 * fade));
        switch (tower.def.type) {
            case MG:
                g.rect(x - half, y - half, size, size, 3);
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                g.rect(x - half + 4, y - half + 4, size - 8, 4, 1);
                break;
            case MISSILE:
                g.ellipse(x, y, size, size);
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                g.ellipse(x, y, size * 0.4f, size * 0.4f);
                break;
            case LASER:
                g.pushMatrix();
                g.translate(x, y);
                g.rotate(PApplet.PI / 4);
                g.rect(-half, -half, size, size, 3);
                g.popMatrix();
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                g.ellipse(x, y, size * 0.3f, size * 0.3f);
                break;
            case SLOW:
                drawHexagon(g, x, y, half * 0.9f);
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                g.ellipse(x, y, size * 0.35f, size * 0.35f);
                break;
        }

        // Hover highlight
        if (tower == app.hoveredTower && !tower.isSelling) {
            g.noFill();
            g.stroke(0xFFFFFFFF, (int)(180 * fade));
            g.strokeWeight(2);
            switch (tower.def.type) {
                case MG:
                    g.rect(x - half - 2, y - half - 2, size + 4, size + 4, 4);
                    break;
                case MISSILE:
                    g.ellipse(x, y, size + 6, size + 6);
                    break;
                case LASER:
                    g.pushMatrix();
                    g.translate(x, y);
                    g.rotate(PApplet.PI / 4);
                    g.rect(-half - 3, -half - 3, size + 6, size + 6, 4);
                    g.popMatrix();
                    break;
                case SLOW:
                    drawHexagon(g, x, y, half * 0.9f + 4);
                    break;
            }
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
    Bullet bullet;  // dynamically bound by Tower.fireAt()

    protected void renderShape(PGraphics g) {
        if (bullet == null || bullet.dead) return;

        float x = bullet.pos.x;
        float y = bullet.pos.y;

        // Trail
        g.noStroke();
        g.fill(0xFFFFFF00, 60);
        g.ellipse(x - bullet.vel.x * 0.02f, y - bullet.vel.y * 0.02f, 8, 8);
        g.fill(0xFFFFFF00, 120);
        g.ellipse(x - bullet.vel.x * 0.01f, y - bullet.vel.y * 0.01f, 5, 5);

        // Core
        g.fill(0xFFFFFFFF);
        g.ellipse(x, y, 7, 7);

        // Glow light for bullet
        if (bullet.towerType == TowerType.MISSILE) {
            TdLightingSystem.addMissileBulletGlow(x, y);
        } else {
            TdLightingSystem.addBulletGlow(x, y);
        }
    }
}

/**
 * Renders all lightweight visual effects (tracers, explosions, lasers, slow waves).
 * Lives at renderLayer 95 — above bullets, below HP bars.
 */
static class EffectRenderer extends RendererComponent {
    protected void renderShape(PGraphics g) {
        for (Effect e : TdGameWorld.effects) {
            e.render(g);
        }
    }
}
