package shenyf.p5engine.ui;

import processing.core.PApplet;
import processing.event.MouseEvent;
import shenyf.p5engine.ui.tutorial.TutorialSequence;
import shenyf.p5engine.ui.tutorial.TutorialStep;

/**
 * A full-screen overlay that highlights a target area with a spotlight mask,
 * pulsing border, and a speech bubble with descriptive text.
 *
 * <p>Implements {@link EventInterceptor} to enforce click-locking: clicks outside
 * the target area are rejected with visual feedback (red flash + shake).
 *
 * <p>Add to the UI root with a high zOrder (e.g. 100) so it draws above everything.
 */
public class TutorialOverlay extends Panel implements EventInterceptor {

    private static final int MASK_COLOR = 0xCC000000;
    private static final int BORDER_COLOR = 0xFF00E5FF;   // cyan glow
    private static final int BUBBLE_COLOR = 0xE61A2035;   // dark blue
    private static final int TEXT_COLOR = 0xFFFFFFFF;
    private static final int REJECT_COLOR = 0x80FF0000;   // red flash overlay
    private static final int HINT_COLOR = 0xFFAAAAAA;

    private final UIManager uiManager;
    private TutorialSequence sequence;

    // Target area (design-resolution coordinates)
    private float targetX, targetY, targetW, targetH;
    private boolean hasTarget = false;
    // Additional target rectangles for multi-spotlight (screen coords, already scaled)
    private java.util.List<float[]> extraTargets = new java.util.ArrayList<>();

    // Animation state
    private float pulseTime = 0;
    private float rejectFlashAlpha = 0;
    private float rejectShakeTimer = 0;

    // Bubble layout
    private float bubblePad = 16;
    private float bubbleArrow = 10;
    private float bubbleMaxW = 420;
    private float bubbleCorner = 4;

    public TutorialOverlay(String id, UIManager uiManager) {
        super(id);
        this.uiManager = uiManager;
        setBounds(0, 0, 10000, 10000); // cover entire UI space
        setZOrder(100);
    }

    public void setSequence(TutorialSequence sequence) {
        this.sequence = sequence;
        refreshTarget();
    }

    public TutorialSequence getSequence() {
        return sequence;
    }

