package de.posy.pdftrenner;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.embed.swing.SwingFXUtils;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.scene.input.KeyCode;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import javafx.stage.FileChooser;
import javafx.stage.Modality;
import javafx.stage.Stage;
import javafx.util.Duration;
import javafx.animation.PauseTransition;
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

    private static final boolean DEBUG = Boolean.getBoolean("pdftrenner.debug");

    private PDDocument document;
    private PDFRenderer renderer;
    private int currentPage = 0;
    private int startPage = 0;
    private String pdfPath;
    private int numPages;

    private ImageView imageView;
    private Label statusLabel;
    private Stage primaryStage;

    private static void debug(String msg) {
        if (DEBUG) {
            System.err.println("[DEBUG] " + msg);
        }
    }

    @Override
    public void init() {
        debug("init() aufgerufen");
        // AWT vor JavaFX initialisieren (benoetigt fuer Taskbar/Dock-Icon)
        try {
            java.awt.Toolkit.getDefaultToolkit();
            debug("AWT initialisiert");
        } catch (Exception e) {
            debug("AWT init fehlgeschlagen: " + e.getMessage());
        }
    }

    @Override
    public void start(Stage primaryStage) {
        this.primaryStage = primaryStage;
        debug("start() aufgerufen");

        // Dock-Icon setzen (Taskbar API = zuverlaessig auf macOS/Windows)
        try {
            if (java.awt.Taskbar.isTaskbarSupported()) {
                java.awt.Image dockIcon = javax.imageio.ImageIO.read(
                    getClass().getResourceAsStream("/icon.png")
                );
                java.awt.Taskbar.getTaskbar().setIconImage(dockIcon);
                debug("Taskbar/Dock-Icon gesetzt");
            }
        } catch (Exception e) {
            debug("Taskbar-Icon fehlgeschlagen: " + e.getMessage());
        }

        // Fenster-Icon fuer Titelleiste
        try {
            Image icon = new Image(getClass().getResourceAsStream("/icon.png"));
            primaryStage.getIcons().add(icon);
            debug("Stage-Icon gesetzt");
        } catch (Exception e) {
            System.err.println("Stage-Icon konnte nicht geladen werden: " + e.getMessage());
        }

        Parameters params = getParameters();
        debug("Args: " + params.getRaw());

        if (!params.getRaw().isEmpty()) {
            pdfPath = params.getRaw().get(0);
            debug("PDF aus Args: " + pdfPath);
            initPdfAndShow();
        } else {
            debug("Keine Args, oeffne FileChooser");
            openFileChooserAndInit();
        }
    }

    private void openFileChooserAndInit() {
        debug("openFileChooserAndInit() start");

        // Stage mit sichtbarem Content anzeigen (NICHT alwaysOnTop!)
        primaryStage.setTitle("PDFTrenner");
        StackPane placeholder = new StackPane(
            new Label("Bitte warten... PDF-Datei wird angefordert.")
        );
        placeholder.setStyle("-fx-background-color: #f0f0f0; -fx-padding: 20;");
        primaryStage.setScene(new Scene(placeholder, 400, 100));
        primaryStage.show();
        primaryStage.toFront();
        primaryStage.requestFocus();
        debug("Stage angezeigt (ohne alwaysOnTop)");

        PauseTransition delay = new PauseTransition(Duration.millis(400));
        delay.setOnFinished(e -> {
            debug("Pause abgelaufen, oeffne FileChooser");

            FileChooser fileChooser = new FileChooser();
            fileChooser.setTitle("PDF-Datei auswaehlen");
            fileChooser.getExtensionFilters().add(
                new FileChooser.ExtensionFilter("PDF-Dateien", "*.pdf", "*.PDF")
            );

            debug("FileChooser.showOpenDialog() vor Aufruf");
            File selectedFile = null;
            try {
                selectedFile = fileChooser.showOpenDialog(primaryStage);
            } catch (Exception ex) {
                debug("Exception im FileChooser: " + ex);
                ex.printStackTrace();
                Alert alert = new Alert(Alert.AlertType.ERROR,
                    "Dateiauswahl-Dialog konnte nicht geöffnet werden:\n" + ex.getMessage());
                alert.showAndWait();
            }
            debug("FileChooser Ergebnis: " + selectedFile);

            if (selectedFile != null) {
                pdfPath = selectedFile.getAbsolutePath();
                debug("Ausgewaehlt: " + pdfPath);
                initPdfAndShow();
            } else {
                debug("Abbruch, beende Anwendung");
                delay.stop();
                primaryStage.close();
                Platform.exit();
                // Notfall-Exit falls Platform.exit() nicht ausreicht
                new Thread(() -> {
                    try {
                        Thread.sleep(1000);
                        debug("Notfall-System.exit(0)");
                    } catch (InterruptedException ignored) {}
                    System.exit(0);
                }).start();
            }
        });
        delay.play();
    }

    private void initPdfAndShow() {
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

        buildAndShowUI();
    }

    private void buildAndShowUI() {
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
        statusLabel.setMaxWidth(Double.MAX_VALUE);
        statusLabel.setAlignment(Pos.CENTER);

        Button firstPageBtn = new Button("First Page");
        firstPageBtn.setTooltip(new Tooltip("Setzt die aktuelle Seite als Startseite fuer die Extraktion (Taste: F)"));
        firstPageBtn.setOnAction(e -> setFirst());

        Button lastPageBtn = new Button("Last Page");
        lastPageBtn.setTooltip(new Tooltip("Setzt die aktuelle Seite als Endseite und oeffnet den Speicherdialog (Taste: L)"));
        lastPageBtn.setOnAction(e -> setLast());

        HBox buttonBox = new HBox(10, firstPageBtn, lastPageBtn);
        buttonBox.setAlignment(Pos.CENTER);
        buttonBox.setStyle("-fx-padding: 8; -fx-background-color: #f0f0f0;");

        VBox bottomBox = new VBox(statusLabel, buttonBox);
        root.setBottom(bottomBox);

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

        // Robuste Vordergrund-Aktivierung auf macOS
        PauseTransition pt = new PauseTransition(Duration.millis(200));
        pt.setOnFinished(e -> {
            primaryStage.toFront();
            primaryStage.requestFocus();
        });
        pt.play();

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
        dialog.setHeaderText(String.format("Dateiname fuer Seiten %d bis %d:", startPage + 1, endPage + 1));
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
