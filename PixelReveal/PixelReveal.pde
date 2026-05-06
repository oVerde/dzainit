/**
 * HARD MASK — VISCOUS METABALLS
 * Export directo para MP4 via VideoExport
 *
 * INSTALAR (uma vez):
 * Sketch → Import Library → Add Library → pesquisa "Video Export" → Install
 * Também precisas de FFmpeg instalado no sistema.
 */

import processing.video.*;
import controlP5.*;
import com.hamoid.*;   // Video Export

ControlP5 cp5;
VideoExport videoExport;

PImage  bgImage, fgImage;
Movie   bgVideo, fgVideo;
boolean bgIsVideo = false;
boolean fgIsVideo = false;

PGraphics maskLayer;
PGraphics fgBuffer;

// BASE DA FORMA
float originX;
float originY;
float sizeW    = 200;
float sizeH    = 200;

// DRIFT DE POSIÇÃO
float driftPos   = 80;
float driftSpeed = 0.4;

// DRIFT DE TAMANHO
float driftSize  = 0.12;

// METABALLS
int   numBlobs       = 4;
float blobBaseSize   = 1.0;
float mergeSharpness = 2.2;
float threshold      = 1.0;

// MOVIMENTO INTERNO
float wanderSpeed = 0.18;
float pulseSpeed  = 0.25;
float pulseAmt    = 0.4;

// DOMAIN WARP
float warpScale = 0.006;
float warpAmt   = 90.0;
float warpSpeed = 0.4;

float pixelSize = 10;

// EXPORT
boolean exporting      = false;
int     exportDuration = 6;   // segundos
int     fps            = 30;
int     exportFrameCount;
int     currentFrame;

float time = 0;

float[] blobX = new float[6];
float[] blobY = new float[6];
float[] blobR = new float[6];

// UI TOGGLE
boolean showUI = true;

float curOriginX, curOriginY, curSizeW, curSizeH;

void settings() {
  size(800, 800, P2D);
}

void setup() {
  surface.setTitle("Viscous Mask");
  frameRate(fps);

  originX = width  * 0.5;
  originY = height * 0.5;

  maskLayer = createGraphics(width, height, P2D);
  fgBuffer  = createGraphics(width, height, P2D);

  // aponta para o ficheiro de saída com path absoluto
  String outputPath = sketchPath("output.mp4");
  videoExport = new VideoExport(this, outputPath);
  videoExport.setFrameRate(fps);
  videoExport.setQuality(85, 0);  // 0 = sem áudio

  setupUI();
}

void draw() {
  time += 1.0 / fps;

  updateOriginAndSize();
  updateBlobs();
  updateMedia();
  renderMask();
  renderScene();

  // grava frame se a exportar
  if (exporting) {
    videoExport.saveFrame();
    currentFrame++;

    // barra de progresso no título
    int pct = (int)(100.0 * currentFrame / exportFrameCount);
    surface.setTitle("A exportar... " + pct + "%");

    if (currentFrame >= exportFrameCount) {
      videoExport.endMovie();
      exporting = false;
      surface.setTitle("Export concluído — output.mp4");
      println("Export concluído.");
    }
  }
}

// ──────────────────────────────────────────────
// DRIFT
// ──────────────────────────────────────────────
void updateOriginAndSize() {
  float px = (noise(0.0, time * driftSpeed * 0.3) * 2 - 1) * driftPos;
  float py = (noise(11.3, time * driftSpeed * 0.3) * 2 - 1) * driftPos;
  curOriginX = originX + px;
  curOriginY = originY + py;

  float sw = (noise(22.7, time * driftSpeed * 0.2) * 2 - 1) * driftSize;
  float sh = (noise(33.1, time * driftSpeed * 0.2) * 2 - 1) * driftSize;
  curSizeW = max(10, sizeW * (1.0 + sw));
  curSizeH = max(10, sizeH * (1.0 + sh));
}

// ──────────────────────────────────────────────
// BLOBS
// ──────────────────────────────────────────────
void updateBlobs() {
  int n = constrain(numBlobs, 2, 6);
  float wanderR = min(curSizeW, curSizeH) * 0.35;

  for (int i = 0; i < n; i++) {
    float seed = i * 47.3;
    float ox = (noise(seed, time * wanderSpeed * 0.25) * 2 - 1) * wanderR;
    float oy = (noise(seed + 13.7, time * wanderSpeed * 0.25) * 2 - 1) * wanderR;
    blobX[i] = curOriginX + ox;
    blobY[i] = curOriginY + oy;

    float pulse = noise(seed + 99, time * pulseSpeed * 0.3);
    float avgR  = (curSizeW + curSizeH) * 0.5 * blobBaseSize;
    blobR[i] = constrain(avgR * (1.0 + map(pulse, 0, 1, -pulseAmt, pulseAmt)), 20, 800);
  }
}

