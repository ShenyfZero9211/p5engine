# PPakDemo - PPAK Resource Loading Test

Tests the shenyf.p5engine.resource.ppak library for p5engine.

## 功能

- 加载 PPAK 资源包中的图片
- 加载 PPAK 资源包中的中文字体
- 加载并播放 PPAK 资源包中的音频
- 加载并播放 PPAK 资源包中的视频（.mp4 等格式）
- 缓存管理

## 运行

直接在 Processing IDE 中打开并运行，或使用 CLI：

```powershell
& "D:\Processing\Processing.exe" cli --sketch="E:\projects\kilo\p5engine\examples\PPakDemo" --build
```

## 依赖

- shenyf.p5engine.resource.ppak (内置于 p5engine.jar)
- ddf.minim (Processing 音频库)
- processing.video (Processing 视频库)

## 控制

- `1` - 切换到图片模式
- `2` - 切换到视频模式
- `空格` - 暂停/继续 音乐和视频
- `V` - 停止视频
- `L` - 循环视频
- `C` - 清理缓存
- `T` - 清理临时文件

## 视频加载示例

```java
import shenyf.p5engine.resource.ppak.*;
import processing.video.*;

PPak ppak;
Movie myVideo;

void setup() {
  size(800, 600);
  ppak = PPak.getInstance();
  ppak.init(this);
  
  // 使用 moviePath() 获取临时文件路径，然后创建 Movie
  String videoPath = ppak.moviePath("data/video.mp4");
  if (videoPath != null) {
    myVideo = new Movie(this, videoPath);
    myVideo.loop();
  }
}

void draw() {
  if (myVideo != null) {
    myVideo.read();
    image(myVideo, 0, 0, width, height);
  }
}

void stop() {
  if (ppak != null) {
    ppak.cleanup();  // cleanup 会清理所有视频临时文件
  }
  if (myVideo != null) {
    myVideo.dispose();
  }
  super.stop();
}
```

## 资源包

测试用资源位于 `data/data.ppak`，可通过以下命令重新打包：

```powershell
python tools/ppak/ppak_pack.py E:\projects\opencode\Processing_PPAK\data_ examples/PPakDemo/data/data.ppak
```