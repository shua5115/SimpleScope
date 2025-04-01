import processing.serial.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;

boolean[] keys = new boolean[256];

final int BAUD = 115200;
final int SAMPLE_RATE = 2000;
final float MIN_VOLTS = 0.0;
final float MAX_VOLTS = 5.0;
final float MAX_SAMPLE_VALUE = 1023.0;
Serial device;
int SAMPLES_PER_PERIOD = SAMPLE_RATE;
boolean update_scope = true;
float cursor_v_1;
int cursor_index_1;
float cursor_v_2;
int cursor_index_2;
boolean show_text = true;
boolean show_cursors = true;
boolean show_help = true;
boolean show_fps = false;

int[] samples;
ArrayList<Integer> samples_to_add = new ArrayList<>();
int samples_cursor;

StringList helptext = new StringList();

int pack_sample(char a, char b) {
  int val = (((int)a & 0xFFFF) << 16) | ((int)b & 0xFFFF);
  return val;
}

char unpack_sample_a(int val) {
  return (char) ((val >> 16) & 0xFFFF);
}

char unpack_sample_b(int val) {
  return (char) (val & 0xFFFF);
}

void setup() {
  size(800, 500, P2D);
  // enable VSYNC to avoid screen tearing
  if (g.isGL()) {
    frameRate(500);
    PJOGL pgl = (PJOGL)beginPGL();
    pgl.gl.setSwapInterval(1);
    endPGL();
  } else {
    frameRate(60);
  }
  surface.setResizable(true);
  hint(ENABLE_KEY_REPEAT);

  helptext.append("Disconnect: Backspace");
  helptext.append("Pause: Space");
  helptext.append("Step: Right Arrow");
  helptext.append("Change Period: Up/Down Arrows");
  helptext.append("Move Cursor 1: Left Click/WASD");
  helptext.append("Move Cursor 2: Right Click/IJKL");
  helptext.append("Input x10: Shift");
  helptext.append("Input x100: Ctrl");
  helptext.append("Export Samples: E");
  helptext.append("Hide/Show Text: T");
  helptext.append("Hide/Show Cursors: C");
  helptext.append("Hide/Show Help: H");
}

