/**
 * Horizontal level list using TdLevelCard components.
 * Parent container manages layout, scroll animation, and input.
 * Cards are dynamically positioned/sized for center-large / side-small effect.
 */
static class TdLevelList extends Panel {

    ArrayList<TdLevelCard> cards = new ArrayList<>();
    int selectedIndex = 0;
    float scrollX = 0f;
    float targetScrollX = 0f;
    int pressedCardIndex = -1;
    Runnable onEnterAction;
    TowerDefenseMin2 appRef;
    TdLabel emptyLabel;

    // Chapter memory: last selected index per chapter
    static final int[] CHAPTER_MEMORY = new int[4];

    static final float CARD_W = 220f;
    static final float CARD_H = 240f;
    static final float SLOT_W = 260f;
    static final float SIDE_SCALE = 0.77f;
    static final float FADE_EDGE = 0.12f;

    PGraphics buffer;
    PShader fadeShader;

    TdLevelList(String id, TowerDefenseMin2 app) {
        super(id);
        this.appRef = app;
        setPaintBackground(false);
    }

    void loadLevels(int chapter) {
        // Remove old card children
        for (TdLevelCard card : cards) {
            remove(card);
        }
        cards.clear();

        // Restore memory for this chapter
        int memoryIndex = (chapter >= 0 && chapter < CHAPTER_MEMORY.length) ? CHAPTER_MEMORY[chapter] : 0;
        selectedIndex = memoryIndex;
        updateTargetScroll();
        scrollX = targetScrollX;

        ArrayList<String> ids = getLevelIdsForChapter(chapter);
        int maxReached = TdSaveData.getMaxLevelReached();

        PImage defaultPreview = appRef.loadImage("textures/thumbnails/chapter1_0.jpg");

        if (emptyLabel == null) {
            emptyLabel = new TdLabel("lbl_empty");
            emptyLabel.setBounds(0, 0, (int) getWidth(), (int) getHeight());
            emptyLabel.setTextAlign(PApplet.CENTER);
            emptyLabel.setLabelStyle(TdLabel.Style.HINT);
            emptyLabel.setCustomTextSize(Math.max(10, CARD_H * 0.058f));
            emptyLabel.setVisible(false);
            add(emptyLabel);
        }

        if (ids.isEmpty()) {
            emptyLabel.setText("暂无关卡");
            emptyLabel.setVisible(true);
        } else {
            emptyLabel.setVisible(false);
        }

        boolean alwaysUnlock = (chapter == 3);
        for (String lid : ids) {
            String name = TdAssets.i18n("level." + lid + ".name");
            if (name == null || name.startsWith("level.")) {
                name = TdAssets.i18n("levelSelect.level", lid);
            }

            TdLevelCard card = new TdLevelCard("card_" + lid);
            card.setPreviewImage(defaultPreview);
            card.setLevelName(name);
            card.setLevelId(lid);
            boolean unlocked = alwaysUnlock;
            if (!unlocked) {
                int idx = getLevelIndex(lid);
                if (idx > 0) {
                    unlocked = idx <= maxReached;
                } else {
                    unlocked = false;
                }
            }
            card.setUnlocked(unlocked);
            card.setCleared(unlocked && TdCompletion.hasAnyCompletion(lid));
            card.setSelected(false);
            card.setEnabled(false); // events managed by parent
            card.setVisible(false);
            add(card);
            cards.add(card);
        }
    }

    String getSelectedLevelId() {
        if (selectedIndex >= 0 && selectedIndex < cards.size()) {
            return cards.get(selectedIndex).getLevelId();
        }
        return null;
    }

    boolean isSelectedUnlocked() {
        if (selectedIndex < 0 || selectedIndex >= cards.size()) return false;
        return cards.get(selectedIndex).isUnlocked();
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

    void saveChapterMemory(int chapter) {
        if (chapter >= 0 && chapter < CHAPTER_MEMORY.length) {
            CHAPTER_MEMORY[chapter] = selectedIndex;
        }
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);

        // Smooth scroll
        if (Math.abs(scrollX - targetScrollX) > 0.5f) {
            scrollX += (targetScrollX - scrollX) * Math.min(1f, 12f * dt);
        } else {
            scrollX = targetScrollX;
        }

        // Layout cards
        layoutCards();

        // Sync hover state after children update (children are disabled, so Button.update won't set hover)
        float mx = UIManager.getDesignMouseX();
        float my = UIManager.getDesignMouseY();
        for (TdLevelCard card : cards) {
            card.setHover(card.isVisible() && !card.isAnimating() && card.containsPoint(mx, my));
        }
    }

