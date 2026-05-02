// ============================================
// Map Info & Enemy Info Windows
// ============================================

// ── MapInfo Window ──
Window mapInfoWindow;
TextInput miTxtId, miTxtNameKey, miTxtSubtitleKey;
Dropdown miDdLevelType;
Dropdown miDdPathMode;
TextInput miTxtInitialMoney, miTxtMaxEscape, miTxtBaseOrbs, miTxtEnemyHpBase;
Checkbox miChkMG, miChkMissile, miChkLaser, miChkSlow;
Checkbox miChkEarnMoneyOnKill;
TextInput miTxtWorldW, miTxtWorldH;

// ── EnemyInfo Window ──
Window enemyInfoWindow;
shenyf.p5engine.ui.List eiWaveList;
Panel eiWaveDetailPanel;
TextInput eiTxtWaveDelay;
shenyf.p5engine.ui.List eiSpawnList;
WaveTimelinePanel eiTimeline;
Button eiBtnAddWave, eiBtnDelWave;
Button eiBtnAddSpawn, eiBtnDelSpawn, eiBtnApplySpawn;
Dropdown eiSpDdType;
TextInput eiSpTxtCount, eiSpTxtInterval, eiSpTxtRoute;
int eiLastWaveListIdx = -1;
int eiLastSpawnListIdx = -1;

// ── MapInfo ──

void onMapInfo() {
  if (mapInfoWindow != null && mapInfoWindow.isVisible()) {
    return;
  }
  buildMapInfoWindow();
}

void buildMapInfoWindow() {
  Panel root = ui.getRoot();

  // Remove old window if it still exists in the hierarchy
  if (mapInfoWindow != null && mapInfoWindow.getParent() != null) {
    mapInfoWindow.getParent().remove(mapInfoWindow);
  }

  mapInfoWindow = new Window("mapinfo_win");
  mapInfoWindow.setBounds((width - 420) / 2, (height - 520) / 2, 420, 520);
  mapInfoWindow.setTitle("Map Info");
  mapInfoWindow.setMovable(true);
  mapInfoWindow.setResizable(false);
  mapInfoWindow.setZOrder(100);
  mapInfoWindow.setLayoutManager(new BorderLayout());

  Panel content = new Panel("mi_content");
  content.setLayoutManager(null);

  float y = 8;
  float rowH = 28;
  float gap = 8;

  miTxtId = new TextInput("mi_id");
  miTxtId.setSize(200, rowH);
  miTxtId.setText(String.valueOf(editorLevel.id));
  y = addMapInfoRow(content, "ID:", miTxtId, y, rowH, gap);

  miTxtNameKey = new TextInput("mi_name");
  miTxtNameKey.setSize(260, rowH);
  miTxtNameKey.setText(editorLevel.nameKey);
  y = addMapInfoRow(content, "Name Key:", miTxtNameKey, y, rowH, gap);

  miTxtSubtitleKey = new TextInput("mi_subtitle");
  miTxtSubtitleKey.setSize(260, rowH);
  miTxtSubtitleKey.setText(editorLevel.subtitleKey);
  y = addMapInfoRow(content, "Subtitle Key:", miTxtSubtitleKey, y, rowH, gap);

  miDdLevelType = new Dropdown("mi_type");
  miDdLevelType.setSize(200, rowH);
  miDdLevelType.addItem("DEFEND_BASE");
  miDdLevelType.addItem("SURVIVAL");
  miDdLevelType.setSelectedIndex(editorLevel.levelType == LevelType.SURVIVAL ? 1 : 0);
  y = addMapInfoRow(content, "Level Type:", miDdLevelType, y, rowH, gap);

  miDdPathMode = new Dropdown("mi_path_mode");
  miDdPathMode.setSize(200, rowH);
  miDdPathMode.addItem("Simple (pathPoints)");
  miDdPathMode.addItem("Multi (paths)");
  miDdPathMode.setSelectedIndex(editorLevel.pathMode == PathMode.MULTI_PATHS ? 1 : 0);
  y = addMapInfoRow(content, "Path Mode:", miDdPathMode, y, rowH, gap);

  miTxtInitialMoney = new TextInput("mi_money");
  miTxtInitialMoney.setSize(120, rowH);
  miTxtInitialMoney.setText(String.valueOf(editorLevel.initialMoney));
  y = addMapInfoRow(content, "Initial Money:", miTxtInitialMoney, y, rowH, gap);

  miTxtBaseOrbs = new TextInput("mi_baseorbs");
  miTxtBaseOrbs.setSize(120, rowH);
  miTxtBaseOrbs.setText(String.valueOf(editorLevel.baseOrbs));
  y = addMapInfoRow(content, "Base Orbs:", miTxtBaseOrbs, y, rowH, gap);

  miTxtMaxEscape = new TextInput("mi_escape");
  miTxtMaxEscape.setSize(120, rowH);
  miTxtMaxEscape.setText(String.valueOf(editorLevel.maxEscapeCount));
  y = addMapInfoRow(content, "Max Escape:", miTxtMaxEscape, y, rowH, gap);

  miTxtEnemyHpBase = new TextInput("mi_hp");
  miTxtEnemyHpBase.setSize(120, rowH);
  miTxtEnemyHpBase.setText(String.valueOf(editorLevel.enemyHpBase));
  y = addMapInfoRow(content, "Enemy HP Base:", miTxtEnemyHpBase, y, rowH, gap);

  Panel towersPanel = new Panel("mi_towers_panel");
  towersPanel.setLayoutManager(new FlowLayout(2, 0, false));

  miChkMG = new Checkbox("mi_chk_mg");
  miChkMG.setLabel("MG");
  miChkMG.setSize(52, 24);
  miChkMG.setChecked(editorLevel.allowedTowers.contains("MG"));
  towersPanel.add(miChkMG);

  miChkMissile = new Checkbox("mi_chk_missile");
  miChkMissile.setLabel("MISSILE");
  miChkMissile.setSize(72, 24);
  miChkMissile.setChecked(editorLevel.allowedTowers.contains("MISSILE"));
  towersPanel.add(miChkMissile);

  miChkLaser = new Checkbox("mi_chk_laser");
  miChkLaser.setLabel("LASER");
  miChkLaser.setSize(62, 24);
  miChkLaser.setChecked(editorLevel.allowedTowers.contains("LASER"));
  towersPanel.add(miChkLaser);

  miChkSlow = new Checkbox("mi_chk_slow");
  miChkSlow.setLabel("SLOW");
  miChkSlow.setSize(62, 24);
  miChkSlow.setChecked(editorLevel.allowedTowers.contains("SLOW"));
  towersPanel.add(miChkSlow);

  y = addMapInfoRow(content, "Allowed Towers:", towersPanel, y, rowH, gap);

  miChkEarnMoneyOnKill = new Checkbox("mi_chk_earn");
  miChkEarnMoneyOnKill.setLabel("Earn Money On Kill");
  miChkEarnMoneyOnKill.setSize(160, 24);
  miChkEarnMoneyOnKill.setChecked(editorLevel.earnMoneyOnKill);
  y = addMapInfoRow(content, "", miChkEarnMoneyOnKill, y, rowH, gap);

  miTxtWorldW = new TextInput("mi_ww");
  miTxtWorldW.setSize(120, rowH);
  miTxtWorldW.setText(String.valueOf(editorLevel.worldW));
  y = addMapInfoRow(content, "World Width:", miTxtWorldW, y, rowH, gap);

  miTxtWorldH = new TextInput("mi_wh");
  miTxtWorldH.setSize(120, rowH);
  miTxtWorldH.setText(String.valueOf(editorLevel.worldH));
  y = addMapInfoRow(content, "World Height:", miTxtWorldH, y, rowH, gap);

  Button btnApply = new Button("mi_apply");
  btnApply.setLabel("Apply");
  btnApply.setSize(120, 32);
  btnApply.setPosition(8, y);
  btnApply.setAction(() -> applyMapInfoSettings());
  content.add(btnApply);

  mapInfoWindow.add(content, BorderLayout.CENTER);

  root.add(mapInfoWindow);
  root.invalidateLayout();
}

