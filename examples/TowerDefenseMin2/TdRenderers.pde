/**
 * Render Components for world layer (renderLayer < 100).
 * Drawn inside SceneViewport's off-screen buffer via p5engine renderer.
 */

// ── Blocked zone visual helpers ──
static boolean RUINS_USE_TEXTURES = true;
static java.util.IdentityHashMap<BlockedZone, float[]> ZONE_DRIFT_CACHE = new java.util.IdentityHashMap<>();
static java.util.HashMap<Integer, int[]> ZONE_LAYER_CACHE = new java.util.HashMap<>();

static float[] getZoneDrift(BlockedZone bz, float time) {
    float[] drift = ZONE_DRIFT_CACHE.get(bz);
    if (drift == null) {
        java.util.Random rng = new java.util.Random(bz.hashCode());
        drift = new float[] {
            0.15f + rng.nextFloat() * 0.40f,  // 0: freqX
            0.10f + rng.nextFloat() * 0.40f,  // 1: freqY
            0.05f + rng.nextFloat() * 0.25f,  // 2: freqRot
            5f    + rng.nextFloat() * 15f,    // 3: ampX
            4f    + rng.nextFloat() * 12f,    // 4: ampY
            0.02f + rng.nextFloat() * 0.08f,  // 5: maxRot
            rng.nextFloat() * PApplet.TWO_PI, // 6: phaseX
            rng.nextFloat() * PApplet.TWO_PI, // 7: phaseY
            rng.nextFloat() * PApplet.TWO_PI  // 8: phaseRot
        };
        ZONE_DRIFT_CACHE.put(bz, drift);
    }
    float driftX = PApplet.sin(time * drift[0] + drift[6]) * drift[3];
    float driftY = PApplet.cos(time * drift[1] + drift[7]) * drift[4];
    float rotation = PApplet.sin(time * drift[2] + drift[8]) * drift[5];
    return new float[] { driftX, driftY, rotation };
}

static int[] getZoneLayers(LevelDef lv) {
    if (lv.blockedZones == null || lv.blockedZones.length == 0) return new int[0];
    int[] layers = ZONE_LAYER_CACHE.get(lv.id);
    boolean fromCache = true;
    if (layers == null || layers.length != lv.blockedZones.length) {
        fromCache = false;
        java.util.Random rng = TdAssets.isRandomBackground()
            ? new java.util.Random()
            : new java.util.Random(lv.id * 7919 + 7);
        layers = new int[lv.blockedZones.length];

        // Ruins: only assign to Layer 2 if they stay inside viewport at default camera position
        float camX = lv.worldW * 0.5f;
        float camY = lv.worldH * 0.5f;
        float safeMinX = Math.max(0, camX * 0.45f - 800f);
        float safeMaxX = camX * 0.45f + 800f;
        float safeMinY = Math.max(0, camY * 0.45f - 450f);
        float safeMaxY = camY * 0.45f + 450f;
        for (int i = 0; i < layers.length; i++) {
            BlockedZone bz = lv.blockedZones[i];
            if (bz.visualType == BlockedVisualType.RUINS) {
                float cx = (bz.type == BlockedZoneType.RECT) ? bz.x + bz.w * 0.5f : bz.cx;
                float cy = (bz.type == BlockedZoneType.RECT) ? bz.y + bz.h * 0.5f : bz.cy;
                boolean visibleInL2 = (cx > safeMinX && cx < safeMaxX && cy > safeMinY && cy < safeMaxY);
                layers[i] = visibleInL2 ? 2 : 3;
            }
        }

        for (int i = 0; i < layers.length; i++) {
            if (lv.blockedZones[i].visualType == BlockedVisualType.ENERGY) {
                layers[i] = 2;
            }
        }

        for (int i = 0; i < layers.length; i++) {
            if (layers[i] != 0) continue;
            BlockedZone bz = lv.blockedZones[i];
            if (bz.visualType == BlockedVisualType.ASTEROID) {
                layers[i] = 2 + rng.nextInt(2);
            }
        }
        ZONE_LAYER_CACHE.put(lv.id, layers);
    }
    return layers;
}

