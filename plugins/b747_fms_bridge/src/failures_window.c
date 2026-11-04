/*
 * The failure window (2026-11-04 the user; docs/overhaul/notes/FAILURES.md),
 * included by b747_fms_bridge.c. Plugins > 747-400 > Failures... or the
 * command laminar/B747/failures/window_toggle shows a floating window in
 * X-Plane's own frame (moved, resized, popped out into a window of its own,
 * in VR when VR is on; X-Plane's frame has the title, the close and
 * the pop-out buttons) with the airplane's failures by ATA chapter: the
 * chapters on the left, each with the number failed (amber); the chosen
 * chapter's failures on the right by group, each NORMAL (green) or FAILED
 * (amber); ARMED (cyan) an X-Plane failure armed by X-Plane's own failure
 * screen; N/A (grey) a dataref not there. A click on a failure fails or
 * repairs it at once; REPAIR ALL repairs every one in the list.
 *
 * (F2) A normal failure's ARM opens the arm bar at the bottom: IN TIME (so
 * many minutes from now, the sim's time: paused, it waits), AT ALTITUDE, AT
 * SPEED (the Captain's indicated, crossed from where it is when armed: at or
 * above from below, at or below from above), RANDOM (a random time within
 * so many minutes, not told), the value by - and +, ARM or CANCEL. An armed
 * failure shows ARMED (cyan) and its trigger (the time left); a click
 * disarms it; it fails when the trigger is met, the window shown or not
 * (b747_fms_bridge.c's loop: fw_poll). REPAIR ALL disarms them too.
 *
 * The list: failures.txt in this plugin's folder (its format there), read
 * when the plugin starts and when the window is shown if the file changed
 * (the armed failures kept). A failure's dataref is looked for when first
 * needed (XTLua makes the airplane's after the plugins start), again each
 * second while it is not there.
 *
 *   laminar/B747/failures/window_open   (int) 0 hidden, 1 shown in X-Plane's
 *                                        window, 2 popped out, 3 in VR; 1 or
 *                                        0 written shows or hides it
 *   laminar/B747/failures/active        (int) the list's failures failed
 *                                        now (read only)
 *   laminar/B747/failures/window_toggle (command) shows or hides it
 *   laminar/B747/failures/repair_all    (command) REPAIR ALL
 *   laminar/B747/failures/test_click    (int) for the tests: a click in the
 *                                        middle of a thing as last drawn,
 *                                        through the window's click handler:
 *                                        1000 + n chapter n (from 0), 2000 + n
 *                                        the shown chapter's row n (from 0,
 *                                        its groups counted), 3000 REPAIR ALL,
 *                                        4000 + n row n's ARM, 5000 + k the
 *                                        arm bar's trigger k (1 time, 2
 *                                        altitude, 3 speed, 4 random), 6000
 *                                        -, 6001 +, 6002 ARM, 6003 CANCEL;
 *                                        reads back the value clicked, -1
 *                                        none drawn
 *   laminar/B747/failures/armed         (int) (F2) failures armed (read only)
 *   laminar/B747/failures/arm_value     (int) (F2) the arm bar's value
 *                                        (minutes, feet, knots), -1 no bar
 *                                        (read only)
 */
#include <math.h>
#include <sys/stat.h>
#include <time.h>
#include <GL/gl.h>
#include "XPLMDisplay.h"
#include "XPLMGraphics.h"

#define FWN_ROWS 640
#define FWN_CHAPS 24
#define FWN_HITS 160
#ifndef FWN_MENU_REF
#define FWN_MENU_REF 100
#endif

enum { FWN_GROUP = 1, FWN_FAIL = 2 };
enum { FWN_NA = 0, FWN_NORMAL, FWN_FAILED, FWN_ARMED };
enum { FWN_HIT_CHAP = 1, FWN_HIT_ROW, FWN_HIT_REPAIR, FWN_HIT_ARM, FWN_HIT_KIND, FWN_HIT_BAR };
/* (F2) our triggers: a time, an altitude, a speed, a random time */
enum { FWN_ARM_NONE = 0, FWN_ARM_TIME, FWN_ARM_ALT, FWN_ARM_SPEED, FWN_ARM_RANDOM };
/* the arm bar's buttons (FWN_HIT_BAR) */
enum { FWN_BAR_MINUS = 0, FWN_BAR_PLUS, FWN_BAR_ARM, FWN_BAR_CANCEL };

typedef struct {
    int type;               /* FWN_GROUP, FWN_FAIL */
    char label[48];
    char name[128];         /* the dataref */
    int index;              /* its element; -1 not an array */
    float failed;           /* its value failed (0 normal) */
    int xp;                 /* X-Plane's: 6 failed, 1-5 armed */
    XPLMDataRef ref;
    int types;
    float next_look;        /* when to look for it again */
    int arm;                /* (F2) our trigger, FWN_ARM_* */
    float arm_at;           /* the flight time it fails at (s), the feet, the knots */
    int arm_dir;            /* altitude, speed: 1 at or above, -1 at or below */
} fw_row_t;

typedef struct {
    char num[8];
    char title[40];
    int first, count;       /* its rows */
    int failed;             /* failed at the last count */
    int armed;              /* (F2) armed by us at the last count */
} fw_chap_t;

typedef struct { int l, b, r, t, kind, id; } fw_hit_t;

static fw_row_t fw_rows[FWN_ROWS];
static int fw_nrows = 0;
static fw_chap_t fw_chaps[FWN_CHAPS];
static int fw_nchaps = 0;
static int fw_chap = 0;             /* the chapter shown */
static int fw_scroll = 0;           /* its first row shown */
static int fw_chap_scroll = 0;      /* the first chapter shown */
static int fw_total = 0;            /* failed at the last count */
static int fw_count_age = 1000;     /* frames since the last count */
static char fw_note[160];           /* the list's trouble, if any */
static fw_hit_t fw_hits[FWN_HITS];
static int fw_nhits = 0;
static int fw_split_x = 0;          /* the chapters' right edge (the wheel's side) */
static int fw_hover_x = 0, fw_hover_y = 0, fw_hover_frame = -100, fw_frame = 0;
static XPLMWindowID fw_win = NULL;
static XPLMCommandRef fw_cmd_toggle = NULL, fw_cmd_repair = NULL;
static XPLMDataRef fw_ref_open = NULL, fw_ref_active = NULL, fw_ref_vr = NULL;
/* (F2) arming: the row being armed (the arm bar), its trigger and value
   (minutes, feet, knots), the armed count; the trigger's inputs */