void applyMapInfoSettings() {
  try {
    editorLevel.id = Integer.parseInt(miTxtId.getText());
    editorLevel.nameKey = miTxtNameKey.getText();
    editorLevel.subtitleKey = miTxtSubtitleKey.getText();
    editorLevel.levelType = miDdLevelType.getSelectedIndex() == 1 ? LevelType.SURVIVAL : LevelType.DEFEND_BASE;
    editorLevel.initialMoney = Integer.parseInt(miTxtInitialMoney.getText());
    editorLevel.baseOrbs = Integer.parseInt(miTxtBaseOrbs.getText());
    editorLevel.maxEscapeCount = Integer.parseInt(miTxtMaxEscape.getText());
    editorLevel.enemyHpBase = Integer.parseInt(miTxtEnemyHpBase.getText());
    StringBuilder towers = new StringBuilder();
    if (miChkMG.isChecked()) { towers.append("MG"); }
    if (miChkMissile.isChecked()) { if (towers.length() > 0) towers.append(","); towers.append("MISSILE"); }
    if (miChkLaser.isChecked()) { if (towers.length() > 0) towers.append(","); towers.append("LASER"); }
    if (miChkSlow.isChecked()) { if (towers.length() > 0) towers.append(","); towers.append("SLOW"); }
    editorLevel.allowedTowers = towers.toString();
    editorLevel.earnMoneyOnKill = miChkEarnMoneyOnKill.isChecked();
    editorLevel.worldW = Integer.parseInt(miTxtWorldW.getText());
    editorLevel.worldH = Integer.parseInt(miTxtWorldH.getText());

    // Apply path mode (with optional data migration)
    PathMode newMode = miDdPathMode.getSelectedIndex() == 1 ? PathMode.MULTI_PATHS : PathMode.PATH_POINTS;
    if (newMode != editorLevel.pathMode) {
      editorLevel.pathMode = newMode;
      if (newMode == PathMode.MULTI_PATHS && editorLevel.paths.isEmpty() && !editorLevel.pathPoints.isEmpty()) {
        // Migrate pathPoints to a single path
        EditorPath legacyPath = new EditorPath();
        legacyPath.id = "legacy_1";
        legacyPath.type = PathRouteType.DIRECT;
        legacyPath.points.addAll(editorLevel.pathPoints);
        editorLevel.paths.add(legacyPath);
        println("[MapInfo] Migrated pathPoints to single path 'legacy_1'");
      } else if (newMode == PathMode.PATH_POINTS && editorLevel.pathPoints.isEmpty() && !editorLevel.paths.isEmpty()) {
        // Merge all paths into pathPoints
        for (EditorPath path : editorLevel.paths) {
          for (Vector2 pt : path.points) {
            if (editorLevel.pathPoints.isEmpty() || editorLevel.pathPoints.get(editorLevel.pathPoints.size() - 1).distance(pt) > 0.5f) {
              editorLevel.pathPoints.add(pt);
            }
          }
        }
        println("[MapInfo] Merged paths into pathPoints");
      }
    }

    camera.setWorldBounds(new Rect(0, 0, editorLevel.worldW, editorLevel.worldH));
    println("[MapInfo] Settings applied.");
  } catch (Exception e) {
    println("[ERROR] Invalid input: " + e.getMessage());
  }
}

