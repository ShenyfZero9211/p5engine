// ============================================
// UI Construction
// ============================================

Button[] toolButtons = new Button[6];

// Dialog windows
Window newMapWindow;
TextInput txtNewW, txtNewH;
Window saveAsWindow;
TextInput saTxtFilename;
Window openWindow;

void buildUi() {
  Panel root = ui.getRoot();
  root.removeAllChildren();
  root.setLayoutManager(null); // null layout allows floating popups/dropdowns at root level

  // Main layout container uses BorderLayout for the editor chrome
  layoutPanel = new Panel("layout_panel");
  layoutPanel.setLayoutManager(new BorderLayout());
  layoutPanel.setBounds(0, 0, width, height);
  root.add(layoutPanel);

  // ── Top Panel: MenuBar + Toolbar stacked vertically ──
  topPanel = new Panel("top_panel");
  topPanel.setLayoutManager(null); // Absolute layout within top panel
  topPanel.setSize(width, 68);
  topPanel.setPaintBackground(false);

  // MenuBar
  menuBar = new MenuBar("menu_bar");
  menuBar.setBounds(0, 0, width, 28);
  menuBar.setPaintBackground(true);

  Menu menuFile = menuBar.addMenu("File");
  menuFile.addItem("New", () -> onFileNew());
  menuFile.addItem("Open...", () -> onFileOpen());
  menuFile.addItem("Save", () -> onFileSave());
  menuFile.addItem("Save As...", () -> onFileSaveAs());
  menuFile.addItem("-", null);
  menuFile.addItem("Exit", () -> exit());

  Menu menuEdit = menuBar.addMenu("Edit");
  menuEdit.addItem("Undo", () -> onUndo());
  menuEdit.addItem("Redo", () -> onRedo());
  menuEdit.addItem("-", null);
  menuEdit.addItem("Map Info...", () -> onMapInfo());
  menuEdit.addItem("Enemy Info...", () -> onEnemyInfo());
  menuEdit.addItem("Delete", () -> onDeleteSelected());

  Menu menuView = menuBar.addMenu("View");
  menuView.addItem("Grid Toggle", () -> onToggleGrid());
  menuView.addItem("Zoom In", () -> onZoomIn());
  menuView.addItem("Zoom Out", () -> onZoomOut());
  menuView.addItem("Reset View", () -> onResetView());

  Menu menuHelp = menuBar.addMenu("Help");
  menuHelp.addItem("About", () -> onAbout());

  topPanel.add(menuBar);

  // Toolbar
  toolbar = new Panel("toolbar");
  toolbar.setBounds(0, 28, width, 40);
  toolbar.setLayoutManager(new FlowLayout(8, 8, false));
  toolbar.setPaintBackground(true);

  String[] toolNames = {"Select (1)", "Spawn (2)", "Base (3)", "Exit (4)", "Path (5)", "Erase (6)"};
  EditorTool[] tools = {EditorTool.SELECT, EditorTool.SPAWN, EditorTool.BASE, EditorTool.EXIT, EditorTool.PATH, EditorTool.ERASE};

  for (int i = 0; i < tools.length; i++) {
    Button btn = new Button("tool_" + tools[i].name().toLowerCase());
    btn.setLabel(toolNames[i]);
    btn.setSize(90, 28);
    final EditorTool t = tools[i];
    btn.setAction(() -> setTool(t));
    toolbar.add(btn);
    toolButtons[i] = btn;
  }

  lblToolInfo = new Label("lbl_tool_info");
  lblToolInfo.setText("Tool: SELECT");
  lblToolInfo.setSize(120, 28);
  toolbar.add(lblToolInfo);

  // Snap toggle button
  Button btnSnap = new Button("btn_snap");
  btnSnap.setLabel("Snap: ON");
  btnSnap.setSize(80, 28);
  btnSnap.setAction(() -> {
    inst.snapToGrid = !inst.snapToGrid;
    btnSnap.setLabel(inst.snapToGrid ? "Snap: ON" : "Snap: OFF");
  });
  toolbar.add(btnSnap);

  topPanel.add(toolbar);
  layoutPanel.add(topPanel, BorderLayout.NORTH);

  // ── Center: Viewport + Properties side by side ──
  centerPanel = new Panel("center_panel");
  centerPanel.setLayoutManager(new BorderLayout());

  // Viewport
  viewport = new EditorViewport("viewport");
  viewport.setCamera(camera);
  viewport.setScene(editorScene);
  viewport.setDrawGrid(true);
  centerPanel.add(viewport, BorderLayout.CENTER);

  // Right: Properties Panel
  propertiesPanel = new Panel("properties_panel");
  propertiesPanel.setSize(200, 400);
  propertiesPanel.setLayoutManager(null);
  propertiesPanel.setPaintBackground(true);

  Label lblPropsTitle = new Label("lbl_props_title");
  lblPropsTitle.setText("Properties");
  lblPropsTitle.setSize(188, 24);
  lblPropsTitle.setPosition(6, 6);
  propertiesPanel.add(lblPropsTitle);

  centerPanel.add(propertiesPanel, BorderLayout.EAST);

  layoutPanel.add(centerPanel, BorderLayout.CENTER);

  // Force layout
  layoutPanel.invalidateLayout();
}