static int fw_sel = -1, fw_sel_kind = FWN_ARM_TIME, fw_narmed = 0;
static int fw_sel_val[5] = {0, 5, 10000, 100, 30};
static float fw_poll_next = 0.0f;
static XPLMDataRef fw_ref_ftime = NULL, fw_ref_alt = NULL, fw_ref_ias = NULL, fw_ref_armed = NULL, fw_ref_armval = NULL;
static const int FWN_MINUTES[] = {1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120};
#define FWN_NMINUTES ((int)(sizeof FWN_MINUTES / sizeof FWN_MINUTES[0]))
static const char *FWN_KIND_WORD[5] = {"", "IN TIME", "AT ALTITUDE", "AT SPEED", "RANDOM"};

/* EICAS-like: dark, white words, green normal, amber failed, cyan headings */
static const float FWN_BG[4] = {0.055f, 0.06f, 0.075f, 1.0f};
static const float FWN_PANE[4] = {0.10f, 0.11f, 0.135f, 1.0f};
static const float FWN_SEL[4] = {0.12f, 0.27f, 0.37f, 1.0f};
static const float FWN_HOVER[4] = {0.15f, 0.17f, 0.21f, 1.0f};
static const float FWN_RULE[4] = {0.24f, 0.27f, 0.32f, 1.0f};
static const float FWN_AMBER_BOX[4] = {0.97f, 0.63f, 0.10f, 1.0f};
static const float FWN_GREEN_BOX[4] = {0.20f, 0.70f, 0.32f, 1.0f};
static const float FWN_CYAN_BOX[4] = {0.30f, 0.72f, 0.90f, 1.0f};
static const float FWN_BUTTON[4] = {0.40f, 0.44f, 0.50f, 1.0f};
static float FWN_WHITE[3] = {0.94f, 0.95f, 0.97f};
static float FWN_LIGHT[3] = {0.78f, 0.81f, 0.86f};
static float FWN_GREY[3] = {0.50f, 0.53f, 0.58f};
static float FWN_GREEN[3] = {0.30f, 0.90f, 0.42f};
static float FWN_AMBER[3] = {0.99f, 0.68f, 0.16f};
static float FWN_CYAN[3] = {0.40f, 0.84f, 0.99f};
static float FWN_DARK[3] = {0.04f, 0.04f, 0.05f};

/* a text into a buffer of n */
static void fw_copy(char *dst, size_t n, const char *src)
{
    size_t k = strlen(src);
    if (k >= n) k = n - 1;
    memcpy(dst, src, k);
    dst[k] = 0;
}

static char *fw_trim(char *s)
{
    while (*s == ' ' || *s == '\t') s++;
    size_t n = strlen(s);
    while (n > 0 && (s[n - 1] == '\r' || s[n - 1] == '\n' || s[n - 1] == ' ' || s[n - 1] == '\t')) s[--n] = 0;
    return s;
}

/* failures.txt beside this plugin's 64 folder */
static void fw_list_path(char *out, size_t n)
{
    char p[PATH_LEN];
    p[0] = 0;
    XPLMGetPluginInfo(XPLMGetMyID(), NULL, p, NULL, NULL);
    for (int k = 0; k < 2; k++) {           /* ...\b747_fms_bridge\64\win.xpl: up two */
        char *a = strrchr(p, '\\'), *b = strrchr(p, '/');
        if (b > a) a = b;
        if (a) *a = 0;
    }
    snprintf(out, n, "%s\\failures.txt", p);
}

/* (F2) the armed triggers kept across a reload of the list */
typedef struct { char name[128]; int index; float failed; int arm; float arm_at; int arm_dir; } fw_keep_t;
static fw_keep_t fw_keep[FWN_ROWS];
static time_t fw_list_mtime = 0;
static int fw_list_loaded = 0;

/* the list: "C <chapter> <title>", "G <title>", "F <dataref>[i] <kind> <label>";
   (F2) read again only when the file changed, the armed triggers kept */
