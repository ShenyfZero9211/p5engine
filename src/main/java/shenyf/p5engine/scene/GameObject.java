package shenyf.p5engine.scene;

import shenyf.p5engine.rendering.IRenderer;
import shenyf.p5engine.rendering.Renderable;
import shenyf.p5engine.util.Logger;

import java.util.*;

public class GameObject implements Iterable<Component> {
    private final String guid;
    private String name;
    private String tag = "";
    Scene scene;
    private final Transform transform;
    private final Map<Class<? extends Component>, Component> components;
    private final List<Component> componentList;
    private boolean active;
    private boolean markedForDestroy;

    public GameObject(String name) {
        this.guid = UUID.randomUUID().toString();
        this.name = name;
        this.transform = new Transform();
        this.transform.setGameObject(this);
        this.components = new HashMap<>();
        this.componentList = new ArrayList<>();
        this.active = true;
    }

    public static GameObject create(String name) {
        return new GameObject(name);
    }

    public void addComponent(Component component) {
        if (component == null) return;
        Class<? extends Component> clazz = component.getClass();
        components.put(clazz, component);
        componentList.add(component);
        component.setGameObject(this);
        component.start();
        Logger.debug("Component " + clazz.getSimpleName() + " added to " + name);
    }

    public <T extends Component> T addComponent(Class<T> componentClass) {
        T component;
        try {
            component = componentClass.getDeclaredConstructor().newInstance();
        } catch (Exception e) {
            throw new RuntimeException("Failed to create component: " + componentClass.getName() + 
                ". Make sure the class has a public no-arg constructor and is not a non-static inner class. " +
                "For PDE inner classes, use addComponent(new MyComponent()) instead.", e);
        }

        components.put(componentClass, component);
        componentList.add(component);
        component.setGameObject(this);
        component.start();
        Logger.debug("Component " + componentClass.getSimpleName() + " added to " + name);
        return component;
    }

    @SuppressWarnings("unchecked")
    public <T extends Component> T getComponent(Class<T> componentClass) {
        return (T) components.get(componentClass);
    }

    public <T extends Component> boolean hasComponent(Class<T> componentClass) {
        return components.containsKey(componentClass);
    }

    public <T extends Component> void removeComponent(Class<T> componentClass) {
        Component component = components.remove(componentClass);
        if (component != null) {
            componentList.remove(component);
            component.onDestroy();
            Logger.debug("Component " + componentClass.getSimpleName() + " removed from " + name);
        }
    }

    public void update(float deltaTime) {
        if (!active) return;
        for (Component component : componentList) {
            if (component.isEnabled()) {
                component.update(deltaTime);
            }
        }
    }

    public void render(IRenderer renderer) {
        if (!active) return;
        for (Component component : componentList) {
            if (component instanceof Renderable && component.isEnabled()) {
                ((Renderable) component).render(renderer);
            }
        }
    }

    public String getGuid() {
        return guid;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Transform getTransform() {
        return transform;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public String getTag() {
        return tag;
    }

    public void setTag(String tag) {
        this.tag = tag != null ? tag : "";
    }

    public boolean isMarkedForDestroy() {
        return markedForDestroy;
    }

    public void markForDestroy() {
        this.markedForDestroy = true;
        if (scene != null) {
            scene.markForDestroy(this);
        }
    }

    public Scene getScene() {
        return scene;
    }

    void setScene(Scene scene) {
        this.scene = scene;
    }

    public List<Component> getComponents() {
        return new ArrayList<>(componentList);
    }

    @Override
    public Iterator<Component> iterator() {
        return componentList.iterator();
    }

    @Override
    public String toString() {
        return "GameObject{name='" + name + "', guid='" + guid + "', components=" + componentList.size() + "}";
    }
}
