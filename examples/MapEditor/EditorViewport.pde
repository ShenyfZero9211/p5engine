// ============================================
// Editor Viewport — renders the editable world
// ============================================

public class EditorViewport extends WorldViewport {

  private boolean drawGrid = true;

  public EditorViewport(String id) {
    super(id);
    setBgColor(0xFF0E1222);
  }

  public boolean isDrawGrid() {
    return drawGrid;
  }

  public void setDrawGrid(boolean drawGrid) {
    this.drawGrid = drawGrid;
  }

  @Override
  protected void renderContent(PGraphics buffer, int w, int h, Camera2D cam, Scene scene) {
    if (editorLevel == null) return;

    // Sync camera viewport
    cam.setViewportSize(w, h);
    cam.setViewportOffset(0, 0);

    // World bounds
    int ww = editorLevel.worldW;
    int wh = editorLevel.worldH;

    // Apply camera transform so grid, boundary and entities all move/scale together
    buffer.pushMatrix();
    Vector2 camPos = cam.getTransform().getPosition();
    float zoom = cam.getZoom();
    buffer.translate(w * 0.5f, h * 0.5f);
    buffer.scale(zoom);
    buffer.translate(-camPos.x, -camPos.y);

    // Grid
    if (drawGrid) {
      buffer.stroke(40, 60, 100, 60);
      buffer.strokeWeight(1 / zoom);
      for (int gx = 0; gx <= ww; gx += 40) {
        buffer.line(gx, 0, gx, wh);
      }
      for (int gy = 0; gy <= wh; gy += 40) {
        buffer.line(0, gy, ww, gy);
      }
    }

    // World boundary
    buffer.noFill();
    buffer.stroke(100, 120, 160, 120);
    buffer.strokeWeight(2 / zoom);
    buffer.rect(0, 0, ww, wh);

    // Path lines based on current mode
    if (editorLevel.pathMode == PathMode.PATH_POINTS) {
      // Simple pathPoints
      if (editorLevel.pathPoints != null && editorLevel.pathPoints.size() > 1) {
        buffer.stroke(0xFF4A9EFF);
        buffer.strokeWeight(4);
        buffer.strokeCap(PApplet.ROUND);
        for (int i = 1; i < editorLevel.pathPoints.size(); i++) {
          Vector2 a = editorLevel.pathPoints.get(i - 1);
          Vector2 b = editorLevel.pathPoints.get(i);
          buffer.line(a.x, a.y, b.x, b.y);
        }
      }
    } else {
      // Multi paths
      for (EditorPath path : editorLevel.paths) {
        if (path.points.size() > 1) {
          buffer.stroke(path.type == PathRouteType.INBOUND ? 0xFF4A9EFF :
                        path.type == PathRouteType.OUTBOUND ? 0xFFFF8C42 : 0xFF66FF66);
          buffer.strokeWeight(4);
          buffer.strokeCap(PApplet.ROUND);
          for (int i = 1; i < path.points.size(); i++) {
            Vector2 a = path.points.get(i - 1);
            Vector2 b = path.points.get(i);
            buffer.line(a.x, a.y, b.x, b.y);
          }
        }
      }
      // Highlight selected path
      if (selectedPath != null && selectedPath.points.size() > 1) {
        buffer.stroke(0xFFFFFFFF);
        buffer.strokeWeight(6);
        buffer.strokeCap(PApplet.ROUND);
        for (int i = 1; i < selectedPath.points.size(); i++) {
          Vector2 a = selectedPath.points.get(i - 1);
          Vector2 b = selectedPath.points.get(i);
          buffer.line(a.x, a.y, b.x, b.y);
        }
      }
    }

    // Current drawing path
    if (isDrawingPath && currentPath != null && currentPath.points.size() > 1) {
      buffer.stroke(0xFFAAAAAA);
      buffer.strokeWeight(3);
      buffer.strokeCap(PApplet.ROUND);
      for (int i = 1; i < currentPath.points.size(); i++) {
        Vector2 a = currentPath.points.get(i - 1);
        Vector2 b = currentPath.points.get(i);
        buffer.line(a.x, a.y, b.x, b.y);
      }
    }

    // Spawn point
    if (editorLevel.spawnPos != null) {
      drawEntity(buffer, editorLevel.spawnPos, 12, 0xFFFF8C42, "S");
    }

    // Base
    if (editorLevel.basePos != null) {
      drawEntity(buffer, editorLevel.basePos, 24, 0xFF4A9EFF, "B");
    }

    // Exit
    if (editorLevel.exitPos != null) {
      drawEntity(buffer, editorLevel.exitPos, 16, 0xFFFF4444, "E");
    }

    // Path points based on current mode
    if (editorLevel.pathMode == PathMode.PATH_POINTS) {
      for (Vector2 pt : editorLevel.pathPoints) {
        drawPoint(buffer, pt, 8, 0xFF4A9EFF);
      }
    } else {
      for (EditorPath path : editorLevel.paths) {
        for (Vector2 pt : path.points) {
          int col = path.type == PathRouteType.INBOUND ? 0xFF4A9EFF :
                    path.type == PathRouteType.OUTBOUND ? 0xFFFF8C42 : 0xFF66FF66;
          drawPoint(buffer, pt, 8, col);
        }
      }
      // Current drawing path points (only in multi-paths mode)
      if (isDrawingPath && currentPath != null) {
        for (Vector2 pt : currentPath.points) {
          drawPoint(buffer, pt, 8, 0xFFAAAAAA);
        }
      }
    }

    // Selection highlight
    if (selectedEntity != null) {
      buffer.noFill();
      buffer.stroke(255, 255, 255, 200);
      buffer.strokeWeight(2 / zoom);
      float sx = selectedEntity.position.x;
      float sy = selectedEntity.position.y;
      buffer.ellipse(sx, sy, 32, 32);
    }

    // Route endpoints (sub-spawn / sub-exit) in multi-paths mode
    if (editorLevel.pathMode == PathMode.MULTI_PATHS) {
      for (EditorPath path : editorLevel.paths) {
        if (path.points.size() < 2) continue;
        Vector2 start = path.points.get(0);
        Vector2 end = path.points.get(path.points.size() - 1);

        // Sub-spawn: start point different from global spawnPos
        if (editorLevel.spawnPos != null && start.distance(editorLevel.spawnPos) > 20) {
          drawSubSpawn(buffer, start);
        }

        // Sub-exit: end point different from base and global exit
        boolean isBase = editorLevel.basePos != null && end.distance(editorLevel.basePos) <= 20;
        boolean isGlobalExit = editorLevel.exitPos != null && end.distance(editorLevel.exitPos) <= 20;
        if (!isBase && !isGlobalExit) {
          drawSubExit(buffer, end);
        }
      }
    }

    buffer.popMatrix();
  }