void draw() {
  background(0);

  if (device == null) {
    push();
    fill(255);
    textAlign(LEFT, TOP);
    textSize(24);
    text("Press number key to select device:", 0, 0);
    int i = 1;
    for (String name : Serial.list()) {
      translate(0, 24);
      text(i+": "+name, 0, 0);
      i++;
    }
    pop();
  } else {
    SAMPLES_PER_PERIOD = constrain(SAMPLES_PER_PERIOD, 2, 1000000000);
    
    if (update_scope) {
      updateScope();
    } else if (samples_to_add.size() > SAMPLES_PER_PERIOD) {
      // only keep most recent elements, up to 1 period of data
      int leftshift = samples_to_add.size() - SAMPLES_PER_PERIOD;
      synchronized(samples_to_add) {
        for (int i = 0; i < SAMPLES_PER_PERIOD; i++) {
          int src = i + leftshift;
          samples_to_add.set(i, samples_to_add.get(src));
        }
        for (int i = samples_to_add.size()-1; i >= SAMPLES_PER_PERIOD; i--) {
          samples_to_add.remove(i);
        }
      }
    }

    drawScope();

    if (mousePressed) {
      int index = round(map(mouseX, 0, width, 0, samples.length-1));
      int Kv = round(map(mouseY, 0.0, height, MAX_VOLTS, MIN_VOLTS)*1000);
      float v = Kv*0.001;
      if (mouseButton == LEFT) {
        cursor_v_1 = v;
        cursor_index_1 = index;
      } else if (mouseButton == RIGHT) {
        cursor_v_2 = v;
        cursor_index_2 = index;
      }
    }
    cursor_index_1 = Math.floorMod(cursor_index_1, samples.length);
    cursor_index_2 = Math.floorMod(cursor_index_2, samples.length);

    if (show_cursors) {
      float cursor_x, cursor_y;
      push();
      stroke(255, 255, 0, 128);
      cursor_x = map(cursor_index_1, 0, samples.length-1, 0, width);
      cursor_y = map(cursor_v_1, MIN_VOLTS, MAX_VOLTS, height, 0);
      line(cursor_x, 0, cursor_x, height);
      line(0, cursor_y, width, cursor_y);

      stroke(0, 255, 255, 128);
      cursor_x = map(cursor_index_2, 0, samples.length-1, 0, width);
      cursor_y = map(cursor_v_2, MIN_VOLTS, MAX_VOLTS, height, 0);
      line(cursor_x, 0, cursor_x, height);
      line(0, cursor_y, width, cursor_y);
      pop();
    }

    float period = (float) SAMPLES_PER_PERIOD / (float) SAMPLE_RATE;
    float hz = 1.0/period;
    int sample = samples[samples_cursor % samples.length];
    int cursor_sample_1 = samples[cursor_index_1];
    int cursor_sample_2 = samples[cursor_index_2];
    float t1 = map(cursor_index_1, 0, samples.length, 0, period);
    float t2 = map(cursor_index_2, 0, samples.length, 0, period);
    float a_volts = map(unpack_sample_a(sample), 0, MAX_SAMPLE_VALUE, MIN_VOLTS, MAX_VOLTS);
    float b_volts = map(unpack_sample_b(sample), 0, MAX_SAMPLE_VALUE, MIN_VOLTS, MAX_VOLTS);
    float ca_volts_1 = map(unpack_sample_a(cursor_sample_1), 0, MAX_SAMPLE_VALUE, MIN_VOLTS, MAX_VOLTS);
    float cb_volts_1 = map(unpack_sample_b(cursor_sample_1), 0, MAX_SAMPLE_VALUE, MIN_VOLTS, MAX_VOLTS);
    float ca_volts_2 = map(unpack_sample_a(cursor_sample_2), 0, MAX_SAMPLE_VALUE, MIN_VOLTS, MAX_VOLTS);
    float cb_volts_2 = map(unpack_sample_b(cursor_sample_2), 0, MAX_SAMPLE_VALUE, MIN_VOLTS, MAX_VOLTS);

    if (hz < frameRate) {
      stroke(255, 200);
      int x = (int) map(samples_cursor, 0, samples.length-1, 0, width);
      line(x, 0, x, height);
    }

    if (show_text) {
      StringList lines = new StringList();
      lines.append("Sample rate: " + SAMPLE_RATE + " Hz");
      lines.append(String.format("Period: %.6f s (%f Hz)", period, hz));
      lines.append(String.format("Voltage Range: %.3f - %.3f V", MIN_VOLTS, MAX_VOLTS));
      lines.append(String.format("Channel A: %.3f V", a_volts));
      lines.append(String.format("Channel B: %.3f V", b_volts));
      if (show_cursors) {
        lines.append(String.format("ChA @ Cursor 1: %.3f V", ca_volts_1));
        lines.append(String.format("ChB @ Cursor 1: %.3f V", cb_volts_1));
        lines.append(String.format("Cursor 1 Volts: %.3f V", cursor_v_1));
        lines.append(String.format("ChA @ Cursor 2: %.3f V", ca_volts_2));
        lines.append(String.format("ChB @ Cursor 2: %.3f V", cb_volts_2));
        lines.append(String.format("Cursor 2 Volts: %.3f V", cursor_v_2));
        lines.append(String.format("Cursor Δt: %.6f s", t2-t1));
        lines.append(String.format("Cursor ΔV: %.3f V", cursor_v_2 - cursor_v_1));
      }

      push();
      color(0, 255, 0, 128);
      textSize(18);

      textAlign(LEFT, TOP);
      for (int i = 0; i < lines.size(); i++) {
        text(lines.get(i), 0, i*18);
      }
      
      if (show_help) {
        textAlign(RIGHT, TOP);
        for (int i = 0; i < helptext.size(); i++) {
          text(helptext.get(i), width, i*18);
        }
      }

      if (!update_scope) {
        textAlign(CENTER, TOP);
        text("Paused", width/2, 0);
      }

      if (show_fps) {
        fill(255, 255, 255, 128);
        textAlign(CENTER, TOP);
        text(floor(frameRate) + " FPS", width/2, 18);
      }

      pop();
    }

    if (!device.active()) {
      device.stop();
      device = null;
    }
  } // else device == null
}

void updateScope() {
  if (samples == null || samples.length != SAMPLES_PER_PERIOD) {
    samples = Arrays.copyOfRange(samples, 0, SAMPLES_PER_PERIOD);
  }
  synchronized(samples_to_add) {
    for (int s : samples_to_add) {
      samples_cursor = (samples_cursor+1) % samples.length;
      samples[samples_cursor] = s;
    }
    samples_to_add.clear();
  }
}

void drawScope() {
  int px, py;
  push();
  strokeWeight(1);
  stroke(0, 255, 0, 128);
  beginShape(LINES);
  px = (int) map(0, 0, samples.length-1, 0, width);
  py = (int) map((float) unpack_sample_a(samples[0]), 0.0, 1023.0, height, 0.0);
  for (int i = 0; i < samples.length; i++) {
    int sample = samples[i];
    char a = unpack_sample_a(sample);
    int x = (int) map(i, 0, samples.length-1, 0, width);
    if (x == px) continue;
    int y = (int) map((float) a, 0.0, 1023.0, height, 0.0);
    vertex(px, py);
    vertex(x, y);
    px = x;
    py = y;
  }
  endShape();

  stroke(0, 0, 255, 128);
  beginShape(LINES);
  px = (int) map(0, 0, samples.length-1, 0, width);
  py = (int) map((float) unpack_sample_b(samples[0]), 0.0, 1023.0, height, 0.0);
  for (int i = 1; i < samples.length; i++) {
    int sample = samples[i];
    char a = unpack_sample_b(sample);
    int x = (int) map(i, 0, samples.length-1, 0, width);
    if (x == px) continue;
    int y = (int) map((float) a, 0.0, 1023.0, height, 0.0);
    vertex(px, py);
    vertex(x, y);
    px = x;
    py = y;
  }
  endShape();

  pop();
}

