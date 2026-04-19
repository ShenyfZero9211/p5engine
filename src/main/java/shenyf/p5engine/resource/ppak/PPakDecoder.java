package shenyf.p5engine.resource.ppak;

import java.io.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;

public class PPakDecoder {
    private byte[] _data;
    private ArrayList<PPakEntry> _entries;
    private boolean _valid;
    private int _count;
    private String _ppakPath;

    public PPakDecoder(String ppakPath) {
        _entries = new ArrayList<>();
        _valid = false;
        _count = 0;
        _data = null;
        _ppakPath = ppakPath;
        load();
    }

    private void load() {
        File file = new File(_ppakPath);
        if (!file.exists()) {
            System.err.println("[PPakDecoder] File not found: " + _ppakPath);
            return;
        }

        FileInputStream fis = null;
        try {
            fis = new FileInputStream(file);
            int fileSize = (int) file.length();
            _data = new byte[fileSize];
            int read = 0;
            while (read < fileSize) {
                int r = fis.read(_data, read, fileSize - read);
                if (r == -1) break;
                read += r;
            }
            fis.close();
            fis = null;

            if (!parseHeader()) {
                System.err.println("[PPakDecoder] Invalid PPAK header");
                _data = null;
                return;
            }

            if (!loadIndex()) {
                System.err.println("[PPakDecoder] Failed to load index");
                _data = null;
                return;
            }

            _valid = true;
            System.out.println("[PPakDecoder] Loaded: " + _ppakPath + " (" + _count + " files)");

        } catch (Exception e) {
            System.err.println("[PPakDecoder] Load error: " + e.getMessage());
            _data = null;
        } finally {
            if (fis != null) {
                try { fis.close(); } catch (Exception ignored) {}
            }
        }
    }

    private boolean parseHeader() {
        if (_data == null || _data.length < PPakConstants.PPAK_HEADER_SIZE) return false;

        for (int i = 0; i < 4; i++) {
            if (_data[i] != (byte) PPakConstants.PPAK_MAGIC.charAt(i)) {
                System.err.println("[PPakDecoder] Bad magic at byte " + i + ": " + (char)_data[i]);
                return false;
            }
        }

        short version = ByteBuffer.wrap(_data, 4, 2).order(ByteOrder.LITTLE_ENDIAN).getShort();
        if (version != PPakConstants.PPAK_VERSION) {
            System.err.println("[PPakDecoder] Unsupported version: " + version);
            return false;
        }

        _count = ByteBuffer.wrap(_data, 6, 4).order(ByteOrder.LITTLE_ENDIAN).getInt();
        return true;
    }

    private boolean loadIndex() {
        if (_data == null || _count <= 0) return false;

        int pos = PPakConstants.PPAK_HEADER_SIZE;

        for (int i = 0; i < _count; i++) {
            if (pos + PPakConstants.PPAK_INDEX_ENTRY_SIZE > _data.length) {
                System.err.println("[PPakDecoder] Index overflow at entry " + i);
                return false;
            }

            int offset = ByteBuffer.wrap(_data, pos, 4).order(ByteOrder.LITTLE_ENDIAN).getInt();
            int size = ByteBuffer.wrap(_data, pos + 4, 4).order(ByteOrder.LITTLE_ENDIAN).getInt();
            int nameLen = ByteBuffer.wrap(_data, pos + 8, 2).order(ByteOrder.LITTLE_ENDIAN).getShort() & 0xFFFF;

            pos += PPakConstants.PPAK_INDEX_ENTRY_SIZE;

            if (pos + nameLen > _data.length) {
                System.err.println("[PPakDecoder] Name overflow at entry " + i);
                return false;
            }

            String name = new String(_data, pos, nameLen);
            pos += nameLen;

            _entries.add(new PPakEntry(offset, size, name));
        }

        return true;
    }

    public boolean isValid() {
        return _valid;
    }

    public int count() {
        return _count;
    }

    public String path() {
        return _ppakPath;
    }

    public String[] list() {
        if (_entries == null) return new String[0];
        String[] names = new String[_entries.size()];
        for (int i = 0; i < _entries.size(); i++) {
            names[i] = _entries.get(i).name;
        }
        return names;
    }

    public boolean contains(String path) {
        if (!isValid() || _entries == null) return false;
        String normPath = normalizePath(stripDataPrefix(path));
        for (PPakEntry entry : _entries) {
            if (entry.name.equals(normPath)) {
                return true;
            }
        }
        return false;
    }

    public byte[] read(String path) {
        if (!isValid() || _entries == null) return null;

        String normPath = normalizePath(stripDataPrefix(path));
        for (PPakEntry entry : _entries) {
            if (entry.name.equals(normPath)) {
                if (entry.offset < 0 || entry.offset + entry.size > _data.length) {
                    System.err.println("[PPakDecoder] Invalid offset/size for: " + path);
                    return null;
                }
                byte[] result = new byte[entry.size];
                System.arraycopy(_data, entry.offset, result, 0, entry.size);
                return result;
            }
        }
        return null;
    }

    public byte[] readBytes(String path) {
        return read(path);
    }

    public int getSize(String path) {
        if (!isValid() || _entries == null) return -1;
        String normPath = normalizePath(path);
        for (PPakEntry entry : _entries) {
            if (entry.name.equals(normPath)) {
                return entry.size;
            }
        }
        return -1;
    }

    public void close() {
        _data = null;
        _entries.clear();
        _valid = false;
    }

    private String normalizePath(String path) {
        if (path == null) return "";
        return path.replace("\\", "/");
    }

    private String stripDataPrefix(String path) {
        if (path == null) return "";
        String normalized = path.replace("\\", "/");
        if (normalized.startsWith("data/")) {
            return normalized.substring(5);
        }
        return normalized;
    }
}