// ── EnemyInfo ──

void onEnemyInfo() {
  if (enemyInfoWindow != null && enemyInfoWindow.isVisible()) {
    return;
  }
  buildEnemyInfoWindow();
}

void buildEnemyInfoWindow() {
  Panel root = ui.getRoot();

  // Remove old window if it still exists in the hierarchy
  if (enemyInfoWindow != null && enemyInfoWindow.getParent() != null) {
    enemyInfoWindow.getParent().remove(enemyInfoWindow);
  }

  enemyInfoWindow = new Window("enemyinfo_win");
  enemyInfoWindow.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
  enemyInfoWindow.setBounds((width - 900) / 2, (height - 680) / 2, 900, 680);
  enemyInfoWindow.setTitle("Enemy Info");
  enemyInfoWindow.setMovable(true);
  enemyInfoWindow.setResizable(false);
  enemyInfoWindow.setZOrder(100);
  enemyInfoWindow.setLayoutManager(new BorderLayout());

  // Left: wave list
  Panel waveListPanel = new Panel("ei_wave_list_panel");
  waveListPanel.setSize(180, 400);
  waveListPanel.setLayoutManager(null);

  eiWaveList = new shenyf.p5engine.ui.List("ei_wave_list");
  eiWaveList.setSize(170, 330);
  eiWaveList.setPosition(5, 5);
  refreshEnemyInfoWaveList();
  waveListPanel.add(eiWaveList);

  eiBtnAddWave = new Button("ei_btn_add_wave");
  eiBtnAddWave.setLabel("+ Wave");
  eiBtnAddWave.setSize(170, 26);
  eiBtnAddWave.setPosition(5, 340);
  eiBtnAddWave.setAction(() -> addEnemyInfoWave());
  waveListPanel.add(eiBtnAddWave);

  eiBtnDelWave = new Button("ei_btn_del_wave");
  eiBtnDelWave.setLabel("- Wave");
  eiBtnDelWave.setSize(170, 26);
  eiBtnDelWave.setPosition(5, 370);
  eiBtnDelWave.setEnabled(false);
  eiBtnDelWave.setAction(() -> deleteEnemyInfoWave());
  waveListPanel.add(eiBtnDelWave);

  enemyInfoWindow.add(waveListPanel, BorderLayout.WEST);

  // Center: wave detail
  eiWaveDetailPanel = new Panel("ei_wave_detail");
  eiWaveDetailPanel.setLayoutManager(new FlowLayout(8, 8, true));

  eiTxtWaveDelay = new TextInput("ei_wave_delay");
  eiTxtWaveDelay.setSize(120, 28);
  eiTxtWaveDelay.setText("2.0");
  eiWaveDetailPanel.add(makeLabeledRow("ei", "Delay:", eiTxtWaveDelay));

  // Timeline preview
  eiTimeline = new WaveTimelinePanel("ei_timeline");
  eiTimeline.setSize(700, 160);
  eiWaveDetailPanel.add(eiTimeline);

  // Spawn List
  eiSpawnList = new shenyf.p5engine.ui.List("ei_spawn_list");
  eiSpawnList.setSize(700, 160);
  eiWaveDetailPanel.add(eiSpawnList);

  // Spawn Editor Panel
  Panel spawnEditorPanel = new Panel("ei_spawn_editor");
  spawnEditorPanel.setLayoutManager(null);
  spawnEditorPanel.setSize(700, 28);

  eiSpDdType = new Dropdown("ei_sp_type");
  eiSpDdType.setSize(90, 24);
  eiSpDdType.setPosition(0, 0);
  eiSpDdType.addItem("level1");
  eiSpDdType.addItem("level2");
  eiSpDdType.addItem("level3");
  eiSpDdType.addItem("level4");
  spawnEditorPanel.add(eiSpDdType);

  eiSpTxtCount = new TextInput("ei_sp_count");
  eiSpTxtCount.setSize(60, 24);
  eiSpTxtCount.setPosition(94, 0);
  eiSpTxtCount.setText("5");
  spawnEditorPanel.add(eiSpTxtCount);

  eiSpTxtInterval = new TextInput("ei_sp_interval");
  eiSpTxtInterval.setSize(60, 24);
  eiSpTxtInterval.setPosition(158, 0);
  eiSpTxtInterval.setText("1.0");
  spawnEditorPanel.add(eiSpTxtInterval);

  eiSpTxtRoute = new TextInput("ei_sp_route");
  eiSpTxtRoute.setSize(90, 24);
  eiSpTxtRoute.setPosition(222, 0);
  eiSpTxtRoute.setText("");
  spawnEditorPanel.add(eiSpTxtRoute);

  eiWaveDetailPanel.add(spawnEditorPanel);

  // Spawn buttons
  Panel spawnBtnPanel = new Panel("ei_spawn_btns");
  spawnBtnPanel.setLayoutManager(new FlowLayout(8, 0, false));
  spawnBtnPanel.setSize(700, 32);

  eiBtnApplySpawn = new Button("ei_btn_apply_spawn");
  eiBtnApplySpawn.setLabel("Apply Spawn");
  eiBtnApplySpawn.setSize(110, 28);
  eiBtnApplySpawn.setAction(() -> applyEnemyInfoSpawnSettings());
  spawnBtnPanel.add(eiBtnApplySpawn);

  eiBtnAddSpawn = new Button("ei_btn_add_spawn");
  eiBtnAddSpawn.setLabel("+ Spawn");
  eiBtnAddSpawn.setSize(90, 28);
  eiBtnAddSpawn.setAction(() -> addEnemyInfoSpawn());
  spawnBtnPanel.add(eiBtnAddSpawn);

  eiBtnDelSpawn = new Button("ei_btn_del_spawn");
  eiBtnDelSpawn.setLabel("- Spawn");
  eiBtnDelSpawn.setSize(90, 28);
  eiBtnDelSpawn.setEnabled(false);
  eiBtnDelSpawn.setAction(() -> deleteEnemyInfoSpawn());
  spawnBtnPanel.add(eiBtnDelSpawn);

  eiWaveDetailPanel.add(spawnBtnPanel);

  // Apply Wave button
  Button btnApplyWave = new Button("ei_btn_apply_wave");
  btnApplyWave.setLabel("Apply Wave");
  btnApplyWave.setSize(120, 32);
  btnApplyWave.setAction(() -> applyEnemyInfoWaveSettings());
  eiWaveDetailPanel.add(btnApplyWave);

  enemyInfoWindow.add(eiWaveDetailPanel, BorderLayout.CENTER);

  root.add(enemyInfoWindow);
  root.invalidateLayout();
}