static void drawBlockedZone(PGraphics g, BlockedZone bz, float time) {
    switch (bz.visualType) {
        case VOID:
            // Cut out platform — show deep space color
            g.noStroke();
            g.fill(0xFF080A14);
            if (bz.type == BlockedZoneType.RECT) {
                g.rect(bz.x, bz.y, bz.w, bz.h);
            } else {
                drawPolyCircle(g, bz.cx, bz.cy, bz.radius, 24);
            }
            // Stars inside the void rift (so it looks like real deep space, not just black)
            g.noStroke();
            java.util.Random voidRng = new java.util.Random((int)(bz.x + bz.y * 1000 + bz.cx));
            float voidArea = (bz.type == BlockedZoneType.RECT) ? bz.w * bz.h : bz.radius * bz.radius * 3.14159f;
            int voidStars = PApplet.max(8, (int)(voidArea / 200));
            float voidBrightness = TdAssets.getStarBrightness();
            for (int i = 0; i < voidStars; i++) {
                float sx, sy;
                if (bz.type == BlockedZoneType.RECT) {
                    sx = bz.x + voidRng.nextFloat() * bz.w;
                    sy = bz.y + voidRng.nextFloat() * bz.h;
                } else {
                    float a = voidRng.nextFloat() * PApplet.TWO_PI;
                    float r = PApplet.sqrt(voidRng.nextFloat()) * bz.radius;
                    sx = bz.cx + PApplet.cos(a) * r;
                    sy = bz.cy + PApplet.sin(a) * r;
                }
                int b = 160 + voidRng.nextInt(96);
                int size = 1 + voidRng.nextInt(3);
                g.fill(b, b, b + 20, (int)((180 + voidRng.nextInt(76)) * voidBrightness));
                g.rect(sx, sy, size, size);
            }
            // Broken jagged border
            g.noFill();
            g.stroke(0xFF3A5A85, 200);
            g.strokeWeight(1);
            if (bz.type == BlockedZoneType.RECT) {
                float step = 10;
                for (float x = bz.x; x < bz.x + bz.w; x += step * 2) {
                    g.line(x, bz.y, PApplet.min(x + step, bz.x + bz.w), bz.y);
                }
                for (float x = bz.x; x < bz.x + bz.w; x += step * 2) {
                    g.line(x, bz.y + bz.h, PApplet.min(x + step, bz.x + bz.w), bz.y + bz.h);
                }
                for (float y = bz.y; y < bz.y + bz.h; y += step * 2) {
                    g.line(bz.x, y, bz.x, PApplet.min(y + step, bz.y + bz.h));
                }
                for (float y = bz.y; y < bz.y + bz.h; y += step * 2) {
                    g.line(bz.x + bz.w, y, bz.x + bz.w, PApplet.min(y + step, bz.y + bz.h));
                }
            } else {
                drawPolyCircle(g, bz.cx, bz.cy, bz.radius, 24);
            }
            break;

        case ASTEROID:
            RockData[] rocks = ASTEROID_ROCK_CACHE.get(bz);
            if (rocks == null) {
                java.util.Random rng = new java.util.Random(System.nanoTime() + bz.hashCode() * 7919L);
                if (bz.type == BlockedZoneType.RECT) {
                    rocks = new RockData[3];
                    rocks[0] = generateFacetedRock(bz.w * 0.38f, bz.h * 0.38f, 0, 0, rng);
                    rocks[1] = generateFacetedRock(bz.w * 0.22f, bz.h * 0.22f, bz.w * 0.18f, bz.h * 0.12f, rng);
                    rocks[2] = generateFacetedRock(bz.w * 0.14f, bz.h * 0.14f, -bz.w * 0.22f, bz.h * 0.18f, rng);
                } else {
                    rocks = new RockData[3];
                    rocks[0] = generateFacetedRock(bz.radius * 0.70f, bz.radius * 0.70f, 0, 0, rng);
                    rocks[1] = generateFacetedRock(bz.radius * 0.32f, bz.radius * 0.32f, bz.radius * 0.35f, bz.radius * 0.22f, rng);
                    rocks[2] = generateFacetedRock(bz.radius * 0.20f, bz.radius * 0.20f, -bz.radius * 0.22f, bz.radius * 0.18f, rng);
                }
                ASTEROID_ROCK_CACHE.put(bz, rocks);
            }
            float[] ad = getZoneDrift(bz, time);
            float spinSpeed = (Math.abs(bz.hashCode()) % 1000) / 1000f * 0.08f - 0.04f;
            if (bz.type == BlockedZoneType.RECT) {
                float cx = bz.x + bz.w * 0.5f + ad[0];
                float cy = bz.y + bz.h * 0.5f + ad[1];
                g.pushMatrix();
                g.translate(cx, cy);
                g.rotate(ad[2] + time * spinSpeed);
                for (RockData rd : rocks) drawFacetedRock(g, 0, 0, rd);
                g.popMatrix();
            } else {
                g.pushMatrix();
                g.translate(bz.cx + ad[0], bz.cy + ad[1]);
                g.rotate(ad[2] + time * spinSpeed);
                for (RockData rd : rocks) drawFacetedRock(g, 0, 0, rd);
                g.popMatrix();
            }
            break;

        case ENERGY:
            float[] ed = getZoneDrift(bz, time);
            float energyPulse = 0.6f + 0.4f * PApplet.sin(time * 2.5f + bz.x * 0.01f);
            float energyCx = (bz.type == BlockedZoneType.RECT) ? bz.x + bz.w * 0.5f + ed[0] : bz.cx + ed[0];
            float energyCy = (bz.type == BlockedZoneType.RECT) ? bz.y + bz.h * 0.5f + ed[1] : bz.cy + ed[1];
            float energyR = (bz.type == BlockedZoneType.RECT) ? Math.max(bz.w, bz.h) * 0.55f : bz.radius;
            g.noStroke();
            g.fill(0xFF00DDFF, (int)(14 * energyPulse));
            drawPolyCircle(g, energyCx, energyCy, energyR, (bz.type == BlockedZoneType.RECT) ? 16 : 24);
            g.noFill();
            g.stroke(0xFF00DDFF, (int)(40 * energyPulse));
            g.strokeWeight(1);
            g.pushMatrix();
            g.translate(energyCx, energyCy);
            g.rotate(time * 0.8f + ed[2]);
            float lineLen = (bz.type == BlockedZoneType.RECT) ? Math.max(bz.w, bz.h) * 0.25f : bz.radius * 0.4f;
            g.line(-lineLen, 0, lineLen, 0);
            g.line(0, -lineLen, 0, lineLen);
            g.popMatrix();
            break;

        case RUINS:
            if (RUINS_USE_TEXTURES && TdAssets.RUINS_TEXTURE_COUNT > 0 && bz.ruinTexIndex >= 0) {
                shenyf.p5engine.rendering.Texture tex =
                    TdAssets.RUINS_TEXTURES[bz.ruinTexIndex % TdAssets.RUINS_TEXTURE_COUNT];
                processing.core.PImage img = tex.getImage();
                float imgW = img.width;
                float imgH = img.height;
                float areaW, areaH, areaX, areaY;
                if (bz.type == BlockedZoneType.RECT) {
                    areaW = bz.w; areaH = bz.h; areaX = bz.x; areaY = bz.y;
                } else {
                    areaW = bz.radius * 2; areaH = areaW;
                    areaX = bz.cx - bz.radius; areaY = bz.cy - bz.radius;
                }

                // Read texture config from YAML
                String texKey = tex.getKey();
                String fileName = texKey.substring(texKey.lastIndexOf('/') + 1);
                TdAssets.TextureConfig cfg = TdAssets.getTextureConfig("ruins", fileName);
                if (cfg == null) cfg = new TdAssets.TextureConfig("fit", 1.0f, "center", 1.0f);

                float baseScale;
                if ("stretch".equals(cfg.scaleMode)) {
                    baseScale = 1.0f;
                } else if ("fill".equals(cfg.scaleMode)) {
                    baseScale = Math.max(areaW / imgW, areaH / imgH);
                } else { // fit
                    baseScale = Math.min(areaW / imgW, areaH / imgH);
                }

                float drawW = imgW * baseScale * cfg.scale * cfg.globalScale;
                float drawH = imgH * baseScale * cfg.scale * cfg.globalScale;
                float drawX, drawY;
                if ("topleft".equals(cfg.anchor)) {
                    drawX = areaX;
                    drawY = areaY;
                } else { // center
                    drawX = areaX + (areaW - drawW) * 0.5f;
                    drawY = areaY + (areaH - drawH) * 0.5f;
                }

                // Space drift: each ruin has independent freq/amp/phase
                float centerX = drawX + drawW * 0.5f;
                float centerY = drawY + drawH * 0.5f;
                float[] d = getZoneDrift(bz, time);

                g.pushMatrix();
                g.translate(centerX + d[0], centerY + d[1]);
                g.rotate(d[2]);
                g.image(img, -drawW * 0.5f, -drawH * 0.5f, drawW, drawH);
                g.popMatrix();
            } else {
                g.noStroke();
                g.fill(0xFF25252A);
                if (bz.type == BlockedZoneType.RECT) {
                    g.rect(bz.x + bz.w * 0.05f, bz.y + bz.h * 0.1f, bz.w * 0.9f, bz.h * 0.25f);
                    g.rect(bz.x + bz.w * 0.2f, bz.y + bz.h * 0.45f, bz.w * 0.6f, bz.h * 0.35f);
                    g.fill(0xFF1E1E22);
                    g.rect(bz.x + bz.w * 0.1f, bz.y + bz.h * 0.55f, bz.w * 0.3f, bz.h * 0.2f);
                } else {
                    g.rect(bz.cx - bz.radius * 0.4f, bz.cy - bz.radius * 0.3f, bz.radius * 0.8f, bz.radius * 0.25f);
                    g.rect(bz.cx - bz.radius * 0.2f, bz.cy, bz.radius * 0.5f, bz.radius * 0.35f);
                }
            }
            // DEBUG: red outline for ruins visibility
            g.noFill();
            g.stroke(0xFFFF0000);
            g.strokeWeight(3);
            if (bz.type == BlockedZoneType.RECT) {
                g.rect(bz.x, bz.y, bz.w, bz.h);
            } else {
                g.ellipse(bz.cx, bz.cy, bz.radius * 2, bz.radius * 2);
            }
            g.noStroke();
            g.strokeWeight(1);
            break;
    }
}