static void fw_load(void)
{
    char path[PATH_LEN], line[320];
    fw_list_path(path, sizeof path);
    struct stat st;
    int have = stat(path, &st) == 0;
    if (fw_list_loaded && have && st.st_mtime == fw_list_mtime) return;
    if (have) fw_list_mtime = st.st_mtime;
    fw_list_loaded = 1;
    int nkeep = 0;
    for (int i = 0; i < fw_nrows; i++) {
        fw_row_t *r = &fw_rows[i];
        if (r->type != FWN_FAIL || !r->arm) continue;
        fw_keep_t *k = &fw_keep[nkeep++];
        fw_copy(k->name, sizeof k->name, r->name);
        k->index = r->index;
        k->failed = r->failed;
        k->arm = r->arm;
        k->arm_at = r->arm_at;
        k->arm_dir = r->arm_dir;
    }
    fw_nrows = 0;
    fw_nchaps = 0;
    fw_note[0] = 0;
    fw_sel = -1;
    FILE *f = fopen(path, "rb");
    if (!f) {
        fw_copy(fw_note, sizeof fw_note, "The list failures.txt is not in the plugin's folder.");
        return;
    }
    while (fgets(line, sizeof line, f)) {
        char *s = fw_trim(line);
        if (!s[0] || s[0] == '#') continue;
        char kind = s[0];
        s = fw_trim(s + 1);
        if (kind == 'C') {
            if (fw_nchaps >= FWN_CHAPS) continue;
            fw_chap_t *c = &fw_chaps[fw_nchaps++];
            memset(c, 0, sizeof *c);
            int n = 0;
            if (sscanf(s, "%7s%n", c->num, &n) != 1) continue;
            fw_copy(c->title, sizeof c->title, fw_trim(s + n));
            c->first = fw_nrows;
        } else if ((kind == 'G' || kind == 'F') && fw_nchaps > 0 && fw_nrows < FWN_ROWS) {
            fw_row_t *r = &fw_rows[fw_nrows];
            memset(r, 0, sizeof *r);
            r->index = -1;
            if (kind == 'G') {
                r->type = FWN_GROUP;
                fw_copy(r->label, sizeof r->label, s);
            } else {
                char name[160], how[16];
                int n = 0;
                if (sscanf(s, "%159s %15s%n", name, how, &n) != 2) continue;
                char *br = strchr(name, '[');
                if (br) {
                    r->index = atoi(br + 1);
                    *br = 0;
                }
                fw_copy(r->name, sizeof r->name, name);
                if (strcmp(how, "on") == 0) {
                    r->failed = 1.0f;
                } else if (strcmp(how, "xp") == 0) {
                    r->failed = 6.0f;
                    r->xp = 1;
                } else {
                    r->failed = (float)atof(how);
                }
                if (r->failed == 0.0f) continue;
                r->type = FWN_FAIL;
                fw_copy(r->label, sizeof r->label, fw_trim(s + n));
            }
            fw_nrows++;
            fw_chaps[fw_nchaps - 1].count = fw_nrows - fw_chaps[fw_nchaps - 1].first;
        }
    }
    fclose(f);
    if (fw_chap >= fw_nchaps) fw_chap = 0;
    if (!fw_nchaps) fw_copy(fw_note, sizeof fw_note, "The list failures.txt has no chapters.");
    fw_narmed = 0;
    for (int k = 0; k < nkeep; k++) {
        for (int i = 0; i < fw_nrows; i++) {
            fw_row_t *r = &fw_rows[i];
            if (r->type != FWN_FAIL || r->arm || r->index != fw_keep[k].index || r->failed != fw_keep[k].failed ||
                strcmp(r->name, fw_keep[k].name) != 0) continue;
            r->arm = fw_keep[k].arm;
            r->arm_at = fw_keep[k].arm_at;
            r->arm_dir = fw_keep[k].arm_dir;
            fw_narmed++;
            break;
        }
    }
    fw_count_age = 1000;
}

/* the dataref, looked for once a second while not there */
static int fw_find(fw_row_t *r)
{
    if (r->ref) return 1;
    float now = XPLMGetElapsedTime();
    if (now < r->next_look) return 0;
    r->ref = XPLMFindDataRef(r->name);
    if (!r->ref) {
        r->next_look = now + 1.0f;
        return 0;
    }
    r->types = XPLMGetDataRefTypes(r->ref);
    return 1;
}

static int fw_read(fw_row_t *r, float *v)
{
    if (!fw_find(r)) return 0;
    int t = r->types;
    if (r->index >= 0) {
        if (t & xplmType_FloatArray) {
            float x = 0.0f;
            if (XPLMGetDatavf(r->ref, &x, r->index, 1) != 1) return 0;
            *v = x;
            return 1;
        }
        if (t & xplmType_IntArray) {
            int x = 0;
            if (XPLMGetDatavi(r->ref, &x, r->index, 1) != 1) return 0;
            *v = (float)x;
            return 1;
        }
        return 0;
    }
    if (t & xplmType_Float) { *v = XPLMGetDataf(r->ref); return 1; }
    if (t & xplmType_Double) { *v = (float)XPLMGetDatad(r->ref); return 1; }
    if (t & xplmType_Int) { *v = (float)XPLMGetDatai(r->ref); return 1; }
    return 0;
}

static void fw_write(fw_row_t *r, float v)
{
    if (!fw_find(r)) return;
    int t = r->types;
    if (r->index >= 0) {
        if (t & xplmType_FloatArray) {
            XPLMSetDatavf(r->ref, &v, r->index, 1);
        } else if (t & xplmType_IntArray) {
            int x = (int)lroundf(v);
            XPLMSetDatavi(r->ref, &x, r->index, 1);
        }
        return;
    }
    if (t & xplmType_Float) XPLMSetDataf(r->ref, v);
    else if (t & xplmType_Double) XPLMSetDatad(r->ref, v);
    else if (t & xplmType_Int) XPLMSetDatai(r->ref, (int)lroundf(v));
}

/* NORMAL, FAILED, ARMED (ours, or X-Plane's own 1-5), N/A */
static int fw_state(fw_row_t *r)
{
    float v = 0.0f;
    if (!fw_read(r, &v)) return FWN_NA;
    int s;
    if (r->xp) {
        int x = (int)lroundf(v);
        s = x == 6 ? FWN_FAILED : x == 0 ? FWN_NORMAL : FWN_ARMED;
    } else if (r->failed == 1.0f) {
        s = v > 0.5f ? FWN_FAILED : FWN_NORMAL;
    } else {
        s = fabsf(v - r->failed) < 0.25f ? FWN_FAILED : FWN_NORMAL;
    }
    if (s == FWN_NORMAL && r->arm) s = FWN_ARMED;
    return s;
}

static void fw_disarm(fw_row_t *r)
{
    if (!r->arm) return;
    r->arm = FWN_ARM_NONE;
    if (fw_narmed > 0) fw_narmed--;
}

/* a click: failed now, or repaired; an armed one disarmed */
static void fw_toggle_row(int i)
{
    if (i < 0 || i >= fw_nrows || fw_rows[i].type != FWN_FAIL) return;
    fw_row_t *r = &fw_rows[i];
    int s = fw_state(r);
    if (s == FWN_NA) return;
    if (s == FWN_ARMED) {
        if (r->arm) fw_disarm(r);
        else fw_write(r, 0.0f);         /* X-Plane's own arming */
    } else {
        fw_write(r, s == FWN_FAILED ? 0.0f : r->failed);
    }
    fw_count_age = 1000;
}

static void fw_repair_all(void)
{
    for (int i = 0; i < fw_nrows; i++) {
        fw_row_t *r = &fw_rows[i];
        if (r->type != FWN_FAIL) continue;
        fw_disarm(r);
        int s = fw_state(r);
        if (s == FWN_FAILED || s == FWN_ARMED) fw_write(r, 0.0f);
    }
    fw_narmed = 0;
    fw_sel = -1;
    fw_count_age = 1000;
}