void updateToolbarHighlight() {
  EditorTool[] tools = {EditorTool.SELECT, EditorTool.SPAWN, EditorTool.BASE, EditorTool.EXIT, EditorTool.PATH, EditorTool.ERASE};

  for (int i = 0; i < tools.length; i++) {
    Button btn = toolButtons[i];
    if (btn == null) continue;
    String rawLabel = btn.getLabel().replaceAll("\\[|\\]", "");
    if (tools[i] == currentTool) {
      btn.setLabel("[" + rawLabel + "]");
    } else {
      btn.setLabel(rawLabel);
    }
  }
}

void refreshPropertiesPanel() {
  propertiesPanel.removeAllChildren();

  float y = 6;
  Label lblTitle = new Label("lbl_props_title");
  lblTitle.setText("Properties");
  lblTitle.setSize(188, 24);
  lblTitle.setPosition(6, y);
  propertiesPanel.add(lblTitle);
  y += 24 + 6;

  if (selectedEntity != null) {
    Label lblType = new Label("lbl_type");
    lblType.setText("Type: " + selectedEntity.type.name());
    lblType.setSize(188, 20);
    lblType.setPosition(6, y);
    propertiesPanel.add(lblType);
    y += 20 + 6;

    Label lblX = new Label("lbl_x");
    lblX.setText("X: " + (int) selectedEntity.position.x);
    lblX.setSize(188, 20);
    lblX.setPosition(6, y);
    propertiesPanel.add(lblX);
    y += 20 + 6;

    Label lblY = new Label("lbl_y");
    lblY.setText("Y: " + (int) selectedEntity.position.y);
    lblY.setSize(188, 20);
    lblY.setPosition(6, y);
    propertiesPanel.add(lblY);
    y += 20 + 6;
  } else if (selectedPath != null) {
    Label lblPathInfo = new Label("lbl_path_info");
    lblPathInfo.setText("Path: " + selectedPath.id);
    lblPathInfo.setSize(188, 20);
    lblPathInfo.setPosition(6, y);
    propertiesPanel.add(lblPathInfo);
    y += 20 + 6;

    Label lblPathType = new Label("lbl_path_type");
    lblPathType.setText("Type: " + selectedPath.type.name());
    lblPathType.setSize(188, 20);
    lblPathType.setPosition(6, y);
    propertiesPanel.add(lblPathType);
    y += 20 + 6;
  } else {
    Label lblNone = new Label("lbl_none");
    lblNone.setText("No selection");
    lblNone.setSize(188, 20);
    lblNone.setPosition(6, y);
    propertiesPanel.add(lblNone);
    y += 20 + 6;
  }

  // Paths list (MULTI_PATHS mode)
  if (editorLevel != null && editorLevel.pathMode == PathMode.MULTI_PATHS) {
    Label lblPathsTitle = new Label("lbl_paths_title");
    lblPathsTitle.setText("Paths");
    lblPathsTitle.setSize(188, 20);
    lblPathsTitle.setPosition(6, y);
    propertiesPanel.add(lblPathsTitle);
    y += 22;

    for (int i = 0; i < editorLevel.paths.size(); i++) {
      EditorPath path = editorLevel.paths.get(i);
      final EditorPath fp = path;
      boolean isSel = (selectedPath == path);

      Button btnPath = new Button("prop_path_" + i);
      btnPath.setLabel((isSel ? "> " : "  ") + path.id + " [" + path.type.name() + "]");
      btnPath.setSize(156, 22);
      btnPath.setPosition(6, y);
      btnPath.setAction(() -> {
        selectedEntity = null;
        selectedPath = fp;
        refreshPropertiesPanel();
      });
      propertiesPanel.add(btnPath);

      Button btnDel = new Button("prop_path_del_" + i);
      btnDel.setLabel("×");
      btnDel.setSize(28, 22);
      btnDel.setPosition(164, y);
      btnDel.setAction(() -> {
        editorLevel.paths.remove(fp);
        if (selectedPath == fp) selectedPath = null;
        refreshPropertiesPanel();
      });
      propertiesPanel.add(btnDel);
      y += 24;
    }

    // Selected path editor
    if (selectedPath != null) {
      y += 4;

      Label lblId = new Label("prop_path_lbl_id");
      lblId.setText("ID:");
      lblId.setSize(28, 22);
      lblId.setPosition(6, y);
      propertiesPanel.add(lblId);

      TextInput txtPathId = new TextInput("prop_path_id");
      txtPathId.setSize(152, 22);
      txtPathId.setText(selectedPath.id);
      txtPathId.setPosition(36, y);
      propertiesPanel.add(txtPathId);
      y += 26;

      Label lblType = new Label("prop_path_lbl_type");
      lblType.setText("Type:");
      lblType.setSize(38, 22);
      lblType.setPosition(6, y);
      propertiesPanel.add(lblType);

      Dropdown ddPathType = new Dropdown("prop_path_type");
      ddPathType.setSize(130, 22);
      ddPathType.addItem("INBOUND");
      ddPathType.addItem("OUTBOUND");
      ddPathType.addItem("DIRECT");
      ddPathType.setSelectedIndex(selectedPath.type.ordinal());
      ddPathType.setPosition(46, y);
      propertiesPanel.add(ddPathType);
      y += 26;

      Button btnApply = new Button("prop_path_apply");
      btnApply.setLabel("Apply");
      btnApply.setSize(56, 24);
      btnApply.setPosition(6, y);
      btnApply.setAction(() -> {
        selectedPath.id = txtPathId.getText();
        String typeStr = ddPathType.getSelectedLabel();
        if (typeStr != null) selectedPath.type = PathRouteType.valueOf(typeStr);
        refreshPropertiesPanel();
      });
      propertiesPanel.add(btnApply);

      Button btnClear = new Button("prop_path_clear");
      btnClear.setLabel("Clear");
      btnClear.setSize(56, 24);
      btnClear.setPosition(66, y);
      btnClear.setAction(() -> {
        selectedPath = null;
        refreshPropertiesPanel();
      });
      propertiesPanel.add(btnClear);
      y += 28;
    }
  }

  // World size
  Label lblWorld = new Label("lbl_world");
  lblWorld.setText("World: " + editorLevel.worldW + "x" + editorLevel.worldH);
  lblWorld.setSize(188, 20);
  lblWorld.setPosition(6, y);
  propertiesPanel.add(lblWorld);

  propertiesPanel.invalidateLayout();
}

