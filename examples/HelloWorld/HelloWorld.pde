import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.math.*;

P5Engine engine;
GameObject player;
PlayerController controller;

public void setup() {
    size(800, 600);

    engine = P5Engine.create(this);

    player = GameObject.create("Player");
    player.getTransform().setPosition(width / 2, height / 2);

    controller = player.addComponent(PlayerController.class);

    engine.getSceneManager().getActiveScene().addGameObject(player);
}

public void draw() {
    background(50);

    engine.update();

    fill(100, 200, 255);
    noStroke();
    Vector2 pos = controller.getPosition();
    ellipse(pos.x, pos.y, 50, 50);

    fill(255);
    textAlign(CENTER);
    text("Use WASD keys to move", width / 2, 30);
    text("FPS: " + (int) engine.getGameTime().getFrameRate(), width / 2, 50);
}

public static class PlayerController extends Component {
    float speed = 200;

    @Override
    public void update(float dt) {
        P5Engine engine = P5Engine.getInstance();

        if (engine.isKeyPressed()) {
            char k = engine.getKey();
            if (k == 'a' || k == 'A') {
                getTransform().translate(-speed * dt, 0);
            }
            if (k == 'd' || k == 'D') {
                getTransform().translate(speed * dt, 0);
            }
            if (k == 'w' || k == 'W') {
                getTransform().translate(0, -speed * dt);
            }
            if (k == 's' || k == 'S') {
                getTransform().translate(0, speed * dt);
            }
        }
    }

    public Vector2 getPosition() {
        return getTransform().getPosition();
    }
}
