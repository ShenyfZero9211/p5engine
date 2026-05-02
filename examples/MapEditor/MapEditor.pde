import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.rendering.*;

static MapEditor inst;

P5Engine engine;
UIManager ui;
SketchUiCoordinator sketchUi;
Camera2D camera;
Scene editorScene;

// UI references
MenuBar menuBar;
Panel toolbar;
EditorViewport viewport;
Panel propertiesPanel;
Label lblToolInfo;

// Layout panels (global for resize handling)
Panel layoutPanel;
Panel topPanel;
Panel centerPanel;
int lastW, lastH;

// Editor state
EditorLevel editorLevel;
EditorTool currentTool = EditorTool.SELECT;
EditorEntity selectedEntity;

// Grid snap
static final float GRID_SIZE = 40f;
boolean snapToGrid = true;

// Edge scroll
boolean keyScrollLeft, keyScrollRight, keyScrollUp, keyScrollDown;
float edgeScrollSpeed = 400;

// Path editing state
boolean isDrawingPath = false;
EditorPath currentPath;
EditorPath selectedPath;   // Selected in Properties Panel for highlight

// Dragging state
boolean isDragging = false;
Vector2 dragStartWorld;
Vector2 dragOffset;

void settings() {
  size(1600, 900, P2D);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  inst = this;

  engine = P5Engine.create(this, P5Config.defaults()
    .renderer(P5Config.RenderMode.P2D)
    .width(1600).height(900)
    .centerWindow(true)
    .displayConfig(DisplayConfig.defaults()
      .designWidth(1600).designHeight(900)
      .scaleMode(ScaleMode.NO_SCALE)
      .resizable(true)));
  engine.setApplicationTitle("MapEditor");
  engine.setSketchVersion("0.1.0");

  ui = new UIManager(this);
  ui.attach();
  sketchUi = new SketchUiCoordinator(this, ui);

  GameObject camGo = GameObject.create("Camera");
  camera = camGo.addComponent(Camera2D.class);
  camera.setWorldBounds(new Rect(0, 0, 2400, 1600));
  camera.getTransform().setPosition(1200, 800);

  editorScene = new Scene("editor");
  editorScene.setCamera(camera);
  editorScene.load();

  buildUi();

  editorLevel = new EditorLevel();
  editorLevel.worldW = 1600;
  editorLevel.worldH = 1200;
}

void draw() {
  if (width != lastW || height != lastH) {
    lastW = width;
    lastH = height;
    if (layoutPanel != null) {
      layoutPanel.setBounds(0, 0, width, height);
    }
    if (topPanel != null) {
      topPanel.setSize(width, 68);
    }
    if (menuBar != null) {
      menuBar.setSize(width, 28);
    }
    if (toolbar != null) {
      toolbar.setSize(width, 40);
    }
    if (layoutPanel != null) {
      layoutPanel.measure(this);
      layoutPanel.setBounds(0, 0, width, height);
      layoutPanel.layout(this);
    }
  }

  background(14, 18, 34);

  engine.update();

  // Update viewport camera
  viewport.setCamera(camera);
  viewport.setScene(editorScene);

  // Update UI
  sketchUi.updateFrame(engine.getGameTime().getDeltaTime());

  // Poll wave/spawn list selection in Enemy Info window
  checkEnemyInfoWaveSelection();
  checkEnemyInfoSpawnSelection();

  // Edge scroll camera pan
  updateEdgeScroll(engine.getGameTime().getDeltaTime());

  // Render UI (includes viewport as a UI component)
  sketchUi.renderFrame();

  // Draw ghost marker for grid snap preview
  drawGhostMarker();
}

