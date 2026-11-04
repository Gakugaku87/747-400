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
 * The list: failures.txt in this plugin's folder (its format there), read
 * when the plugin starts and whenever the window is shown. A failure's
 * dataref is looked for when first needed (XTLua makes the airplane's after
 * the plugins start), again each second while it is not there.
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
 *                                        its groups counted), 3000 REPAIR ALL;
 *                                        reads back the value clicked, -1
 *                                        none drawn
 */
#include <math.h>
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
enum { FWN_HIT_CHAP = 1, FWN_HIT_ROW, FWN_HIT_REPAIR };

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
} fw_row_t;

typedef struct {
    char num[8];
    char title[40];
    int first, count;       /* its rows */
    int failed;             /* failed at the last count */
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

/* the list: "C <chapter> <title>", "G <title>", "F <dataref>[i] <kind> <label>" */
static void fw_load(void)
{
    char path[PATH_LEN], line[320];
    fw_nrows = 0;
    fw_nchaps = 0;
    fw_note[0] = 0;
    fw_list_path(path, sizeof path);
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

static int fw_state(fw_row_t *r)
{
    float v = 0.0f;
    if (!fw_read(r, &v)) return FWN_NA;
    if (r->xp) {
        int x = (int)lroundf(v);
        if (x == 6) return FWN_FAILED;
        return x == 0 ? FWN_NORMAL : FWN_ARMED;
    }
    if (r->failed == 1.0f) return v > 0.5f ? FWN_FAILED : FWN_NORMAL;
    return fabsf(v - r->failed) < 0.25f ? FWN_FAILED : FWN_NORMAL;
}

/* a click: failed now, or repaired */
static void fw_toggle_row(int i)
{
    if (i < 0 || i >= fw_nrows || fw_rows[i].type != FWN_FAIL) return;
    fw_row_t *r = &fw_rows[i];
    int s = fw_state(r);
    if (s == FWN_NA) return;
    fw_write(r, s == FWN_FAILED ? 0.0f : r->failed);
    fw_count_age = 1000;
}

static void fw_repair_all(void)
{
    for (int i = 0; i < fw_nrows; i++) {
        fw_row_t *r = &fw_rows[i];
        if (r->type != FWN_FAIL) continue;
        int s = fw_state(r);
        if (s == FWN_FAILED || s == FWN_ARMED) fw_write(r, 0.0f);
    }
    fw_count_age = 1000;
}

static int fw_count(void)
{
    int total = 0;
    for (int c = 0; c < fw_nchaps; c++) {
        int n = 0;
        for (int i = fw_chaps[c].first; i < fw_chaps[c].first + fw_chaps[c].count; i++) {
            if (fw_rows[i].type == FWN_FAIL && fw_state(&fw_rows[i]) == FWN_FAILED) n++;
        }
        fw_chaps[c].failed = n;
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
        fw_text(l + pad, ty, FWN_GREEN, "ALL NORMAL");
    }
    {
        int bx1 = r - pad, bb = hb + 6, bt = t - 6;
        int bx0 = bx1 - fw_width("REPAIR ALL") - 24;
        fw_button(bx0, bb, bx1, bt, "REPAIR ALL", fw_total > 0 ? FWN_AMBER : FWN_GREY,
            fw_total > 0 ? FWN_AMBER_BOX : FWN_BUTTON, hover && fw_in(hx, hy, bx0, bb, bx1, bt));
        fw_hit(bx0, bb, bx1, bt, FWN_HIT_REPAIR, 0);
    }

    /* the bottom: how to use it, or the list's trouble */
    int fb = b, ft = b + rowh;
    fw_rect(l, fb, r, ft, FWN_PANE);
    fw_text(l + pad, fb + (rowh - fh) / 2 + 2, fw_note[0] ? FWN_AMBER : FWN_GREY, fw_note[0] ? fw_note :
        "Click a failure to fail it now, again to repair it. Mouse wheel scrolls.");

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
        if (fw_chaps[c].failed > 0) {
            snprintf(buf, sizeof buf, "%d", fw_chaps[c].failed);
            int bw = fw_width(buf) + 12, x1 = cr - 10, x0 = x1 - bw;
            fw_rect(x0, yb + 4, x1, yt - 4, FWN_AMBER_BOX);
            fw_text(x0 + 6, tyc, FWN_DARK, buf);
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
    if (kind == FWN_HIT_ROW && fw_chap < fw_nchaps) id += fw_chaps[fw_chap].first;
    for (int k = 0; k < fw_nhits; k++) {
        fw_hit_t *h = &fw_hits[k];
        if (h->kind != kind || h->id != id) continue;
        fw_test_last = v;
        fw_click(fw_win, (h->l + h->r) / 2, (h->b + h->t) / 2, xplm_MouseDown, NULL);
        return;
    }
}
static XPLMDataRef fw_ref_test = NULL;

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
    if (fw_win) XPLMDestroyWindow(fw_win);
    fw_win = NULL;
}
