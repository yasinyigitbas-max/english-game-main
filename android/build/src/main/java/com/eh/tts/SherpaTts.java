// SherpaTts Godot v2 Android plugin (on-device Piper/VITS TTS through sherpa-onnx).
// RECONSTRUCTED 2026-10-17 from the shipped v31.1 APK (classes3.dex, decompiled with jadx); the original android/build was lost in the snapshot restore.
package com.eh.tts;

import android.net.ConnectivityManager;
import android.util.Log;
import com.k2fsa.sherpa.onnx.GeneratedAudio;
import com.k2fsa.sherpa.onnx.OfflineTts;
import com.k2fsa.sherpa.onnx.OfflineTtsConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

public class SherpaTts extends GodotPlugin {
    private int sampleRate;
    private OfflineTts tts;

    public SherpaTts(Godot godot) {
        super(godot);
        this.sampleRate = 22050;
    }

    @Override // org.godotengine.godot.plugin.GodotPlugin
    public String getPluginName() {
        return "SherpaTts";
    }

    @UsedByGodot
    public boolean init(String dir) {
        try {
            OfflineTtsVitsModelConfig vits = new OfflineTtsVitsModelConfig();
            vits.setModel(dir + "/en_US-ljspeech-medium.onnx");
            vits.setTokens(dir + "/tokens.txt");
            vits.setDataDir(dir + "/espeak-ng-data");
            OfflineTtsModelConfig mc = new OfflineTtsModelConfig();
            mc.setVits(vits);
            mc.setNumThreads(2);
            mc.setProvider("cpu");
            mc.setDebug(false);
            OfflineTtsConfig cfg = new OfflineTtsConfig();
            cfg.setModel(mc);
            this.tts = new OfflineTts(null, cfg);
            this.sampleRate = this.tts.sampleRate();
            return true;
        } catch (Throwable t) {
            Log.e("SherpaTts", "init failed", t);
            this.tts = null;
            return false;
        }
    }

    @UsedByGodot
    public int getSampleRate() {
        return this.sampleRate;
    }

    @UsedByGodot
    public byte[] generate(String text) {
        if (this.tts == null) {
            return new byte[0];
        }
        try {
            GeneratedAudio a = this.tts.generate(text, 0, 1.0f);
            float[] s = a.getSamples();
            this.sampleRate = a.getSampleRate();
            byte[] out = new byte[s.length * 2];
            for (int i = 0; i < s.length; i++) {
                int v = Math.max(-32768, Math.min(32767, (int) (s[i] * 32767.0f)));
                out[i * 2] = (byte) (v & 255);
                out[(i * 2) + 1] = (byte) ((v >> 8) & 255);
            }
            return out;
        } catch (Throwable t) {
            Log.e("SherpaTts", "generate failed", t);
            return new byte[0];
        }
    }

    @UsedByGodot
    public boolean isMetered() {
        try {
            ConnectivityManager cm = (ConnectivityManager) getActivity().getSystemService("connectivity");
            return cm != null && cm.isActiveNetworkMetered();
        } catch (Exception e) {
            return false;
        }
    }
}