    private void layoutCards() {
        float centerX = getWidth() / 2f;

        for (int i = 0; i < cards.size(); i++) {
            TdLevelCard card = cards.get(i);
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

            card.setPosition(x, y);
            card.setSize(cardW, cardH);
            card.setSelected(dist < 0.5f);

            // Visibility culling
            boolean visible = (x + cardW > -20 && x < getWidth() + 20);
            card.setVisible(visible);
        }
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        if (w <= 0 || h <= 0) return;

        float scale = appRef.engine.getDisplayManager().getUniformScale();
        int bufW = Math.round(w * scale);
        int bufH = Math.round(h * scale);

        // Create/recreate buffer when size changes
        if (buffer == null || buffer.width != bufW || buffer.height != bufH) {
            buffer = applet.createGraphics(bufW, bufH, JAVA2D);
            if (fadeShader == null) {
                fadeShader = applet.loadShader("shaders/carousel_fade.glsl");
            }
        }

        // Save original positions and temporarily scale children for high-res rendering
        int n = cards.size();
        float[] savedX = new float[n];
        float[] savedY = new float[n];
        float[] savedW = new float[n];
        float[] savedH = new float[n];
        for (int i = 0; i < n; i++) {
            TdLevelCard card = cards.get(i);
            savedX[i] = card.getX();
            savedY[i] = card.getY();
            savedW[i] = card.getWidth();
            savedH[i] = card.getHeight();
            card.setPosition(savedX[i] * scale, savedY[i] * scale);
            card.setSize(savedW[i] * scale, savedH[i] * scale);
        }

        float emptySavedW = 0, emptySavedH = 0, emptySavedTextSize = 0;
        if (emptyLabel != null && emptyLabel.isVisible()) {
            emptySavedW = emptyLabel.getWidth();
            emptySavedH = emptyLabel.getHeight();
            emptySavedTextSize = emptyLabel.getCustomTextSize();
            emptyLabel.setSize(emptySavedW * scale, emptySavedH * scale);
            emptyLabel.setCustomTextSize(emptySavedTextSize * scale);
        }

        // Temporarily offset position so children paint at buffer-local coordinates
        float origX = getX();
        float origY = getY();
        setPosition(origX - ax, origY - ay);

        // Draw children into offscreen buffer by swapping applet.g
        PGraphics originalG = applet.g;
        try {
            applet.g = buffer;
            buffer.beginDraw();
            buffer.background(0, 0);
            paintChildren(applet, theme);
            buffer.endDraw();
        } finally {
            applet.g = originalG;
            setPosition(origX, origY);
        }

        // Restore children to logical sizes
        for (int i = 0; i < n; i++) {
            TdLevelCard card = cards.get(i);
            card.setPosition(savedX[i], savedY[i]);
            card.setSize(savedW[i], savedH[i]);
        }
        if (emptyLabel != null && emptyLabel.isVisible()) {
            emptyLabel.setSize(emptySavedW, emptySavedH);
            emptyLabel.setCustomTextSize(emptySavedTextSize);
        }

        // Snapshot and apply edge-fade shader
        PImage snapshot = buffer.get();
        applet.shader(fadeShader);
        fadeShader.set("edgeWidth", FADE_EDGE);
        fadeShader.set("globalAlpha", getEffectiveAlpha());
        applet.image(snapshot, ax, ay, w, h);
        applet.resetShader();
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        // Empty: cards paint themselves via paintChildren
        if (cards.isEmpty()) {
            applet.textAlign(PApplet.CENTER, PApplet.CENTER);
            applet.fill(0xFF8899AA);
            applet.textSize(18);
            applet.text(TdAssets.i18n("levelSelect.empty"), getAbsoluteX() + getWidth() / 2f, getAbsoluteY() + getHeight() / 2f);
        }
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;

        switch (event.getType()) {
            case MOUSE_PRESSED:
                int pressedIdx = findCardAt(absMouseX, absMouseY);
                if (pressedIdx >= 0) {
                    pressedCardIndex = pressedIdx;
                    cards.get(pressedIdx).setPressedVisual(true);
                    return true;
                }
                return false;

            case MOUSE_RELEASED:
                int releasedIdx = findCardAt(absMouseX, absMouseY);
                if (pressedCardIndex >= 0 && releasedIdx == pressedCardIndex) {
                    TdLevelCard card = cards.get(pressedCardIndex);
                    if (pressedCardIndex == selectedIndex) {
                        if (card.isUnlocked() && onEnterAction != null) {
                            TdSound.playClick();
                            onEnterAction.run();
                        }
                    } else {
                        TdSound.playClick();
                        selectedIndex = pressedCardIndex;
                        updateTargetScroll();
                    }
                }
                if (pressedCardIndex >= 0 && pressedCardIndex < cards.size()) {
                    cards.get(pressedCardIndex).setPressedVisual(false);
                }
                pressedCardIndex = -1;
                return releasedIdx >= 0;

            case MOUSE_DRAGGED:
                return pressedCardIndex >= 0;

            default:
                return false;
        }
    }

    private int findCardAt(float absMx, float absMy) {
        for (int i = 0; i < cards.size(); i++) {
            TdLevelCard card = cards.get(i);
            if (card.isVisible() && card.containsPoint(absMx, absMy)) {
                return i;
            }
        }
        return -1;
    }
}