void mousePressed() {
  if (ui.closeMenuPopupsIfOutside(mouseX, mouseY)) return;
  if (ui.isMouseOverWindow() || ui.isMouseOverPopup()) return;
  if (mouseButton == CENTER) {
    isDragging = true;
    dragStartWorld = screenToWorld(new Vector2(mouseX, mouseY));
    return;
  }

  // Only handle world interaction if mouse is inside viewport
  if (!viewport.containsPoint(mouseX, mouseY)) return;
  if (mouseButton != LEFT) return;

  Vector2 worldPos = screenToWorld(new Vector2(mouseX, mouseY));

  switch (currentTool) {
    case SELECT:
      handleSelectTool(worldPos);
      break;
    case SPAWN:
      worldPos = snapWorldPos(worldPos);
      editorLevel.spawnPos = worldPos.copy();
      selectedEntity = new EditorEntity(EditorEntityType.SPAWN, worldPos);
      break;
    case BASE:
      worldPos = snapWorldPos(worldPos);
      editorLevel.basePos = worldPos.copy();
      selectedEntity = new EditorEntity(EditorEntityType.BASE, worldPos);
      break;
    case EXIT:
      worldPos = snapWorldPos(worldPos);
      editorLevel.exitPos = worldPos.copy();
      selectedEntity = new EditorEntity(EditorEntityType.EXIT, worldPos);
      break;
    case PATH:
      worldPos = snapWorldPos(worldPos);
      handlePathTool(worldPos);
      break;
    case ERASE:
      handleEraseTool(worldPos);
      break;
  }

  refreshPropertiesPanel();
}

void mouseDragged() {
  if (ui.isMouseOverWindow() || ui.isMouseOverPopup()) return;
  if (isDragging && mouseButton == CENTER) {
    Vector2 currentWorld = screenToWorld(new Vector2(mouseX, mouseY));
    Vector2 delta = new Vector2(
      dragStartWorld.x - currentWorld.x,
      dragStartWorld.y - currentWorld.y
    );
    camera.getTransform().translate(delta.x, delta.y);
    return;
  }

  if (currentTool == EditorTool.SELECT && selectedEntity != null && mouseButton == LEFT) {
    Vector2 worldPos = screenToWorld(new Vector2(mouseX, mouseY));
    worldPos = snapWorldPos(worldPos);
    selectedEntity.position.set(worldPos);
    syncEntityToLevel(selectedEntity);
    refreshPropertiesPanel();
  }
}

void mouseReleased() {
  if (ui.isMouseOverWindow() || ui.isMouseOverPopup()) return;
  isDragging = false;
}

void mouseWheel(processing.event.MouseEvent event) {
  if (ui.isMouseOverWindow() || ui.isMouseOverPopup()) return;
  float zoomFactor = event.getCount() > 0 ? 0.9f : 1.1f;
  float newZoom = camera.getZoom() * zoomFactor;
  newZoom = constrain(newZoom, 0.1f, 5.0f);
  camera.setZoom(newZoom);
}

void keyPressed() {
  if (key == ESC) {
    key = 0; // Always block Processing default quit behavior
    if (isDrawingPath && currentPath != null) {
      // Cancel: abandon current path
      isDrawingPath = false;
      currentPath = null;
    }
  }

  if (ui.isFocusInsideWindow()) return;

  if (keyCode == ENTER || keyCode == RETURN) {
    if (isDrawingPath && currentPath != null) {
      // Confirm: save path if it has at least 2 points
      isDrawingPath = false;
      if (currentPath.points.size() >= 2) {
        editorLevel.paths.add(currentPath);
      }
      currentPath = null;
    }
  }

  switch (keyCode) {
    case LEFT:  keyScrollLeft = true; break;
    case RIGHT: keyScrollRight = true; break;
    case UP:    keyScrollUp = true; break;
    case DOWN:  keyScrollDown = true; break;
  }

  switch (key) {
    case '1': setTool(EditorTool.SELECT); break;
    case '2': setTool(EditorTool.SPAWN); break;
    case '3': setTool(EditorTool.BASE); break;
    case '4': setTool(EditorTool.EXIT); break;
    case '5': setTool(EditorTool.PATH); break;
    case '6': setTool(EditorTool.ERASE); break;
  }
}

