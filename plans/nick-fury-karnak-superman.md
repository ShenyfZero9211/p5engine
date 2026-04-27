# BGM切换卡顿优化 —— 后台线程异步加载方案

## 目标
消除切换BGM时的卡顿，通过后台线程异步加载音频文件，加载期间主线程完全不阻塞，加载完成后自动播放。

## 背景
当前 `TdSound` 每次切换BGM都同步调用 `AudioManager.loadMusic()`，文件I/O和OGG解码阻塞主线程。用户明确拒绝预加载方案（增加启动等待时间），要求改为**后台加载 + 不阻塞**。

## 方案：后台线程加载底层 Music 对象，主线程接管播放

### 核心思路
1. 后台线程只调用 `TinySound.loadMusic(file, stream)` 完成最耗时的文件读取和OGG解码，得到底层 `Music` 对象
2. 通过线程安全队列将 `Music` 对象传回主线程
3. 主线程每帧检查队列，将 `Music` 包装为 `TinyMusicClip`、注册到 `AudioManager`、立即播放
4. 切换BGM时如果尚未加载完成，游戏正常运行，加载完毕后自动切入播放

### 为什么安全
- `TinySound.loadMusic()` 是静态方法，只涉及文件读取和OpenAL缓冲区创建，不修改 `AudioManager` 的内部状态
- `AudioManager.activeMusics`（`ArrayList`）的 `add` 和 `get` 操作全部在主线程执行，无并发风险
- `TinyMusicClip` 的创建和播放也全部在主线程执行

### 实施步骤

1. **修改引擎核心 `AudioManager.java`**：
   - 添加公共方法 `registerMusic(TinyMusicClip clip)`，用于在主线程将已创建的 clip 加入 `activeMusics`

2. **修改 `TdSound.pde`**：
   - 添加 `bgmCache` 缓存已加载的 clip（保留已有缓存逻辑）
   - 添加 `bgmLoadQueue`（`ConcurrentLinkedQueue`）用于后台线程向主线程传递加载结果
   - 添加 `bgmLoading` Set 记录正在加载中的路径，避免重复加载
   - 修改 `playBgmMenu()` / `playTrack()`：
     - 已缓存 → 直接播放
     - 未缓存且未在加载 → 启动后台线程加载
     - 正在加载中 → 等待加载完成后自动播放（通过 `currentBgmPath` 匹配）
   - 添加 `update()` 方法：主线程每帧检查 `bgmLoadQueue`，完成注册和播放
   - 后台线程加载逻辑：
     ```java
     new Thread(() -> {
         File file = new File(app.sketchPath(path));
         Music music = TinySound.loadMusic(file, true);
         // 将 music 对象放入队列，由主线程接管
         bgmLoadQueue.offer(new LoadResult(path, music, loop));
     }).start();
     ```

3. **修改 `TowerDefenseMin2.pde`**：
   - 在 `draw()` 中加入 `TdSound.update();`（每帧检查加载队列）
   - 移除 `setup()` 中的 `TdSound.preloadAllBgm(this)` 调用（恢复为先前状态）

### 交互行为
- 点击"开始游戏" → 立即调用 `playBgmGame()` → 如果游戏BGM未缓存，启动后台线程加载 → 菜单BGM继续播放（不中断）→ 加载完成后自动切换到游戏BGM
- 游戏结束返回菜单 → 同理，菜单BGM后台加载期间静默或保持当前BGM
- Track 自动切歌 → 后台预加载下一首，加载完成后无缝切换

## 验收标准
- [ ] 从主菜单点击"开始游戏"时画面不卡顿
- [ ] 游戏结束返回主菜单时画面不卡顿
- [ ] BGM加载期间游戏帧率不受影响
- [ ] 加载完成后BGM自动正常播放
- [ ] 游戏内track自动切歌逻辑正常
- [ ] 编译通过，游戏可正常运行

## 相关文件
- `src/main/java/shenyf/p5engine/audio/AudioManager.java`（添加 registerMusic 方法）
- `examples/TowerDefenseMin2/TdSound.pde`（后台加载队列 + 播放逻辑改造）
- `examples/TowerDefenseMin2/TowerDefenseMin2.pde`（draw 中调用 TdSound.update）