// ── Menu Actions ──

void onFileNew() {
  showNewMapDialog();
}

void showNewMapDialog() {
  if (newMapWindow != null) {
    txtNewW.setText("1600");
    txtNewH.setText("1200");
    newMapWindow.setVisible(true);
    return;
  }
  buildNewMapDialog();
}

void buildNewMapDialog() {
  Panel root = ui.getRoot();

  newMapWindow = new Window("newmap_win");
  newMapWindow.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
  newMapWindow.setBounds(0, 0, 360, 180);
  newMapWindow.setTitle("New Map");
  newMapWindow.setMovable(true);
  newMapWindow.setResizable(false);
  newMapWindow.setZOrder(200);

  // Width row
  Label lblW = new Label("nm_lbl_w");
  lblW.setText("Width:");
  lblW.setSize(70, 28);
  lblW.setPosition(20, 16);
  newMapWindow.add(lblW);

  txtNewW = new TextInput("nm_txt_w");
  txtNewW.setSize(200, 28);
  txtNewW.setText("1600");
  txtNewW.setPosition(100, 16);
  newMapWindow.add(txtNewW);

  // Height row
  Label lblH = new Label("nm_lbl_h");
  lblH.setText("Height:");
  lblH.setSize(70, 28);
  lblH.setPosition(20, 56);
  newMapWindow.add(lblH);

  txtNewH = new TextInput("nm_txt_h");
  txtNewH.setSize(200, 28);
  txtNewH.setText("1200");
  txtNewH.setPosition(100, 56);
  newMapWindow.add(txtNewH);

  // Buttons
  Button btnOk = new Button("nm_btn_ok");
  btnOk.setLabel("OK");
  btnOk.setSize(80, 32);
  btnOk.setPosition(60, 110);
  btnOk.setAction(() -> onNewMapConfirm());
  newMapWindow.add(btnOk);

  Button btnCancel = new Button("nm_btn_cancel");
  btnCancel.setLabel("Cancel");
  btnCancel.setSize(80, 32);
  btnCancel.setPosition(220, 110);
  btnCancel.setAction(() -> newMapWindow.close());
  newMapWindow.add(btnCancel);

  root.add(newMapWindow);
  root.invalidateLayout();
}