  private void drawSubSpawn(PGraphics g, Vector2 pos) {
    g.noStroke();
    g.fill(0xFFFF8C42, 100);
    g.ellipse(pos.x, pos.y, 20, 20);
    g.fill(0xFFFF8C42);
    g.ellipse(pos.x, pos.y, 10, 10);
  }

  private void drawSubExit(PGraphics g, Vector2 pos) {
    g.noStroke();
    g.fill(0xFFFF4444, 80);
    g.ellipse(pos.x, pos.y, 28, 28);
    g.stroke(0xFFFF4444);
    g.strokeWeight(3);
    g.line(pos.x - 6, pos.y - 6, pos.x + 6, pos.y + 6);
    g.line(pos.x + 6, pos.y - 6, pos.x - 6, pos.y + 6);
  }

  private void drawEntity(PGraphics g, Vector2 pos, float radius, int col, String label) {
    g.noStroke();
    g.fill(col);
    g.ellipse(pos.x, pos.y, radius * 2, radius * 2);
    g.fill(255);
    g.textAlign(PApplet.CENTER, PApplet.CENTER);
    g.textSize(10);
    g.text(label, pos.x, pos.y);
  }

  private void drawPoint(PGraphics g, Vector2 pos, float radius, int col) {
    g.noStroke();
    g.fill(col);
    g.ellipse(pos.x, pos.y, radius * 2, radius * 2);
    g.fill(255);
    g.ellipse(pos.x, pos.y, 4, 4);
  }
}
