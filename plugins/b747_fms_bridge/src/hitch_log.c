/*
 * The hitch log (2026-11-05 the user: "with this airplane only, an operation
 * now and then freezes the screen for a while"), included by
 * b747_fms_bridge.c. The bridge's frame loop runs on X-Plane's main thread
 * (the one that draws): a frame that comes over HL_GAP_S of wall time after
 * the one before, the sim's time moving (not paused) and under HL_LONG_S
 * (not a load), goes to Output/B747_hitches.txt with the local time and what
 * this plugin did since the frame before (its X-Plane FMS plan load with its
 * entries, its folder scan when slow: their times). The XTLua plugins' slow
 * callouts go to the same file (their init.lua). HL_MAX lines a session.
 * For the users' reports: the time of a freeze against what was done then.
 */
#define HL_GAP_S 0.25
#define HL_LONG_S 20.0
#define HL_WORK_S 0.05
#define HL_MAX 300

static LARGE_INTEGER hl_hz;
static double hl_prev = 0.0;      /* the last frame's call, wall seconds */
static float hl_prev_sim = 0.0f;  /* and the sim's time then */
static int hl_n = 0;
static char hl_did[200];          /* the bridge's work since the last frame */
static XPLMDataRef hl_ref_sim = NULL;

static double hl_now(void)
{
    LARGE_INTEGER t;
    QueryPerformanceCounter(&t);
    return hl_hz.QuadPart ? (double)t.QuadPart / (double)hl_hz.QuadPart : 0.0;
}

static void hl_write(const char *text)
{
    if (hl_n >= HL_MAX) return;
    hl_n++;
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
    fclose(f);
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

/* each frame, first in the frame loop */
static void hl_frame(void)
{
    double t = hl_now();
    float sim = hl_ref_sim ? XPLMGetDataf(hl_ref_sim) : 0.0f;
    double gap = hl_prev > 0.0 ? t - hl_prev : 0.0;
    int moving = sim - hl_prev_sim > 0.001f;
    if (gap > HL_GAP_S && gap < HL_LONG_S && moving) {
        char line[300];
        snprintf(line, sizeof line, "frame %.2f s after the one before%s%s", gap,
            hl_did[0] ? "; the bridge in it: " : "", hl_did);
        hl_write(line);
    }
    hl_prev = t;
    hl_prev_sim = sim;
    hl_did[0] = 0;
}

static void hl_start(void)
{
    QueryPerformanceFrequency(&hl_hz);
    hl_ref_sim = XPLMFindDataRef("sim/time/total_running_time_sec");
}
