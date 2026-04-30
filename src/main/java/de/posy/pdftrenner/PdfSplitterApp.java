package de.posy.pdftrenner;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.embed.swing.SwingFXUtils;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.image.ImageView;
import javafx.scene.input.KeyCode;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.StackPane;
import javafx.stage.Modality;
import javafx.stage.Stage;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.PDFRenderer;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import java.util.Properties;
import java.util.concurrent.TimeUnit;

public class PdfSplitterApp extends Application {

    private PDDocument document;
    private PDFRenderer renderer;
    private int currentPage = 0;
    private int startPage = 0;
    private String pdfPath;
    private int numPages;

    private ImageView imageView;
    private Label statusLabel;
    private Stage primaryStage;

    @Override
    public void start(Stage primaryStage) {
        this.primaryStage = primaryStage;

        Parameters params = getParameters();
        if (!params.getRaw().isEmpty()) {
            pdfPath = params.getRaw().get(0);
        } else {
            File dir = new File(".");
            File[] pdfs = dir.listFiles((d, name) -> name.toLowerCase().endsWith(".pdf"));
            if (pdfs != null && pdfs.length > 0) {
                pdfPath = pdfs[0].getPath();
            }
        }

        if (pdfPath == null) {
            System.err.println("Keine PDF-Datei angegeben.");
            Platform.exit();
            return;
        }

        try {
            document = PDDocument.load(new File(pdfPath));
            numPages = document.getNumberOfPages();
            renderer = new PDFRenderer(document);
        } catch (IOException e) {
            e.printStackTrace();
            Platform.exit();
            return;
        }

        int savedPage = loadState();
        if (savedPage >= 0 && savedPage < numPages) {
            currentPage = savedPage;
            startPage = savedPage;
            System.out.println("Zustand wiederhergestellt: Seite " + (startPage + 1));
        }

        BorderPane root = new BorderPane();
        imageView = new ImageView();
        imageView.setPreserveRatio(true);
        imageView.setFocusTraversable(false);

        StackPane centerPane = new StackPane(imageView);
        centerPane.setStyle("-fx-background-color: #2b2b2b;");
        centerPane.widthProperty().addListener((obs, oldVal, newVal) ->
            imageView.setFitWidth(newVal.doubleValue() - 20));
        centerPane.heightProperty().addListener((obs, oldVal, newVal) ->
            imageView.setFitHeight(newVal.doubleValue() - 20));
        root.setCenter(centerPane);

        statusLabel = new Label();
        statusLabel.setStyle("-fx-padding: 8; -fx-background-color: #f0f0f0;");
        root.setBottom(statusLabel);

        Scene scene = new Scene(root, 900, 1000);
        scene.addEventFilter(javafx.scene.input.KeyEvent.KEY_PRESSED, event -> {
            if (event.getCode() == KeyCode.RIGHT) {
                nextPage();
                event.consume();
            } else if (event.getCode() == KeyCode.LEFT) {
                prevPage();
                event.consume();
            } else if (event.getCode() == KeyCode.F) {
                setFirst();
                event.consume();
            } else if (event.getCode() == KeyCode.L) {
                setLast();
                event.consume();
            }
        });

        primaryStage.setTitle("Java PDF Splitter - " + new File(pdfPath).getName());
        primaryStage.setScene(scene);
        primaryStage.show();
        primaryStage.toFront();
        Platform.runLater(() -> primaryStage.requestFocus());

        showPage();
    }

