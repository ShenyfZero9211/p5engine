# p5engine

2D Game Engine for Processing

## 安装

1. 将此文件夹复制到 `~/Documents/Processing/libraries/` 目录下
2. 重启 Processing IDE

## 快速开始

```java
import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.rendering.*;

P5Engine engine;
GameObject player;

public void setup() {
    size(800, 600);

    engine = P5Engine.create(this);

    player = GameObject.create("Player");
    player.getTransform().setPosition(width / 2, height / 2);
    player.addComponent(PlayerController.class);
}

public void draw() {
    background(0);
    engine.update();
    engine.render();
}

public class PlayerController extends Component {
    float speed = 100;

    @Override
    public void update(float dt) {
        if (keyPressed) {
            if (key == 'a') getTransform().translate(-speed * dt, 0);
            if (key == 'd') getTransform().translate(speed * dt, 0);
        }
    }
}
```

## 核心概念

### GameObject
游戏对象，所有实体的基类。

```java
GameObject go = GameObject.create("Name");
```

### Component
组件，附加到GameObject上提供功能。

```java
public class MyComponent extends Component {
    @Override
    public void start() {
        // 初始化时调用
    }

    @Override
    public void update(float dt) {
        // 每帧调用
    }
}

go.addComponent(MyComponent.class);
```

### Transform
变换组件，控制位置、旋转、缩放。

```java
Transform transform = go.getTransform();
transform.setPosition(100, 200);
transform.setRotationDegrees(45);
transform.setScale(2, 2);
```

### Scene
场景，管理一组GameObject。

```java
Scene scene = engine.getSceneManager().createScene("Main");
scene.addGameObject(player);
engine.getSceneManager().loadScene("Main");
```

## API

### P5Engine
- `P5Engine.create(PApplet)` - 创建引擎实例
- `P5Engine.getInstance()` - 获取单例
- `engine.update()` - 更新逻辑
- `engine.render()` - 渲染画面
- `engine.getSceneManager()` - 获取场景管理器
- `engine.getGameTime()` - 获取时间

### P5GameTime
- `getDeltaTime()` - 帧间隔时间
- `getTotalTime()` - 总运行时间
- `getFrameRate()` - 当前帧率
- `getFrameCount()` - 帧计数器

## 示例

参考 `examples/` 目录下的示例代码。
