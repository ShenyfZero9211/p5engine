package shenyf.p5engine.util;

import processing.core.PApplet;
import processing.core.PImage;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.datatransfer.*;
import java.awt.image.BufferedImage;
import java.io.File;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Captures the current sketch frame to the system clipboard.
 * Optionally saves to a PNG file if configured.
 */
public class ScreenshotTool {

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd_HH-mm-ss-SSS");

    /**
     * Captures the current PApplet frame.
     *
     * @param applet      the sketch
     * @param saveToFile  whether to also save as PNG
     * @param outputDir   directory for PNG files (relative to sketch path)
     */
    public static void capture(PApplet applet, boolean saveToFile, String outputDir) {
        try {
            // 1. Grab the current frame
            PImage pimg = applet.g.get();
            BufferedImage bufferedImage = toBufferedImage(pimg);

            // 2. Copy to clipboard
            copyToClipboard(bufferedImage);

            // 3. Optionally save to file
            if (saveToFile) {
                saveToFile(applet, bufferedImage, outputDir);
            }

            Logger.info("Screenshot captured" + (saveToFile ? " and saved to " + outputDir : ""));
        } catch (Exception e) {
            Logger.error("Screenshot capture failed: " + e.getMessage());
        }
    }

    private static BufferedImage toBufferedImage(PImage pimg) {
        // PImage pixels are stored in ARGB format (32-bit int)
        int w = pimg.width;
        int h = pimg.height;
        BufferedImage bi = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        pimg.loadPixels();
        bi.setRGB(0, 0, w, h, pimg.pixels, 0, w);
        return bi;
    }

    private static void copyToClipboard(BufferedImage image) {
        Toolkit.getDefaultToolkit().getSystemClipboard().setContents(
            new TransferableImage(image), null
        );
    }

    private static void saveToFile(PApplet applet, BufferedImage image, String outputDir) {
        try {
            String dirPath = applet.sketchPath(outputDir);
            File dir = new File(dirPath);
            if (!dir.exists()) {
                dir.mkdirs();
            }
            String filename = "screenshot_" + LocalDateTime.now().format(FMT) + ".png";
            File file = new File(dir, filename);
            ImageIO.write(image, "png", file);
        } catch (Exception e) {
            Logger.error("Screenshot file save failed: " + e.getMessage());
        }
    }

    /**
     * AWT Transferable wrapper for BufferedImage.
     */
    private static class TransferableImage implements Transferable {
        private final Image image;

        TransferableImage(Image image) {
            this.image = image;
        }

        @Override
        public DataFlavor[] getTransferDataFlavors() {
            return new DataFlavor[]{DataFlavor.imageFlavor};
        }

        @Override
        public boolean isDataFlavorSupported(DataFlavor flavor) {
            return DataFlavor.imageFlavor.equals(flavor);
        }

        @Override
        public Object getTransferData(DataFlavor flavor) throws UnsupportedFlavorException {
            if (DataFlavor.imageFlavor.equals(flavor)) {
                return image;
            }
            throw new UnsupportedFlavorException(flavor);
        }
    }
}