// ──────────────────────────────────────────────
// MÁSCARA
// ──────────────────────────────────────────────
void renderMask() {
  maskLayer.beginDraw();
  maskLayer.background(255);

  int n    = constrain(numBlobs, 2, 6);
  float ps = max(pixelSize, 2);
  float h2 = ps * 0.5;
  float scaleY = (curSizeH > 0) ? curSizeW / curSizeH : 1.0;

  for (int y = 0; y < height; y += (int)ps) {
    for (int x = 0; x < width; x += (int)ps) {
      float cx = x + h2;
      float cy = y + h2;

      float w1x = noise(cx * warpScale, cy * warpScale, time * warpSpeed) * 2 - 1;
      float w1y = noise(cx * warpScale + 5.2, cy * warpScale + 5.2, time * warpSpeed) * 2 - 1;
      float wx  = cx + w1x * warpAmt;
      float wy  = cy + w1y * warpAmt;
      float w2x = noise(wx * warpScale * 1.8, wy * warpScale * 1.8, time * warpSpeed * 1.3) * 2 - 1;
      float w2y = noise(wx * warpScale * 1.8 + 9.1, wy * warpScale * 1.8 + 9.1, time * warpSpeed * 1.3) * 2 - 1;
      float sx  = cx + w1x * warpAmt + w2x * warpAmt * 0.4;
      float sy  = cy + w1y * warpAmt + w2y * warpAmt * 0.4;

      float relX = sx - curOriginX;
      float relY = (sy - curOriginY) * scaleY;

      float field = 0;
      for (int i = 0; i < n; i++) {
        float bRelX = blobX[i] - curOriginX;
        float bRelY = (blobY[i] - curOriginY) * scaleY;
        float dx = relX - bRelX;
        float dy = relY - bRelY;
        float d2 = max(dx * dx + dy * dy, 1);
        field += pow((blobR[i] * blobR[i]) / d2, mergeSharpness * 0.5);
      }

      maskLayer.fill(field > threshold ? 0 : 255);
      maskLayer.noStroke();
      maskLayer.rect(x, y, ps, ps);
    }
  }
  maskLayer.endDraw();
}

// ──────────────────────────────────────────────
// RENDER
// ──────────────────────────────────────────────
void renderScene() {
  background(0);
  if      (bgIsVideo && bgVideo != null) image(bgVideo, 0, 0, width, height);
  else if (bgImage != null)              image(bgImage, 0, 0, width, height);
  else                                   background(20, 20, 20);

  PImage fgFrame = fgIsVideo ? fgVideo : fgImage;
  if (fgFrame != null) {
    fgBuffer.beginDraw();
    fgBuffer.clear();
    fgBuffer.image(fgFrame, 0, 0, width, height);
    fgBuffer.endDraw();
    fgBuffer.mask(maskLayer);
    image(fgBuffer, 0, 0);
  }
}

void updateMedia() {
  if (bgIsVideo && bgVideo != null && bgVideo.available()) bgVideo.read();
  if (fgIsVideo && fgVideo != null && fgVideo.available()) fgVideo.read();
}

void bgSelected(File f) {
  if (f == null) return;
  String p = f.getAbsolutePath();
  if (p.endsWith(".mp4") || p.endsWith(".mov")) {
    bgVideo = new Movie(this, p);
    bgVideo.loop();
    bgIsVideo = true;
  } else {
    bgImage = loadImage(p);
    bgIsVideo = false;
  }
}
void fgSelected(File f) {
  if (f == null) return;
  String p = f.getAbsolutePath();
  if (p.endsWith(".mp4") || p.endsWith(".mov")) {
    fgVideo = new Movie(this, p);
    fgVideo.loop();
    fgIsVideo = true;
  } else {
    fgImage = loadImage(p);
    fgIsVideo = false;
  }
}