    public void refreshTarget() {
        hasTarget = false;
        extraTargets.clear();
        if (sequence == null || !sequence.isActive()) return;
        TutorialStep step = sequence.getCurrentStep();
        if (step == null) return;

        if (step.targetType == TutorialStep.TargetType.UI_COMPONENT && step.targetId != null) {
            UIComponent comp = uiManager.getRoot().findChildById(step.targetId);
            if (comp != null) {
                targetX = comp.getAbsoluteX();
                targetY = comp.getAbsoluteY();
                targetW = comp.getWidth();
                targetH = comp.getHeight();
                hasTarget = true;
            }
        } else if (step.targetType == TutorialStep.TargetType.SCREEN_RECT) {
            // SCREEN_RECT coords in JSON are design-resolution coords (origin at design area top-left).
            // TutorialOverlay paints in the FIT coordinate system where (0,0) is the design origin,
            // but the UI root itself is offset by (-ox, -oy) to cover the full physical screen.
            // We convert design coords to UI root internal coords by subtracting ox/oy.
            float ox = 0, oy = 0;
            var dm = uiManager.getDisplayManager();
            if (dm != null) {
                float us = dm.getUniformScale();
                ox = dm.getOffsetX() / us;
                oy = dm.getOffsetY() / us;
            }
            targetX = step.targetX - ox;
            targetY = step.targetY - oy;
            targetW = step.targetW;
            targetH = step.targetH;
            // If the rect matches the design-resolution viewport size, resize it to actual viewport
            if (step.targetW == 1280 - 240 && step.targetH == 720 - 48) {
                float sw = uiManager.getUiWidth();
                float sh = uiManager.getUiHeight();
                targetW = sw - 240;
                targetH = sh - 48;
            }
            hasTarget = true;
        } else if (step.targetType == TutorialStep.TargetType.WORLD_RECT) {
            var engine = shenyf.p5engine.core.P5Engine.getInstance();
            if (engine != null) {
                var scene = engine.getSceneManager().getActiveScene();
                if (scene != null) {
                    var camera = scene.getCamera();
                    var dm = uiManager.getDisplayManager();
                    if (camera != null && dm != null) {
                        shenyf.p5engine.math.Vector2 screen = camera.worldToScreen(
                                new shenyf.p5engine.math.Vector2(step.targetX, step.targetY));
                        float zoom = camera.getZoom();
                        float us = dm.getUniformScale();
                        float offX = dm.getOffsetX();
                        float offY = dm.getOffsetY();
                        // Convert screen pixels → design coords (same space as UI_COMPONENT targets)
                        float designX = (screen.x - offX) / us;
                        float designY = (screen.y - offY) / us;
                        targetX = designX - (step.targetW * zoom) / (2f * us);
                        targetY = designY - (step.targetH * zoom) / (2f * us);
                        targetW = step.targetW * zoom / us;
                        targetH = step.targetH * zoom / us;
                        hasTarget = true;
                    }
                }
            }
        } else if (step.targetType == TutorialStep.TargetType.FULL_SCREEN_NO_MASK) {
            hasTarget = true;
            targetX = targetY = targetW = targetH = 0;
            // skip targetRects — borders are drawn by world-layer TutorialGridRenderer
        } else if (step.targetType == TutorialStep.TargetType.GLOBAL) {
            hasTarget = true;
            targetX = targetY = targetW = targetH = 0;
        }
        // Additional target rectangles (already in screen/design coords)
        if (step.targetRects != null && !step.targetRects.isEmpty()) {
            var engine = shenyf.p5engine.core.P5Engine.getInstance();
            var camera = (engine != null) ? engine.getSceneManager().getActiveScene().getCamera() : null;
            var dm = uiManager.getDisplayManager();
            for (float[] r : step.targetRects) {
                if (r == null || r.length < 4) continue;
                if (step.targetType == TutorialStep.TargetType.WORLD_RECT && camera != null && dm != null) {
                    shenyf.p5engine.math.Vector2 screen = camera.worldToScreen(
                            new shenyf.p5engine.math.Vector2(r[0], r[1]));
                    float zoom = camera.getZoom();
                    float us = dm.getUniformScale();
                    float offX = dm.getOffsetX();
                    float offY = dm.getOffsetY();
                    float designX = (screen.x - offX) / us;
                    float designY = (screen.y - offY) / us;
                    extraTargets.add(new float[]{
                        designX - (r[2] * zoom) / (2f * us),
                        designY - (r[3] * zoom) / (2f * us),
                        r[2] * zoom / us,
                        r[3] * zoom / us
                    });
                } else if (step.targetType == TutorialStep.TargetType.FULL_SCREEN_NO_MASK) {
                    // Borders drawn by world-layer renderer; skip UI-layer conversion
                    continue;
                } else {
                    extraTargets.add(new float[]{r[0], r[1], r[2], r[3]});
                }
            }
        }
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        pulseTime += dt;
        if (rejectFlashAlpha > 0) {
            rejectFlashAlpha -= dt * 3.0f;
            if (rejectFlashAlpha < 0) rejectFlashAlpha = 0;
        }
        if (rejectShakeTimer > 0) {
            rejectShakeTimer -= dt * 5.0f;
            if (rejectShakeTimer < 0) rejectShakeTimer = 0;
        }
        if (sequence != null) {
            sequence.update(dt);
            // If step changed, refresh target
            refreshTarget();
        }
    }

