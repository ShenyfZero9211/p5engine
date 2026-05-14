/**
 * Horizontal level carousel with 3-slot visible layout (center large, sides small)
 * and GLSL shader edge fade on an offscreen PGraphics buffer.
 * Flickering is avoided by snapshotting the buffer via get() before shader draw.
 */
static class LevelCarousel extends Panel {

    static final class LevelCard {
        int levelId;
        String name;
        PImage preview;

        LevelCard(int levelId, String name, PImage preview) {
            this.levelId = levelId;
            this.name = name;
            this.preview = preview;
        }
    }

    // Layout constants (design-resolution pixels)
    static final float CARD_W = 220f;
    static final float CARD_H = 240f;
    static final float SIDE_SCALE = 0.77f;
    static final float SLOT_W = 260f;   // center-to-center distance
    static final float FADE_EDGE = 0.12f;

    ArrayList<LevelCard> cards = new ArrayList<>();
    int selectedIndex = 0;
    float scrollX = 0f;        // current animated scroll offset
    float targetScrollX = 0f;  // target scroll offset
    int pressedCardIndex = -1; // -1 = none pressed

    PGraphics buffer;
    PShader fadeShader;
    TowerDefenseMin2 appRef;
    Runnable onEnterAction;
    PImage defaultPreview;

    LevelCarousel(String id, TowerDefenseMin2 app) {
        super(id);
        this.appRef = app;
        setPaintBackground(false);
        this.defaultPreview = app.loadImage("textures/thumbnails/chapter1_0.jpg");
    }

    void loadLevels(int chapter) {
        cards.clear();
        selectedIndex = 0;
        scrollX = 0f;
        targetScrollX = 0f;

        ArrayList<Integer> ids = getLevelIdsForChapter(chapter);
        for (int lid : ids) {
            String name = TdAssets.i18n("level." + lid + ".name");
            if (name == null || name.startsWith("level.")) {
                name = TdAssets.i18n("levelSelect.level", lid);
            }
            PImage img = appRef.loadImage("previews/level_" + lid + ".png");
            cards.add(new LevelCard(lid, name, img));
        }
    }

    int getSelectedLevelId() {
        if (selectedIndex >= 0 && selectedIndex < cards.size()) {
            return cards.get(selectedIndex).levelId;
        }
        return -1;
    }

    boolean isSelectedUnlocked() {
        if (selectedIndex < 0 || selectedIndex >= cards.size()) return false;
        return cards.get(selectedIndex).levelId <= TdSaveData.getMaxLevelReached();
    }

    void prev() {
        if (selectedIndex > 0) {
            selectedIndex--;
            updateTargetScroll();
        }
    }

    void next() {
        if (selectedIndex < cards.size() - 1) {
            selectedIndex++;
            updateTargetScroll();
        }
    }

    void updateTargetScroll() {
        targetScrollX = -selectedIndex * SLOT_W;
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        if (Math.abs(scrollX - targetScrollX) > 0.5f) {
            scrollX += (targetScrollX - scrollX) * Math.min(1f, 12f * dt);
        } else {
            scrollX = targetScrollX;
        }
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        if (w <= 0 || h <= 0) return;

        // Create buffer once; use JAVA2D to avoid P2D FBO flickering and alpha issues
        if (buffer == null || buffer.width != (int) w || buffer.height != (int) h) {
            buffer = applet.createGraphics((int) w, (int) h, JAVA2D);
            fadeShader = applet.loadShader("shaders/carousel_fade.glsl");
        }

        buffer.beginDraw();
        if (applet.g.textFont != null) {
            buffer.textFont(applet.g.textFont);
        }
        buffer.background(0, 0); // transparent

        if (cards.isEmpty()) {
            buffer.textAlign(PApplet.CENTER, PApplet.CENTER);
            buffer.fill(0xFF8899AA);
            buffer.textSize(18);
            buffer.text(TdAssets.i18n("levelSelect.empty"), buffer.width / 2f, buffer.height / 2f);
        } else {
            drawCards(buffer);
        }

        buffer.endDraw();

        // Snapshot buffer to a fresh PImage (JAVA2D -> PImage copy, no stale texture cache)
        PImage snapshot = buffer.get();

        // Apply edge-fade shader and draw to screen
        applet.shader(fadeShader);
        fadeShader.set("edgeWidth", FADE_EDGE);
        fadeShader.set("globalAlpha", getEffectiveAlpha());
        applet.image(snapshot, ax, ay);
        applet.resetShader();
    }