// === Parallax star cache ===
static final class StarData {
    final float x, y;
    final int col;
    final int size;
    StarData(float x, float y, int col, int size) {
        this.x = x; this.y = y; this.col = col; this.size = size;
    }
}

static final class GlowStarData {
    final float x, y;
    final int size;
    GlowStarData(float x, float y, int size) { this.x = x; this.y = y; this.size = size; }
}

static java.util.HashMap<Integer, StarData[]> FAR_STARS = new java.util.HashMap<>();
static java.util.HashMap<Integer, StarData[]> MID_STARS = new java.util.HashMap<>();
static java.util.HashMap<Integer, GlowStarData[]> NEAR_STARS = new java.util.HashMap<>();

// ── Procedural nebula clouds ──
static final class NebulaData {
    final float x, y;
    final int col;
    final int alpha;
    final float radius;
    final int verts;
    final float driftFreqX, driftFreqY;
    final float driftAmpX, driftAmpY;
    final float driftPhaseX, driftPhaseY;

    NebulaData(float x, float y, int col, int alpha, float radius, int verts,
               float driftFreqX, float driftFreqY, float driftAmpX, float driftAmpY,
               float driftPhaseX, float driftPhaseY) {
        this.x = x; this.y = y; this.col = col; this.alpha = alpha;
        this.radius = radius; this.verts = verts;
        this.driftFreqX = driftFreqX; this.driftFreqY = driftFreqY;
        this.driftAmpX = driftAmpX; this.driftAmpY = driftAmpY;
        this.driftPhaseX = driftPhaseX; this.driftPhaseY = driftPhaseY;
    }
}

static java.util.HashMap<Integer, NebulaData[]> NEBULA_CACHE = new java.util.HashMap<>();

static final int[] NEBULA_PALETTE = {
    0xFF00AAAA, 0xFF6600AA, 0xFFAA4400, 0xFF4488FF,
    0xFFFF5588, 0xFF44FFAA, 0xFFAA44FF, 0xFF44AA88
};

// ── Faceted low-poly rock rendering ──
static class RockFacet {
    float x0, y0, x1, y1, x2, y2;
    int col;
    RockFacet(float x0, float y0, float x1, float y1, float x2, float y2, int col) {
        this.x0=x0; this.y0=y0; this.x1=x1; this.y1=y1; this.x2=x2; this.y2=y2; this.col=col;
    }
}

static class RockData {
    RockFacet[] facets;
    float offsetX, offsetY;
    float[] outlineX;
    float[] outlineY;
    int outlineVerts;
}

static java.util.IdentityHashMap<BlockedZone, RockData[]> ASTEROID_ROCK_CACHE = new java.util.IdentityHashMap<>();

static float calcRockBrightness(float cx, float cy, float rx, float ry, java.util.Random rng, float base) {
    // Position-based lighting: upper faces brighter, lower darker (screen Y goes down)
    float bright = base;
    bright += (-cy / (ry + 0.001f)) * 0.22f;     // upper = brighter
    bright += (cx / (rx + 0.001f)) * 0.06f;      // right side slightly darker
    bright += (rng.nextFloat() - 0.5f) * 0.10f;  // per-facet randomness
    return PApplet.constrain(bright, 0.32f, 1.08f);
}

