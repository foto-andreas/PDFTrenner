package de.posy.pdftrenner;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.embed.swing.SwingFXUtils;
import javafx.geometry.Insets;
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
import java.awt.SplashScreen;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import java.util.Properties;
import java.util.concurrent.TimeUnit;

public class PdfSplitterApp extends Application {

    private static final boolean DEBUG = Boolean.getBoolean("pdftrenner.debug");
    private static final boolean IS_MAC = System.getProperty("os.name", "").toLowerCase().contains("mac");

    private PDDocument document;
    private PDFRenderer renderer;
    private int currentPage = 0;
    private int startPage = 0;
    private String pdfPath;
    private int numPages;

    private ImageView imageView;
    private Label statusLabel;
    private Label splashLabel;
    private Stage primaryStage;
    private Process ocrProcess;

    private static void debug(String msg) {
        if (DEBUG) {
            System.err.println("[DEBUG] " + msg);
        }
    }

    private void bringToFront(Stage stage) {
        stage.toFront();
        stage.requestFocus();
        if (IS_MAC) {
            stage.setAlwaysOnTop(true);
            PauseTransition revert = new PauseTransition(Duration.millis(150));
            revert.setOnFinished(e -> stage.setAlwaysOnTop(false));
            revert.play();
        }
    }

    private void dismissNativeSplash() {
        try {
            SplashScreen splash = SplashScreen.getSplashScreen();
            if (splash != null) {
                splash.close();
                debug("Native splash screen closed");
            }
        } catch (Exception e) {
            debug("No native splash to close: " + e.getMessage());
        }
    }

    private void showError(String message) {
        if (splashLabel != null) {
            splashLabel.setStyle("-fx-font-size: 12px; -fx-text-fill: red;");
            splashLabel.setText(message);
        }
        Alert alert = new Alert(Alert.AlertType.ERROR, message);
        alert.initOwner(primaryStage);
        alert.showAndWait();
    }

    @Override
    public void start(Stage primaryStage) {
        this.primaryStage = primaryStage;
        debug("start() aufgerufen");

        try {
            Image icon = new Image(getClass().getResourceAsStream("/icon.png"));
            primaryStage.getIcons().add(icon);
        } catch (Exception e) {
            System.err.println("Stage-Icon: " + e.getMessage());
        }

        primaryStage.setTitle("PDFTrenner");
        showSplashContent();
        primaryStage.show();
        bringToFront(primaryStage);
        dismissNativeSplash();

        Parameters params = getParameters();
        if (!params.getRaw().isEmpty()) {
            File f = new File(params.getRaw().get(0));
            pdfPath = f.getAbsolutePath();
            updateSplash("Lade: " + f.getName());
            Platform.runLater(this::initPdfAndShow);
        } else {
            updateSplash("Oeffne Dateiauswahl...");
            Platform.runLater(this::openFileChooserAndInit);
        }
    }

    private void showSplashContent() {
        ImageView splashIcon = new ImageView();
        try {
            Image iconImg = new Image(getClass().getResourceAsStream("/icon.png"), 48, 48, true, true);
            splashIcon.setImage(iconImg);
        } catch (Exception ignored) {}

        Label titleLabel = new Label("PDFTrenner");
        titleLabel.setStyle("-fx-font-size: 18px; -fx-font-weight: bold;");

        HBox titleRow = new HBox(10, splashIcon, titleLabel);
        titleRow.setAlignment(Pos.CENTER_LEFT);

        splashLabel = new Label("Anwendung wird gestartet...");
        splashLabel.setStyle("-fx-font-size: 12px; -fx-text-fill: #555555;");

        VBox splashRoot = new VBox(12, titleRow, splashLabel);
        splashRoot.setStyle("-fx-background-color: #f0f0f0; -fx-padding: 20;");
        splashRoot.setAlignment(Pos.CENTER_LEFT);

        primaryStage.setScene(new Scene(splashRoot, 400, 120));
        primaryStage.setResizable(false);
    }

    private void updateSplash(String msg) {
        debug(msg);
        if (splashLabel != null) {
            Platform.runLater(() -> splashLabel.setText(msg));
        }
    }

    private void openFileChooserAndInit() {
        FileChooser fileChooser = new FileChooser();
        fileChooser.setTitle("PDF-Datei auswaehlen");
        fileChooser.getExtensionFilters().add(
                new FileChooser.ExtensionFilter("PDF-Dateien", "*.pdf", "*.PDF")
        );
        fileChooser.setInitialDirectory(new File(System.getProperty("user.home")));

        debug("FileChooser.showOpenDialog()");
        File selectedFile = null;
        try {
            selectedFile = fileChooser.showOpenDialog(primaryStage);
        } catch (Exception ex) {
            debug("Exception im FileChooser: " + ex);
            ex.printStackTrace();
            showError("Dateiauswahl-Dialog konnte nicht ge\u00f6ffnet werden:\n" + ex.getMessage());
        }
        debug("FileChooser Ergebnis: " + selectedFile);

        if (selectedFile != null) {
            pdfPath = selectedFile.getAbsolutePath();
            updateSplash("Lade: " + new File(pdfPath).getName());
            Platform.runLater(this::initPdfAndShow);
        } else {
            debug("Abbruch, beende Anwendung");
            primaryStage.close();
            Platform.exit();
        }
    }

