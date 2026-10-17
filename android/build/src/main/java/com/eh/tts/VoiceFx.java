// Narrator post-processing for on-device lines, so a runtime line matches the pre-rendered pack clips of the same narrator.
// Pure Java (no Android deps): the box runs this same class for QA (/workspace/voices_qa/fx).
// Pack chains (identified 2026-10-17 by matching the shipped voice_{m,c,g} clips, see CREDITS.md):
//   f : Piper en_US-ljspeech-medium (noise_w 0.333), m : Piper en_US-joe-medium (noise_w 0.8), both "loudnorm=I=-18"
//   c : Kokoro v1.0 af_sky  (sid 10, speed 1.0, 24 kHz) -> aresample=24000,asetrate=24000*1.35,aresample=24000,
//       atempo=1/1.35*1.05,loudnorm=I=-18,aresample=22050
//   g : Kokoro v1.0 af_heart (sid 3) -> same chain with r = 1.25
// asetrate*r = band-limited resample (pitch AND formants x r, duration / r); atempo = WSOLA time stretch (pitch kept).
package com.eh.tts;

public final class VoiceFx {
    private VoiceFx() {}
    public static final int OUT_RATE = 22050;

    /** asetrate factor per narrator (0 = none). */
    public static double rate(String narrator) {
        if ("c".equals(narrator)) return 1.35;
        if ("g".equals(narrator)) return 1.25;
        return 0;
    }

    /** Loudness target per narrator (gated block RMS in dBFS, see loudness()): the mean of that pack's own clips
     *  ("my name is ali/ahmet/mehmet/mustafa", "this is my family/the news"), i.e. where loudnorm=I=-18 landed them. */
    public static float targetDb(String narrator) {
        if ("m".equals(narrator)) return -20.0f;
        if ("c".equals(narrator)) return -17.9f;
        if ("g".equals(narrator)) return -18.1f;
        return -19.1f;
    }

    /** model output (any rate) -> pack-matched line at OUT_RATE. */
    public static float[] apply(float[] x, int sr, String narrator) {
        if (x == null || x.length == 0) return x;
        float[] y = x;
        double r = rate(narrator);
        if (r > 0) {
            y = resample(y, r);                        // asetrate=sr*r,aresample=sr
            y = wsola(y, sr, 1.0 / r * 1.05);          // atempo
        }
        if (sr != OUT_RATE) y = resample(y, (double) sr / OUT_RATE);   // aresample=22050
        return normalize(y, OUT_RATE, targetDb(narrator));
    }

    /** read x at step r (windowed sinc, low-passed at min(1, 1/r) of the source Nyquist). Output length n / r. */
    public static float[] resample(float[] x, double r) {
        int n = (int) Math.floor(x.length / r);
        float[] y = new float[n];
        double fc = Math.min(1.0, 1.0 / r) * 0.97;
        int half = 24;
        for (int i = 0; i < n; i++) {
            double t = i * r;
            int c = (int) Math.floor(t);
            double acc = 0;
            for (int k = c - half + 1; k <= c + half; k++) {
                if (k < 0 || k >= x.length) continue;
                double d = t - k;
                double s = d == 0 ? 1.0 : Math.sin(Math.PI * fc * d) / (Math.PI * fc * d);
                double w = 0.5 + 0.5 * Math.cos(Math.PI * d / half);
                acc += x[k] * fc * s * w;
            }
            y[i] = (float) acc;
        }
        return y;
    }

    /** WSOLA time stretch: tempo > 1 = faster. Output length ~ n / tempo; pitch unchanged. */
    public static float[] wsola(float[] x, int sr, double tempo) {
        int N = (int) (0.04 * sr) & ~1, Hs = N / 2, tol = (int) (0.012 * sr);
        int n = (int) Math.round(x.length / tempo);
        double[] out = new double[n + N], ws = new double[n + N];
        double[] win = new double[N];
        for (int i = 0; i < N; i++) win[i] = 0.5 - 0.5 * Math.cos(2 * Math.PI * i / N);
        int prev = 0;   // analysis position of the last copied frame
        for (int so = 0; so < n; so += Hs) {
            int ideal = (int) Math.round(so * tempo);
            int best = ideal;
            if (so > 0) {
                // natural continuation of the previous frame: x[prev + Hs ...]; pick the candidate that correlates best with it
                int nat = prev + Hs; double bc = -1e30;
                for (int d = -tol; d <= tol; d++) {
                    int c = ideal + d;
                    if (c < 0 || c + N > x.length) continue;
                    double acc = 0;
                    for (int i = 0; i < N; i += 2) { int a = nat + i; if (a >= x.length) break; acc += x[a] * x[c + i]; }
                    if (acc > bc) { bc = acc; best = c; }
                }
            }
            best = Math.max(0, Math.min(best, Math.max(0, x.length - 1)));
            for (int i = 0; i < N; i++) {
                int s = best + i, d = so + i;
                if (s >= x.length || d >= out.length) break;
                out[d] += x[s] * win[i]; ws[d] += win[i];
            }
            prev = best;
        }
        float[] y = new float[n];
        for (int i = 0; i < n; i++) y[i] = (float) (ws[i] > 1e-3 ? out[i] / ws[i] : 0);
        return y;
    }

    /** gated (-70 abs / -10 rel) 400 ms block RMS like EBU R128 (no K filter), gain to targetDb, peak-limited to -1 dBFS. */
    public static float[] normalize(float[] x, int sr, float targetDb) {
        double l = loudness(x, sr);
        if (Double.isNaN(l)) return x;
        double g = Math.pow(10, (targetDb - l) / 20.0);
        double pk = 0;
        for (float v : x) pk = Math.max(pk, Math.abs(v));
        if (pk * g > 0.89) g = 0.89 / pk;
        float[] y = new float[x.length];
        for (int i = 0; i < x.length; i++) y[i] = (float) (x[i] * g);
        return y;
    }

    public static double loudness(float[] x, int sr) {
        int blk = (int) (0.4 * sr), step = blk / 4;
        java.util.ArrayList<Double> ms = new java.util.ArrayList<>();
        for (int s = 0; s + blk <= Math.max(x.length, blk); s += step) {
            double e = 0;
            for (int i = 0; i < blk; i++) { int j = s + i; if (j < x.length) e += x[j] * x[j]; }
            ms.add(e / blk);
        }
        double sum = 0; int cnt = 0;
        for (double m : ms) if (10 * Math.log10(m + 1e-20) > -70) { sum += m; cnt++; }
        if (cnt == 0) return Double.NaN;
        double rel = 10 * Math.log10(sum / cnt) - 10;
        sum = 0; cnt = 0;
        for (double m : ms) if (10 * Math.log10(m + 1e-20) > rel) { sum += m; cnt++; }
        return cnt == 0 ? Double.NaN : 10 * Math.log10(sum / cnt);
    }

    /** float -> 16-bit little-endian PCM (the format audio.gd puts into AudioStreamWAV). */
    public static byte[] pcm16(float[] s) {
        byte[] out = new byte[s.length * 2];
        for (int i = 0; i < s.length; i++) {
            int v = Math.max(-32768, Math.min(32767, (int) (s[i] * 32767.0f)));
            out[i * 2] = (byte) (v & 255);
            out[i * 2 + 1] = (byte) ((v >> 8) & 255);
        }
        return out;
    }
}
