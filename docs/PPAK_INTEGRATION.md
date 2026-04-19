# PPAK 整合文档

> **整合日期**: 2026年4月18日
> **版本**: v1.0.0
> **来源**: `E:\projects\opencode\Processing_PPAK`

---

## 一、整合概述

### 1.1 整合内容

| 类别 | 内容 | 位置 |
|------|------|------|
| Java 库 | PPAK 资源加载类 (7个) | `src/main/java/shenyf/p5engine/resource/ppak/` |
| 打包进库 | 已编译类 | `library/p5engine.jar` |
| Python 工具 | PPAK 打包/解包/查看工具 | `tools/ppak/` |
| 导出脚本 | Processing 应用导出脚本 | `scripts/export_game.ps1` |
| 测试示例 | PPakDemo 示例 sketch | `examples/PPakDemo/` |

### 1.2 PPAK 功能列表

| 类 | 功能 |
|----|------|
| PPak | 主类，单例模式，管理初始化和资源加载 |
| PPakDecoder | PPAK 文件解码器，解析头部和索引 |
| PPakEntry | 文件条目数据结构 |
| PPakConstants | 常量定义 |
| PPakImage | 图片加载，支持内存缓存 |
| PPakAudio | 音频字节加载，支持内存缓存 |
| PPakFont | 字体加载，支持内存缓存 |

**注意**: PPakVideo（视频加载）因依赖 Processing video 库已移除

---

## 二、文件结构

### 2.1 Java 库结构

```
src/main/java/shenyf/p5engine/resource/ppak/
├── PPak.java              # 主类
├── PPakDecoder.java       # 解码器
├── PPakEntry.java         # 条目
├── PPakConstants.java     # 常量
├── PPakImage.java         # 图片
├── PPakAudio.java         # 音频
├── PPakFont.java          # 字体
└── PPakVideo.java         # 视频（已移除）
```

### 2.2 Python 工具结构

```
tools/ppak/
├── __init__.py
├── ppak_lib.py            # 核心库
├── ppak_pack.py           # 打包工具
├── ppak_unpack.py         # 解包工具
├── ppak_ls.py             # 列表工具
└── ppak_cli.py            # CLI 集成工具
```

### 2.3 测试示例结构

```
examples/PPakDemo/
├── PPakDemo.pde           # 主程序
├── README.md              # 说明文档
└── data/
    └── data.ppak          # 测试资源包 (9.6MB)
```

---

## 三、使用方法

### 3.1 在 Processing Sketch 中使用 PPAK

```java
import shenyf.p5engine.resource.ppak.*;

PPak ppak;
Minim minim;

void setup() {
  size(800, 600);

  // 初始化 PPAK（自动检测 data/data.ppak 或 data.ppak）
  ppak = PPak.getInstance();
  ppak.init(this);

  // 加载图片
  PImage img = ppak.image("data/player.png");

  // 加载字体
  PFont font = ppak.font("data/text.ttf", 32);

  // 加载音频文件
  String audioFile = ppak.audioFile("data/bgm.mp3");
  minim = new Minim(this);
  AudioPlayer bgm = minim.loadFile(audioFile);
  bgm.loop();
}

void draw() {
  // 使用资源
}

void stop() {
  ppak.cleanup();
  super.stop();
}
```

### 3.2 API 速查表

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `ppak.init(this)` | void | 初始化（自动检测 data.ppak） |
| `ppak.image("path")` | PImage | 加载图片 |
| `ppak.font("path", size)` | PFont | 加载字体 |
| `ppak.audioFile("path")` | String | 获取音频文件路径（临时文件） |
| `ppak.audioBytes("path")` | byte[] | 读取音频原始字节 |
| `ppak.sampleFile("path")` | String | 获取音效文件路径 |
| `ppak.read("path")` | byte[] | 读取原始字节 |
| `ppak.contains("path")` | boolean | 检查资源是否存在 |
| `ppak.list()` | String[] | 列出所有资源 |
| `ppak.clearCache()` | void | 清理内存缓存 |
| `ppak.cleanup()` | void | 清理所有资源 |

### 3.3 资源包位置检测顺序

1. `sketch/data/data.ppak` （优先，导出后标准位置）
2. `sketch/data.ppak` （备选，开发时位置）
3. 如果都不存在，自动回退到 `data/` 目录

---

## 四、打包工具使用

### 4.1 打包资源为 .ppak 文件

```powershell
python tools/ppak/ppak_pack.py <源目录> [输出.ppak] [选项]

# 示例：打包 data_ 目录为 data.ppak
python tools/ppak/ppak_pack.py E:\projects\opencode\Processing_PPAK\data_ examples/PPakDemo/data/data.ppak

# 带压缩
python tools/ppak/ppak_pack.py data/ output.ppak --compress
```

### 4.2 查看 .ppak 内容

```powershell
python tools/ppak/ppak_ls.py <file.ppak> [选项]

# 详细模式
python tools/ppak/ppak_ls.py data.ppak --details

# 过滤
python tools/ppak/ppak_ls.py data.ppak --grep ".png"
```

### 4.3 解包 .ppak 文件

```powershell
python tools/ppak/ppak_unpack.py <file.ppak> [输出目录] [选项]

# 基本解包
python tools/ppak/ppak_unpack.py data.ppak extracted/

# 强制覆盖
python tools/ppak/ppak_unpack.py data.ppak extracted/ --force
```

