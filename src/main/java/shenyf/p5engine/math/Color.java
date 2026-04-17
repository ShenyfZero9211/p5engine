package shenyf.p5engine.math;

public class Color {
    public int r;
    public int g;
    public int b;
    public int a;

    public Color() {
        this.r = 255;
        this.g = 255;
        this.b = 255;
        this.a = 255;
    }

    public Color(int r, int g, int b) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = 255;
    }

    public Color(int r, int g, int b, int a) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    public Color(int argb) {
        this.a = (argb >> 24) & 0xFF;
        this.r = (argb >> 16) & 0xFF;
        this.g = (argb >> 8) & 0xFF;
        this.b = argb & 0xFF;
    }

    public int toARGB() {
        return (a << 24) | (r << 16) | (g << 8) | b;
    }

    public int toRGB() {
        return (r << 16) | (g << 8) | b;
    }

    public static Color fromARGB(int argb) {
        return new Color(argb);
    }

    public static Color fromRGB(int rgb) {
        Color c = new Color();
        c.r = (rgb >> 16) & 0xFF;
        c.g = (rgb >> 8) & 0xFF;
        c.b = rgb & 0xFF;
        c.a = 255;
        return c;
    }

    public Color copy() {
        return new Color(r, g, b, a);
    }

    public Color set(int r, int g, int b) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = 255;
        return this;
    }

    public Color set(int r, int g, int b, int a) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
        return this;
    }

    public Color lerp(Color target, float t) {
        r = (int) (r + (target.r - r) * t);
        g = (int) (g + (target.g - g) * t);
        b = (int) (b + (target.b - b) * t);
        a = (int) (a + (target.a - a) * t);
        return this;
    }

    @Override
    public String toString() {
        return "Color(" + r + ", " + g + ", " + b + ", " + a + ")";
    }
}
