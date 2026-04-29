package shenyf.p5engine.rendering;

import java.util.Objects;

/**
 * Describes a single display resolution with refresh rate and bit depth.
 * Used for dynamic resolution enumeration from the GraphicsEnvironment.
 */
public class ResolutionInfo {
    public final int width;
    public final int height;
    public final int refreshRate;
    public final int bitDepth;

    public ResolutionInfo(int width, int height, int refreshRate, int bitDepth) {
        this.width = width;
        this.height = height;
        this.refreshRate = refreshRate;
        this.bitDepth = bitDepth;
    }

    public ResolutionInfo(int width, int height) {
        this(width, height, 0, 0);
    }

    /** Aspect ratio as a float (width / height). */
    public float getAspectRatio() {
        return height > 0 ? (float) width / height : 0f;
    }

    /** Formatted label like "1920 × 1080 @ 60Hz". */
    public String getLabel() {
        if (refreshRate > 0) {
            return width + " × " + height + " @ " + refreshRate + "Hz";
        }
        return width + " × " + height;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof ResolutionInfo)) return false;
        ResolutionInfo other = (ResolutionInfo) o;
        return width == other.width && height == other.height;
    }

    @Override
    public int hashCode() {
        return Objects.hash(width, height);
    }

    @Override
    public String toString() {
        return getLabel();
    }
}