### 4.4 CLI 集成工具

```powershell
python tools/ppak/ppak_cli.py <command> [options]

# 列出 sketch
python tools/ppak/ppak_cli.py list my_project.ppak

# 运行
python tools/ppak/ppak_cli.py run my_project.ppak --sketch my_sketch

# 构建
python tools/ppak/ppak_cli.py build my_project.ppak --sketch my_sketch --output ./build

# 导出
python tools/ppak/ppak_cli.py export my_project.ppak --sketch my_sketch --output ./dist
```

---

## 五、导出脚本使用

### 5.1 导出 Processing 应用

```powershell
# 基本用法
.\scripts\export_game.ps1 -SketchPath "E:\projects\myGame"

# 指定输出名称
.\scripts\export_game.ps1 -SketchPath "E:\projects\myGame" -OutputName "MyGame"
```

### 5.2 脚本功能

1. 检测并复制 `data.ppak` → `data/data.ppak`
2. 调用 Processing CLI 导出 Windows 应用
3. 输出到 `dist/` 目录

---

## 六、PPAK 文件格式

```
+----------- 4 bytes --------+----------- 2 bytes --------+
|         MAGIC (b'PPAK')   |       VERSION (1)         |
+---------------------------+---------------------------+
|          ENTRY COUNT      |      RESERVED (4 bytes)   |
+---------------------------+---------------------------+
|                    INDEX SECTION                        |
|  [Offset:4] [Size:4] [NameLen:2] [Name:NameLen]  ...     |
+---------------------------+---------------------------+
|                    DATA SECTION                         |
|                   (raw file data)                      |
+-------------------------------------------------------+
```

- **MAGIC**: 4 bytes "PPAK"
- **VERSION**: 2 bytes short (当前为 1)
- **ENTRY_COUNT**: 4 bytes int
- **INDEX**: 每个条目 10 bytes + 文件名
- **DATA**: 原始文件数据

---

## 七、临时文件管理

### 7.1 临时文件命名

```
__ppak_<timestamp>_<random>_<suffix>.<ext>
例如: __ppak_1713360000000_12345_audio.mp3
```

### 7.2 清理时机

| 时机 | 动作 |
|------|------|
| `ppak.init()` | 调用 `cleanupOldTempFiles()` 清理旧临时文件 |
| 音频/字体加载后 | 临时文件立即删除 |
| `ppak.cleanup()` | 清理所有缓存和临时文件 |

### 7.3 API

```java
ppak.cleanupOldTempFiles();  // 清理所有旧临时文件
ppak.clearTempFiles();       // 清理当前临时文件
ppak.clearCache();           // 清理内存缓存
ppak.cleanup();              // 清理所有资源
```

---

## 八、缓存机制

### 8.1 图片缓存

- 最大条目数: 64
- 最大内存: 50MB
- LRU 淘汰策略

### 8.2 字体缓存

- 最大条目数: 16
- 按路径+字号组合缓存

### 8.3 音频缓存

- 最大条目数: 32
- 最大内存: 100MB
- LRU 淘汰策略

---

## 九、注意事项

### 9.1 路径格式

- PPAK 中存储路径不带 `data/` 前缀
- API 调用时可以使用 `data/xxx.png` 或 `xxx.png`
- 自动处理 `data/` 前缀

### 9.2 回退机制

- 如果 PPAK 文件不存在或资源不在包中，自动从 `data/` 目录读取
- `ppak.image("data/player.png")` 如果包中没有，会尝试 `sketch/data/data/player.png`

### 9.3 音频文件处理

- `ppak.audioFile()` 返回临时文件路径
- 临时文件在 `cleanup()` 时清理
- 如果需要持续访问音频，使用 `ppak.audioBytes()` 自己管理

### 9.4 字体注意事项

- Processing 的 `createFont()` 需要文件扩展名为 `.ttf`
- 如果 PPAK 中字体扩展名不是 `.ttf`，临时文件会使用 `.ttf` 扩展名

---

## 十、测试示例

### 10.1 运行测试

```powershell
# CLI 编译验证
& "D:\Processing\Processing.exe" cli --sketch="E:\projects\kilo\p5engine\examples\PPakDemo" --build
```

### 10.2 测试功能

- 图片加载显示（Soldier, Enemy, RockDamage）
- 中文字体加载
- 音频加载和播放控制
- 缓存管理

### 10.3 测试控制

| 键 | 功能 |
|----|------|
| `1` | 显示图片模式 |
| `空格` | 暂停/继续音乐 |
| `C` | 清理缓存 |
| `T` | 清理临时文件 |

---

## 十一、相关文档

- [PPakDemo README](examples/PPakDemo/README.md)
- [PPAK Python 工具](../Processing_PPAK/README.md) (原始项目)
- [Processing 开发心得](../__NEW_HOPE_2026__/技术栈/processing/Processing开发心得.md)

---

## 附录：包名变更记录

| 版本 | 包名 |
|------|------|
| 原始 (Processing_PPAK) | `shenyf.p5engine.ppak.*` |
| 整合后 (p5engine) | `shenyf.p5engine.resource.ppak.*` |

**迁移影响**: 使用旧包名的 sketch 需要更新 import 语句