void onNewMapConfirm() {
  int newW = 1600;
  int newH = 1200;
  try {
    newW = Integer.parseInt(txtNewW.getText().trim());
  } catch (Exception e) {
    // use default
  }
  try {
    newH = Integer.parseInt(txtNewH.getText().trim());
  } catch (Exception e) {
    // use default
  }

  // Clamp
  newW = constrain(newW, 400, 5000);
  newH = constrain(newH, 300, 5000);

  editorLevel = new EditorLevel();
  editorLevel.worldW = newW;
  editorLevel.worldH = newH;
  selectedEntity = null;
  selectedPath = null;
  isDrawingPath = false;
  currentPath = null;
  camera.setWorldBounds(new Rect(0, 0, newW, newH));
  camera.getTransform().setPosition(newW * 0.5f, newH * 0.5f);
  camera.setZoom(1.0f);

  refreshPropertiesPanel();
  newMapWindow.close();
}

void onFileOpen() {
  if (fileBrowserWindow != null && fileBrowserWindow.isVisible()) return;
  showFileBrowser("open", "Open Level", "");
}

void onOpenSelected(java.io.File selection) {
  if (selection == null) return;
  try {
    String content = new String(java.nio.file.Files.readAllBytes(selection.toPath()));
    EditorLevel loaded = loadLevelFromYamlString(content);
    if (loaded != null) {
      editorLevel = loaded;
      camera.setWorldBounds(new Rect(0, 0, editorLevel.worldW, editorLevel.worldH));
      selectedEntity = null;
      selectedPath = null;
      isDrawingPath = false;
      currentPath = null;
      refreshPropertiesPanel();
      if (lblToolInfo != null) {
        lblToolInfo.setText("Tool: " + currentTool.name());
      }
      println("[Open] Loaded from " + selection.getAbsolutePath());
    }
  } catch (Exception e) {
    println("[ERROR] Failed to open: " + e.getMessage());
    e.printStackTrace();
  }
}

void onFileSave() {
  String yaml = saveLevelToYaml(editorLevel);
  String filename = "data/config/levels/level_" + editorLevel.id + ".yaml";
  java.io.File dir = new java.io.File(sketchPath("data/config/levels"));
  if (!dir.exists()) dir.mkdirs();
  saveStrings(filename, yaml.split("\n"));
  println("[Save] Saved to " + filename);
}

void onFileSaveAs() {
  if (fileBrowserWindow != null && fileBrowserWindow.isVisible()) return;
  showFileBrowser("save", "Save As", "level_" + editorLevel.id + ".yaml");
}

void onSaveAsSelected(java.io.File selection) {
  if (selection == null) return;
  String yaml = saveLevelToYaml(editorLevel);
  saveStrings(selection.getAbsolutePath(), yaml.split("\n"));
  println("[Save As] Saved to " + selection.getAbsolutePath());
}

void onUndo() {
  println("Undo: not yet implemented");
}

void onRedo() {
  println("Redo: not yet implemented");
}