    private String recognizeTitle(int pageIndex) {
        if (renderer == null) return "";
        Path tempImage = null;
        try {
            BufferedImage full = renderer.renderImageWithDPI(pageIndex, 300);
            int cropHeight = (int) (full.getHeight() * 0.10);
            if (cropHeight < 10) cropHeight = full.getHeight();
            BufferedImage cropped = full.getSubimage(0, 0, full.getWidth(), cropHeight);

            tempImage = Files.createTempFile("pdftrenner_ocr_", ".png");
            ImageIO.write(cropped, "png", tempImage.toFile());

            ProcessBuilder pb = new ProcessBuilder(
                    "tesseract", tempImage.toString(), "stdout",
                    "-l", "deu+eng",
                    "--psm", "6"
            );
            pb.redirectErrorStream(true);
            Process process = pb.start();

            boolean finished = process.waitFor(15, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                System.err.println("OCR-Timeout");
                return "";
            }

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                StringBuilder output = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append(" ");
                }
                String text = output.toString().replaceAll("\\s+", " ").trim();
                System.out.println("OCR-Ergebnis: [" + text + "]");
                return text;
            }
        } catch (IOException | InterruptedException e) {
            System.err.println("OCR-Fehler: " + e.getMessage());
            return "";
        } finally {
            if (tempImage != null) {
                try {
                    Files.deleteIfExists(tempImage);
                } catch (IOException ignored) {}
            }
        }
    }

    private void showPage() {
        if (currentPage < 0 || currentPage >= numPages) return;

        try {
            BufferedImage bim = renderer.renderImageWithDPI(currentPage, 150);
            imageView.setImage(SwingFXUtils.toFXImage(bim, null));
            updateStatus();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void updateStatus() {
        String status = String.format("Seite: %d / %d | Aktueller Start: Seite %d", currentPage + 1, numPages, startPage + 1);
        statusLabel.setText(status);
    }

    private void nextPage() {
        if (currentPage < numPages - 1) {
            currentPage++;
            showPage();
        }
    }

    private void prevPage() {
        if (currentPage > 0) {
            currentPage--;
            showPage();
        }
    }

    private void setFirst() {
        startPage = currentPage;
        updateStatus();
        System.out.println("Startseite gesetzt auf: " + (startPage + 1));
    }

    private void setLast() {
        int endPage = currentPage;
        if (endPage < startPage) {
            Alert alert = new Alert(Alert.AlertType.ERROR, "Endseite kann nicht vor der Startseite liegen!");
            alert.initOwner(primaryStage);
            alert.initModality(Modality.WINDOW_MODAL);
            alert.showAndWait();
            primaryStage.requestFocus();
            return;
        }

        String detectedTitle = recognizeTitle(startPage);
        if (!detectedTitle.isEmpty()) {
            System.out.println("Erkannter Titel: " + detectedTitle);
        }

        TextInputDialog dialog = new TextInputDialog(detectedTitle);
        dialog.initOwner(primaryStage);
        dialog.initModality(Modality.WINDOW_MODAL);
        dialog.setTitle("Extraktion");
        dialog.setHeaderText(String.format("Dateiname für Seiten %d bis %d:", startPage + 1, endPage + 1));
        dialog.setContentText("Songtitel:");

        Optional<String> result = dialog.showAndWait();
        primaryStage.requestFocus();
        result.ifPresent(songTitle -> {
            saveSplit(songTitle, startPage, endPage);
        });
    }

    private void saveSplit(String songTitle, int start, int end) {
        String safeTitle = songTitle.replaceAll("[^a-zA-Z0-9 _-]", "").trim();
        if (safeTitle.isEmpty()) {
            safeTitle = "Song_Seite_" + (start + 1);
        }

        File outputDir = new File(new File(pdfPath).getParent(), "Manual_Splits");
        if (!outputDir.exists()) {
            outputDir.mkdirs();
        }

        File outFile = new File(outputDir, safeTitle + ".pdf");

        try (PDDocument newDoc = new PDDocument()) {
            for (int i = start; i <= end; i++) {
                newDoc.importPage(document.getPage(i));
            }
            newDoc.save(outFile);
            System.out.println("Erfolgreich extrahiert: " + outFile.getAbsolutePath());

            saveState();
            if (end < numPages - 1) {
                currentPage = end + 1;
                startPage = currentPage;
                showPage();
            } else {
                Alert alert = new Alert(Alert.AlertType.INFORMATION, "Letzte Seite erreicht.");
                alert.initOwner(primaryStage);
                alert.initModality(Modality.WINDOW_MODAL);
                alert.showAndWait();
                primaryStage.requestFocus();
            }
        } catch (IOException e) {
            Alert alert = new Alert(Alert.AlertType.ERROR, "Fehler beim Speichern: " + e.getMessage());
            alert.initOwner(primaryStage);
            alert.initModality(Modality.WINDOW_MODAL);
            alert.showAndWait();
            primaryStage.requestFocus();
        }
    }

    @Override
    public void stop() throws Exception {
        saveState();
        if (document != null) {
            document.close();
        }
        super.stop();
    }

    private File getStateFile() {
        File pdf = new File(pdfPath);
        return new File(pdf.getParent(), pdf.getName() + ".pdftrenner.state");
    }

    private int loadState() {
        File stateFile = getStateFile();
        if (!stateFile.exists()) return -1;
        try (FileInputStream fis = new FileInputStream(stateFile)) {
            Properties props = new Properties();
            props.load(fis);
            String value = props.getProperty("startPage", "-1");
            return Integer.parseInt(value);
        } catch (IOException | NumberFormatException e) {
            return -1;
        }
    }

    private void saveState() {
        if (pdfPath == null) return;
        File stateFile = getStateFile();
        try (FileOutputStream fos = new FileOutputStream(stateFile)) {
            Properties props = new Properties();
            props.setProperty("startPage", String.valueOf(startPage));
            props.store(fos, "PDFTrenner State");
        } catch (IOException e) {
            System.err.println("Zustand konnte nicht gespeichert werden: " + e.getMessage());
        }
    }

    public static void main(String[] args) {
        launch(args);
    }
}