void saveSamples(File output) {
  if (output == null) return; // cancelled
  float period = (float) SAMPLES_PER_PERIOD / (float) SAMPLE_RATE;
  Table table = new Table();
  table.addColumn("time", Table.FLOAT);
  table.addColumn("va", Table.FLOAT);
  table.addColumn("vb", Table.FLOAT);
  int start_idx = samples_cursor+1;
  for (int i = 0; i < samples.length; i++) {
    int idx = (start_idx+i) % samples.length;
    int sample = samples[idx];
    float t = map(i, 0, samples.length, 0, period);
    float a_volts = map(unpack_sample_a(sample), 0, MAX_SAMPLE_VALUE, MIN_VOLTS, MAX_VOLTS);
    float b_volts = map(unpack_sample_b(sample), 0, MAX_SAMPLE_VALUE, MIN_VOLTS, MAX_VOLTS);
    TableRow row = table.addRow();
    row.setFloat(0, t);
    row.setFloat(1, a_volts);
    row.setFloat(2, b_volts);
  }
  saveTable(table, output.getAbsolutePath());
}

void exit() {
  // prevent exiting with Ctrl+W to allow moving cursor
  if (keys[CONTROL] && keys['W']) {
    return;
  }
  super.exit();
}

void keyPressed() {
  if (keyCode >= 0 && keyCode < 256) {
    keys[keyCode] = true;
  }
  if (device == null) {
    if (key >= '1' && key <= '9') {
      int index = key - '1';
      try {
        device = new Serial(this, Serial.list()[index], BAUD);
        device.buffer(64);
        samples = new int[SAMPLES_PER_PERIOD];
        samples_to_add.clear();
        samples_cursor = 0;
        update_scope = true;
      }
      catch (Exception e) {
        e.printStackTrace();
      }
    }
  } else {
    int move_scale = 1;
    if (keys[SHIFT]) {
      move_scale *= 10;
    }
    if (keys[CONTROL]) {
      move_scale *= 100;
    }

    switch (keyCode) {
    case ' ':
      update_scope = !update_scope;
      break;
    case 'E':
      selectOutput("Save (.csv, .tsv, .html, .bin)", "saveSamples");
      update_scope = false;
      break;
    case 'W':
      cursor_v_1 += 0.001*move_scale;
      break;
    case 'S':
      cursor_v_1 -= 0.001*move_scale;
      break;
    case 'A':
      cursor_index_1 -= move_scale;
      break;
    case 'D':
      cursor_index_1 += move_scale;
      break;
    case 'I':
      cursor_v_2 += 0.001*move_scale;
      break;
    case 'K':
      cursor_v_2 -= 0.001*move_scale;
      break;
    case 'J':
      cursor_index_2 -= move_scale;
      break;
    case 'L':
      cursor_index_2 += move_scale;
      break;
    case 'T':
      show_text = !show_text;
      break;
    case 'C':
      show_cursors = !show_cursors;
      break;
    case 'H':
      show_help = !show_help;
      break;
    case UP:
      SAMPLES_PER_PERIOD += move_scale;
      break;
    case DOWN:
      SAMPLES_PER_PERIOD -= move_scale;
      break;
    case RIGHT:
      updateScope();
      break;
    case 'F':
      show_fps = !show_fps;
      break;
    case BACKSPACE:
      device.stop();
      device = null;
      break;
    }
    SAMPLES_PER_PERIOD = constrain(SAMPLES_PER_PERIOD, 2, 1000000000);
  }
}

void keyReleased() {
  if (keyCode >= 0 && keyCode < 256) {
    keys[keyCode] = false;
  }
}

void mouseWheel(MouseEvent event) {
  int scroll = event.getCount();
  if (event.isShiftDown()) {
    scroll *= 10;
  }
  if (event.isControlDown()) {
    scroll *= 100;
  }
  SAMPLES_PER_PERIOD = constrain(SAMPLES_PER_PERIOD + scroll, 2, 1000000000);
}

void serialEvent(Serial s) {
  byte[] buf = new byte[4];
  synchronized(samples_to_add) {
    while (s.available() >= 4) {
      s.readBytes(buf);
      ByteBuffer inbuffer = ByteBuffer.wrap(buf);
      inbuffer.order(ByteOrder.LITTLE_ENDIAN);
      char s1 = inbuffer.getChar();
      char s2 = inbuffer.getChar();
      boolean is_s1_a = (s1 & 0x8000) != 0;
      boolean is_s2_a = (s2 & 0x8000) != 0;
      if (is_s1_a == is_s2_a) {
        // then signal is probably misaligned by 1 byte, so consume one more byte.
        s.read();
      }
      s1 = (char) (s1 & 0x7FFF);
      s2 = (char) (s2 & 0x7FFF);
      samples_to_add.add(is_s1_a ? pack_sample(s1, s2) : pack_sample(s2, s1));
    }
  }
}