void keyReleased() {
  switch (keyCode) {
    case LEFT:  keyScrollLeft = false; break;
    case RIGHT: keyScrollRight = false; break;
    case UP:    keyScrollUp = false; break;
    case DOWN:  keyScrollDown = false; break;
  }
}

// ── Helpers ──

Vector2 screenToWorld(Vector2 screenPos) {
  float zoom = camera.getZoom();
  Vector2 camPos = camera.getTransform().getPosition();
  float vpW = viewport.getWidth();
  float vpH = viewport.getHeight();
  float vpX = viewport.getAbsoluteX();
  float vpY = viewport.getAbsoluteY();

  float relX = (screenPos.x - vpX) - vpW * 0.5f;
  float relY = (screenPos.y - vpY) - vpH * 0.5f;

  return new Vector2(
    camPos.x + relX / zoom,
    camPos.y + relY / zoom
  );
}

Vector2 worldToScreen(Vector2 worldPos) {
  float zoom = camera.getZoom();
  Vector2 camPos = camera.getTransform().getPosition();
  float vpW = viewport.getWidth();
  float vpH = viewport.getHeight();
  float vpX = viewport.getAbsoluteX();
  float vpY = viewport.getAbsoluteY();

  float relX = (worldPos.x - camPos.x) * zoom;
  float relY = (worldPos.y - camPos.y) * zoom;

  return new Vector2(
    vpX + vpW * 0.5f + relX,
    vpY + vpH * 0.5f + relY
  );
}

void setTool(EditorTool tool) {
  currentTool = tool;
  isDrawingPath = false;
  currentPath = null;
  selectedPath = null;
  if (lblToolInfo != null) {
    String modeInfo = "";
    if (tool == EditorTool.PATH && editorLevel != null) {
      modeInfo = editorLevel.pathMode == PathMode.PATH_POINTS ? " [Simple]" : " [Multi]";
    }
    lblToolInfo.setText("Tool: " + tool.name() + modeInfo);
  }
  updateToolbarHighlight();
}

void handleSelectTool(Vector2 worldPos) {
  // Hit test entities
  selectedEntity = null;
  selectedPath = null;

  // Check spawn
  if (editorLevel.spawnPos != null && editorLevel.spawnPos.distance(worldPos) < 20) {
    selectedEntity = new EditorEntity(EditorEntityType.SPAWN, editorLevel.spawnPos);
    return;
  }
  // Check base
  if (editorLevel.basePos != null && editorLevel.basePos.distance(worldPos) < 20) {
    selectedEntity = new EditorEntity(EditorEntityType.BASE, editorLevel.basePos);
    return;
  }
  // Check exit
  if (editorLevel.exitPos != null && editorLevel.exitPos.distance(worldPos) < 20) {
    selectedEntity = new EditorEntity(EditorEntityType.EXIT, editorLevel.exitPos);
    return;
  }
  // Check path points based on current mode
  if (editorLevel.pathMode == PathMode.PATH_POINTS) {
    for (Vector2 pt : editorLevel.pathPoints) {
      if (pt.distance(worldPos) < 15) {
        selectedEntity = new EditorEntity(EditorEntityType.PATH_POINT, pt);
        return;
      }
    }
  } else {
    for (EditorPath path : editorLevel.paths) {
      for (Vector2 pt : path.points) {
        if (pt.distance(worldPos) < 15) {
          selectedEntity = new EditorEntity(EditorEntityType.PATH_POINT, pt);
          selectedEntity.pathRef = path;
          return;
        }
      }
    }
  }
}

void handlePathTool(Vector2 worldPos) {
  worldPos = snapWorldPos(worldPos);
  if (editorLevel.pathMode == PathMode.PATH_POINTS) {
    // Simple mode: add directly to pathPoints
    editorLevel.pathPoints.add(worldPos.copy());
  } else {
    // Multi-paths mode: start or continue a path
    if (!isDrawingPath) {
      isDrawingPath = true;
      currentPath = new EditorPath();
      currentPath.id = "path_" + (editorLevel.paths.size() + 1);
      currentPath.type = PathRouteType.DIRECT;
    }
    currentPath.points.add(worldPos.copy());
  }
}