    @Override
    public void paint(PApplet g, Theme theme) {
        if (!isVisible()) return;
        if (sequence == null || !sequence.isActive()) return;
        if (!sequence.isStepReady()) return;
        if (!hasTarget) return;

        float sw = uiManager.getUiWidth();
        float sh = uiManager.getUiHeight();
        // UIManager root bounds may not be set yet before first render()
        if (sw < 100 || sh < 100) {
            if (uiManager.getDisplayManager() != null) {
                sw = uiManager.getDisplayManager().getDesignWidth();
                sh = uiManager.getDisplayManager().getDesignHeight();
            } else {
                sw = g.width;
                sh = g.height;
            }
        }

        TutorialStep step = sequence.getCurrentStep();
        boolean isGlobal = (step != null && step.targetType == TutorialStep.TargetType.GLOBAL);
        boolean isNoMask = (step != null && step.targetType == TutorialStep.TargetType.FULL_SCREEN_NO_MASK);

        // Compute shake offset for reject feedback (only affects border, not actual target)
        float shakeX = 0, shakeY = 0;
        if (rejectShakeTimer > 0) {
            float intensity = rejectShakeTimer * 4;
            shakeX = PApplet.sin(rejectShakeTimer * 40) * intensity;
            shakeY = PApplet.cos(rejectShakeTimer * 35) * intensity;
        }

        float tx = targetX + shakeX;
        float ty = targetY + shakeY;
        float tw = targetW;
        float th = targetH;

        // ---- 1. Spotlight mask (4 rectangles around primary target) ----
        // Overlay bounds are offset by root's negative ox/oy to cover the full physical screen
        float ox = getAbsoluteX();
        float oy = getAbsoluteY();
        if (!isGlobal && !isNoMask) {
            g.noStroke();
            g.fill(MASK_COLOR);
            // Top
            g.rect(ox, oy, sw, Math.max(0, ty - oy));
            // Bottom
            g.rect(ox, ty + th, sw, Math.max(0, oy + sh - ty - th));
            // Left
            g.rect(ox, ty, Math.max(0, tx - ox), th);
            // Right
            g.rect(tx + tw, ty, Math.max(0, ox + sw - tx - tw), th);
        }

        // ---- 2. Reject flash overlay ----
        if (rejectFlashAlpha > 0) {
            g.fill((int) (0xFF000000 | (REJECT_COLOR & 0x00FFFFFF)), (int) (rejectFlashAlpha * 128));
            g.rect(ox, oy, sw, sh);
        }

        // ---- 3. Border effect (primary + extra targets) ----
        TutorialStep.BorderEffect effect =
                (step != null) ? step.borderEffect : TutorialStep.BorderEffect.PULSE;

        if (effect != TutorialStep.BorderEffect.NONE) {
            float pulse = 0.5f + 0.5f * PApplet.sin(pulseTime * 4f);
            int borderAlpha = (int) (100 + 155 * pulse);
            float strokeW, pad;
            if (effect == TutorialStep.BorderEffect.FLASH) {
                strokeW = 2f;
                pad = 0f; // exact fit, no expansion
            } else {
                strokeW = 2f + 1.5f * pulse;
                pad = 3 + 2 * pulse;
            }
            g.noFill();
            g.strokeWeight(strokeW);
            g.stroke((BORDER_COLOR >> 16) & 0xFF, (BORDER_COLOR >> 8) & 0xFF, BORDER_COLOR & 0xFF, borderAlpha);
            if (!isGlobal && !isNoMask) {
                g.rect(tx - pad, ty - pad, tw + pad * 2, th + pad * 2);
            }
            for (float[] et : extraTargets) {
                g.rect(et[0] - pad, et[1] - pad, et[2] + pad * 2, et[3] + pad * 2);
            }
        }

        // ---- 4. Speech bubble ----
        paintBubble(g, theme, tx, ty, tw, th, sw, sh);
    }