static RockFacet makeFacet(float x0, float y0, float x1, float y1, float x2, float y2, float brightness) {
    int br = (int)PApplet.constrain(140 * brightness, 0, 255);
    int bg = (int)PApplet.constrain(138 * brightness, 0, 255);
    int bb = (int)PApplet.constrain(134 * brightness, 0, 255);
    int col = 0xFF000000 | (br << 16) | (bg << 8) | bb;
    return new RockFacet(x0, y0, x1, y1, x2, y2, col);
}

// Low-poly rock made of 3~4 large triangles (like a 3D polyhedron projection).
// A convex polygon is split by 1~2 diagonals into large facets.
// No single center point — edges connect polygon vertices directly.
static RockData generateFacetedRock(float rx, float ry, float offX, float offY, java.util.Random rng) {
    // Larger rocks get 6 verts (4 facets), smaller ones 5 verts (3 facets)
    int verts = (rx > ry * 0.55f) ? 6 : 5;
    float[] angles = new float[verts];
    float[] radii = new float[verts];
    float angleSum = 0;
    for (int i = 0; i < verts; i++) {
        angles[i] = rng.nextFloat() * 0.35f + 0.825f;
        angleSum += angles[i];
    }
    for (int i = 0; i < verts; i++) {
        angles[i] = angles[i] / angleSum * PApplet.TWO_PI;
    }
    for (int i = 0; i < verts; i++) {
        float n = 0.86f + 0.14f * PApplet.sin(rng.nextFloat() * PApplet.TWO_PI + i * 2.3f);
        radii[i] = rx * n;
    }
    
    float[] vx = new float[verts];
    float[] vy = new float[verts];
    float curA = rng.nextFloat() * PApplet.TWO_PI;
    for (int i = 0; i < verts; i++) {
        vx[i] = PApplet.cos(curA) * radii[i];
        vy[i] = PApplet.sin(curA) * radii[i] * (ry / rx);
        curA += angles[i];
    }
    
    java.util.ArrayList<RockFacet> facets = new java.util.ArrayList<>();
    float[] oX = new float[verts];
    float[] oY = new float[verts];
    System.arraycopy(vx, 0, oX, 0, verts);
    System.arraycopy(vy, 0, oY, 0, verts);
    
    if (verts == 6) {
        // 6-gon split into 4 large triangles by diagonals v0-v2 and v0-v4
        float b0 = calcRockBrightness((vx[0]+vx[1]+vx[2])/3, (vy[0]+vy[1]+vy[2])/3, rx, ry, rng, 0.88f);
        facets.add(makeFacet(vx[0], vy[0], vx[1], vy[1], vx[2], vy[2], b0));
        
        float b1 = calcRockBrightness((vx[0]+vx[2]+vx[4])/3, (vy[0]+vy[2]+vy[4])/3, rx, ry, rng, 0.95f);
        facets.add(makeFacet(vx[0], vy[0], vx[2], vy[2], vx[4], vy[4], b1));
        
        float b2 = calcRockBrightness((vx[2]+vx[3]+vx[4])/3, (vy[2]+vy[3]+vy[4])/3, rx, ry, rng, 0.78f);
        facets.add(makeFacet(vx[2], vy[2], vx[3], vy[3], vx[4], vy[4], b2));
        
        float b3 = calcRockBrightness((vx[0]+vx[4]+vx[5])/3, (vy[0]+vy[4]+vy[5])/3, rx, ry, rng, 0.68f);
        facets.add(makeFacet(vx[0], vy[0], vx[4], vy[4], vx[5], vy[5], b3));
    } else {
        // 5-gon split into 3 large triangles by diagonal v0-v2
        float b0 = calcRockBrightness((vx[0]+vx[1]+vx[2])/3, (vy[0]+vy[1]+vy[2])/3, rx, ry, rng, 0.88f);
        facets.add(makeFacet(vx[0], vy[0], vx[1], vy[1], vx[2], vy[2], b0));
        
        float b1 = calcRockBrightness((vx[0]+vx[2]+vx[4])/3, (vy[0]+vy[2]+vy[4])/3, rx, ry, rng, 0.92f);
        facets.add(makeFacet(vx[0], vy[0], vx[2], vy[2], vx[4], vy[4], b1));
        
        float b2 = calcRockBrightness((vx[2]+vx[3]+vx[4])/3, (vy[2]+vy[3]+vy[4])/3, rx, ry, rng, 0.72f);
        facets.add(makeFacet(vx[2], vy[2], vx[3], vy[3], vx[4], vy[4], b2));
    }
    
    RockData rd = new RockData();
    rd.facets = facets.toArray(new RockFacet[0]);
    rd.offsetX = offX; rd.offsetY = offY;
    rd.outlineX = oX; rd.outlineY = oY; rd.outlineVerts = verts;
    return rd;
}

static void drawFacetedRock(PGraphics g, float cx, float cy, RockData rock) {
    float ox = cx + rock.offsetX;
    float oy = cy + rock.offsetY;
    g.noStroke();
    for (RockFacet f : rock.facets) {
        g.fill(f.col);
        g.beginShape();
        g.vertex(ox + f.x0, oy + f.y0);
        g.vertex(ox + f.x1, oy + f.y1);
        g.vertex(ox + f.x2, oy + f.y2);
        g.endShape(PApplet.CLOSE);
    }
    g.noFill();
    g.stroke(0xFF3A3A38, 140);
    g.strokeWeight(0.8f);
    g.beginShape();
    for (int i = 0; i < rock.outlineVerts; i++) {
        g.vertex(ox + rock.outlineX[i], oy + rock.outlineY[i]);
    }
    g.endShape(PApplet.CLOSE);
}