// ── Wave Timeline Preview Panel ──

class WaveTimelinePanel extends Panel {
  EditorWave currentWave;

  // Scroll state
  float scrollX, scrollY;
  float contentWidth, contentHeight;

  // Scroll bar interaction
  boolean hBarHover, vBarHover;
  boolean draggingHBar, draggingVBar;
  float dragStartMouseX, dragStartMouseY;
  float dragStartScrollX, dragStartScrollY;

  static final float SCROLL_BAR_SIZE = 10f;
  static final float MAX_SCALE_X = 150f;
  static final float MIN_SCALE_X = 30f;
  float scaleX = MAX_SCALE_X;

  // Scroll bar track hover (for click-to-jump)
  boolean hTrackHover, vTrackHover;

  // PGraphics off-screen buffer (persistent, recreated only on resize)
  PGraphics buffer;
  int bufferW, bufferH;

  WaveTimelinePanel(String id) {
    super(id);
  }

  void setWave(EditorWave wave) {
    this.currentWave = wave;
    scrollX = 0;
    scrollY = 0;
    autoScale();
  }

  void autoScale() {
    float w = getWidth();
    if (currentWave == null || currentWave.spawns.isEmpty()) {
      scaleX = MAX_SCALE_X;
      return;
    }
    float totalDuration = 0;
    for (EditorSpawn spawn : currentWave.spawns) {
      totalDuration += spawn.count * spawn.interval;
    }
    if (totalDuration < 0.001f) {
      scaleX = MAX_SCALE_X;
      return;
    }
    float marginLeft = 50;
    float marginRight = 10;
    float availableW = w - marginLeft - marginRight;
    if (availableW <= 0) return;
    float needed = availableW / totalDuration;
    scaleX = Math.max(MIN_SCALE_X, Math.min(MAX_SCALE_X, needed));
  }

  void recalcContentSize() {
    float w = getWidth();
    float h = getHeight();
    if (currentWave == null || currentWave.spawns.isEmpty()) {
      contentWidth = w;
      contentHeight = h;
      return;
    }

    float totalDuration = 0;
    for (EditorSpawn spawn : currentWave.spawns) {
      totalDuration += spawn.count * spawn.interval;
    }

    float marginLeft = 50;
    float marginRight = 10;
    contentWidth = marginLeft + marginRight + totalDuration * scaleX;

    int barSlotHeight = Math.max(14, (int) ((h - 34) / Math.max(1, currentWave.spawns.size())) - 2);
    float marginTop = 18;
    float marginBottom = 16;
    contentHeight = marginTop + marginBottom + currentWave.spawns.size() * (barSlotHeight + 2);
  }

  @Override
  public void update(PApplet applet, float dt) {
    float mx = UIManager.getDesignMouseX();
    float my = UIManager.getDesignMouseY();
    recalcContentSize();
    hBarHover = isHorizontalThumbHit(mx, my);
    vBarHover = isVerticalThumbHit(mx, my);
    hTrackHover = isHorizontalTrackHit(mx, my) && !hBarHover;
    vTrackHover = isVerticalTrackHit(mx, my) && !vBarHover;
  }

