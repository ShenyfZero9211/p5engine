import shenyf.p5engine.core.*;
import shenyf.p5engine.ui.*;

P5Engine engine;
UIManager ui;
SketchUiCoordinator sketchUi;
ProgressBar progDemo;

void settings() {
  size(920, 640);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  engine = P5Engine.create(this);
  engine.setApplicationTitle("UIDemo");
  engine.setSketchVersion("0.0.1");

  ui = new UIManager(this);
  ui.attach();
  sketchUi = new SketchUiCoordinator(this, ui);

  buildUi();
}

void buildUi() {
  Panel root = ui.getRoot();

  Window win = new Window("demo_window");
  win.setBounds(32, 28, 560, 460);
  win.setTitle("p5engine UI demo");
  win.setZOrder(0);
  win.setLayoutManager(new BorderLayout());

  TabPane tabs = new TabPane("main_tabs");
  win.add(tabs, BorderLayout.CENTER);

  Panel pageWidgets = new Panel("page_widgets");
  pageWidgets.setLayoutManager(new FlowLayout(10, 10, true));

  Label title = new Label("lbl_title");
  title.setText("Basic widgets");
  pageWidgets.add(title);

  Button btn = new Button("btn_click");
  btn.setLabel("Click me");
  btn.setAction(() -> println("[UIDemo] button click"));
  pageWidgets.add(btn);

  Checkbox cb = new Checkbox("cb_demo");
  cb.setLabel("Enable feature");
  pageWidgets.add(cb);

  RadioButton r1 = new RadioButton("rb_a");
  r1.setGroupId("demo_grp");
  r1.setLabel("Option A");
  r1.setSelected(true);
  pageWidgets.add(r1);

  RadioButton r2 = new RadioButton("rb_b");
  r2.setGroupId("demo_grp");
  r2.setLabel("Option B");
  pageWidgets.add(r2);

  Slider sl = new Slider("slider_demo");
  sl.setSize(220, 28);
  pageWidgets.add(sl);

  ScrollBar sbH = new ScrollBar("sb_demo_h");
  sbH.setVertical(false);
  sbH.setSize(200, 18);
  pageWidgets.add(sbH);

  ScrollBar sbV = new ScrollBar("sb_demo_v");
  sbV.setVertical(true);
  sbV.setSize(18, 120);
  pageWidgets.add(sbV);

  TextInput field = new TextInput("field_demo");
  field.setText("Type here...");
  pageWidgets.add(field);

  progDemo = new ProgressBar("prog_demo");
  progDemo.setSize(220, 20);
  pageWidgets.add(progDemo);

  tabs.addTab("Widgets", pageWidgets);

  Panel pageScroll = new Panel("page_scroll");
  pageScroll.setLayoutManager(new BorderLayout());

  ScrollPane sp = new ScrollPane("scroll_demo");
  pageScroll.add(sp, BorderLayout.CENTER);

  List lst = new List("list_demo");
  for (int i = 0; i < 80; i++) {
    lst.addItem("List row #" + i);
  }
  sp.getViewport().setLayoutManager(null);
  sp.getViewport().add(lst);
  lst.setBounds(6, 6, 400, 900);

  Label scrollHint = new Label("lbl_scroll_hint");
  scrollHint.setText("Wheel to scroll, click to select");
  pageScroll.add(scrollHint, BorderLayout.SOUTH);

  tabs.addTab("Scroll + list", pageScroll);

  Panel pageFrame = new Panel("page_frame");
  pageFrame.setLayoutManager(new FlowLayout(10, 10, true));

  Frame fr = new Frame("inner_frame");
  fr.setSize(260, 140);
  Label in = new Label("lbl_in_frame");
  in.setText("Label inside Frame");
  fr.setLayoutManager(new BorderLayout());
  fr.add(in, BorderLayout.CENTER);
  pageFrame.add(fr);

  PImage pic = createImage(96, 64, ARGB);
  for (int y = 0; y < pic.height; y++) {
    for (int x = 0; x < pic.width; x++) {
      pic.set(x, y, color(40 + x * 2, 80 + y, 160));
    }
  }
  pic.updatePixels();
  Image img = new Image("img_demo");
  img.setImage(pic);
  img.setSize(120, 80);
  pageFrame.add(img);

  tabs.addTab("Frame / Image", pageFrame);

  Panel pageLayout = new Panel("page_layout");
  pageLayout.setLayoutManager(new BorderLayout());

  Label layoutTitle = new Label("lbl_layout_intro");
  layoutTitle.setText("GridLayout + AbsoluteLayout + nested BorderLayout");
  pageLayout.add(layoutTitle, BorderLayout.NORTH);

  Panel gridHost = new Panel("grid_host");
  gridHost.setLayoutManager(new GridLayout(3, 4, 6, 6));
  for (int i = 0; i < 12; i++) {
    Label cell = new Label("gcell_" + i);
    int row = i / 4;
    int col = i % 4;
    cell.setText(row + "," + col);
    gridHost.add(cell);
  }
  pageLayout.add(gridHost, BorderLayout.CENTER);

  Panel bottomRow = new Panel("layout_bottom");
  bottomRow.setLayoutManager(new FlowLayout(10, 10, false));

  Panel absDemo = new Panel("abs_demo");
  absDemo.setLayoutManager(new AbsoluteLayout());
  absDemo.setSize(260, 100);
  Label absLbl = new Label("lbl_abs");
  absLbl.setText("AbsoluteLayout (fixed child bounds)");
  absLbl.setBounds(6, 4, 240, 18);
  absDemo.add(absLbl);
  Button ax1 = new Button("abs_b1");
  ax1.setBounds(8, 28, 72, 26);
  ax1.setLabel("A1");
  ax1.setAction(() -> println("[UIDemo] absolute A1"));
  absDemo.add(ax1);
  Button ax2 = new Button("abs_b2");
  ax2.setBounds(96, 48, 72, 26);
  ax2.setLabel("A2");
  absDemo.add(ax2);
  bottomRow.add(absDemo);

  Panel nestBorder = new Panel("nest_border");
  nestBorder.setLayoutManager(new BorderLayout());
  nestBorder.setSize(220, 100);
  Label nN = new Label("nb_n");
  nN.setText("N");
  nestBorder.add(nN, BorderLayout.NORTH);
  Label nW = new Label("nb_w");
  nW.setText("W");
  nestBorder.add(nW, BorderLayout.WEST);
  Label nC = new Label("nb_c");
  nC.setText("Center");
  nestBorder.add(nC, BorderLayout.CENTER);
  bottomRow.add(nestBorder);

  pageLayout.add(bottomRow, BorderLayout.SOUTH);

  tabs.addTab("Layouts", pageLayout);

  Window tools = new Window("tools_window");
  tools.setBounds(620, 40, 260, 200);
  tools.setTitle("Second window (drag title)");
  tools.setZOrder(10);
  tools.setLayoutManager(new BorderLayout());
  Label toolsHint = new Label("tools_hint");
  toolsHint.setText("Extra Panel / Window + z-order");
  tools.add(toolsHint, BorderLayout.CENTER);
  Slider toolsSlider = new Slider("tools_slider");
  toolsSlider.setValue(0.35f);
  tools.add(toolsSlider, BorderLayout.SOUTH);

  root.removeAllChildren();
  root.add(win);
  root.add(tools);
  root.invalidateLayout();
}

void draw() {
  background(38);

  engine.update();

  if (progDemo != null) {
    float t = (sin(frameCount * 0.05f) * 0.5f + 0.5f);
    progDemo.setValue(t);
  }

  ui.beginFrame();
  Button poolBtn = ui.button("pooled_top_btn");
  poolBtn.setBounds(width - 148, 8, 132, 26);
  poolBtn.setZOrder(500);
  poolBtn.setLabel("Pooled (pool)");
  poolBtn.setAction(() -> println("[UIDemo] pooled button (beginFrame/endFrame)"));
  ui.endFrame();

  float dt = engine.getGameTime().getDeltaTime();
  sketchUi.updateFrame(dt);
  sketchUi.renderFrame();
}