static void clearStarCaches() {
    FAR_STARS.clear();
    MID_STARS.clear();
    NEAR_STARS.clear();
    ASTEROID_ROCK_CACHE.clear();
    ZONE_DRIFT_CACHE.clear();
    ZONE_LAYER_CACHE.clear();
}

static StarData[] generateFarStars(LevelDef lv) {
    java.util.Random rng = TdAssets.isRandomBackground()
        ? new java.util.Random()
        : new java.util.Random(lv.id * 7919);
    int count = (lv.worldW * lv.worldH) / 500;
    StarData[] arr = new StarData[count];
    for (int i = 0; i < count; i++) {
        float sx = rng.nextFloat() * lv.worldW * 3 - lv.worldW;
        float sy = rng.nextFloat() * lv.worldH * 3 - lv.worldH;
        int b = 120 + rng.nextInt(80);
        int a = 120 + rng.nextInt(80);
        int col = (a << 24) | ((b & 0xFF) << 16) | ((b & 0xFF) << 8) | ((b + 20) & 0xFF);
        arr[i] = new StarData(sx, sy, col, 1 + rng.nextInt(2));
    }
    return arr;
}

static StarData[] generateMidStars(LevelDef lv) {
    java.util.Random rng = TdAssets.isRandomBackground()
        ? new java.util.Random()
        : new java.util.Random(lv.id * 7919 + 1);
    int count = (lv.worldW * lv.worldH) / 350;
    StarData[] arr = new StarData[count];
    for (int i = 0; i < count; i++) {
        float sx = rng.nextFloat() * lv.worldW * 3 - lv.worldW;
        float sy = rng.nextFloat() * lv.worldH * 3 - lv.worldH;
        int b = 160 + rng.nextInt(96);
        int a = 160 + rng.nextInt(96);
        int col = (a << 24) | ((b & 0xFF) << 16) | ((b & 0xFF) << 8) | ((b + 30) & 0xFF);
        arr[i] = new StarData(sx, sy, col, 1 + rng.nextInt(3));
    }
    return arr;
}

static GlowStarData[] generateNearStars(LevelDef lv) {
    java.util.Random rng = TdAssets.isRandomBackground()
        ? new java.util.Random()
        : new java.util.Random(lv.id * 7919 + 2);
    int count = (lv.worldW * lv.worldH) / 2000;
    GlowStarData[] arr = new GlowStarData[count];
    for (int i = 0; i < count; i++) {
        float sx = rng.nextFloat() * lv.worldW * 3 - lv.worldW;
        float sy = rng.nextFloat() * lv.worldH * 3 - lv.worldH;
        int size = 3 + rng.nextInt(3);
        arr[i] = new GlowStarData(sx, sy, size);
    }
    return arr;
}

static NebulaData[] generateNebulas(LevelDef lv) {
    java.util.Random rng = TdAssets.isRandomBackground()
        ? new java.util.Random()
        : new java.util.Random(lv.id * 7919 + 3);
    float w = lv.worldW, h = lv.worldH;
    float baseR = Math.min(w, h);

    // Radius adaptive to world size: big ~26%, medium ~17%, small ~10%
    float[] radii = {
        baseR * (0.17f + rng.nextFloat() * 0.18f), // big:    17~35%
        baseR * (0.12f + rng.nextFloat() * 0.10f), // medium: 12~22%
        baseR * (0.07f + rng.nextFloat() * 0.08f)  // small:   7~15%
    };

    // Generate 3 positions outside the central region
    float[][] pos = new float[3][2];
    for (int i = 0; i < 3; i++) {
        float nx, ny;
        int attempts = 0;
        do {
            nx = w * (0.05f + rng.nextFloat() * 0.90f);
            ny = h * (0.05f + rng.nextFloat() * 0.90f);
            float dx = Math.abs(nx / w - 0.5f);
            float dy = Math.abs(ny / h - 0.5f);
            if (dx > 0.25f || dy > 0.25f) break;
            attempts++;
        } while (attempts < 30);
        pos[i][0] = nx;
        pos[i][1] = ny;
    }

    // Sort by distance from center: farthest gets biggest radius
    float[] dists = new float[3];
    for (int i = 0; i < 3; i++) {
        float dx = pos[i][0] - w * 0.5f;
        float dy = pos[i][1] - h * 0.5f;
        dists[i] = dx * dx + dy * dy;
    }
    Integer[] order = {0, 1, 2};
    java.util.Arrays.sort(order, (a, b) -> Float.compare(dists[b], dists[a]));

    // Ensure the two smaller nebulae are close to each other,
    // and both are far from the big one
    float bigX = pos[order[0]][0], bigY = pos[order[0]][1];
    float midX = pos[order[1]][0], midY = pos[order[1]][1];
    float smallX = pos[order[2]][0], smallY = pos[order[2]][1];

    // If medium is too close to big, nudge it toward small
    float dBM = PApplet.dist(bigX, bigY, midX, midY);
    if (dBM < baseR * 0.45f) {
        midX = (midX + smallX) * 0.5f;
        midY = (midY + smallY) * 0.5f;
    }
    // If small is too close to big, nudge it toward medium
    float dBS = PApplet.dist(bigX, bigY, smallX, smallY);
    if (dBS < baseR * 0.45f) {
        smallX = (smallX + midX) * 0.5f;
        smallY = (smallY + midY) * 0.5f;
    }
    // Clamp to world bounds
    midX = PApplet.constrain(midX, w * 0.05f, w * 0.95f);
    midY = PApplet.constrain(midY, h * 0.05f, h * 0.95f);
    smallX = PApplet.constrain(smallX, w * 0.05f, w * 0.95f);
    smallY = PApplet.constrain(smallY, h * 0.05f, h * 0.95f);

    NebulaData[] arr = new NebulaData[3];
    float[][] finalPos = {{bigX, bigY}, {midX, midY}, {smallX, smallY}};
    for (int i = 0; i < 3; i++) {
        int col = NEBULA_PALETTE[rng.nextInt(NEBULA_PALETTE.length)];
        arr[i] = new NebulaData(
            finalPos[i][0], finalPos[i][1], col,
            10 + rng.nextInt(10), radii[i], 16,
            0.010f + rng.nextFloat() * 0.02f,
            0.010f + rng.nextFloat() * 0.02f,
            20 + rng.nextFloat() * 30f,
            15 + rng.nextFloat() * 25f,
            rng.nextFloat() * PApplet.TWO_PI,
            rng.nextFloat() * PApplet.TWO_PI
        );
    }
    return arr;
}