  @Override
  protected void paintSelf(PApplet applet, Theme theme) {
    float ax = getAbsoluteX();
    float ay = getAbsoluteY();
    float w = getWidth();
    float h = getHeight();

    recalcContentSize();

    // Clamp scroll
    float maxScrollX = Math.max(0, contentWidth - w);
    float maxScrollY = Math.max(0, contentHeight - h);
    scrollX = Math.max(0, Math.min(scrollX, maxScrollX));
    scrollY = Math.max(0, Math.min(scrollY, maxScrollY));

    int bw = (int) w, bh = (int) h;
    if (bw <= 0 || bh <= 0) return;

    if (buffer == null || bufferW != bw || bufferH != bh) {
      buffer = applet.createGraphics(bw, bh, PApplet.P2D);
      bufferW = bw;
      bufferH = bh;
    }

    buffer.beginDraw();
    try {
      // Background
      buffer.background(20, 22, 30);
      buffer.stroke(60);
      buffer.strokeWeight(1);
      buffer.noFill();
      buffer.rect(0.5f, 0.5f, bw - 1, bh - 1);

      if (currentWave == null || currentWave.spawns.isEmpty()) {
        buffer.fill(120);
        buffer.textAlign(PApplet.CENTER, PApplet.CENTER);
        buffer.textSize(12);
        buffer.text("No spawn data", bw / 2, bh / 2);
      } else {
        drawTimelineContent(buffer, bw, bh);
      }

      drawScrollBars(buffer, bw, bh);
    } finally {
      buffer.endDraw();
    }

    applet.image(buffer, ax, ay);
  }

  void drawTimelineContent(PGraphics g, float viewW, float viewH) {
    float marginLeft = 50;
    float marginRight = 10;
    float marginTop = 18;
    float marginBottom = 16;

    float totalDuration = 0;
    for (EditorSpawn spawn : currentWave.spawns) {
      totalDuration += spawn.count * spawn.interval;
    }
    if (totalDuration < 0.5f) totalDuration = 0.5f;

    float chartW = contentWidth - marginLeft - marginRight;
    float chartH = contentHeight - marginTop - marginBottom;

    // Axis line
    float axisY = marginTop + chartH - scrollY;
    if (axisY >= 0 && axisY <= viewH) {
      g.stroke(100);
      g.strokeWeight(1);
      g.line(marginLeft - scrollX, axisY, contentWidth - marginRight - scrollX, axisY);
    }

    // Time labels and ticks
    g.fill(160);
    g.textAlign(PApplet.CENTER, PApplet.TOP);
    g.textSize(10);
    int numTicks = Math.max(5, (int) (totalDuration / 2));
    for (int i = 0; i <= numTicks; i++) {
      float t = (totalDuration * i) / numTicks;
      float x = marginLeft + chartW * i / numTicks - scrollX;
      float labelY = marginTop + chartH - scrollY + 2;
      if (x >= marginLeft - 10 && x <= viewW && labelY >= 0 && labelY <= viewH) {
        g.text(String.format("%.1f", t) + "s", x, labelY);
      }
      float tickY1 = marginTop - scrollY;
      float tickY2 = marginTop + chartH - scrollY;
      if (x >= 0 && x <= viewW) {
        g.stroke(50);
        g.line(x, Math.max(0, tickY1), x, Math.min(viewH, tickY2));
      }
    }

    // Spawn bars
    int barSlotHeight = Math.max(14, (int) (chartH / Math.max(1, currentWave.spawns.size())) - 2);
    int[] typeColors = {
      g.color(100, 200, 100),
      g.color(230, 210, 80),
      g.color(230, 140, 60),
      g.color(220, 80, 80)
    };

    float cumulativeDuration = 0;
    for (int i = 0; i < currentWave.spawns.size(); i++) {
      EditorSpawn spawn = currentWave.spawns.get(i);
      float spawnDuration = spawn.count * spawn.interval;
      float startX = marginLeft + chartW * (cumulativeDuration / totalDuration) - scrollX;
      float barW = Math.max(2, chartW * (spawnDuration / totalDuration));
      float barY = marginTop + i * (barSlotHeight + 2) - scrollY;

      // Only draw if visible
      if (barY + barSlotHeight >= 0 && barY <= viewH && startX + barW >= 0 && startX <= viewW) {
        int colorIdx = 0;
        if (spawn.type.equals("level2")) colorIdx = 1;
        else if (spawn.type.equals("level3")) colorIdx = 2;
        else if (spawn.type.equals("level4")) colorIdx = 3;

        g.fill(typeColors[colorIdx]);
        g.noStroke();
        g.rect(startX, barY, barW, barSlotHeight);

        // Label
        String label = spawn.type + " x" + spawn.count;
        float labelW = g.textWidth(label);
        float labelX = startX + 4;
        if (labelW + 8 >= barW) {
          labelX = startX + barW + 4;
        }
        float labelY = barY + barSlotHeight / 2;
        if (labelY >= 0 && labelY <= viewH) {
          g.fill(labelW + 8 < barW ? 255 : 200);
          g.textAlign(PApplet.LEFT, PApplet.CENTER);
          g.textSize(9);
          g.text(label, labelX, labelY);
        }
      }

      cumulativeDuration += spawnDuration;
    }
  }