void onDeleteSelected() {
  if (selectedEntity == null) return;
  switch (selectedEntity.type) {
    case SPAWN: editorLevel.spawnPos = null; break;
    case BASE: editorLevel.basePos = null; break;
    case EXIT: editorLevel.exitPos = null; break;
    case PATH_POINT:
      editorLevel.pathPoints.remove(selectedEntity.position);
      if (selectedEntity.pathRef != null) {
        selectedEntity.pathRef.points.remove(selectedEntity.position);
      }
      break;
  }
  selectedEntity = null;
  refreshPropertiesPanel();
}

void onToggleGrid() {
  viewport.setDrawGrid(!viewport.isDrawGrid());
}

void onZoomIn() {
  camera.setZoom(min(camera.getZoom() * 1.2f, 5.0f));
}

void onZoomOut() {
  camera.setZoom(max(camera.getZoom() * 0.8f, 0.1f));
}

void onResetView() {
  camera.getTransform().setPosition(editorLevel.worldW * 0.5f, editorLevel.worldH * 0.5f);
  camera.setZoom(1.0f);
}

void onAbout() {
  // TODO: show about window
  println("MapEditor v0.1.0 - p5engine Level Editor");
}


// ── Shared File Browser Dialog ──

Window fileBrowserWindow;
Label fbLblPath;
ScrollPane fbScrollPane;
Panel fbListPanel;
TextInput fbTxtFilename;
Button fbBtnConfirm;
java.io.File fbCurrentDir;
String fbMode = "open";   // "open" or "save"
String fbDefaultName = "";

void showFileBrowser(String mode, String title, String defaultName) {
  fbMode = mode;
  fbDefaultName = defaultName;

  Panel root = ui.getRoot();
  if (fileBrowserWindow != null && fileBrowserWindow.getParent() != null) {
    fileBrowserWindow.getParent().remove(fileBrowserWindow);
  }

  fileBrowserWindow = new Window("fb_win");
  fileBrowserWindow.setLayoutManager(new BorderLayout());
  fileBrowserWindow.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
  fileBrowserWindow.setBounds(0, 0, 600, 460);
  fileBrowserWindow.setTitle(title);
  fileBrowserWindow.setMovable(true);
  fileBrowserWindow.setResizable(false);
  fileBrowserWindow.setZOrder(300);

  Panel content = new Panel("fb_content");
  content.setLayoutManager(null);

  // Path label
  fbLblPath = new Label("fb_path");
  fbLblPath.setSize(480, 22);
  fbLblPath.setPosition(12, 10);
  content.add(fbLblPath);

  // Up button
  Button btnUp = new Button("fb_up");
  btnUp.setLabel("↑ Up");
  btnUp.setSize(80, 24);
  btnUp.setPosition(500, 10);
  btnUp.setAction(() -> onBrowserUp());
  content.add(btnUp);

  // File list scroll pane
  fbScrollPane = new ScrollPane("fb_scroll");
  fbScrollPane.setBounds(12, 40, 568, 310);
  fbListPanel = new Panel("fb_list");
  fbListPanel.setLayoutManager(null);
  fbScrollPane.getViewport().add(fbListPanel);
  content.add(fbScrollPane);

  // Bottom area (filename input for save mode)
  float by = 362;
  if ("save".equals(mode)) {
    Label lblName = new Label("fb_lbl_name");
    lblName.setText("Filename:");
    lblName.setSize(70, 24);
    lblName.setPosition(12, by);
    content.add(lblName);

    fbTxtFilename = new TextInput("fb_filename");
    fbTxtFilename.setSize(380, 24);
    fbTxtFilename.setPosition(88, by);
    fbTxtFilename.setText(defaultName);
    content.add(fbTxtFilename);
    by += 36;
  }

  fbBtnConfirm = new Button("fb_confirm");
  fbBtnConfirm.setLabel("save".equals(mode) ? "Save" : "Open");
  fbBtnConfirm.setSize(90, 28);
  fbBtnConfirm.setPosition(180, by);
  fbBtnConfirm.setAction(() -> onBrowserConfirm());
  content.add(fbBtnConfirm);

  Button btnCancel = new Button("fb_cancel");
  btnCancel.setLabel("Cancel");
  btnCancel.setSize(90, 28);
  btnCancel.setPosition(300, by);
  btnCancel.setAction(() -> fileBrowserWindow.close());
  content.add(btnCancel);

  fileBrowserWindow.add(content, BorderLayout.CENTER);
  root.add(fileBrowserWindow);
  root.invalidateLayout();

  // Set initial directory
  if (fbCurrentDir == null) {
    fbCurrentDir = new java.io.File(sketchPath("data/config/levels"));
  }
  if (!fbCurrentDir.exists()) {
    fbCurrentDir = new java.io.File(sketchPath(""));
  }
  refreshFileBrowserList();
}