/* (F2) the sim's time (stops when paused), the altitude and the speed */
static float fw_now(void) { return fw_ref_ftime ? XPLMGetDataf(fw_ref_ftime) : XPLMGetElapsedTime(); }
static float fw_alt(void) { return fw_ref_alt ? XPLMGetDataf(fw_ref_alt) : 0.0f; }
static float fw_ias(void) { return fw_ref_ias ? XPLMGetDataf(fw_ref_ias) : 0.0f; }

/* arm a failure: in so many minutes, at an altitude or a speed (crossed
   from where it is now), at a random time within so many minutes */
static void fw_arm(int i, int kind, int val)
{
    if (i < 0 || i >= fw_nrows || fw_rows[i].type != FWN_FAIL) return;
    fw_row_t *r = &fw_rows[i];
    if (fw_state(r) != FWN_NORMAL || kind < FWN_ARM_TIME || kind > FWN_ARM_RANDOM) return;
    r->arm = kind;
    if (kind == FWN_ARM_TIME) {
        r->arm_at = fw_now() + (float)val * 60.0f;
    } else if (kind == FWN_ARM_RANDOM) {
        r->arm_at = fw_now() + (float)rand() / (float)RAND_MAX * (float)val * 60.0f;
    } else {
        float v = kind == FWN_ARM_ALT ? fw_alt() : fw_ias();
        r->arm_at = (float)val;
        r->arm_dir = v < (float)val ? 1 : -1;
    }
    fw_narmed++;
    fw_count_age = 1000;
}

/* every frame (b747_fms_bridge.c's loop), five times a second: the armed
   failures whose condition is met fail */
static void fw_poll(void)
{
    if (fw_narmed <= 0) return;
    float t = XPLMGetElapsedTime();
    if (t < fw_poll_next) return;
    fw_poll_next = t + 0.2f;
    float now = fw_now(), alt = fw_alt(), ias = fw_ias();
    int n = 0;
    for (int i = 0; i < fw_nrows; i++) {
        fw_row_t *r = &fw_rows[i];
        if (r->type != FWN_FAIL || !r->arm) continue;
        int hit;
        if (r->arm == FWN_ARM_TIME || r->arm == FWN_ARM_RANDOM) {
            hit = now >= r->arm_at;
        } else {
            float v = r->arm == FWN_ARM_ALT ? alt : ias;
            hit = r->arm_dir > 0 ? v >= r->arm_at : v <= r->arm_at;
        }
        if (hit) {
            r->arm = FWN_ARM_NONE;
            fw_write(r, r->failed);
            fw_count_age = 1000;
        } else {
            n++;
        }
    }
    fw_narmed = n;
}

/* the arm bar's value: one step down or up */
static void fw_step(int up)
{
    int k = fw_sel_kind, *v = &fw_sel_val[k];
    if (k == FWN_ARM_TIME || k == FWN_ARM_RANDOM) {
        int j = 0;
        while (j < FWN_NMINUTES - 1 && FWN_MINUTES[j] < *v) j++;
        j += up ? 1 : -1;
        if (j < 0) j = 0;
        if (j >= FWN_NMINUTES) j = FWN_NMINUTES - 1;
        *v = FWN_MINUTES[j];
    } else if (k == FWN_ARM_ALT) {
        *v += up ? 1000 : -1000;
        if (*v < 0) *v = 0;
        if (*v > 45000) *v = 45000;
    } else if (k == FWN_ARM_SPEED) {
        *v += up ? 10 : -10;
        if (*v < 40) *v = 40;
        if (*v > 400) *v = 400;
    }
}

/* the arm bar's value in words */
static void fw_value_words(int kind, int v, char *out, size_t n)
{
    if (kind == FWN_ARM_TIME) snprintf(out, n, "%d MIN", v);
    else if (kind == FWN_ARM_ALT) snprintf(out, n, "%d FT", v);
    else if (kind == FWN_ARM_SPEED) snprintf(out, n, "%d KT", v);
    else snprintf(out, n, "WITHIN %d MIN", v);
}

/* an armed row's trigger in words (the random one's time not told) */
static void fw_arm_words(const fw_row_t *r, char *out, size_t n)
{
    if (r->arm == FWN_ARM_TIME) {
        int s = (int)(r->arm_at - fw_now());
        if (s < 0) s = 0;
        snprintf(out, n, "IN %d:%02d", s / 60, s % 60);
    } else if (r->arm == FWN_ARM_ALT) {
        snprintf(out, n, "%s %d FT", r->arm_dir > 0 ? "ABOVE" : "BELOW", (int)r->arm_at);
    } else if (r->arm == FWN_ARM_SPEED) {
        snprintf(out, n, "%s %d KT", r->arm_dir > 0 ? "ABOVE" : "BELOW", (int)r->arm_at);
    } else if (r->arm == FWN_ARM_RANDOM) {
        snprintf(out, n, "RANDOM");
    } else {
        out[0] = 0;
    }
}

static int fw_count(void)
{
    int total = 0;
    for (int c = 0; c < fw_nchaps; c++) {
        int n = 0, a = 0;
        for (int i = fw_chaps[c].first; i < fw_chaps[c].first + fw_chaps[c].count; i++) {
            if (fw_rows[i].type != FWN_FAIL) continue;
            if (fw_state(&fw_rows[i]) == FWN_FAILED) n++;
            if (fw_rows[i].arm) a++;
        }
        fw_chaps[c].failed = n;
        fw_chaps[c].armed = a;
        total += n;
    }
    fw_total = total;
    return total;
}

/* drawing, in the window's boxels */
static void fw_rect(int l, int b, int r, int t, const float *c)
{
    XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0);
    glColor4f(c[0], c[1], c[2], c[3]);
    glBegin(GL_QUADS);
    glVertex2i(l, b);
    glVertex2i(r, b);
    glVertex2i(r, t);
    glVertex2i(l, t);
    glEnd();
}