    private void drawCards(PGraphics g) {
        float centerX = g.width / 2f;
        int maxReached = TdSaveData.getMaxLevelReached();

        for (int i = 0; i < cards.size(); i++) {
            LevelCard card = cards.get(i);
            float offsetIndex = i - selectedIndex + (scrollX - targetScrollX) / SLOT_W;
            float cx = centerX + offsetIndex * SLOT_W;

            // Compute scale based on distance from center
            float dist = Math.abs(offsetIndex);
            float scale;
            if (dist < 0.5f) {
                scale = 1.0f;
            } else if (dist < 1.5f) {
                float t = (dist - 0.5f);
                scale = 1.0f - t * (1.0f - SIDE_SCALE);
            } else {
                scale = SIDE_SCALE;
            }

            boolean isPressed = (i == pressedCardIndex);
            if (isPressed) {
                scale *= 0.96f;
            }

            float cardW = CARD_W * scale;
            float cardH = CARD_H * scale;
            float x = cx - cardW / 2f;
            float y = (g.height - cardH) / 2f;

            // Cull cards far outside visible area
            if (x + cardW < -20 || x > g.width + 20) continue;

            boolean isSelected = dist < 0.5f;
            boolean unlocked = card.levelId <= maxReached;
            boolean cleared = unlocked && TdCompletion.hasAnyCompletion(card.levelId);

            g.pushMatrix();
            g.translate(x, y);

            // Card background
            g.noStroke();
            int bgColor = isPressed ? 0xFF151B2E : 0xFF1A2035;
            g.fill(bgColor);
            g.rect(0, 0, cardW, cardH, 4);

            // Preview image or placeholder
            float previewMargin = 6 * scale;
            float previewH = cardH * 0.55f;
            float px = previewMargin;
            float py = previewMargin;
            float pw = cardW - previewMargin * 2;
            float ph = previewH;

            PImage previewImg = (card.preview != null) ? card.preview : defaultPreview;
            if (previewImg != null) {
                g.imageMode(PApplet.CORNER);
                g.image(previewImg, px, py, pw, ph);
            } else {
                // Placeholder: dark rect with grid pattern hint
                g.noStroke();
                g.fill(0xFF111827);
                g.rect(px, py, pw, ph, 2);
                // Draw a small cross/plus pattern
                g.stroke(0xFF2A3A55);
                g.strokeWeight(1);
                float cx2 = px + pw / 2;
                float cy2 = py + ph / 2;
                g.line(cx2 - 10 * scale, cy2, cx2 + 10 * scale, cy2);
                g.line(cx2, cy2 - 10 * scale, cx2, cy2 + 10 * scale);
            }

            // Level name (bottom area)
            g.fill(0xFFE0E6F0);
            g.textAlign(PApplet.CENTER, PApplet.CENTER);
            g.textSize(Math.max(10, 14 * scale));
            float nameY = cardH - (cardH - previewH) / 2f - previewMargin;
            g.text(card.name, cardW / 2f, nameY);

            // Border
            if (isSelected) {
                // Accent glow border
                g.stroke(0xFF4A9EFF);
                g.strokeWeight(2);
                g.noFill();
                g.rect(1, 1, cardW - 2, cardH - 2, 4);
                // Subtle inner glow
                g.stroke(0x404A9EFF);
                g.strokeWeight(1);
                g.rect(2, 2, cardW - 4, cardH - 4, 3);
            } else {
                g.stroke(0xFF2A3A55);
                g.strokeWeight(1);
                g.noFill();
                g.rect(0.5f, 0.5f, cardW - 1, cardH - 1, 4);
            }

            // Lock overlay
            if (!unlocked) {
                g.noStroke();
                g.fill(0xB0000000);
                g.rect(0, 0, cardW, cardH, 4);
                drawLock(g, cardW / 2f, cardH / 2f, scale);
            } else if (cleared) {
                drawClearedBadge(g, cardW - 12 * scale, 10 * scale, scale);
            }

            g.popMatrix();
        }
    }