// ──────────────────────────────────────────────
// UI
// ──────────────────────────────────────────────
void setupUI() {
  cp5 = new ControlP5(this);
  int xp = 10, y = 10, w = 155;

  cp5.addButton("loadBG").setPosition(xp, y).setSize(w, 22).setLabel("Load BG");
  y+=30;
  cp5.addButton("loadFG").setPosition(xp, y).setSize(w, 22).setLabel("Load FG");
  y+=40;

  cp5.addSlider("originX").setPosition(xp, y).setSize(w, 18).setRange(0, 800).setValue(width*0.5).setLabel("origin X");
  y+=28;
  cp5.addSlider("originY").setPosition(xp, y).setSize(w, 18).setRange(0, 1200).setValue(height*0.5).setLabel("origin Y");
  y+=28;
  cp5.addSlider("driftPos").setPosition(xp, y).setSize(w, 18).setRange(0, 300).setValue(80).setLabel("pos drift (px)");
  y+=28;
  cp5.addSlider("driftSpeed").setPosition(xp, y).setSize(w, 18).setRange(0.05, 2.0).setValue(0.4).setLabel("drift speed");
  y+=40;

  cp5.addSlider("sizeW").setPosition(xp, y).setSize(w, 18).setRange(20, 600).setValue(200).setLabel("size W");
  y+=28;
  cp5.addSlider("sizeH").setPosition(xp, y).setSize(w, 18).setRange(20, 600).setValue(200).setLabel("size H");
  y+=28;
  cp5.addSlider("driftSize").setPosition(xp, y).setSize(w, 18).setRange(0, 0.5).setValue(0.12).setLabel("size drift (%)");
  y+=40;

  cp5.addSlider("numBlobs").setPosition(xp, y).setSize(w, 18).setRange(2, 6).setValue(4).setLabel("blobs");
  y+=28;
  cp5.addSlider("mergeSharpness").setPosition(xp, y).setSize(w, 18).setRange(1, 4).setValue(2.2).setLabel("merge sharpness");
  y+=40;

  cp5.addSlider("wanderSpeed").setPosition(xp, y).setSize(w, 18).setRange(0, 1).setValue(0.18).setLabel("wander speed");
  y+=28;
  cp5.addSlider("pulseSpeed").setPosition(xp, y).setSize(w, 18).setRange(0, 1).setValue(0.25).setLabel("pulse speed");
  y+=28;
  cp5.addSlider("pulseAmt").setPosition(xp, y).setSize(w, 18).setRange(0, 0.8).setValue(0.4).setLabel("pulse amount");
  y+=40;

  cp5.addSlider("warpAmt").setPosition(xp, y).setSize(w, 18).setRange(0, 200).setValue(90).setLabel("warp amount");
  y+=28;
  cp5.addSlider("warpScale").setPosition(xp, y).setSize(w, 18).setRange(0.001, 0.02).setValue(0.006).setLabel("warp scale");
  y+=28;
  cp5.addSlider("warpSpeed").setPosition(xp, y).setSize(w, 18).setRange(0, 1.5).setValue(0.4).setLabel("warp speed");
  y+=40;

  cp5.addSlider("pixelSize").setPosition(xp, y).setSize(w, 18).setRange(4, 30).setValue(10).setLabel("pixel size");
  y+=28;
  cp5.addSlider("exportDuration").setPosition(xp, y).setSize(w, 18).setRange(2, 30).setValue(6).setLabel("duração (seg)");
  y+=40;

  cp5.addButton("doExport").setPosition(xp, y).setSize(w, 25).setLabel("EXPORT MP4");
  y+=35;
  cp5.addButton("square").setPosition(xp, y).setSize(72, 22).setLabel("1:1");
  cp5.addButton("vertical").setPosition(xp+83, y).setSize(72, 22).setLabel("2:3");
}

void loadBG() {
  selectInput("BG", "bgSelected");
}
void loadFG() {
  selectInput("FG", "fgSelected");
}

void doExport() {
  if (exporting) return;
  // recria o VideoExport para evitar o bug do Processing 4
  String outputPath = sketchPath("output_" + millis() + ".mp4");
  videoExport = new VideoExport(this, outputPath);
  videoExport.setFrameRate(fps);
  videoExport.setQuality(85, 0);
  videoExport.startMovie();
  exportFrameCount = exportDuration * fps;
  currentFrame = 0;
  time = 0;
  exporting = true;
  println("A exportar para: " + outputPath);
}

void square() {
  surface.setSize(800, 800);
  resizeBuffers();
}
void vertical() {
  surface.setSize(800, 1200);
  resizeBuffers();
}
void resizeBuffers() {
  maskLayer = createGraphics(width, height, P2D);
  fgBuffer  = createGraphics(width, height, P2D);
}

// ──────────────────────────────────────────────
// INPUT
// ──────────────────────────────────────────────
void keyPressed() {
  if (key == 'h' || key == 'H') {
    showUI = !showUI;
    cp5.setVisible(showUI);
  }
}