static void fw_outline(int l, int b, int r, int t, const float *c)
{
    fw_rect(l, b, r, b + 1, c);
    fw_rect(l, t - 1, r, t, c);
    fw_rect(l, b, l + 1, t, c);
    fw_rect(r - 1, b, r, t, c);
}

static int fw_width(const char *s)
{
    return (int)XPLMMeasureString(xplmFont_Proportional, s, (int)strlen(s));
}

static void fw_text(int x, int y, float *c, const char *s)
{
    XPLMDrawString(c, x, y, s, NULL, xplmFont_Proportional);
}

static void fw_hit(int l, int b, int r, int t, int kind, int id)
{
    if (fw_nhits >= FWN_HITS) return;
    fw_hit_t *h = &fw_hits[fw_nhits++];
    h->l = l; h->b = b; h->r = r; h->t = t; h->kind = kind; h->id = id;
}

static int fw_in(int x, int y, int l, int b, int r, int t)
{
    return x >= l && x < r && y >= b && y < t;
}

/* a button: its words centred in an outline (filled when hovered) */
static void fw_button(int l, int b, int r, int t, const char *s, float *c, const float *edge, int hover)
{
    if (hover) fw_rect(l, b, r, t, FWN_HOVER);
    fw_outline(l, b, r, t, edge);
    int fh = 0;
    XPLMGetFontDimensions(xplmFont_Proportional, NULL, &fh, NULL);
    fw_text(l + (r - l - fw_width(s)) / 2, b + (t - b - fh) / 2 + 2, c, s);
}

