/*
 * The hitch log (2026-11-05 the user: "with this airplane only, an operation
 * now and then freezes the screen for a while"), included by
 * b747_fms_bridge.c. The bridge's frame loop runs on X-Plane's main thread
 * (the one that draws): a frame that comes over HL_GAP_S of wall time after
 * the one before, the sim's time moving (not paused), goes to
 * Output/B747_hitches.txt with the local time and what this plugin did since
 * the frame before (its X-Plane FMS plan load with its entries, its folder
 * scan when slow: their times). The XTLua plugins' slow callouts go to the
 * same file (their init.lua). For the users' reports: the time of a freeze
 * against what was done then.
 * (2026-11-05) The frames' gap is laminar/B747/diag/hitch_gap_s (seconds,
 * HL_GAP_S at the start; written lower for a test by hand: the user's
 * "freezes when input comes from the 3D cockpit, not the API").
 * (2026-11-13; the 2026-11-12 review D-6, 案 22) a gap of HL_LONG_S or more
 * is written too, marked (a scenery or aircraft load, or a long freeze:
 * before, left out, and the freezes of tens of seconds were not in the
 * file); no more HL_MAX (300) lines a session (a long flight used them up
 * early): past HL_FILE_MAX bytes the file keeps its newest HL_FILE_KEEP
 * bytes of whole lines.
 * hitch_log_test.c (tests/static/bridge_hitch_test.lua) runs it without
 * X-Plane.
 */
#define HL_GAP_S 0.25
#define HL_LONG_S 20.0
#define HL_WORK_S 0.05
#define HL_FILE_MAX 262144L
#define HL_FILE_KEEP 131072L

static LARGE_INTEGER hl_hz;
static double hl_prev = 0.0;      /* the last frame's call, wall seconds */
static float hl_prev_sim = 0.0f;  /* and the sim's time then */
static char hl_did[200];          /* the bridge's work since the last frame */
static XPLMDataRef hl_ref_sim = NULL, hl_ref_gap = NULL;
static float hl_gap = (float)HL_GAP_S;
static float hl_gap_get(void *ref) { (void)ref; return hl_gap; }
static void hl_gap_set(void *ref, float v) { (void)ref; if (v >= 0.02f && v <= 5.0f) hl_gap = v; }

static double hl_now(void)
{
    LARGE_INTEGER t;
    QueryPerformanceCounter(&t);
    return hl_hz.QuadPart ? (double)t.QuadPart / (double)hl_hz.QuadPart : 0.0;
}

/* (案 22) the file past HL_FILE_MAX bytes: its newest HL_FILE_KEEP bytes,
   from the first whole line in them, under a line that says so */
static void hl_trim(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) return;
    long size = -1;
    if (fseek(f, 0, SEEK_END) == 0) size = ftell(f);
    if (size <= HL_FILE_MAX) { fclose(f); return; }
    char *buf = (char *)malloc((size_t)HL_FILE_KEEP);
    if (!buf) { fclose(f); return; }
    size_t n = 0;
    if (fseek(f, size - HL_FILE_KEEP, SEEK_SET) == 0) n = fread(buf, 1, (size_t)HL_FILE_KEEP, f);
    fclose(f);
    size_t i = 0;
    while (i < n && buf[i] != '\n') i++;
    if (i < n) {
        f = fopen(path, "wb");
        if (f) {
            fprintf(f, "(older lines dropped: the file kept to its newest %ld bytes)\n", HL_FILE_KEEP);
            fwrite(buf + i + 1, 1, n - i - 1, f);
            fclose(f);
        }
    }
    free(buf);
}

static void hl_write(const char *text)
{
    char p[PATH_LEN];
    p[0] = 0;
    XPLMGetSystemPath(p);
    size_t n = strlen(p);
    snprintf(p + n, sizeof p - n, "Output\\B747_hitches.txt");
    FILE *f = fopen(p, "ab");
    if (!f) return;
    SYSTEMTIME st;
    GetLocalTime(&st);
    fprintf(f, "%04d-%02d-%02d %02d:%02d:%02d.%03d bridge: %s\n", st.wYear, st.wMonth, st.wDay,
        st.wHour, st.wMinute, st.wSecond, st.wMilliseconds, text);
    long size = ftell(f);
    fclose(f);
    if (size > HL_FILE_MAX) hl_trim(p);
}

/* the bridge's own work since t0: kept for the next frame's line (always
   with a count, the FMS plan's entries; without, only when slow) */
static void hl_work(const char *what, double t0, int count)
{
    double dt = hl_now() - t0;
    if (count < 0 && dt < HL_WORK_S) return;
    size_t n = strlen(hl_did);
    if (n + 80 >= sizeof hl_did) return;
    if (count >= 0) snprintf(hl_did + n, sizeof hl_did - n, "%s%s %.3f s (%d entries)", n ? ", " : "", what, dt, count);
    else snprintf(hl_did + n, sizeof hl_did - n, "%s%s %.3f s", n ? ", " : "", what, dt);
}

/* a frame's line: 1 with it in line when the gap is one to write (over the
   threshold, the sim's time moving), else 0. (案 22) HL_LONG_S or more
   marked */
static int hl_frame_line(char *line, size_t size, double gap, int moving, const char *did)
{
    if (!(gap > hl_gap && moving)) return 0;
    snprintf(line, size, "frame %.2f s after the one before%s%s%s", gap,
        gap >= HL_LONG_S ? " (20 s or more: a scenery or aircraft load, or a long freeze)" : "",
        did[0] ? "; the bridge in it: " : "", did);
    return 1;
}

/* each frame, first in the frame loop */
static void hl_frame(void)
{
    double t = hl_now();
    float sim = hl_ref_sim ? XPLMGetDataf(hl_ref_sim) : 0.0f;
    double gap = hl_prev > 0.0 ? t - hl_prev : 0.0;
    int moving = sim - hl_prev_sim > 0.001f;
    char line[400];
    if (hl_frame_line(line, sizeof line, gap, moving, hl_did)) hl_write(line);
    hl_prev = t;
    hl_prev_sim = sim;
    hl_did[0] = 0;
}

static void hl_start(void)
{
    QueryPerformanceFrequency(&hl_hz);
    hl_ref_sim = XPLMFindDataRef("sim/time/total_running_time_sec");
    hl_ref_gap = XPLMRegisterDataAccessor("laminar/B747/diag/hitch_gap_s", xplmType_Float, 1,
        NULL, NULL, hl_gap_get, hl_gap_set, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}

static void hl_stop(void)
{
    XPLMUnregisterDataAccessor(hl_ref_gap);
}