  void drawScrollBars(PGraphics g, float w, float h) {
    boolean needH = contentWidth > w + 0.5f;
    boolean needV = contentHeight > h + 0.5f;
    float vBarW = needV ? SCROLL_BAR_SIZE : 0;
    float hBarH = needH ? SCROLL_BAR_SIZE : 0;
    float clipW = Math.max(1, w - vBarW);
    float clipH = Math.max(1, h - hBarH);

    if (needH) {
      float maxS = Math.max(1, contentWidth - clipW);
      float thumbLen = clipW * (clipW / Math.max(clipW, contentWidth));
      thumbLen = Math.max(16, thumbLen);
      float t0 = (maxS <= 0.001f) ? 0f : (scrollX / maxS) * (clipW - thumbLen);
      g.fill(hTrackHover ? 70 : 50);
      g.noStroke();
      g.rect(0, clipH, clipW, hBarH);
      g.fill(hBarHover ? 140 : 90);
      g.rect(t0, clipH, thumbLen, hBarH);
    }

    if (needV) {
      float maxS = Math.max(1, contentHeight - clipH);
      float thumbLen = clipH * (clipH / Math.max(clipH, contentHeight));
      thumbLen = Math.max(16, thumbLen);
      float t0 = (maxS <= 0.001f) ? 0f : (scrollY / maxS) * (clipH - thumbLen);
      g.fill(vTrackHover ? 70 : 50);
      g.noStroke();
      g.rect(clipW, 0, vBarW, clipH);
      g.fill(vBarHover ? 140 : 90);
      g.rect(clipW, t0, vBarW, thumbLen);
    }
  }

  // ── Scroll bar hit tests ──

  private void getScrollBarMetrics(float w, float h, float[] out) {
    boolean needH = contentWidth > w + 0.5f;
    boolean needV = contentHeight > h + 0.5f;
    float vBarW = needV ? SCROLL_BAR_SIZE : 0;
    float hBarH = needH ? SCROLL_BAR_SIZE : 0;
    float clipW = Math.max(1, w - vBarW);
    float clipH = Math.max(1, h - hBarH);
    float maxSX = Math.max(1, contentWidth - clipW);
    float maxSY = Math.max(1, contentHeight - clipH);
    float thumbLenH = needH ? Math.max(16, clipW * (clipW / Math.max(clipW, contentWidth))) : 0;
    float thumbLenV = needV ? Math.max(16, clipH * (clipH / Math.max(clipH, contentHeight))) : 0;
    float spanH = Math.max(1, clipW - thumbLenH);
    float spanV = Math.max(1, clipH - thumbLenV);
    float t0H = (maxSX <= 0.001f) ? 0f : (scrollX / maxSX) * spanH;
    float t0V = (maxSY <= 0.001f) ? 0f : (scrollY / maxSY) * spanV;
    out[0] = needH ? 1 : 0; out[1] = needV ? 1 : 0;
    out[2] = vBarW; out[3] = hBarH; out[4] = clipW; out[5] = clipH;
    out[6] = maxSX; out[7] = maxSY;
    out[8] = thumbLenH; out[9] = thumbLenV;
    out[10] = spanH; out[11] = spanV;
    out[12] = t0H; out[13] = t0V;
  }

  private boolean isHorizontalThumbHit(float mx, float my) {
    float ax = getAbsoluteX(), ay = getAbsoluteY();
    float w = getWidth(), h = getHeight();
    float[] m = new float[14];
    getScrollBarMetrics(w, h, m);
    if (m[0] == 0) return false;
    return mx >= ax + m[12] && mx < ax + m[12] + m[8] && my >= ay + m[5] && my < ay + h;
  }

  private boolean isVerticalThumbHit(float mx, float my) {
    float ax = getAbsoluteX(), ay = getAbsoluteY();
    float w = getWidth(), h = getHeight();
    float[] m = new float[14];
    getScrollBarMetrics(w, h, m);
    if (m[1] == 0) return false;
    return mx >= ax + m[4] && mx < ax + w && my >= ay + m[13] && my < ay + m[13] + m[9];
  }

  private boolean isHorizontalTrackHit(float mx, float my) {
    float ax = getAbsoluteX(), ay = getAbsoluteY();
    float w = getWidth(), h = getHeight();
    float[] m = new float[14];
    getScrollBarMetrics(w, h, m);
    if (m[0] == 0) return false;
    return mx >= ax && mx < ax + m[4] && my >= ay + m[5] && my < ay + h;
  }

  private boolean isVerticalTrackHit(float mx, float my) {
    float ax = getAbsoluteX(), ay = getAbsoluteY();
    float w = getWidth(), h = getHeight();
    float[] m = new float[14];
    getScrollBarMetrics(w, h, m);
    if (m[1] == 0) return false;
    return mx >= ax + m[4] && mx < ax + w && my >= ay && my < ay + m[5];
  }

  @Override
  public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
    if (!isEnabled()) return false;
    recalcContentSize();