static void fw_draw_body(XPLMWindowID w)
{
    int l, t, r, b;
    XPLMGetWindowGeometry(w, &l, &t, &r, &b);
    fw_frame++;
    fw_nhits = 0;
    int fh = 0;
    XPLMGetFontDimensions(xplmFont_Proportional, NULL, &fh, NULL);
    if (fh <= 0) fh = 12;
    int rowh = fh + 11, pad = 10;
    int hover = fw_frame - fw_hover_frame <= 2;
    int hx = fw_hover_x, hy = fw_hover_y;
    if (++fw_count_age >= 15) {
        fw_count();
        fw_count_age = 0;
    }
    fw_rect(l, b, r, t, FWN_BG);

    /* the top: the count and REPAIR ALL (X-Plane's frame has the title,
       the close and the pop-out buttons) */
    int hh = rowh + 10, hb = t - hh;
    fw_rect(l, hb, r, t, FWN_PANE);
    int ty = hb + (hh - fh) / 2 + 2;
    char buf[64];
    if (fw_total > 0) {
        snprintf(buf, sizeof buf, "%d FAILED", fw_total);
        fw_text(l + pad, ty, FWN_AMBER, buf);
    } else {
        fw_copy(buf, sizeof buf, "ALL NORMAL");
        fw_text(l + pad, ty, FWN_GREEN, buf);
    }
    if (fw_narmed > 0) {                /* (F2) and the armed ones */
        int x = l + pad + fw_width(buf) + 18;
        snprintf(buf, sizeof buf, "%d ARMED", fw_narmed);
        fw_text(x, ty, FWN_CYAN, buf);
    }
    {
        int bx1 = r - pad, bb = hb + 6, bt = t - 6;
        int bx0 = bx1 - fw_width("REPAIR ALL") - 24;
        fw_button(bx0, bb, bx1, bt, "REPAIR ALL", fw_total > 0 ? FWN_AMBER : FWN_GREY,
            fw_total > 0 ? FWN_AMBER_BOX : FWN_BUTTON, hover && fw_in(hx, hy, bx0, bb, bx1, bt));
        fw_hit(bx0, bb, bx1, bt, FWN_HIT_REPAIR, 0);
    }

    /* the bottom: how to use it, or the list's trouble; (F2) arming a
       failure: its name, the triggers, the value, ARM and CANCEL */
    int fb = b, ft = b + rowh;
    if (fw_sel >= 0 && fw_sel < fw_nrows) {
        ft = b + 2 * rowh + 8;
        fw_rect(l, fb, r, ft, FWN_PANE);
        int y1 = fb + rowh + 4;
        fw_text(l + pad, y1 + (rowh - fh) / 2 + 2, FWN_CYAN, "ARM");
        fw_text(l + pad + fw_width("ARM") + 12, y1 + (rowh - fh) / 2 + 2, FWN_WHITE, fw_rows[fw_sel].label);
        int x = l + pad, y0 = fb + 4, y2 = fb + rowh;
        for (int k = FWN_ARM_TIME; k <= FWN_ARM_RANDOM; k++) {
            int w = fw_width(FWN_KIND_WORD[k]) + 16, on = k == fw_sel_kind;
            if (on) fw_rect(x, y0, x + w, y2, FWN_CYAN_BOX);
            fw_button(x, y0, x + w, y2, FWN_KIND_WORD[k], on ? FWN_DARK : FWN_CYAN, FWN_CYAN_BOX,
                !on && hover && fw_in(hx, hy, x, y0, x + w, y2));
            fw_hit(x, y0, x + w, y2, FWN_HIT_KIND, k);
            x += w + 6;
        }
        x += 10;
        int sw = fw_width("-") + 18;
        fw_button(x, y0, x + sw, y2, "-", FWN_WHITE, FWN_BUTTON, hover && fw_in(hx, hy, x, y0, x + sw, y2));
        fw_hit(x, y0, x + sw, y2, FWN_HIT_BAR, FWN_BAR_MINUS);
        x += sw + 6;
        fw_value_words(fw_sel_kind, fw_sel_val[fw_sel_kind], buf, sizeof buf);
        int vw = fw_width("WITHIN 120 MIN") + 8;
        fw_text(x + (vw - fw_width(buf)) / 2, fb + 4 + (rowh - 4 - fh) / 2 + 2, FWN_WHITE, buf);
        x += vw + 6;
        fw_button(x, y0, x + sw, y2, "+", FWN_WHITE, FWN_BUTTON, hover && fw_in(hx, hy, x, y0, x + sw, y2));
        fw_hit(x, y0, x + sw, y2, FWN_HIT_BAR, FWN_BAR_PLUS);
        int cx1 = r - pad, cx0 = cx1 - fw_width("CANCEL") - 20;
        fw_button(cx0, y0, cx1, y2, "CANCEL", FWN_LIGHT, FWN_BUTTON, hover && fw_in(hx, hy, cx0, y0, cx1, y2));
        fw_hit(cx0, y0, cx1, y2, FWN_HIT_BAR, FWN_BAR_CANCEL);
        int ax1 = cx0 - 8, ax0 = ax1 - fw_width("ARM") - 28;
        fw_rect(ax0, y0, ax1, y2, FWN_CYAN_BOX);
        fw_button(ax0, y0, ax1, y2, "ARM", FWN_DARK, FWN_CYAN_BOX, 0);
        fw_hit(ax0, y0, ax1, y2, FWN_HIT_BAR, FWN_BAR_ARM);
    } else {
        fw_rect(l, fb, r, ft, FWN_PANE);
        fw_text(l + pad, fb + (rowh - fh) / 2 + 2, fw_note[0] ? FWN_AMBER : FWN_GREY, fw_note[0] ? fw_note :
            "Click: fail now / repair.  ARM: fail later (time, altitude, speed, random).  Wheel: scroll.");
    }

    /* the chapters */
    int top = hb - 1, bottom = ft + 1;
    int cw = (r - l) * 3 / 10;
    if (cw < 200) cw = 200;
    if (cw > 280) cw = 280;
    int cl = l, cr = l + cw;
    fw_split_x = cr;
    fw_rect(cl, bottom, cr, top, FWN_PANE);
    int ch = rowh + 4;
    int fit = (top - bottom - 8) / ch;
    if (fit < 1) fit = 1;
    if (fw_chap_scroll > fw_nchaps - fit) fw_chap_scroll = fw_nchaps - fit;
    if (fw_chap_scroll < 0) fw_chap_scroll = 0;
    int numw = fw_width("70-80") + 12;
    int y = top - 4;
    for (int c = fw_chap_scroll; c < fw_nchaps && y - ch >= bottom; c++) {
        int yt = y, yb = y - ch, sel = c == fw_chap;
        if (sel) fw_rect(cl + 4, yb + 1, cr - 4, yt - 1, FWN_SEL);
        else if (hover && fw_in(hx, hy, cl, yb, cr, yt)) fw_rect(cl + 4, yb + 1, cr - 4, yt - 1, FWN_HOVER);
        int tyc = yb + (ch - fh) / 2 + 2;
        fw_text(cl + 12, tyc, FWN_CYAN, fw_chaps[c].num);
        fw_text(cl + 12 + numw, tyc, sel ? FWN_WHITE : FWN_LIGHT, fw_chaps[c].title);
        int x1 = cr - 10;
        if (fw_chaps[c].failed > 0) {
            snprintf(buf, sizeof buf, "%d", fw_chaps[c].failed);
            int x0 = x1 - fw_width(buf) - 12;
            fw_rect(x0, yb + 4, x1, yt - 4, FWN_AMBER_BOX);
            fw_text(x0 + 6, tyc, FWN_DARK, buf);
            x1 = x0 - 4;
        }
        if (fw_chaps[c].armed > 0) {    /* (F2) armed: cyan */
            snprintf(buf, sizeof buf, "%d", fw_chaps[c].armed);
            int x0 = x1 - fw_width(buf) - 12;
            fw_outline(x0, yb + 4, x1, yt - 4, FWN_CYAN_BOX);
            fw_text(x0 + 6, tyc, FWN_CYAN, buf);
        }
        fw_hit(cl, yb, cr, yt, FWN_HIT_CHAP, c);
        y -= ch;
    }
    if (fw_nchaps > fit) {              /* the chapters' scroll bar */
        int len = (top - bottom) * fit / fw_nchaps, pos = (top - bottom - len) * fw_chap_scroll / (fw_nchaps - fit);
        fw_rect(cr - 4, top - pos - len, cr - 2, top - pos, FWN_RULE);
    }
    if (!fw_nchaps) return;

    /* the chosen chapter's failures */
    fw_chap_t *C = &fw_chaps[fw_chap];
    int pl = cr + 16, pr = r - 16;
    fit = (top - bottom - 8) / rowh;
    if (fit < 1) fit = 1;
    if (fw_scroll > C->count - fit) fw_scroll = C->count - fit;
    if (fw_scroll < 0) fw_scroll = 0;
    int boxw = fw_width("NORMAL") + 22;
    y = top - 4;
    for (int i = C->first + fw_scroll; i < C->first + C->count && y - rowh >= bottom; i++) {
        fw_row_t *R = &fw_rows[i];
        int yt = y, yb = y - rowh, tyr = yb + (rowh - fh) / 2 + 2;
        if (R->type == FWN_GROUP) {
            fw_text(pl, tyr, FWN_CYAN, R->label);
            int x0 = pl + fw_width(R->label) + 10;
            if (x0 < pr) fw_rect(x0, yb + rowh / 2 - 1, pr, yb + rowh / 2, FWN_RULE);
        } else {
            int s = fw_state(R);
            if (s != FWN_NA && hover && fw_in(hx, hy, cr, yb, r, yt)) fw_rect(pl - 6, yb + 1, pr + 6, yt - 1, FWN_HOVER);
            fw_text(pl + 12, tyr, s == FWN_NA ? FWN_GREY : FWN_WHITE, R->label);
            int x1 = pr, x0 = pr - boxw, y0 = yb + 3, y1 = yt - 3;
            const char *word = s == FWN_FAILED ? "FAILED" : s == FWN_ARMED ? "ARMED" : s == FWN_NA ? "N/A" : "NORMAL";
            int wx = x0 + (boxw - fw_width(word)) / 2;
            if (s == FWN_FAILED) {
                fw_rect(x0, y0, x1, y1, FWN_AMBER_BOX);
                fw_text(wx, tyr, FWN_DARK, word);
            } else if (s == FWN_ARMED) {
                fw_outline(x0, y0, x1, y1, FWN_CYAN_BOX);
                fw_text(wx, tyr, FWN_CYAN, word);
            } else if (s == FWN_NORMAL) {
                fw_outline(x0, y0, x1, y1, FWN_GREEN_BOX);
                fw_text(wx, tyr, FWN_GREEN, word);
            } else {
                fw_text(wx, tyr, FWN_GREY, word);
            }
            /* (F2) left of it: ARM (a normal one), or the trigger (armed) */
            int ax1 = x0 - 8;
            if (s == FWN_NORMAL) {
                int ax0 = ax1 - fw_width("ARM") - 20;
                int on = hover && fw_in(hx, hy, ax0, y0, ax1, y1);
                fw_button(ax0, y0, ax1, y1, "ARM", on || i == fw_sel ? FWN_CYAN : FWN_GREY,
                    on || i == fw_sel ? FWN_CYAN_BOX : FWN_BUTTON, on);
                fw_hit(ax0, y0, ax1, y1, FWN_HIT_ARM, i);
            } else if (s == FWN_ARMED && R->arm) {
                fw_arm_words(R, buf, sizeof buf);
                fw_text(ax1 - fw_width(buf), tyr, FWN_CYAN, buf);
            }
            if (s != FWN_NA) fw_hit(cr, yb, r, yt, FWN_HIT_ROW, i);
        }
        y -= rowh;
    }
    if (C->count > fit) {               /* the failures' scroll bar */
        int len = (top - bottom) * fit / C->count, pos = (top - bottom - len) * fw_scroll / (C->count - fit);
        fw_rect(r - 6, top - pos - len, r - 3, top - pos, FWN_RULE);
    }
}