void handleEraseTool(Vector2 worldPos) {
  if (editorLevel.pathMode == PathMode.PATH_POINTS) {
    // Simple mode: remove from pathPoints
    editorLevel.pathPoints.removeIf(pt -> pt.distance(worldPos) < 15);
  } else {
    // Multi-paths mode: remove from paths
    for (EditorPath path : editorLevel.paths) {
      path.points.removeIf(pt -> pt.distance(worldPos) < 15);
    }
    editorLevel.paths.removeIf(path -> path.points.size() < 2);
  }
}

Vector2 snapWorldPos(Vector2 worldPos) {
  if (!snapToGrid) return worldPos.copy();
  float sx = Math.round(worldPos.x / GRID_SIZE) * GRID_SIZE;
  float sy = Math.round(worldPos.y / GRID_SIZE) * GRID_SIZE;
  return new Vector2(sx, sy);
}

void drawGhostMarker() {
  if (ui.isMouseOverWindow() || ui.isMouseOverPopup()) return;
  if (!snapToGrid) return;
  if (currentTool == EditorTool.SELECT || currentTool == EditorTool.ERASE) return;
  if (!viewport.containsPoint(mouseX, mouseY)) return;

  Vector2 worldPos = screenToWorld(new Vector2(mouseX, mouseY));
  worldPos = snapWorldPos(worldPos);
  Vector2 screenPos = worldToScreen(worldPos);

  pushStyle();
  noFill();
  stroke(255, 255, 0, 180);
  strokeWeight(2);

  // Crosshair at snapped grid vertex
  float cs = 12;
  line(screenPos.x - cs, screenPos.y, screenPos.x + cs, screenPos.y);
  line(screenPos.x, screenPos.y - cs, screenPos.x, screenPos.y + cs);

  // Circle indicating placement size
  switch (currentTool) {
    case SPAWN: ellipse(screenPos.x, screenPos.y, 24, 24); break;
    case BASE:  ellipse(screenPos.x, screenPos.y, 48, 48); break;
    case EXIT:  ellipse(screenPos.x, screenPos.y, 32, 32); break;
    case PATH:  ellipse(screenPos.x, screenPos.y, 16, 16); break;
  }
  popStyle();
}

void syncEntityToLevel(EditorEntity entity) {
  switch (entity.type) {
    case SPAWN: editorLevel.spawnPos = entity.position; break;
    case BASE: editorLevel.basePos = entity.position; break;
    case EXIT: editorLevel.exitPos = entity.position; break;
    case PATH_POINT:
      // Position is already updated in-place (Vector2 reference)
      break;
  }
}

void updateCoordinateDisplay() {
  if (ui.isMouseOverWindow() || ui.isMouseOverPopup()) return;
  if (viewport.containsPoint(mouseX, mouseY)) {
    Vector2 worldPos = screenToWorld(new Vector2(mouseX, mouseY));
    // Could draw coordinate overlay here if needed
  }
}

void updateEdgeScroll(float dt) {
  if (ui.isMouseOverWindow() || ui.isMouseOverPopup()) return;
  float dx = 0, dy = 0;
  if (keyScrollLeft || mouseX <= 0)           dx = -edgeScrollSpeed;
  if (keyScrollRight || mouseX >= width - 1)  dx =  edgeScrollSpeed;
  if (keyScrollUp || mouseY <= 0)             dy = -edgeScrollSpeed;
  if (keyScrollDown || mouseY >= height - 1)  dy =  edgeScrollSpeed;

  if (dx != 0 || dy != 0) {
    camera.getTransform().translate(dx * dt / camera.getZoom(), dy * dt / camera.getZoom());
    camera.clampToBounds();
  }
}
