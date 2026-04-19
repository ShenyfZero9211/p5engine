package shenyf.p5engine.resource.ppak;

public class PPakEntry {
    public final int offset;
    public final int size;
    public final String name;

    public PPakEntry(int offset, int size, String name) {
        this.offset = offset;
        this.size = size;
        this.name = name;
    }

    @Override
    public String toString() {
        return "PPakEntry{name='" + name + "', offset=" + offset + ", size=" + size + "}";
    }
}