/* X-Plane 12 calls a window's drawing with back faces culled, ours facing
   away (s242, 2026-11-04: the text drawn, none of the boxes): culling off
   while drawing, put back as it was */
static void fw_draw(XPLMWindowID w, void *ref)
{
    (void)ref;
    GLboolean cull = glIsEnabled(GL_CULL_FACE);
    if (cull) glDisable(GL_CULL_FACE);
    fw_draw_body(w);
    if (cull) glEnable(GL_CULL_FACE);
}

/* back into X-Plane's window, in the middle */
static void fw_place(XPLMWindowID w)
{
    int sl = 0, st = 0, sr = 0, sb = 0;
    XPLMGetScreenBoundsGlobal(&sl, &st, &sr, &sb);
    int ww = 780, wh = 540, cx = (sl + sr) / 2, cy = (sb + st) / 2;
    XPLMSetWindowGeometry(w, cx - ww / 2, cy + wh / 2, cx + ww / 2, cy - wh / 2);
}

static int fw_click(XPLMWindowID w, int x, int y, XPLMMouseStatus st, void *ref)
{
    (void)w; (void)ref;
    if (st != xplm_MouseDown) return 1;
    for (int k = 0; k < fw_nhits; k++) {
        fw_hit_t *h = &fw_hits[k];
        if (!fw_in(x, y, h->l, h->b, h->r, h->t)) continue;
        if (h->kind == FWN_HIT_CHAP) {
            if (fw_chap != h->id) {
                fw_chap = h->id;
                fw_scroll = 0;
            }
        } else if (h->kind == FWN_HIT_ROW) {
            fw_toggle_row(h->id);
        } else if (h->kind == FWN_HIT_REPAIR) {
            fw_repair_all();
        } else if (h->kind == FWN_HIT_ARM) {          /* (F2) the arm bar for it */
            fw_sel = h->id;
        } else if (h->kind == FWN_HIT_KIND) {
            fw_sel_kind = h->id;
        } else if (h->kind == FWN_HIT_BAR) {
            if (h->id == FWN_BAR_MINUS || h->id == FWN_BAR_PLUS) {
                fw_step(h->id == FWN_BAR_PLUS);
            } else {
                if (h->id == FWN_BAR_ARM) fw_arm(fw_sel, fw_sel_kind, fw_sel_val[fw_sel_kind]);
                fw_sel = -1;
            }
        }
        return 1;
    }
    return 1;
}

static int fw_right_click(XPLMWindowID w, int x, int y, XPLMMouseStatus st, void *ref)
{
    (void)w; (void)x; (void)y; (void)st; (void)ref;
    return 1;
}

static int fw_wheel(XPLMWindowID w, int x, int y, int wheel, int clicks, void *ref)
{
    (void)w; (void)y; (void)ref;
    if (wheel != 0) return 1;
    if (x < fw_split_x) fw_chap_scroll -= clicks;
    else fw_scroll -= clicks * 3;
    if (fw_scroll < 0) fw_scroll = 0;
    if (fw_chap_scroll < 0) fw_chap_scroll = 0;
    return 1;
}

static void fw_key(XPLMWindowID w, char key, XPLMKeyFlags flags, char vkey, void *ref, int losing)
{
    (void)w; (void)key; (void)flags; (void)vkey; (void)ref; (void)losing;
}

/* the mouse over the window (each frame it is): where, for the hover */
static XPLMCursorStatus fw_cursor(XPLMWindowID w, int x, int y, void *ref)
{
    (void)w; (void)ref;
    fw_hover_x = x;
    fw_hover_y = y;
    fw_hover_frame = fw_frame;
    return xplm_CursorDefault;
}

static int fw_shown(void)
{
    return fw_win && XPLMGetWindowIsVisible(fw_win);
}

