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
        float t = (TowerDefenseMin2.inst.engine.getGameTime().getTotalTime() % 2.0f) / 2.0f;
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
        float time = TowerDefenseMin2.inst.engine.getGameTime().getTotalTime();
        float pulse = 1 + 0.15f * PApplet.sin(time * 3);
        g.noStroke();
        // Outer glow
        g.fill(0xFF4A9EFF, 60);
        drawPolyCircle(g, lv.basePos.x, lv.basePos.y, 24 * pulse, 16);
        // Core
        g.fill(0xFF4A9EFF);
        drawPolyCircle(g, lv.basePos.x, lv.basePos.y, 10, 12);
        g.fill(0xFFFFFFFF);
        drawPolyCircle(g, lv.basePos.x, lv.basePos.y, 4, 8);
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
        drawPolyCircle(g, lv.exitPos.x, lv.exitPos.y, 14, 12);
        g.stroke(0xFFFF4444);
        g.strokeWeight(3);
        float ex = 6;
        g.line(lv.exitPos.x - ex, lv.exitPos.y - ex, lv.exitPos.x + ex, lv.exitPos.y + ex);
        g.line(lv.exitPos.x + ex, lv.exitPos.y - ex, lv.exitPos.x - ex, lv.exitPos.y + ex);

        // Spawn — orange pulsing dot
        float sp = 1 + 0.2f * PApplet.sin(time * 4);
        g.noStroke();
        g.fill(0xFFFF8C42, 100);
        drawPolyCircle(g, lv.spawnPos.x, lv.spawnPos.y, 10 * sp, 12);
        g.fill(0xFFFF8C42);
        drawPolyCircle(g, lv.spawnPos.x, lv.spawnPos.y, 5, 8);

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
                    drawPolyCircle(g, start.x, start.y, 10 * sp, 12);
                    g.fill(0xFFFF8C42);
                    drawPolyCircle(g, start.x, start.y, 5, 8);
                }

                // Render route end if different from global exitPos and basePos
                boolean isBase = end.distance(lv.basePos) <= 20f;
                boolean isGlobalExit = end.distance(lv.exitPos) <= 20f;
                if (!isBase && !isGlobalExit) {
                    g.noStroke();
                    g.fill(0xFFFF4444, 80);
                    drawPolyCircle(g, end.x, end.y, 14, 12);
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
        drawPolyCircle(g, 0, 0, r * 1.4f, 16);

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
        Camera2D cam = TowerDefenseMin2.inst.camera;
        Rect vp = (cam != null) ? cam.getViewport() : null;
        g.noStroke();
        for (Enemy e : TdGameWorld.enemies) {
            if (e == null || e.hp <= 0 || e.hp >= e.maxHp) continue;
            if (vp != null && !vp.contains(e.pos.x, e.pos.y)) continue;

            float x = e.pos.x;
            float y = e.pos.y;
            float r = e.radius;
            float barW = r * 2.4f;
            float barH = 5;
            float barX = x - barW * 0.5f;
            float barY = y - r - 12;

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
        float time = TowerDefenseMin2.inst.engine.getGameTime().getTotalTime();
        float fade = tower.sellFade;

        // Range indicator (shown when building or manually toggled)
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        boolean shouldShowRange = app.showTowerRanges || app.buildMode != TdBuildMode.NONE;
        if (tower.built && shouldShowRange) {
            g.noFill();
            g.stroke(c & 0x40FFFFFF, (int)(255 * fade));
            g.strokeWeight(1);
            drawPolyCircle(g, x, y, tower.def.range, 32);
        }

        // Build animation
        if (!tower.built) {
            float prog = tower.buildProgress / tower.def.buildTime;
            g.noStroke();
            g.fill(0xFF444444, (int)(180 * fade));
            g.rect(x - half, y - half, size, size, 4);
            g.fill(c, (int)(120 * fade));
            g.rect(x - half, y - half, size * prog, size, 4);
            // Static build border
            g.noFill();
            g.stroke(c, (int)(150 * fade));
            g.strokeWeight(2);
            g.rect(x - half, y - half, size, size, 4);
            return;
        }

        // Upgrade animation
        if (tower.isUpgrading) {
            float targetTime = (tower.upgradeLevel == 0) ? tower.def.upgradeBuildTime : tower.def.upgrade2BuildTime;
            float prog = tower.upgradeProgress / targetTime;
            g.noStroke();
            g.fill(0xFF444444, (int)(180 * fade));
            g.rect(x - half, y - half, size, size, 4);
            g.fill(0xFFC0C0C0, (int)(120 * fade));
            g.rect(x - half, y - half, size * prog, size, 4);
            // Static upgrade border
            g.noFill();
            g.stroke(0xFFC0C0C0, (int)(150 * fade));
            g.strokeWeight(2);
            g.rect(x - half, y - half, size, size, 4);
            return;
        }

        // Tower shadow
        g.noStroke();
        g.fill(0xFF000000, (int)(60 * fade));
        g.rect(x - half + 3, y - half + 3, size, size, 4);

        // Command tower: persistent buff aura (subtle pulsing glow)
        float cmdOffset = (tower.def.type == TowerType.COMMAND) ? half * 0.25f : 0f;
        if (tower.def.type == TowerType.COMMAND && tower.built) {
            float auraPulse = 0.6f + 0.4f * PApplet.sin(time * 2.5f);
            g.noStroke();
            g.fill(c, (int)(14 * auraPulse * fade));
            drawTriangle(g, x, y + cmdOffset, half * 1.35f);
        }

        // Command tower buff: pulsing golden grid highlight
        if (tower.def.type != TowerType.COMMAND && tower.built &&
            TdGameWorld.isGridInCommandAura(tower.gridX, tower.gridY)) {
            g.noStroke();
            float gameT = TowerDefenseMin2.inst.engine.getGameTime().getTotalTime();
            float buffPulse = 0.5f + 0.5f * PApplet.sin(gameT * 2.5f);
            int buffAlpha = (int)(45 * buffPulse);
            g.fill(135, 206, 250, buffAlpha);
            g.rect(tower.gridX * TdConfig.GRID + 2, tower.gridY * TdConfig.GRID + 2,
                   TdConfig.GRID - 4, TdConfig.GRID - 4, 6);
        }

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
                drawPolyCircle(g, x, y, half, 24);
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                drawPolyCircle(g, x, y, half * 0.4f, 16);
                break;
            case LASER:
                g.pushMatrix();
                g.translate(x, y);
                g.rotate(PApplet.PI / 4);
                g.rect(-half, -half, size, size, 3);
                g.popMatrix();
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                drawPolyCircle(g, x, y, half * 0.3f, 10);
                break;
            case SLOW:
                drawHexagon(g, x, y, half * 0.9f);
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                drawPolyCircle(g, x, y, half * 0.35f, 10);
                break;
            case POISON:
                drawPentagon(g, x, y, half * 0.95f);
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                drawPolyCircle(g, x, y, half * 0.3f, 10);
                break;
            case COMMAND:
                drawTriangle(g, x, y + cmdOffset, half);
                if (tower.upgradeLevel >= 2) {
                    float pulse = 0.5f + 0.5f * PApplet.sin(time * 3f);
                    int centerAlpha = (int)(80 + 175 * pulse);
                    g.fill(0xFFFF7777, (int)(centerAlpha * fade));
                } else {
                    g.fill(0xFFFFFFFF, (int)(120 * fade));
                }
                drawPolyCircle(g, x, y + cmdOffset, half * 0.3f, 6);
                break;
        }

        // Upgraded border
        if (tower.upgradeLevel >= 1) {
            g.noFill();
            // Outer glow: theme color (both levels)
            int outerAlpha;
            if (tower.def.type == TowerType.COMMAND) {
                outerAlpha = (tower.upgradeLevel == 1) ? 30 : 90;
            } else {
                outerAlpha = 120;
            }
            g.stroke(c, (int)(outerAlpha * fade));
            g.strokeWeight(4f);
            switch (tower.def.type) {
                case MG:
                    g.rect(x - half - 1, y - half - 1, size + 2, size + 2, 3);
                    break;
                case MISSILE:
                    drawPolyCircle(g, x, y, half + 1.5f, 24);
                    break;
                case LASER:
                    g.pushMatrix();
                    g.translate(x, y);
                    g.rotate(PApplet.PI / 4);
                    g.rect(-half - 1.5f, -half - 1.5f, size + 3, size + 3, 3);
                    g.popMatrix();
                    break;
                case SLOW:
                    drawHexagon(g, x, y, half * 0.9f + 2);
                    break;
                case POISON:
                    drawPentagon(g, x, y, half * 0.95f + 2);
                    break;
                case COMMAND:
                    drawTriangle(g, x, y + cmdOffset, half + 2.5f);
                    break;
            }
            // Inner stroke: white (level 1) or double gold (level 2)
            if (tower.upgradeLevel >= 2) {
                // Inner double stroke: gold for most towers, silver-white for command
                int innerColor = (tower.def.type == TowerType.COMMAND) ? 0xFFE0E0E0 : 0xFFFFD700;
                // Outer inner stroke (thinner, closer to edge)
                g.stroke(innerColor, (int)(200 * fade));
                g.strokeWeight(0.8f);
                switch (tower.def.type) {
                    case MG:
                        g.rect(x - half + 1, y - half + 1, size - 2, size - 2, 3);
                        break;
                    case MISSILE:
                        drawPolyCircle(g, x, y, half - 1, 24);
                        break;
                    case LASER:
                        g.pushMatrix();
                        g.translate(x, y);
                        g.rotate(PApplet.PI / 4);
                        g.rect(-half + 1, -half + 1, size - 2, size - 2, 3);
                        g.popMatrix();
                        break;
                    case SLOW:
                        drawHexagon(g, x, y, half * 0.9f - 1);
                        break;
                    case POISON:
                        drawPentagon(g, x, y, half * 0.95f - 1);
                        break;
                    case COMMAND:
                        drawTriangle(g, x, y + cmdOffset, half - 1);
                        break;
                }
                // Inner inner stroke (thicker, further inward)
                g.stroke(innerColor, (int)(255 * fade));
                g.strokeWeight(1.5f);
                switch (tower.def.type) {
                    case MG:
                        g.rect(x - half + 3, y - half + 3, size - 6, size - 6, 3);
                        break;
                    case MISSILE:
                        drawPolyCircle(g, x, y, half - 3, 24);
                        break;
                    case LASER:
                        g.pushMatrix();
                        g.translate(x, y);
                        g.rotate(PApplet.PI / 4);
                        g.rect(-half + 3, -half + 3, size - 6, size - 6, 3);
                        g.popMatrix();
                        break;
                    case SLOW:
                        drawHexagon(g, x, y, half * 0.9f - 3);
                        break;
                    case POISON:
                        drawPentagon(g, x, y, half * 0.95f - 3);
                        break;
                    case COMMAND:
                        drawTriangle(g, x, y + cmdOffset, half - 3);
                        break;
                }
            } else {
                g.stroke(0xFFFFFFFF, (int)(200 * fade));
                g.strokeWeight(1.5f);
                switch (tower.def.type) {
                    case MG:
                        g.rect(x - half, y - half, size, size, 3);
                        break;
                    case MISSILE:
                        drawPolyCircle(g, x, y, half, 24);
                        break;
                    case LASER:
                        g.pushMatrix();
                        g.translate(x, y);
                        g.rotate(PApplet.PI / 4);
                        g.rect(-half, -half, size, size, 3);
                        g.popMatrix();
                        break;
                    case SLOW:
                        drawHexagon(g, x, y, half * 0.9f);
                        break;
                    case POISON:
                        drawPentagon(g, x, y, half * 0.95f);
                        break;
                    case COMMAND:
                        drawTriangle(g, x, y + cmdOffset, half);
                        break;
                }
            }
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
                    drawPolyCircle(g, x, y, half + 3, 24);
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
                case POISON:
                    drawPentagon(g, x, y, half * 0.95f + 4);
                    break;
                case COMMAND:
                    drawTriangle(g, x, y + cmdOffset, half + 5);
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

    private void drawTriangle(PGraphics g, float cx, float cy, float r) {
        // Circumradius = r, geometric center at (cx, cy)
        g.beginShape();
        g.vertex(cx, cy - r);
        g.vertex(cx + r * 0.866f, cy + r * 0.5f);
        g.vertex(cx - r * 0.866f, cy + r * 0.5f);
        g.endShape(PApplet.CLOSE);
    }

    private void drawStar(PGraphics g, float cx, float cy, float r) {
        g.beginShape();
        for (int i = 0; i < 10; i++) {
            float angle = PApplet.TWO_PI / 10 * i - PApplet.PI / 2;
            float radius = (i % 2 == 0) ? r : r * 0.4f;
            g.vertex(cx + PApplet.cos(angle) * radius, cy + PApplet.sin(angle) * radius);
        }
        g.endShape(PApplet.CLOSE);
    }

    private void drawPentagon(PGraphics g, float cx, float cy, float r) {
        g.beginShape();
        for (int i = 0; i < 5; i++) {
            float angle = PApplet.TWO_PI / 5 * i - PApplet.PI / 2;
            g.vertex(cx + PApplet.cos(angle) * r, cy + PApplet.sin(angle) * r);
        }
        g.endShape(PApplet.CLOSE);
    }

    // ─── Dashed border helpers (marching ants) ───

    private void drawDashedLine(PGraphics g, float x1, float y1, float x2, float y2,
                                 float dashLen, float gapLen, float offset, int col, float fade) {
        float dx = x2 - x1;
        float dy = y2 - y1;
        float len = PApplet.sqrt(dx * dx + dy * dy);
        if (len <= 0) return;
        float nx = dx / len;
        float ny = dy / len;
        float cycle = dashLen + gapLen;
        float pos = -offset;
        g.stroke(col, (int)(255 * fade));
        g.strokeWeight(2);
        while (pos < len) {
            float segStart = PApplet.max(0, pos);
            float segEnd = PApplet.min(len, pos + dashLen);
            if (segEnd > segStart) {
                g.line(x1 + nx * segStart, y1 + ny * segStart,
                       x1 + nx * segEnd, y1 + ny * segEnd);
            }
            pos += cycle;
        }
    }

    private void drawDashedRect(PGraphics g, float rx, float ry, float rw, float rh,
                                 float cornerR, float dashLen, float gapLen, float offset, int col, float fade) {
        // Simplified: ignore corner radius for dashed outline (radius is small)
        float perim = 2 * (rw + rh);
        float cycle = dashLen + gapLen;
        float o = offset % cycle;
        // Top edge
        drawDashedLine(g, rx, ry, rx + rw, ry, dashLen, gapLen, o, col, fade);
        // Right edge
        drawDashedLine(g, rx + rw, ry, rx + rw, ry + rh, dashLen, gapLen, (o + rw) % cycle, col, fade);
        // Bottom edge
        drawDashedLine(g, rx + rw, ry + rh, rx, ry + rh, dashLen, gapLen, (o + rw + rh) % cycle, col, fade);
        // Left edge
        drawDashedLine(g, rx, ry + rh, rx, ry, dashLen, gapLen, (o + rw + rh + rw) % cycle, col, fade);
    }

    private void drawDashedEllipse(PGraphics g, float cx, float cy, float rx, float ry,
                                    float dashLen, float gapLen, float offset, int col, float fade) {
        float circ = PApplet.PI * (3 * (rx + ry) - PApplet.sqrt((3 * rx + ry) * (rx + 3 * ry)));
        float cycle = dashLen + gapLen;
        int segments = PApplet.max(32, (int)(circ / 2));
        float step = PApplet.TWO_PI / segments;
        float o = offset % cycle;
        for (int i = 0; i < segments; i++) {
            float a1 = i * step - PApplet.PI / 2;
            float a2 = (i + 1) * step - PApplet.PI / 2;
            float segLen = PApplet.sqrt(
                PApplet.sq(rx * (PApplet.cos(a2) - PApplet.cos(a1))) +
                PApplet.sq(ry * (PApplet.sin(a2) - PApplet.sin(a1)))
            );
            float segStartPos = i * (circ / segments);
            float phase = (segStartPos + o) % cycle;
            if (phase < dashLen || (phase > cycle - segLen && phase < cycle)) {
                g.stroke(col, (int)(255 * fade));
                g.strokeWeight(2);
                g.line(cx + rx * PApplet.cos(a1), cy + ry * PApplet.sin(a1),
                       cx + rx * PApplet.cos(a2), cy + ry * PApplet.sin(a2));
            }
        }
    }

    private void drawDashedRotatedRect(PGraphics g, float cx, float cy, float half, float size,
                                        float dashLen, float gapLen, float offset, int col, float fade) {
        // Rotated 45° rect vertices (same as laser body)
        float cos45 = PApplet.cos(PApplet.PI / 4);
        float sin45 = PApplet.sin(PApplet.PI / 4);
        float[][] v = new float[4][2];
        // corners of unrotated rect centered at origin: (-h,-h), (h,-h), (h,h), (-h,h) where h = half
        float hx = half, hy = half;
        float[][] local = { {-hx,-hy}, {hx,-hy}, {hx,hy}, {-hx,hy} };
        for (int i = 0; i < 4; i++) {
            float lx = local[i][0];
            float ly = local[i][1];
            v[i][0] = cx + (lx * cos45 - ly * sin45);
            v[i][1] = cy + (lx * sin45 + ly * cos45);
        }
        drawDashedPolygon(g, v, dashLen, gapLen, offset, col, fade);
    }

    private void drawDashedHexagon(PGraphics g, float cx, float cy, float r,
                                    float dashLen, float gapLen, float offset, int col, float fade) {
        float[][] v = new float[6][2];
        for (int i = 0; i < 6; i++) {
            float a = PApplet.TWO_PI / 6 * i - PApplet.PI / 2;
            v[i][0] = cx + PApplet.cos(a) * r;
            v[i][1] = cy + PApplet.sin(a) * r;
        }
        drawDashedPolygon(g, v, dashLen, gapLen, offset, col, fade);
    }

    private void drawDashedStar(PGraphics g, float cx, float cy, float r,
                                 float dashLen, float gapLen, float offset, int col, float fade) {
        float[][] v = new float[10][2];
        for (int i = 0; i < 10; i++) {
            float a = PApplet.TWO_PI / 10 * i - PApplet.PI / 2;
            float radius = (i % 2 == 0) ? r : r * 0.4f;
            v[i][0] = cx + PApplet.cos(a) * radius;
            v[i][1] = cy + PApplet.sin(a) * radius;
        }
        drawDashedPolygon(g, v, dashLen, gapLen, offset, col, fade);
    }

    private void drawDashedPolygon(PGraphics g, float[][] vertices,
                                    float dashLen, float gapLen, float offset, int col, float fade) {
        int n = vertices.length;
        float cycle = dashLen + gapLen;
        float currentOffset = offset % cycle;
        for (int i = 0; i < n; i++) {
            float x1 = vertices[i][0];
            float y1 = vertices[i][1];
            float x2 = vertices[(i + 1) % n][0];
            float y2 = vertices[(i + 1) % n][1];
            float segLen = PApplet.sqrt(PApplet.sq(x2 - x1) + PApplet.sq(y2 - y1));
            drawDashedLine(g, x1, y1, x2, y2, dashLen, gapLen, currentOffset, col, fade);
            currentOffset = (currentOffset + segLen) % cycle;
        }
    }
}

static class BulletRenderer extends RendererComponent {
    Bullet bullet;  // dynamically bound by Tower.fireAt()

    protected void renderShape(PGraphics g) {
        if (bullet == null || bullet.dead) return;

        float x = bullet.pos.x;
        float y = bullet.pos.y;

        float sc = (bullet.towerType == TowerType.MISSILE) ? bullet.sizeMult : 1f;

        // Trail
        g.noStroke();
        g.fill(0xFFFFFF00, 60);
        drawPolyCircle(g, x - bullet.vel.x * 0.02f, y - bullet.vel.y * 0.02f, 4 * sc, 6);
        g.fill(0xFFFFFF00, 120);
        drawPolyCircle(g, x - bullet.vel.x * 0.01f, y - bullet.vel.y * 0.01f, 2.5f * sc, 6);

        // Core
        g.fill(0xFFFFFFFF);
        drawPolyCircle(g, x, y, 3.5f * sc, 6);

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