    private void initPdfAndShow() {
        File pdfFile = new File(pdfPath);
        if (!pdfFile.exists()) {
            showError("Datei nicht gefunden:\n" + pdfPath);
            primaryStage.close();
            Platform.exit();
            return;
        }
        try {
            document = PDDocument.load(pdfFile);
            numPages = document.getNumberOfPages();
            updateSplash("Bereite Renderer vor (" + numPages + " Seiten)...");
            renderer = new PDFRenderer(document);
        } catch (IOException e) {
            e.printStackTrace();
            showError("PDF konnte nicht geladen werden:\n" + e.getMessage());
            primaryStage.close();
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
        splashLabel = null;

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
        firstPageBtn.setTooltip(new Tooltip("Startseite setzen (Taste: F)"));
        firstPageBtn.setOnAction(e -> setFirst());

        Button lastPageBtn = new Button("Last Page");
        lastPageBtn.setTooltip(new Tooltip("Endseite setzen + Speichern (Taste: L)"));
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

        primaryStage.setTitle("PDFTrenner - " + new File(pdfPath).getName());
        primaryStage.setScene(scene);
        primaryStage.setResizable(true);

        primaryStage.show();
        bringToFront(primaryStage);
        showPage();
    }

    private String recognizeTitle(int pageIndex) {
        if (renderer == null || document == null) return "";
        Path tempImage = null;
        Process process = null;
        try {
            BufferedImage full;
            synchronized (this) {
                full = renderer.renderImageWithDPI(pageIndex, 300);
            }
            if (full == null) {
                System.err.println("OCR: renderImageWithDPI returned null");
                return "";
            }
            int cropHeight = (int) (full.getHeight() * 0.10);
            if (cropHeight < 10) cropHeight = full.getHeight();
            BufferedImage cropped = full.getSubimage(0, 0, full.getWidth(), cropHeight);

            tempImage = Files.createTempFile("pdftrenner_ocr_", ".png");
            ImageIO.write(cropped, "png", tempImage.toFile());
            debug("OCR: temp image written to " + tempImage);

            ProcessBuilder pb = new ProcessBuilder(
                    "tesseract", tempImage.toString(), "stdout",
                    "-l", "deu+eng",
                    "--psm", "6"
            );
            pb.redirectErrorStream(true);
            process = pb.start();
            ocrProcess = process;

            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append(" ");
                }
            }

            boolean finished = process.waitFor(15, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                System.err.println("OCR-Timeout");
                return "";
            }

            int exitCode = process.exitValue();
            String text = output.toString().replaceAll("\\s+", " ").trim();
            debug("OCR: exit=" + exitCode + " result=[" + text + "]");
            return text;
        } catch (IOException | InterruptedException e) {
            System.err.println("OCR-Fehler: " + e.getMessage());
            e.printStackTrace();
            return "";
        } finally {
            ocrProcess = null;
            if (tempImage != null) {
                try {
                    Files.deleteIfExists(tempImage);
                } catch (IOException ignored) {
                }
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

        statusLabel.setText("Erkenne Titel (OCR)...");
        Thread ocrThread = new Thread(() -> {
            String detectedTitle = recognizeTitle(startPage);
            if (!detectedTitle.isEmpty()) {
                System.out.println("Erkannter Titel: " + detectedTitle);
            }
            Platform.runLater(() -> {
                statusLabel.setText(null);
                showTitleDialog(detectedTitle, startPage, endPage);
            });
        }, "OCR-Thread");
        ocrThread.setDaemon(true);
        ocrThread.start();
    }

    private void showTitleDialog(String detectedTitle, int start, int end) {
        debug("showTitleDialog: detectedTitle=[" + detectedTitle + "]");
        String defaultValue = (detectedTitle != null && !detectedTitle.isEmpty()) ? detectedTitle : "";
        TextInputDialog dialog = new TextInputDialog(defaultValue);
        dialog.initOwner(primaryStage);
        dialog.initModality(Modality.WINDOW_MODAL);
        dialog.setTitle("Extraktion");
        dialog.setHeaderText(String.format("Dateiname f\u00fcr Seiten %d bis %d:", start + 1, end + 1));
        dialog.setContentText("Songtitel:");

        bringToFront(primaryStage);
        Optional<String> result = dialog.showAndWait();
        primaryStage.requestFocus();
        result.ifPresent(songTitle -> {
            saveSplit(songTitle, start, end);
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
        if (ocrProcess != null) {
            ocrProcess.destroyForcibly();
        }
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

}