    private void paintBubble(PApplet g, Theme theme, float tx, float ty, float tw, float th, float sw, float sh) {
        TutorialStep step = sequence.getCurrentStep();
        if (step == null || step.textKey == null) return;

        String text = shenyf.p5engine.core.P5Engine.getInstance().getI18n().get(step.textKey);
        if (text == null || text.isEmpty()) return;

        // Measure text
        g.pushStyle();
        g.textSize(16);
        float maxTextW = bubbleMaxW - bubblePad * 2;
        String[] lines = splitLines(g, text, maxTextW);
        float lineH = g.textAscent() + g.textDescent();
        float textH = lines.length * lineH;
        float bubbleW = bubbleMaxW;
        float bubbleH = textH + bubblePad * 2 + 20; // +20 for hint text

        boolean isGlobal = (step.targetType == TutorialStep.TargetType.GLOBAL)
                        || (step.targetType == TutorialStep.TargetType.FULL_SCREEN_NO_MASK);
        String anchor = (step.bubbleAnchor != null) ? step.bubbleAnchor : "center";
        float bubbleX, bubbleY;
        boolean drawArrow = true;

        // Overlay bounds offset by root's negative ox/oy to align with physical screen edges
        float ox = getAbsoluteX();
        float oy = getAbsoluteY();

        if (isGlobal) {
            drawArrow = false;
            switch (anchor) {
                case "top_center":
                    bubbleX = ox + (sw - bubbleW) / 2;
                    bubbleY = oy + 48f + 8f; // just below the top HUD bar (design coords)
                    break;
                case "top_right":
                    bubbleX = ox + sw - bubbleW - 16;
                    bubbleY = oy + 16;
                    break;
                case "top_left":
                    bubbleX = ox + 16;
                    bubbleY = oy + 16;
                    break;
                case "bottom_right":
                    bubbleX = ox + sw - bubbleW - 16;
                    bubbleY = oy + sh - bubbleH - 16;
                    break;
                case "bottom_left":
                    bubbleX = ox + 16;
                    bubbleY = oy + sh - bubbleH - 16;
                    break;
                default:
                    bubbleX = ox + (sw - bubbleW) / 2;
                    bubbleY = oy + (sh - bubbleH) / 2;
                    break;
            }
        } else {
            // Determine bubble position (above or below target)
            boolean below = (ty + th / 2) < oy + sh / 2;
            bubbleX = PApplet.constrain(tx + tw / 2 - bubbleW / 2, ox + 16, ox + sw - bubbleW - 16);
            if (below) {
                bubbleY = ty + th + bubbleArrow + 8;
            } else {
                bubbleY = ty - bubbleH - bubbleArrow - 8;
            }
            // Clamp vertically within physical screen
            bubbleY = PApplet.constrain(bubbleY, oy + 16, oy + sh - bubbleH - 16);
        }

        // Draw bubble background
        g.noStroke();
        g.fill(BUBBLE_COLOR);
        g.rect(bubbleX, bubbleY, bubbleW, bubbleH);

        // Draw arrow triangle (only for non-global)
        if (drawArrow) {
            float arrowTipX = tx + tw / 2;
            float arrowTipY = 0;
            float ax1 = 0, ay1 = 0, ax2 = 0, ay2 = 0;
            // Determine arrow direction based on actual bubble position relative to target
            boolean bubbleAboveTarget = bubbleY + bubbleH <= ty;
            boolean bubbleBelowTarget = bubbleY >= ty + th;
            boolean canDrawArrow = true;
            if (bubbleAboveTarget) {
                arrowTipY = ty - 2;
                ax1 = arrowTipX - bubbleArrow; ay1 = bubbleY + bubbleH;
                ax2 = arrowTipX + bubbleArrow; ay2 = bubbleY + bubbleH;
            } else if (bubbleBelowTarget) {
                arrowTipY = ty + th + 2;
                ax1 = arrowTipX - bubbleArrow; ay1 = bubbleY;
                ax2 = arrowTipX + bubbleArrow; ay2 = bubbleY;
            } else {
                // Bubble overlaps target vertically (e.g. very tall target), skip arrow
                canDrawArrow = false;
            }
            if (canDrawArrow) {
                g.beginShape();
                g.vertex(ax1, ay1);
                g.vertex(arrowTipX, arrowTipY);
                g.vertex(ax2, ay2);
                g.endShape(PApplet.CLOSE);
            }
        }

        // Draw text lines
        g.fill(TEXT_COLOR);
        g.textAlign(PApplet.LEFT, PApplet.TOP);
        float textX = bubbleX + bubblePad;
        float textY = bubbleY + bubblePad;
        for (String line : lines) {
            g.text(line, textX, textY);
            textY += lineH;
        }

        // Draw hint text (click to continue)
        g.textSize(12);
        g.fill(HINT_COLOR);
        String hint = step.advanceMode == TutorialStep.AdvanceMode.AUTO
                ? "" : shenyf.p5engine.core.P5Engine.getInstance().getI18n().get("tutorial.click.continue");
        if (!hint.isEmpty() && !hint.equals("tutorial.click.continue")) {
            g.textAlign(PApplet.CENTER, PApplet.BOTTOM);
            g.text(hint, bubbleX + bubbleW / 2, bubbleY + bubbleH - bubblePad / 2);
        }

        g.popStyle();
    }