    switch (event.getType()) {
      case MOUSE_WHEEL:
        if (containsPoint(absMouseX, absMouseY)) {
          scrollY = scrollY - event.getScrollDelta() * 28f;
          markLayoutDirty();
          return true;
        }
        return false;

      case MOUSE_PRESSED:
        if (event.getMouseButton() == PApplet.LEFT) {
          if (hBarHover) {
            draggingHBar = true;
            dragStartMouseX = absMouseX;
            dragStartScrollX = scrollX;
            return true;
          }
          if (vBarHover) {
            draggingVBar = true;
            dragStartMouseY = absMouseY;
            dragStartScrollY = scrollY;
            return true;
          }
          // Click on scrollbar track to jump
          if (hTrackHover) {
            float w = getWidth();
            float h = getHeight();
            float ax = getAbsoluteX();
            float[] m = new float[14];
            getScrollBarMetrics(w, h, m);
            float trackX = absMouseX - ax;
            float ratio = trackX / m[4];
            ratio = Math.max(0, Math.min(1, ratio));
            float maxS = Math.max(1, contentWidth - m[4]);
            scrollX = ratio * maxS;
            markLayoutDirty();
            return true;
          }
          if (vTrackHover) {
            float w = getWidth();
            float h = getHeight();
            float ay = getAbsoluteY();
            float[] m = new float[14];
            getScrollBarMetrics(w, h, m);
            float trackY = absMouseY - ay;
            float ratio = trackY / m[5];
            ratio = Math.max(0, Math.min(1, ratio));
            float maxS = Math.max(1, contentHeight - m[5]);
            scrollY = ratio * maxS;
            markLayoutDirty();
            return true;
          }
        }
        return false;

      case MOUSE_DRAGGED:
        if (draggingHBar) {
          float w = getWidth();
          float h = getHeight();
          boolean needV = contentHeight > h + 0.5f;
          float vBarW = needV ? SCROLL_BAR_SIZE : 0;
          float clipW = Math.max(1, w - vBarW);
          float maxS = Math.max(1, contentWidth - clipW);
          float thumbLen = clipW * (clipW / Math.max(clipW, contentWidth));
          thumbLen = Math.max(16, thumbLen);
          float span = Math.max(1, clipW - thumbLen);
          float delta = absMouseX - dragStartMouseX;
          scrollX = dragStartScrollX + (delta / span) * maxS;
          scrollX = Math.max(0, Math.min(maxS, scrollX));
          markLayoutDirty();
          return true;
        }
        if (draggingVBar) {
          float w = getWidth();
          float h = getHeight();
          boolean needH = contentWidth > w + 0.5f;
          float hBarH = needH ? SCROLL_BAR_SIZE : 0;
          float clipH = Math.max(1, h - hBarH);
          float maxS = Math.max(1, contentHeight - clipH);
          float thumbLen = clipH * (clipH / Math.max(clipH, contentHeight));
          thumbLen = Math.max(16, thumbLen);
          float span = Math.max(1, clipH - thumbLen);
          float delta = absMouseY - dragStartMouseY;
          scrollY = dragStartScrollY + (delta / span) * maxS;
          scrollY = Math.max(0, Math.min(maxS, scrollY));
          markLayoutDirty();
          return true;
        }
        return false;

      case MOUSE_RELEASED:
        if (event.getMouseButton() == PApplet.LEFT) {
          draggingHBar = false;
          draggingVBar = false;
          return true;
        }
        return false;

      default:
        return false;
    }
  }
}

// ── Wave management ──

void refreshEnemyInfoWaveList() {
  if (eiWaveList == null) return;
  eiWaveList.clearItems();
  for (int i = 0; i < editorLevel.waves.size(); i++) {
    eiWaveList.addItem("Wave " + (i + 1));
  }
}

void checkEnemyInfoWaveSelection() {
  if (eiWaveList == null) return;
  int idx = eiWaveList.getSelectedIndex();
  if (idx != eiLastWaveListIdx) {
    eiLastWaveListIdx = idx;
    if (eiBtnDelWave != null) eiBtnDelWave.setEnabled(idx >= 0);
    if (idx < 0 || idx >= editorLevel.waves.size()) {
      if (eiSpawnList != null) eiSpawnList.clearItems();
      if (eiTxtWaveDelay != null) eiTxtWaveDelay.setText("2.0");
      if (eiTimeline != null) eiTimeline.setWave(null);
      return;
    }
    EditorWave wave = editorLevel.waves.get(idx);
    if (eiTxtWaveDelay != null) eiTxtWaveDelay.setText(String.valueOf(wave.delay));
    refreshEnemyInfoSpawnList(wave);
    if (eiTimeline != null) eiTimeline.setWave(wave);
  }
  // Keep button enabled state in sync even when selection hasn't changed
  if (eiBtnDelWave != null) {
    boolean hasSelection = idx >= 0 && idx < editorLevel.waves.size();
    eiBtnDelWave.setEnabled(hasSelection);
  }
}

void refreshEnemyInfoSpawnList(EditorWave wave) {
  if (eiSpawnList == null) return;
  eiSpawnList.clearItems();
  for (int i = 0; i < wave.spawns.size(); i++) {
    EditorSpawn spawn = wave.spawns.get(i);
    String summary = spawn.type + " x" + spawn.count + " @" + spawn.interval + "s";
    if (spawn.route != null && !spawn.route.isEmpty()) summary += " (" + spawn.route + ")";
    eiSpawnList.addItem(summary);
  }
  eiLastSpawnListIdx = -1;
  if (eiBtnDelSpawn != null) eiBtnDelSpawn.setEnabled(false);
}