static void getViewportBounds(LevelDef lv, float margin,
                               float[] outMinMax) {
    Camera2D cam = TowerDefenseMin2.inst.camera;
    Rect vp = (cam != null) ? cam.getViewport() : null;
    if (vp != null) {
        outMinMax[0] = vp.x - margin;
        outMinMax[1] = vp.y - margin;
        outMinMax[2] = vp.x + vp.width + margin;
        outMinMax[3] = vp.y + vp.height + margin;
    } else {
        outMinMax[0] = -lv.worldW;
        outMinMax[1] = -lv.worldH;
        outMinMax[2] = lv.worldW * 2;
        outMinMax[3] = lv.worldH * 2;
    }
}

static class WorldBgRenderer extends RendererComponent {
    // Grid line visibility toggle (default hidden for platform-style maps)
    static boolean SHOW_GRID_LINES = false;
    // LOD: true when camera is zoomed out (reduces background rendering cost)
    static boolean lodActive = false;
    final int layerIndex;

    WorldBgRenderer() { this(3); }
    WorldBgRenderer(int layerIndex) { this.layerIndex = layerIndex; }

    @Override
    public void update(float dt) {
        Camera2D cam = TowerDefenseMin2.inst.camera;
        if (cam != null) {
            lodActive = cam.getZoom() <= TdAssets.getBgLodZoomThreshold();
        }
    }

    protected void renderShape(PGraphics g) {
        LevelDef lv = TdGameWorld.level;
        if (lv == null) return;
        float time = TowerDefenseMin2.inst.engine.getGameTime().getTotalTime();

        switch (layerIndex) {
            case 0: drawFarLayer(g, lv, time); break;
            case 1: drawMidLayer(g, lv, time); break;
            case 2: drawNearLayer(g, lv, time); break;
            default: drawPlatformLayer(g, lv, time); break;
        }
    }

    void drawBlockedZonesForLayer(PGraphics g, LevelDef lv, float time, int layer) {
        if (lv.blockedZones == null || !TdAssets.isRenderBlockedZones()) return;
        int[] layers = getZoneLayers(lv);
        for (int i = 0; i < lv.blockedZones.length; i++) {
            if (layers[i] == layer) drawBlockedZone(g, lv.blockedZones[i], time);
        }
    }

    void drawFarLayer(PGraphics g, LevelDef lv, float time) {
        // Deep space background (3x3 area to avoid edge visibility under parallax)
        g.noStroke();
        g.fill(0xFF080A14);
        g.rect(-lv.worldW, -lv.worldH, lv.worldW * 3, lv.worldH * 3);
        if (lodActive) {
            // LOD: still draw blocked zones even when stars are skipped
            drawBlockedZonesForLayer(g, lv, time, 0);
            return;
        }

        // Far stars — sparse, small, dim (precomputed + viewport-culled)
        if (TdAssets.isRenderStars()) {
            StarData[] stars = FAR_STARS.get(lv.id);
            if (stars == null) {
                stars = generateFarStars(lv);
                FAR_STARS.put(lv.id, stars);
            }
            float[] b = new float[4];
            getViewportBounds(lv, lv.worldW * 0.5f, b);
            float brightness = TdAssets.getStarBrightness();
            g.noStroke();
            for (StarData s : stars) {
                if (s.x < b[0] || s.x > b[2] || s.y < b[1] || s.y > b[3]) continue;
                int a = (int)(((s.col >>> 24) & 0xFF) * brightness);
                g.fill((a << 24) | (s.col & 0x00FFFFFF));
                g.rect(s.x, s.y, s.size, s.size);
            }
        }

        // Blocked zones assigned to far layer
        drawBlockedZonesForLayer(g, lv, time, 0);
    }

    void drawMidLayer(PGraphics g, LevelDef lv, float time) {
        // Mid stars — medium density (precomputed + viewport-culled)
        if (TdAssets.isRenderStars()) {
            StarData[] stars = MID_STARS.get(lv.id);
            if (stars == null) {
                stars = generateMidStars(lv);
                MID_STARS.put(lv.id, stars);
            }
            float[] b = new float[4];
            getViewportBounds(lv, lv.worldW * 0.5f, b);
            float brightness = TdAssets.getStarBrightness();
            g.noStroke();
            for (StarData s : stars) {
                if (s.x < b[0] || s.x > b[2] || s.y < b[1] || s.y > b[3]) continue;
                int a = (int)(((s.col >>> 24) & 0xFF) * brightness);
                g.fill((a << 24) | (s.col & 0x00FFFFFF));
                g.rect(s.x, s.y, s.size, s.size);
            }
        }

        // Procedural nebula clouds (slow drift, per-level random)
        if (TdAssets.isRenderNebulas()) {
            NebulaData[] nebulas = NEBULA_CACHE.get(lv.id);
            if (nebulas == null) {
                nebulas = generateNebulas(lv);
                NEBULA_CACHE.put(lv.id, nebulas);
            }
            float nebBrightness = TdAssets.getStarBrightness();
            g.noStroke();
            for (NebulaData n : nebulas) {
                float nx = n.x + PApplet.sin(time * n.driftFreqX + n.driftPhaseX) * n.driftAmpX;
                float ny = n.y + PApplet.cos(time * n.driftFreqY + n.driftPhaseY) * n.driftAmpY;
                g.fill(n.col, (int)(n.alpha * nebBrightness));
                drawPolyCircle(g, nx, ny, n.radius, n.verts);
            }
        }

        // Blocked zones assigned to mid layer
        drawBlockedZonesForLayer(g, lv, time, 1);
    }