static void fw_show(int on)
{
    if (!on) {
        if (fw_win) XPLMSetWindowIsVisible(fw_win, 0);
        return;
    }
    if (!fw_win) {
        XPLMCreateWindow_t p;
        memset(&p, 0, sizeof p);
        p.structSize = sizeof p;
        p.left = 100;
        p.top = 640;
        p.right = 880;
        p.bottom = 100;
        p.visible = 0;
        p.drawWindowFunc = fw_draw;
        p.handleMouseClickFunc = fw_click;
        p.handleRightClickFunc = fw_right_click;
        p.handleMouseWheelFunc = fw_wheel;
        p.handleKeyFunc = fw_key;
        p.handleCursorFunc = fw_cursor;
        p.refcon = NULL;
        p.layer = xplm_WindowLayerFloatingWindows;
        p.decorateAsFloatingWindow = xplm_WindowDecorationRoundRectangle;
        fw_win = XPLMCreateWindowEx(&p);
        if (!fw_win) return;
        XPLMSetWindowPositioningMode(fw_win, xplm_WindowPositionFree, -1);
        XPLMSetWindowResizingLimits(fw_win, 560, 340, 2400, 1800);
        XPLMSetWindowTitle(fw_win, "747-400 Failures");
        fw_place(fw_win);
    }
    if (!XPLMGetWindowIsVisible(fw_win)) fw_load();
    if (fw_ref_vr && XPLMGetDatai(fw_ref_vr)) {
        XPLMSetWindowPositioningMode(fw_win, xplm_WindowVR, -1);
    } else if (XPLMWindowIsInVR(fw_win)) {
        XPLMSetWindowPositioningMode(fw_win, xplm_WindowPositionFree, -1);
        fw_place(fw_win);
    }
    XPLMSetWindowIsVisible(fw_win, 1);
    XPLMBringWindowToFront(fw_win);
}

static int fw_command(XPLMCommandRef cmd, XPLMCommandPhase phase, void *ref)
{
    (void)cmd;
    if (phase != xplm_CommandBegin) return 0;
    if ((intptr_t)ref == 1) fw_show(!fw_shown());
    else fw_repair_all();
    return 0;
}

/* 0 hidden, 1 in X-Plane's window, 2 popped out, 3 in VR */
static int fw_open_get(void *ref)
{
    (void)ref;
    if (!fw_shown()) return 0;
    if (XPLMWindowIsInVR(fw_win)) return 3;
    return XPLMWindowIsPoppedOut(fw_win) ? 2 : 1;
}
static void fw_open_set(void *ref, int v) { (void)ref; fw_show(v != 0); }
static int fw_active_get(void *ref) { (void)ref; return fw_count(); }

/* the tests' click: the thing's middle as last drawn, into fw_click */
static int fw_test_last = 0;
static int fw_test_get(void *ref) { (void)ref; return fw_test_last; }
static void fw_test_set(void *ref, int v)
{
    (void)ref;
    fw_test_last = -1;
    if (!fw_shown() || v < 1000) return;
    int kind = v / 1000, id = v % 1000;
    if ((kind == FWN_HIT_ROW || kind == FWN_HIT_ARM) && fw_chap < fw_nchaps) id += fw_chaps[fw_chap].first;
    for (int k = 0; k < fw_nhits; k++) {
        fw_hit_t *h = &fw_hits[k];
        if (h->kind != kind || h->id != id) continue;
        fw_test_last = v;
        fw_click(fw_win, (h->l + h->r) / 2, (h->b + h->t) / 2, xplm_MouseDown, NULL);
        return;
    }
}
static XPLMDataRef fw_ref_test = NULL;

/* (F2) the armed count; the arm bar's value (-1 no bar) */
static int fw_armed_get(void *ref) { (void)ref; return fw_narmed; }
static int fw_armval_get(void *ref) { (void)ref; return fw_sel >= 0 ? fw_sel_val[fw_sel_kind] : -1; }

/* the menu's item */
static void fw_menu_pick(void)
{
    fw_show(!fw_shown());
}

/* VR: the window goes in and out with the headset */
static void fw_message(int msg)
{
    if (!fw_win) return;
    if (msg == XPLM_MSG_ENTERED_VR && XPLMGetWindowIsVisible(fw_win)) {
        XPLMSetWindowPositioningMode(fw_win, xplm_WindowVR, -1);
    } else if (msg == XPLM_MSG_EXITING_VR && XPLMWindowIsInVR(fw_win)) {
        XPLMSetWindowPositioningMode(fw_win, xplm_WindowPositionFree, -1);
        fw_place(fw_win);
    }
}

static void fw_start(XPLMMenuID m)
{
    fw_load();
    fw_ref_vr = XPLMFindDataRef("sim/graphics/VR/enabled");
    fw_ref_open = int_ref("laminar/B747/failures/window_open", fw_open_get, fw_open_set);
    fw_ref_active = int_ref("laminar/B747/failures/active", fw_active_get, NULL);
    fw_ref_test = int_ref("laminar/B747/failures/test_click", fw_test_get, fw_test_set);
    fw_ref_armed = int_ref("laminar/B747/failures/armed", fw_armed_get, NULL);
    fw_ref_armval = int_ref("laminar/B747/failures/arm_value", fw_armval_get, NULL);
    fw_ref_ftime = XPLMFindDataRef("sim/time/total_running_time_sec");
    fw_ref_alt = XPLMFindDataRef("sim/cockpit2/gauges/indicators/altitude_ft_pilot");
    fw_ref_ias = XPLMFindDataRef("sim/cockpit2/gauges/indicators/airspeed_kts_pilot");
    srand((unsigned)GetTickCount());
    fw_cmd_toggle = XPLMCreateCommand("laminar/B747/failures/window_toggle", "Show or hide the failure window");
    fw_cmd_repair = XPLMCreateCommand("laminar/B747/failures/repair_all", "Repair every failure in the failure window's list");
    XPLMRegisterCommandHandler(fw_cmd_toggle, fw_command, 1, (void *)1);
    XPLMRegisterCommandHandler(fw_cmd_repair, fw_command, 1, (void *)2);
    if (m) {
        XPLMAppendMenuSeparator(m);
        XPLMAppendMenuItem(m, "Failures...", (void *)(intptr_t)FWN_MENU_REF, 0);
    }
}

static void fw_stop(void)
{
    XPLMUnregisterCommandHandler(fw_cmd_toggle, fw_command, 1, (void *)1);
    XPLMUnregisterCommandHandler(fw_cmd_repair, fw_command, 1, (void *)2);
    XPLMUnregisterDataAccessor(fw_ref_open);
    XPLMUnregisterDataAccessor(fw_ref_active);
    XPLMUnregisterDataAccessor(fw_ref_test);
    XPLMUnregisterDataAccessor(fw_ref_armed);
    XPLMUnregisterDataAccessor(fw_ref_armval);
    if (fw_win) XPLMDestroyWindow(fw_win);
    fw_win = NULL;
}