void refreshFileBrowserList() {
  fbListPanel.removeAllChildren();
  fbLblPath.setText(fbCurrentDir.getAbsolutePath());

  java.io.File[] entries = fbCurrentDir.listFiles();
  java.util.ArrayList<java.io.File> dirs = new java.util.ArrayList<>();
  java.util.ArrayList<java.io.File> files = new java.util.ArrayList<>();

  if (entries != null) {
    for (java.io.File f : entries) {
      if (f.isHidden()) continue;
      if (f.isDirectory()) dirs.add(f);
      else if ("open".equals(fbMode) && f.getName().endsWith(".yaml")) files.add(f);
      else if ("save".equals(fbMode)) files.add(f);
    }
  }

  java.util.Collections.sort(dirs, (a, b) -> a.getName().compareToIgnoreCase(b.getName()));
  java.util.Collections.sort(files, (a, b) -> a.getName().compareToIgnoreCase(b.getName()));

  float y = 4;
  int idx = 0;

  for (java.io.File d : dirs) {
    final java.io.File fd = d;
    Button btn = new Button("fb_dir_" + idx);
    btn.setLabel("[D] " + d.getName());
    btn.setSize(540, 24);
    btn.setPosition(4, y);
    btn.setAction(() -> onBrowserEnterDir(fd));
    fbListPanel.add(btn);
    y += 26;
    idx++;
  }

  for (java.io.File f : files) {
    final java.io.File ff = f;
    Button btn = new Button("fb_file_" + idx);
    btn.setLabel(f.getName());
    btn.setSize(540, 24);
    btn.setPosition(4, y);
    btn.setAction(() -> onBrowserSelectFile(ff));
    fbListPanel.add(btn);
    y += 26;
    idx++;
  }

  if (idx == 0) {
    Label lblEmpty = new Label("fb_empty");
    lblEmpty.setText("(empty folder)");
    lblEmpty.setSize(540, 24);
    lblEmpty.setPosition(4, y);
    fbListPanel.add(lblEmpty);
  }

  fbListPanel.setSize(548, Math.max(310, y + 4));
  fbListPanel.invalidateLayout();
}

void onBrowserUp() {
  java.io.File parent = fbCurrentDir.getParentFile();
  if (parent != null) {
    fbCurrentDir = parent;
    refreshFileBrowserList();
  }
}

void onBrowserEnterDir(java.io.File dir) {
  fbCurrentDir = dir;
  refreshFileBrowserList();
}

void onBrowserSelectFile(java.io.File file) {
  if ("save".equals(fbMode)) {
    fbTxtFilename.setText(file.getName());
  } else {
    fileBrowserWindow.close();
    onOpenSelected(file);
  }
}

void onBrowserConfirm() {
  if ("save".equals(fbMode)) {
    String filename = fbTxtFilename.getText().trim();
    if (filename.isEmpty()) return;
    String yaml = saveLevelToYaml(editorLevel);
    String path = fbCurrentDir.getAbsolutePath() + "/" + filename;
    // Normalize path separator for Windows
    path = path.replace('/', java.io.File.separatorChar);
    saveStrings(path, yaml.split("\n"));
    println("[Save As] Saved to " + path);
    fileBrowserWindow.close();
  } else {
    // Open mode: try to open selected file from filename input, or show hint
    String filename = fbTxtFilename != null ? fbTxtFilename.getText().trim() : "";
    if (!filename.isEmpty()) {
      java.io.File f = new java.io.File(fbCurrentDir, filename);
      if (f.exists()) {
        fileBrowserWindow.close();
        onOpenSelected(f);
        return;
      }
    }
    println("[Open] Please select a file from the list.");
  }
}