    void drawNearLayer(PGraphics g, LevelDef lv, float time) {
        // Bright focal stars with glow (precomputed + viewport-culled)
        GlowStarData[] stars = NEAR_STARS.get(lv.id);
        if (stars == null) {
            stars = generateNearStars(lv);
            NEAR_STARS.put(lv.id, stars);
        }
        float[] b = new float[4];
        getViewportBounds(lv, lv.worldW * 0.5f, b);
        float brightness = TdAssets.getStarBrightness();
        if (!TdAssets.isRenderStars()) brightness = 0;
        for (GlowStarData s : stars) {
            if (s.x < b[0] || s.x > b[2] || s.y < b[1] || s.y > b[3]) continue;
            float cx = s.x + s.size * 0.5f;
            float cy = s.y + s.size * 0.5f;
            float half = s.size * 0.5f;
            if (lodActive) {
                // LOD: simple rect instead of glow polygons when zoomed out
                // Match the core star brightness (230) so LOD switch is less noticeable
                g.fill(255, 255, 255, (int)(230 * brightness));
                g.rect(cx - 2, cy - 2, 4, 4);
            } else {
                // Outer glow
                g.fill(200, 210, 255, (int)(35 * brightness));
                drawPolyCircle(g, cx, cy, half + 4, 12);
                // Inner glow
                g.fill(220, 230, 255, (int)(70 * brightness));
                drawPolyCircle(g, cx, cy, half + 1, 10);
                // Core
                g.fill(255, 255, 255, (int)(230 * brightness));
                drawPolyCircle(g, cx, cy, half, 8);
            }
        }

        // Blocked zones assigned to near layer
        drawBlockedZonesForLayer(g, lv, time, 2);
    }

    void drawPlatformLayer(PGraphics g, LevelDef lv, float time) {
        // Platform base & terrain
        if (TdAssets.isRenderPlatformLayer()) {
            // Platform base (only if no platforms defined)
            if (lv.platforms == null || lv.platforms.length == 0) {
                g.noStroke();
                g.fill(0xFF14182B);
                g.rect(0, 0, lv.worldW, lv.worldH);
            }

            // Platforms (buildable terrain with glowing edges)
            if (lv.platforms != null) {
                for (PlatformZone pz : lv.platforms) {
                    if (pz.vertices == null || pz.vertices.length < 3) continue;
                    float seed = pz.vertices[0].x + pz.vertices[0].y;
                    float pulse = 0.75f + 0.25f * PApplet.sin(time * 1.5f + seed * 0.01f);
                    // Outer glow
                    g.noFill();
                    g.stroke(pz.edgeColor, (int)(50 * pulse));
                    g.strokeWeight(5f);
                    g.beginShape();
                    for (Vector2 v : pz.vertices) g.vertex(v.x, v.y);
                    g.endShape(PApplet.CLOSE);
                    // Inner sharp edge
                    g.stroke(pz.edgeColor, 200);
                    g.strokeWeight(1.5f);
                    g.beginShape();
                    for (Vector2 v : pz.vertices) g.vertex(v.x, v.y);
                    g.endShape(PApplet.CLOSE);
                    // Interior fill
                    g.noStroke();
                    g.fill(pz.fillColor);
                    g.beginShape();
                    for (Vector2 v : pz.vertices) g.vertex(v.x, v.y);
                    g.endShape(PApplet.CLOSE);
                }
            }
        }

        // Blocked zones assigned to platform layer
        drawBlockedZonesForLayer(g, lv, time, 3);

        // Grid lines (toggleable, default hidden)
        if (SHOW_GRID_LINES) {
            g.stroke(0xFF354A6B);
            g.strokeWeight(1);
            g.noFill();
            for (int gx = 0; gx <= lv.worldW; gx += TdConfig.GRID) {
                g.line(gx, 0, gx, lv.worldH);
            }
            for (int gy = 0; gy <= lv.worldH; gy += TdConfig.GRID) {
                g.line(0, gy, lv.worldW, gy);
            }
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

        // Glow 锟?red by default, gold when carrying orbs
        g.noStroke();
        if (enemy.orbsCarried > 0) {
            g.fill(0xFFFFDD00, 80);
        } else {
            g.fill(0xFFFF4444, 60);
        }
        drawPolyCircle(g, 0, 0, r * 1.4f, 16);

        // Body 锟?red by default, gold only when carrying orbs
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

        // Orb capacity indicator 锟?small dots behind body
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
            drawRoundRect(g, barX - 1, barY - 1, barW + 2, barH + 2, 2);
            g.fill(0xFF333333);
            drawRoundRect(g, barX, barY, barW, barH, 2);
            float hpPct = e.maxHp > 0 ? e.hp / e.maxHp : 0;
            int hpColor = hpPct > 0.5f ? 0xFF44FF66 : (hpPct > 0.25f ? 0xFFFFCC44 : 0xFFFF4444);
            g.fill(hpColor);
            drawRoundRect(g, barX, barY, barW * hpPct, barH, 2);
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
        boolean shouldShowRange = app.showTowerRanges || app.buildMode != TdBuildMode.NONE || tower == app.hoveredTower;
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
            drawRoundRect(g, x - half, y - half, size, size, 4);
            g.fill(c, (int)(120 * fade));
            drawRoundRect(g, x - half, y - half, size * prog, size, 4);
            // Static build border
            g.noFill();
            g.stroke(c, (int)(150 * fade));
            g.strokeWeight(2);
            drawRoundRect(g, x - half, y - half, size, size, 4);
            return;
        }

        // Upgrade animation
        if (tower.isUpgrading) {
            float targetTime = (tower.upgradeLevel == 0) ? tower.def.upgradeBuildTime : tower.def.upgrade2BuildTime;
            float prog = tower.upgradeProgress / targetTime;
            g.noStroke();
            g.fill(0xFF444444, (int)(180 * fade));
            drawRoundRect(g, x - half, y - half, size, size, 4);
            g.fill(0xFFC0C0C0, (int)(120 * fade));
            drawRoundRect(g, x - half, y - half, size * prog, size, 4);
            // Static upgrade border
            g.noFill();
            g.stroke(0xFFC0C0C0, (int)(150 * fade));
            g.strokeWeight(2);
            drawRoundRect(g, x - half, y - half, size, size, 4);
            return;
        }

        // Tower shadow
        g.noStroke();
        g.fill(0xFF000000, (int)(60 * fade));
        drawRoundRect(g, x - half + 3, y - half + 3, size, size, 4);

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
            drawRoundRect(g, tower.gridX * TdConfig.GRID + 2, tower.gridY * TdConfig.GRID + 2,
                   TdConfig.GRID - 4, TdConfig.GRID - 4, 6);
        }