void checkEnemyInfoSpawnSelection() {
  if (eiSpawnList == null) return;
  int idx = eiSpawnList.getSelectedIndex();
  if (idx == eiLastSpawnListIdx) return;
  eiLastSpawnListIdx = idx;

  if (eiBtnDelSpawn != null) eiBtnDelSpawn.setEnabled(idx >= 0);

  int waveIdx = eiWaveList != null ? eiWaveList.getSelectedIndex() : -1;
  if (waveIdx < 0 || waveIdx >= editorLevel.waves.size()) return;
  EditorWave wave = editorLevel.waves.get(waveIdx);

  if (idx < 0 || idx >= wave.spawns.size()) {
    if (eiSpDdType != null) eiSpDdType.setSelectedIndex(0);
    if (eiSpTxtCount != null) eiSpTxtCount.setText("5");
    if (eiSpTxtInterval != null) eiSpTxtInterval.setText("1.0");
    if (eiSpTxtRoute != null) eiSpTxtRoute.setText("");
    return;
  }

  EditorSpawn spawn = wave.spawns.get(idx);
  selectDropdownItem(eiSpDdType, spawn.type);
  eiSpTxtCount.setText(String.valueOf(spawn.count));
  eiSpTxtInterval.setText(String.valueOf(spawn.interval));
  eiSpTxtRoute.setText(spawn.route != null ? spawn.route : "");
}

void addEnemyInfoWave() {
  EditorWave wave = new EditorWave();
  wave.delay = 2.0f;
  editorLevel.waves.add(wave);
  refreshEnemyInfoWaveList();
}

void deleteEnemyInfoWave() {
  int idx = eiWaveList.getSelectedIndex();
  if (idx < 0 || idx >= editorLevel.waves.size()) return;
  editorLevel.waves.remove(idx);
  refreshEnemyInfoWaveList();
  if (eiSpawnList != null) eiSpawnList.clearItems();
  if (eiTxtWaveDelay != null) eiTxtWaveDelay.setText("2.0");
  if (eiTimeline != null) eiTimeline.setWave(null);
  eiLastWaveListIdx = -1;
}

void addEnemyInfoSpawn() {
  int idx = eiWaveList.getSelectedIndex();
  if (idx < 0 || idx >= editorLevel.waves.size()) return;
  EditorWave wave = editorLevel.waves.get(idx);
  EditorSpawn spawn = new EditorSpawn();
  wave.spawns.add(spawn);
  refreshEnemyInfoSpawnList(wave);
  if (eiTimeline != null) eiTimeline.setWave(wave);
  if (eiSpawnList != null) {
    eiSpawnList.setSelectedIndex(wave.spawns.size() - 1);
    eiLastSpawnListIdx = -1; // force refresh on next frame
  }
}

void deleteEnemyInfoSpawn() {
  int waveIdx = eiWaveList.getSelectedIndex();
  if (waveIdx < 0 || waveIdx >= editorLevel.waves.size()) return;
  EditorWave wave = editorLevel.waves.get(waveIdx);

  int idx = eiSpawnList.getSelectedIndex();
  if (idx < 0 || idx >= wave.spawns.size()) return;

  wave.spawns.remove(idx);
  refreshEnemyInfoSpawnList(wave);
  if (eiTimeline != null) eiTimeline.setWave(wave);
}

void applyEnemyInfoSpawnSettings() {
  int waveIdx = eiWaveList.getSelectedIndex();
  if (waveIdx < 0 || waveIdx >= editorLevel.waves.size()) return;
  EditorWave wave = editorLevel.waves.get(waveIdx);

  int idx = eiSpawnList.getSelectedIndex();
  if (idx < 0 || idx >= wave.spawns.size()) return;

  EditorSpawn spawn = wave.spawns.get(idx);
  spawn.type = eiSpDdType.getSelectedLabel();
  try { spawn.count = Integer.parseInt(eiSpTxtCount.getText()); } catch (Exception ignored) {}
  try { spawn.interval = Float.parseFloat(eiSpTxtInterval.getText()); } catch (Exception ignored) {}
  spawn.route = eiSpTxtRoute.getText();

  refreshEnemyInfoSpawnList(wave);
  if (eiTimeline != null) eiTimeline.setWave(wave);
  println("[EnemyInfo] Spawn " + (idx + 1) + " applied.");
}

void applyEnemyInfoWaveSettings() {
  int idx = eiWaveList.getSelectedIndex();
  if (idx < 0 || idx >= editorLevel.waves.size()) return;
  EditorWave wave = editorLevel.waves.get(idx);
  try {
    wave.delay = Float.parseFloat(eiTxtWaveDelay.getText());
  } catch (Exception e) {
    println("[ERROR] Invalid delay: " + eiTxtWaveDelay.getText());
    return;
  }
  if (eiTimeline != null) eiTimeline.setWave(wave);
  println("[EnemyInfo] Wave " + (idx + 1) + " applied.");
}

// ── Helpers ──

float addMapInfoRow(Panel parent, String label, UIComponent ctrl, float y, float rowH, float gap) {
  Panel row = makeLabeledRow("mi", label, ctrl);
  row.setPosition(8, y);
  row.setSize(400, rowH);
  parent.add(row);
  return y + rowH + gap;
}

Panel makeLabeledRow(String prefix, String label, UIComponent ctrl) {
  Panel row = new Panel(prefix + "_row_" + label.replaceAll("[^a-zA-Z0-9]", "_"));
  row.setLayoutManager(new FlowLayout(6, 4, false));
  Label lbl = new Label(prefix + "_lbl_" + label.replaceAll("[^a-zA-Z0-9]", "_"));
  lbl.setText(label);
  lbl.setSize(110, 28);
  row.add(lbl);
  row.add(ctrl);
  return row;
}

void selectDropdownItem(Dropdown dd, String item) {
  for (int i = 0; i < dd.getItemCount(); i++) {
    if (item.equals(dd.getItem(i))) {
      dd.setSelectedIndex(i);
      return;
    }
  }
  dd.setSelectedIndex(-1);
}