    private void drawLock(PGraphics g, float cx, float cy, float scale) {
        g.pushStyle();
        g.noFill();
        g.stroke(0xFF999999);
        g.strokeWeight(2.0f);
        g.strokeCap(PApplet.ROUND);
        float r = 5 * scale;
        g.arc(cx, cy - 1 * scale, r * 2, r * 2, PApplet.PI, PApplet.TWO_PI);
        g.noStroke();
        g.fill(0xFF999999);
        g.rect(cx - r, cy - 1 * scale, r * 2, r + 2 * scale, 1.5f * scale);
        g.fill(0xFF444444);
        g.ellipse(cx, cy + 2 * scale, 2 * scale, 2 * scale);
        g.popStyle();
    }

    private void drawClearedBadge(PGraphics g, float cx, float cy, float scale) {
        g.pushStyle();
        g.noStroke();
        g.fill(0xFF4ADE80, 64);
        g.ellipse(cx, cy, 12 * scale, 12 * scale);
        g.fill(0xFF4ADE80);
        g.ellipse(cx, cy, 8 * scale, 8 * scale);
        g.stroke(0xFFFFFFFF);
        g.strokeWeight(1.5f);
        g.strokeCap(PApplet.ROUND);
        g.line(cx - 2 * scale, cy, cx, cy + 2 * scale);
        g.line(cx, cy + 2 * scale, cx + 3 * scale, cy - 2 * scale);
        g.popStyle();
    }

    private int findCardAt(float localMx, float localMy) {
        float centerX = getWidth() / 2f;
        for (int i = 0; i < cards.size(); i++) {
            float offsetIndex = i - selectedIndex + (scrollX - targetScrollX) / SLOT_W;
            float cx = centerX + offsetIndex * SLOT_W;
            float dist = Math.abs(offsetIndex);
            float scale;
            if (dist < 0.5f) {
                scale = 1.0f;
            } else if (dist < 1.5f) {
                float t = (dist - 0.5f);
                scale = 1.0f - t * (1.0f - SIDE_SCALE);
            } else {
                scale = SIDE_SCALE;
            }
            float cardW = CARD_W * scale;
            float cardH = CARD_H * scale;
            float x = cx - cardW / 2f;
            float y = (getHeight() - cardH) / 2f;
            if (localMx >= x && localMx <= x + cardW && localMy >= y && localMy <= y + cardH) {
                return i;
            }
        }
        return -1;
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        float localMx = absMouseX - getAbsoluteX();
        float localMy = absMouseY - getAbsoluteY();

        if (event.getType() == UIEvent.Type.MOUSE_PRESSED) {
            pressedCardIndex = findCardAt(localMx, localMy);
            return pressedCardIndex >= 0;
        }

        if (event.getType() == UIEvent.Type.MOUSE_RELEASED) {
            int releasedCard = findCardAt(localMx, localMy);
            if (pressedCardIndex >= 0 && releasedCard == pressedCardIndex) {
                // Clicked on a card
                if (pressedCardIndex == selectedIndex) {
                    // Center card: enter level if unlocked
                    if (cards.get(pressedCardIndex).levelId <= TdSaveData.getMaxLevelReached() && onEnterAction != null) {
                        TdSound.playClick();
                        onEnterAction.run();
                    }
                } else {
                    // Side card: just scroll to center
                    TdSound.playClick();
                    selectedIndex = pressedCardIndex;
                    updateTargetScroll();
                }
            }
            pressedCardIndex = -1;
            return releasedCard >= 0;
        }

        return super.onEvent(event, absMouseX, absMouseY);
    }
}