        // Tower body by type
        g.noStroke();
        g.fill(c, (int)(255 * fade));
        switch (tower.def.type) {
            case MG:
                drawRoundRect(g, x - half, y - half, size, size, 3);
                g.fill(0xFFFFFFFF, (int)(120 * fade));
                drawRoundRect(g, x - half + 4, y - half + 4, size - 8, 4, 1);
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
                drawRoundRect(g, -half, -half, size, size, 3);
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
                    drawRoundRect(g, x - half - 1, y - half - 1, size + 2, size + 2, 3);
                    break;
                case MISSILE:
                    drawPolyCircle(g, x, y, half + 1.5f, 24);
                    break;
                case LASER:
                    g.pushMatrix();
                    g.translate(x, y);
                    g.rotate(PApplet.PI / 4);
                    drawRoundRect(g, -half - 1.5f, -half - 1.5f, size + 3, size + 3, 3);
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
                        drawRoundRect(g, x - half + 1, y - half + 1, size - 2, size - 2, 3);
                        break;
                    case MISSILE:
                        drawPolyCircle(g, x, y, half - 1, 24);
                        break;
                    case LASER:
                        g.pushMatrix();
                        g.translate(x, y);
                        g.rotate(PApplet.PI / 4);
                        drawRoundRect(g, -half + 1, -half + 1, size - 2, size - 2, 3);
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
                        drawRoundRect(g, x - half + 3, y - half + 3, size - 6, size - 6, 3);
                        break;
                    case MISSILE:
                        drawPolyCircle(g, x, y, half - 3, 24);
                        break;
                    case LASER:
                        g.pushMatrix();
                        g.translate(x, y);
                        g.rotate(PApplet.PI / 4);
                        drawRoundRect(g, -half + 3, -half + 3, size - 6, size - 6, 3);
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
                        drawRoundRect(g, x - half, y - half, size, size, 3);
                        break;
                    case MISSILE:
                        drawPolyCircle(g, x, y, half, 24);
                        break;
                    case LASER:
                        g.pushMatrix();
                        g.translate(x, y);
                        g.rotate(PApplet.PI / 4);
                        drawRoundRect(g, -half, -half, size, size, 3);
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
                    drawRoundRect(g, x - half - 2, y - half - 2, size + 4, size + 4, 4);
                    break;
                case MISSILE:
                    drawPolyCircle(g, x, y, half + 3, 24);
                    break;
                case LASER:
                    g.pushMatrix();
                    g.translate(x, y);
                    g.rotate(PApplet.PI / 4);
                    drawRoundRect(g, -half - 3, -half - 3, size + 6, size + 6, 4);
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

    // 鈹€鈹€鈹€ Dashed border helpers (marching ants) 鈹€鈹€鈹€

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
        // Rotated 45掳 rect vertices (same as laser body)
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
 * Lives at renderLayer 95 锟?above bullets, below HP bars.
 */
static class EffectRenderer extends RendererComponent {
    protected void renderShape(PGraphics g) {
        for (Effect e : TdGameWorld.effects) {
            e.render(g);
        }
    }
}

/** Lightweight round-rect drawn with beginShape (avoids P2D rect() radius overhead). */
static void drawRoundRect(PGraphics g, float x, float y, float w, float h, float r) {
    if (r <= 0.5f) {
        g.rect(x, y, w, h);
        return;
    }
    r = Math.min(r, Math.min(w * 0.5f, h * 0.5f));
    int segs = Math.max(2, (int)(r * 0.6f));
    g.beginShape();
    // Top edge
    g.vertex(x + r, y);
    g.vertex(x + w - r, y);
    // Top-right corner
    for (int i = 1; i <= segs; i++) {
        float a = PApplet.lerp(-PApplet.HALF_PI, 0, (float)i / segs);
        g.vertex(x + w - r + PApplet.cos(a) * r, y + r + PApplet.sin(a) * r);
    }
    // Right edge
    g.vertex(x + w, y + h - r);
    // Bottom-right corner
    for (int i = 1; i <= segs; i++) {
        float a = PApplet.lerp(0, PApplet.HALF_PI, (float)i / segs);
        g.vertex(x + w - r + PApplet.cos(a) * r, y + h - r + PApplet.sin(a) * r);
    }
    // Bottom edge
    g.vertex(x + r, y + h);
    // Bottom-left corner
    for (int i = 1; i <= segs; i++) {
        float a = PApplet.lerp(PApplet.HALF_PI, PApplet.PI, (float)i / segs);
        g.vertex(x + r + PApplet.cos(a) * r, y + h - r + PApplet.sin(a) * r);
    }
    // Left edge
    g.vertex(x, y + r);
    // Top-left corner
    for (int i = 1; i <= segs; i++) {
        float a = PApplet.lerp(PApplet.PI, PApplet.PI + PApplet.HALF_PI, (float)i / segs);
        g.vertex(x + r + PApplet.cos(a) * r, y + r + PApplet.sin(a) * r);
    }
    g.endShape(PApplet.CLOSE);
}