    private String[] splitLines(PApplet g, String text, float maxW) {
        java.util.List<String> result = new java.util.ArrayList<>();
        String[] rawLines = text.split("\n");
        for (String raw : rawLines) {
            if (g.textWidth(raw) <= maxW) {
                result.add(raw);
                continue;
            }
            StringBuilder line = new StringBuilder();
            for (int i = 0; i < raw.length(); i++) {
                char c = raw.charAt(i);
                if (g.textWidth(line.toString() + c) > maxW && line.length() > 0) {
                    result.add(line.toString());
                    line.setLength(0);
                }
                line.append(c);
            }
            if (line.length() > 0) {
                result.add(line.toString());
            }
        }
        return result.toArray(new String[0]);
    }

    @Override
    public UIComponent hitTest(float px, float py) {
        // Allow mouse events to pass through to underlying components.
        // The UIManager's eventInterceptor handles click-locking logic.
        return null;
    }

    // ---- Event Interceptor ----

    @Override
    public boolean interceptMouseEvent(MouseEvent event, UIComponent hit) {
        if (sequence == null || !sequence.isActive()) return false;
        if (!sequence.isStepReady()) return false;
        if (!hasTarget) return false;

        TutorialStep step = sequence.getCurrentStep();
        if (step != null && step.targetType == TutorialStep.TargetType.FULL_SCREEN_NO_MASK) {
            return false; // allow free interaction during no-mask steps
        }
        if (step != null && step.advanceMode == TutorialStep.AdvanceMode.AUTO) {
            return false; // pure hint steps do not block interaction
        }

        int act = event.getAction();
        float mx = event.getX();
        float my = event.getY();

        // Convert screen to design coordinates (use uniformScale to match paint()'s FIT matrix)
        var dm = uiManager.getDisplayManager();
        if (dm != null) {
            float us = dm.getUniformScale();
            mx = (mx - dm.getOffsetX()) / us;
            my = (my - dm.getOffsetY()) / us;
        }

        boolean inside = mx >= targetX && mx <= targetX + targetW
                      && my >= targetY && my <= targetY + targetH;
        if (!inside) {
            for (float[] et : extraTargets) {
                if (mx >= et[0] && mx <= et[0] + et[2] && my >= et[1] && my <= et[1] + et[3]) {
                    inside = true;
                    break;
                }
            }
        }

        if (inside) {
            // Click inside target: allow event to pass through.
            // For CLICK advance mode, advance on RELEASE to let the button action happen first.
            if (act == MouseEvent.RELEASE) {
                step = sequence.getCurrentStep();
                if (step != null && step.advanceMode == TutorialStep.AdvanceMode.CLICK) {
                    sequence.nextStep();
                }
            }
            return false; // do not intercept
        }

        // Click outside target: intercept and trigger reject feedback
        if (act == MouseEvent.PRESS) {
            triggerRejectFeedback();
        }
        return true; // intercept
    }

    private void triggerRejectFeedback() {
        rejectFlashAlpha = 1.0f;
        rejectShakeTimer = 1.0f;
    }

    // Skip support via keyboard (ESC)
    public boolean onKeyPressed(int keyCode) {
        if (sequence == null || !sequence.isActive()) return false;
        TutorialStep step = sequence.getCurrentStep();
        if (step == null) return false;

        if (keyCode == java.awt.event.KeyEvent.VK_ESCAPE && step.allowSkip) {
            sequence.skip();
            return true;
        }
        if (step.advanceMode == TutorialStep.AdvanceMode.KEY) {
            sequence.nextStep();
            return true;
        }
        return false;
    }
}
