// SherpaTts Godot v2 Android plugin (on-device Piper/VITS + Kokoro TTS through sherpa-onnx).
// RECONSTRUCTED 2026-10-17 from the shipped v31.1 APK (classes3.dex, decompiled with jadx); the original android/build was lost in the snapshot restore.
// v32-voices: one model per narrator, the SAME model + speaker + post-processing that rendered that narrator's pack clips
// (f ljspeech, m joe, c Kokoro af_sky, g Kokoro af_heart; see VoiceFx). Old API (init / generate / getSampleRate) unchanged.
package com.eh.tts;

import android.net.ConnectivityManager;
import android.util.Log;
import com.k2fsa.sherpa.onnx.GeneratedAudio;
import com.k2fsa.sherpa.onnx.OfflineTts;
import com.k2fsa.sherpa.onnx.OfflineTtsConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsKokoroModelConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

public class SherpaTts extends GodotPlugin {
    private int sampleRate;
    private OfflineTts tts;          // model of init()/generate() (legacy: ljspeech = narrator f)
    private OfflineTts ntts;         // narrator model (initNarrator / generateNarrator); one loaded at a time to bound RAM
    private String nModel = "";      // which model ntts holds: "lj", "joe", "kokoro"
    private String nDir = "";

    public SherpaTts(Godot godot) {
        super(godot);
        this.sampleRate = 22050;
    }

    @Override // org.godotengine.godot.plugin.GodotPlugin
    public String getPluginName() {
        return "SherpaTts";
    }

    /** narrator -> model key */
    static String modelOf(String narrator) {
        if ("m".equals(narrator)) return "joe";
        if ("c".equals(narrator) || "g".equals(narrator)) return "kokoro";
        return "lj";
    }

    /** narrator -> speaker id inside its model */
    static int sidOf(String narrator) {
        if ("c".equals(narrator)) return 10;   // af_sky
        if ("g".equals(narrator)) return 3;    // af_heart
        return 0;
    }

    /** files (relative to the tts dir) the narrator's model needs, comma separated; espeak-ng-data/ is shared by all. */
    @UsedByGodot
    public String narratorFiles(String narrator) {
        switch (modelOf(narrator)) {
            case "joe": return "en_US-joe-medium.onnx,tokens_joe.txt";
            case "kokoro": return "kokoro/model.onnx,kokoro/voices.bin,kokoro/tokens.txt";
            default: return "en_US-ljspeech-medium.onnx,tokens.txt";
        }
    }

    static OfflineTts load(String dir, String model) {
        OfflineTtsModelConfig mc = new OfflineTtsModelConfig();
        if ("kokoro".equals(model)) {
            OfflineTtsKokoroModelConfig k = new OfflineTtsKokoroModelConfig();
            k.setModel(dir + "/kokoro/model.onnx");
            k.setVoices(dir + "/kokoro/voices.bin");
            k.setTokens(dir + "/kokoro/tokens.txt");
            k.setDataDir(dir + "/espeak-ng-data");
            k.setLang("en-us");   // multi-lang Kokoro v1.0: espeak en-us front end (= kokoro-onnx lang="en-us" of the pack)
            k.setLengthScale(1.0f);
            mc.setKokoro(k);
        } else {
            boolean joe = "joe".equals(model);
            OfflineTtsVitsModelConfig vits = new OfflineTtsVitsModelConfig();
            vits.setModel(dir + (joe ? "/en_US-joe-medium.onnx" : "/en_US-ljspeech-medium.onnx"));
            vits.setTokens(dir + (joe ? "/tokens_joe.txt" : "/tokens.txt"));
            vits.setDataDir(dir + "/espeak-ng-data");
            // the inference values of the model's Piper .onnx.json (what the pack renders used)
            vits.setNoiseScale(0.667f);
            vits.setNoiseScaleW(joe ? 0.8f : 0.333f);
            vits.setLengthScale(1.0f);
            mc.setVits(vits);
        }
        mc.setNumThreads(Math.max(2, Math.min(4, Runtime.getRuntime().availableProcessors() / 2)));
        mc.setProvider("cpu");
        mc.setDebug(false);
        OfflineTtsConfig cfg = new OfflineTtsConfig();
        cfg.setModel(mc);
        return new OfflineTts(null, cfg);
    }

    @UsedByGodot
    public boolean init(String dir) {
        try {
            if (this.tts != null) { this.tts.release(); this.tts = null; }
            this.tts = load(dir, "lj");
            this.sampleRate = this.tts.sampleRate();
            return true;
        } catch (Throwable t) {
            Log.e("SherpaTts", "init failed", t);
            this.tts = null;
            return false;
        }
    }

    /** load the model of narrator f / m / c / g from dir (no-op when it is already loaded). */
    @UsedByGodot
    public boolean initNarrator(String dir, String narrator) {
        String model = modelOf(narrator);
        if (this.ntts != null && model.equals(this.nModel) && dir.equals(this.nDir)) return true;
        try {
            if (this.ntts != null) { this.ntts.release(); this.ntts = null; this.nModel = ""; }
            if ("lj".equals(model) && this.tts != null) { this.tts.release(); this.tts = null; }   // never two big models in RAM
            this.ntts = load(dir, model);
            this.nModel = model;
            this.nDir = dir;
            return true;
        } catch (Throwable t) {
            Log.e("SherpaTts", "initNarrator " + narrator + " failed", t);
            this.ntts = null;
            this.nModel = "";
            return false;
        }
    }

    /** whole line in narrator's voice, pack-matched (VoiceFx), 16-bit mono PCM at getSampleRate() (= 22050). */
    @UsedByGodot
    public byte[] generateNarrator(String narrator, String text) {
        if (this.ntts == null || !modelOf(narrator).equals(this.nModel)) return new byte[0];
        try {
            GeneratedAudio a = this.ntts.generate(text, sidOf(narrator), 1.0f);
            float[] s = VoiceFx.apply(a.getSamples(), a.getSampleRate(), narrator);
            this.sampleRate = VoiceFx.OUT_RATE;
            return VoiceFx.pcm16(s);
        } catch (Throwable t) {
            Log.e("SherpaTts", "generateNarrator failed", t);
            return new byte[0];
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
            this.sampleRate = a.getSampleRate();
            return VoiceFx.pcm16(a.getSamples());
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
