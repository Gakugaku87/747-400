/*
 * The weight and balance window (2026-11-05 the user: "the failure window's
 * plugin, a window with each weight and each CG now"), included by
 * b747_fms_bridge.c after failures_window.c (its drawing and colours).
 * Plugins > 747-400 > Weight and balance... or the command
 * laminar/B747/wb/window_toggle shows a floating window in X-Plane's own
 * frame (moved, resized, popped out, in VR), as the failure window's, with
 * X-Plane's weights and centres of gravity now, in kilograms and pounds.
 * The sim's, not the airplane's (no such page in the airplane):
 *
 *   GROSS WEIGHT       sim/flightmodel/weight/m_total
 *   ZERO FUEL WEIGHT   m_total less m_fuel_total (the FMC's and the CDU's
 *                      convenience the same: B744.fms.pages.lua)
 *   FUEL               m_fuel_total, and by tank: m_fuel[0..7], X-Plane's
 *                      CTR, MAIN 1-4, RES 2, RES 3, STAB (B747.25.xt.fuel.lua)
 *   PAYLOAD            m_fixed
 *   EMPTY              sim/aircraft/weight/acf_m_empty (the acf's)
 *   MAXIMUM            acf_m_max (the acf's)
 *   CG                 sim/flightmodel2/misc/cg_offset_z_mac (% MAC, with
 *                      the payload and the fuel)
 *   ZFW CG             zfw_cg_offset_z in % MAC: X-Plane's own MAC, WBW_MAC_PER_M
 *                      % MAC a metre aft (measured on the custom acf,
 *                      2026-11-05: 8 t and 3 t in the stabilizer tank moved
 *                      cg_offset_z 0.857 and 0.257 m aft and cg_offset_z_mac
 *                      8.17 and 2.45: 9.537 % a metre, a 10.49 m MAC; the
 *                      airplane's is 8.33 m, X-Plane's from the acf's wings)
 *
 * (2026-11-05, the user: "passengers' weight and number, cargo and fuel
 * entered here directly") LOAD: the CDU's PAX/CARGO page's load (MENU >
 * GROUND HANDLING; the FMC publishes it: laminar/B747/wb/load_zones,
 * load_cargo, load_pax_kg, load_freighter) and the fuel's total, each
 * entered here as on that page: a click on a value, digits, Enter (Escape
 * or a click elsewhere: none). On the ground only, as the page. The entry
 * goes to the FMC module (and the fuel's to the fuel module) as
 *
 *   laminar/B747/wb/req_field  (int) 0 the passengers' total, 1-5 zone A-E
 *                              (a freighter's main deck freight, kg), 6-8
 *                              cargo FWD, AFT, BULK (kg), 9 kg a
 *                              passenger, 10 the fuel's total (kg), 11 the
 *                              cargo's total (kg: the FMC shares it over
 *                              FWD, AFT and BULK in the ratio of the page's
 *                              limits; 2026-11-11 the user: "the cargo's
 *                              weight entered at once")
 *   laminar/B747/wb/req_value  (float) the value entered
 *   laminar/B747/wb/req_id     (int) counted up after each entry (the
 *                              three writable: the flight tests, others)
 *
 * which go through the page's own entries (B744.fms.pages.lua
 * B747_fms_wb_update; the fuel: B747.25.xt.fuel.lua by the refuelling's
 * order).
 *
 *   laminar/B747/wb/window_open   (int) 0 hidden, 1 shown in X-Plane's
 *                                 window, 2 popped out, 3 in VR; 1 or 0
 *                                 written shows or hides it
 *   laminar/B747/wb/window_toggle (command) shows or hides it
 */
#define WBW_MENU_REF 101       /* as b747_fms_bridge.c's */
#define WBW_TANKS 8
/* X-Plane's % MAC for a metre of cg_offset_z (+ aft), the custom acf's
   (measured, above) */
#define WBW_MAC_PER_M 9.537f
static const char *WBW_TANK[WBW_TANKS] = {"CTR", "MAIN 1", "MAIN 2", "MAIN 3", "MAIN 4", "RES 2", "RES 3", "STAB"};
static const float WBW_LB_PER_KG = 2.20462262f;
/* the load's fields (laminar/B747/wb/req_field) */
enum { WBF_PAX = 0, WBF_ZONE = 1, WBF_CARGO = 6, WBF_PAX_KG = 9, WBF_FUEL = 10, WBF_CARGO_TOTAL = 11, WBF_N = 12 };
static const char *WBW_CARGO[3] = {"  Cargo FWD", "  Cargo AFT", "  Cargo BULK"};

static XPLMWindowID wb_win = NULL;
static XPLMCommandRef wb_cmd_toggle = NULL;
static XPLMDataRef wb_ref_open = NULL;
static XPLMDataRef wb_ref_total = NULL, wb_ref_fuel = NULL, wb_ref_tanks = NULL, wb_ref_payload = NULL;
static XPLMDataRef wb_ref_empty = NULL, wb_ref_max = NULL;
static XPLMDataRef wb_ref_cg = NULL, wb_ref_cg_mac = NULL, wb_ref_zfw_cg = NULL;
static XPLMDataRef wb_ref_ground = NULL;
static XPLMDataRef wb_ref_req_id = NULL, wb_ref_req_field = NULL, wb_ref_req_value = NULL;
/* the entry asked for */
static int wb_req_id = 0, wb_req_field = -1;
static float wb_req_value = 0.0f;
/* the field being entered (-1 none) and its text; the fields' value boxes
   as last drawn (l, b, r, t; none when r <= l) */
static int wb_edit = -1;
static char wb_buf[12];
static int wb_box[WBF_N][4];

static float wb_getf(XPLMDataRef r) { return r ? XPLMGetDataf(r) : 0.0f; }

/* a whole number with thousands' commas: 285,431 */
static void wb_num(char *out, size_t n, float v)
{
    long x = (long)(v >= 0 ? v + 0.5f : v - 0.5f);
    int neg = x < 0;
    if (neg) x = -x;
    char d[32];
    int k = 0;
    do {
        if (k > 0 && k % 4 == 3) d[k++] = ',';
        d[k++] = (char)('0' + x % 10);
        x /= 10;
    } while (x > 0 && k < 30);
    if (neg) d[k++] = '-';
    size_t j = 0;
    while (k > 0 && j + 1 < n) out[j++] = d[--k];
    out[j] = 0;
}

/* the ZFW CG in % MAC, from the CG now and the metres between them */
static float wb_zfw_mac(void)
{
    return wb_getf(wb_ref_cg_mac) + (wb_getf(wb_ref_zfw_cg) - wb_getf(wb_ref_cg)) * WBW_MAC_PER_M;
}

/* a weight's row: its name, kilograms and pounds right-aligned */
static void wb_row(int l, int x_kg, int x_lb, int y, const char *name, float kg, float *c)
{
    char a[32], b[32];
    wb_num(a, sizeof a, kg);
    wb_num(b, sizeof b, kg * WBW_LB_PER_KG);
    fw_text(l, y, FWN_LIGHT, name);
    fw_text(x_kg - fw_width(a), y, c, a);
    fw_text(x_lb - fw_width(b), y, c, b);
}

/* the FMC's datarefs (XTLua's: made when its plugin loads, again with each
   aircraft load): found as drawn */
static XPLMDataRef wb_fmc(const char *name) { return XPLMFindDataRef(name); }

static int wb_on_ground(void)
{
    return wb_ref_ground ? XPLMGetDatai(wb_ref_ground) != 0 : 0;
}

/* a load's row: its name, the value (kg, or a number with pounds empty)
   in its box, cyan when it can be entered; the box being entered shows
   the text typed */
static void wb_load_row(int l, int x_kg, int x_lb, int y, int fh, int f, const char *name, float v, int is_kg, int decimals, int can)
{
    char a[32], b[32];
    fw_text(l, y, FWN_LIGHT, name);
    int bl = x_kg - 96, br = x_kg + 4, bb = y - 4, bt = y + fh + 2;
    wb_box[f][0] = bl; wb_box[f][1] = bb; wb_box[f][2] = br; wb_box[f][3] = bt;
    if (wb_edit == f) {
        snprintf(a, sizeof a, "%s_", wb_buf);
        fw_rect(bl, bb, br, bt, FWN_SEL);
        fw_text(x_kg - fw_width(a), y, FWN_WHITE, a);
        return;
    }
    if (decimals) snprintf(a, sizeof a, "%.1f", v);
    else wb_num(a, sizeof a, v);
    if (can) fw_outline(bl, bb, br, bt, FWN_RULE);
    fw_text(x_kg - fw_width(a), y, can ? FWN_CYAN : FWN_LIGHT, a);
    if (is_kg) {
        if (decimals) snprintf(b, sizeof b, "%.1f", v * WBW_LB_PER_KG);
        else wb_num(b, sizeof b, v * WBW_LB_PER_KG);
        fw_text(x_lb - fw_width(b), y, can ? FWN_CYAN : FWN_LIGHT, b);
    }
}

static void wb_draw_body(XPLMWindowID w)
{
    int l = 0, t = 0, r = 0, b = 0;
    XPLMGetWindowGeometry(w, &l, &t, &r, &b);
    int fh = 0;
    XPLMGetFontDimensions(xplmFont_Proportional, NULL, &fh, NULL);
    int lh = fh + 8, pad = 14;
    fw_rect(l, b, r, t, FWN_BG);
    int x0 = l + pad, x_kg = l + (r - l) * 62 / 100, x_lb = r - pad;
    int y = t - pad - fh;
    for (int f = 0; f < WBF_N; f++) wb_box[f][2] = wb_box[f][0];

    /* the load (the PAX/CARGO page's, the fuel's total) */
    XPLMDataRef zones = wb_fmc("laminar/B747/wb/load_zones"), cargo = wb_fmc("laminar/B747/wb/load_cargo");
    XPLMDataRef pax_kg = wb_fmc("laminar/B747/wb/load_pax_kg"), freighter = wb_fmc("laminar/B747/wb/load_freighter");
    int fmc = zones && cargo && pax_kg && freighter;
    int ground = wb_on_ground();
    int can = fmc && ground;
    if (!ground && wb_edit >= 0) {
        wb_edit = -1;
        XPLMTakeKeyboardFocus(0);
    }
    fw_text(x0, y, FWN_WHITE, "LOAD");
    fw_text(x_kg - fw_width("KG"), y, FWN_GREY, "KG");
    fw_text(x_lb - fw_width("LB"), y, FWN_GREY, "LB");
    y -= lh;
    if (fmc) {
        float z[5] = {0}, c[3] = {0};
        XPLMGetDatavf(zones, z, 0, 5);
        XPLMGetDatavf(cargo, c, 0, 3);
        int fr = XPLMGetDataf(freighter) > 0.5f;
        if (!fr) {
            float total = z[0] + z[1] + z[2] + z[3] + z[4];
            wb_load_row(x0, x_kg, x_lb, y, fh, WBF_PAX, "Passengers (total)", total, 0, 0, can);
            y -= lh;
        }
        for (int k = 0; k < 5; k++) {
            char name[48];
            snprintf(name, sizeof name, fr ? "  Main deck %c" : "  Zone %c", 'A' + k);
            wb_load_row(x0, x_kg, x_lb, y, fh, WBF_ZONE + k, name, z[k], fr, 0, can);
            y -= lh;
        }
        if (!fr) {
            wb_load_row(x0, x_kg, x_lb, y, fh, WBF_PAX_KG, "Weight a passenger", XPLMGetDataf(pax_kg), 1, 1, can);
            y -= lh;
        }
        /* the cargo's total, shared over the holds by the FMC; the holds
           under it, as the passengers' zones */
        wb_load_row(x0, x_kg, x_lb, y, fh, WBF_CARGO_TOTAL, "Cargo (total)", c[0] + c[1] + c[2], 1, 0, can);
        y -= lh;
        for (int k = 0; k < 3; k++) {
            wb_load_row(x0, x_kg, x_lb, y, fh, WBF_CARGO + k, WBW_CARGO[k], c[k], 1, 0, can);
            y -= lh;
        }
    } else {
        fw_text(x0, y, FWN_GREY, "(the FMC's load: not running)");
        y -= lh;
    }
    wb_load_row(x0, x_kg, x_lb, y, fh, WBF_FUEL, "Fuel (total)", wb_getf(wb_ref_fuel), 1, 0, ground);
    y -= lh;
    fw_text(x0, y, FWN_GREY, ground ? "Click a value, type it, Enter (as the CDU's PAX/CARGO)" : "On the ground only");
    y -= lh / 2;
    fw_rect(x0, y, x_lb, y + 1, FWN_RULE);
    y -= lh;

    /* the weights */
    fw_text(x0, y, FWN_WHITE, "WEIGHTS");
    fw_text(x_kg - fw_width("KG"), y, FWN_GREY, "KG");
    fw_text(x_lb - fw_width("LB"), y, FWN_GREY, "LB");
    y -= lh;
    float total = wb_getf(wb_ref_total), fuel = wb_getf(wb_ref_fuel);
    wb_row(x0, x_kg, x_lb, y, "Gross weight", total, FWN_GREEN);
    y -= lh;
    wb_row(x0, x_kg, x_lb, y, "Zero fuel weight", total - fuel, FWN_GREEN);
    y -= lh;
    wb_row(x0, x_kg, x_lb, y, "Fuel", fuel, FWN_GREEN);
    y -= lh;
    wb_row(x0, x_kg, x_lb, y, "Payload", wb_getf(wb_ref_payload), FWN_GREEN);
    y -= lh;
    wb_row(x0, x_kg, x_lb, y, "Empty (acf)", wb_getf(wb_ref_empty), FWN_LIGHT);
    y -= lh;
    wb_row(x0, x_kg, x_lb, y, "Maximum (acf)", wb_getf(wb_ref_max), FWN_LIGHT);
    y -= lh / 2;
    fw_rect(x0, y, x_lb, y + 1, FWN_RULE);
    y -= lh;

    /* the centres of gravity */
    char v[32];
    fw_text(x0, y, FWN_WHITE, "CENTRE OF GRAVITY");
    fw_text(x_lb - fw_width("% MAC"), y, FWN_GREY, "% MAC");
    y -= lh;
    fw_text(x0, y, FWN_LIGHT, "CG (payload and fuel)");
    snprintf(v, sizeof v, "%.1f", wb_getf(wb_ref_cg_mac));
    fw_text(x_lb - fw_width(v), y, FWN_GREEN, v);
    y -= lh;
    fw_text(x0, y, FWN_LIGHT, "Zero fuel weight CG");
    snprintf(v, sizeof v, "%.1f", wb_zfw_mac());
    fw_text(x_lb - fw_width(v), y, FWN_GREEN, v);
    y -= lh / 2;
    fw_rect(x0, y, x_lb, y + 1, FWN_RULE);
    y -= lh;

    /* the fuel by tank */
    fw_text(x0, y, FWN_WHITE, "FUEL BY TANK");
    fw_text(x_kg - fw_width("KG"), y, FWN_GREY, "KG");
    fw_text(x_lb - fw_width("LB"), y, FWN_GREY, "LB");
    y -= lh;
    float tanks[WBW_TANKS];
    memset(tanks, 0, sizeof tanks);
    if (wb_ref_tanks) XPLMGetDatavf(wb_ref_tanks, tanks, 0, WBW_TANKS);
    for (int i = 0; i < WBW_TANKS && y > b + pad; i++) {
        wb_row(x0, x_kg, x_lb, y, WBW_TANK[i], tanks[i], FWN_GREEN);
        y -= lh;
    }
}

/* culling off while drawing (as the failure window's: X-Plane 12) */
static void wb_draw(XPLMWindowID w, void *ref)
{
    (void)ref;
    GLboolean cull = glIsEnabled(GL_CULL_FACE);
    if (cull) glDisable(GL_CULL_FACE);
    wb_draw_body(w);
    if (cull) glEnable(GL_CULL_FACE);
}

/* (2026-11-11 review) the height (px) of the rows through the one `rows`
   steps (of fh + 8) under the first, at X-Plane's font, the pads and a row
   for the last one's descenders (wb_draw_body's layout, the passengers'
   load: the freighter's has two rows fewer) */
#define WBW_ROWS_ALL 33.5           /* the last tank's row (8 tanks) */
#define WBW_ROWS_MIN 25.5           /* the FUEL BY TANK heading */
static int wb_rows_height(double rows)
{
    int fh = 0;
    XPLMGetFontDimensions(xplmFont_Proportional, NULL, &fh, NULL);
    int lh = fh + 8, pad = 14;
    return pad + fh + (int)((rows + 1.0) * lh + 0.5) + pad;
}

/* back into X-Plane's window, left of the middle; (2026-11-11 review) high
   enough for every row (before, 760: with the cargo's total row the last
   two tanks were cut) */
static void wb_place(XPLMWindowID w)
{
    int sl = 0, st = 0, sr = 0, sb = 0;
    XPLMGetScreenBoundsGlobal(&sl, &st, &sr, &sb);
    int ww = 440, wh = wb_rows_height(WBW_ROWS_ALL), cx = (sl + sr) / 2 - 300, cy = (sb + st) / 2;
    if (wh > st - sb - 40) wh = st - sb - 40;
    XPLMSetWindowGeometry(w, cx - ww / 2, cy + wh / 2, cx + ww / 2, cy - wh / 2);
}

static void wb_edit_end(void)
{
    if (wb_edit < 0) return;
    wb_edit = -1;
    if (wb_win && XPLMHasKeyboardFocus(wb_win)) XPLMTakeKeyboardFocus(0);
}

/* the entry: to the FMC (and the fuel module) through req_field,
   req_value and req_id */
static void wb_edit_commit(void)
{
    if (wb_edit >= 0 && wb_buf[0]) {
        char *end = NULL;
        double v = strtod(wb_buf, &end);
        if (end && *end == 0 && v >= 0.0) {
            wb_req_field = wb_edit;
            wb_req_value = (float)v;
            wb_req_id++;
        }
    }
    wb_edit_end();
}

static int wb_click(XPLMWindowID w, int x, int y, XPLMMouseStatus st, void *ref)
{
    (void)ref;
    if (st != xplm_MouseDown) return 1;
    for (int f = 0; f < WBF_N; f++) {
        int *k = wb_box[f];
        if (k[2] <= k[0] || !fw_in(x, y, k[0], k[1], k[2], k[3])) continue;
        if (!wb_on_ground()) break;
        wb_edit = f;
        wb_buf[0] = 0;
        XPLMTakeKeyboardFocus(w);
        return 1;
    }
    wb_edit_end();
    return 1;
}
static int wb_wheel(XPLMWindowID w, int x, int y, int wheel, int clicks, void *ref)
{
    (void)w; (void)x; (void)y; (void)wheel; (void)clicks; (void)ref;
    return 1;
}
/* the value's digits and point, Backspace, Enter; Escape or the focus
   lost: none */
static void wb_key(XPLMWindowID w, char key, XPLMKeyFlags flags, char vkey, void *ref, int losing)
{
    (void)w; (void)ref;
    if (losing) {
        wb_edit = -1;
        return;
    }
    if (wb_edit < 0 || !(flags & xplm_DownFlag)) return;
    unsigned char vk = (unsigned char)vkey;
    size_t n = strlen(wb_buf);
    if (vk == XPLM_VK_RETURN || vk == XPLM_VK_ENTER || vk == XPLM_VK_NUMPAD_ENT || key == '\r' || key == '\n') {
        wb_edit_commit();
    } else if (vk == XPLM_VK_ESCAPE) {
        wb_edit_end();
    } else if (vk == XPLM_VK_BACK || vk == XPLM_VK_DELETE) {
        if (n > 0) wb_buf[n - 1] = 0;
    } else if (((key >= '0' && key <= '9') || (key == '.' && !strchr(wb_buf, '.'))) && n + 1 < sizeof wb_buf) {
        wb_buf[n] = key;
        wb_buf[n + 1] = 0;
    }
}
static XPLMCursorStatus wb_cursor(XPLMWindowID w, int x, int y, void *ref)
{
    (void)w; (void)x; (void)y; (void)ref;
    return xplm_CursorDefault;
}

static int wb_shown(void)
{
    return wb_win && XPLMGetWindowIsVisible(wb_win);
}

static void wb_show(int on)
{
    if (!on) {
        wb_edit_end();
        if (wb_win) XPLMSetWindowIsVisible(wb_win, 0);
        return;
    }
    if (!wb_win) {
        XPLMCreateWindow_t p;
        memset(&p, 0, sizeof p);
        p.structSize = sizeof p;
        p.left = 100;
        p.top = 860;
        p.right = 540;
        p.bottom = 100;
        p.visible = 0;
        p.drawWindowFunc = wb_draw;
        p.handleMouseClickFunc = wb_click;
        p.handleRightClickFunc = wb_click;
        p.handleMouseWheelFunc = wb_wheel;
        p.handleKeyFunc = wb_key;
        p.handleCursorFunc = wb_cursor;
        p.refcon = NULL;
        p.layer = xplm_WindowLayerFloatingWindows;
        p.decorateAsFloatingWindow = xplm_WindowDecorationRoundRectangle;
        wb_win = XPLMCreateWindowEx(&p);
        if (!wb_win) return;
        XPLMSetWindowPositioningMode(wb_win, xplm_WindowPositionFree, -1);
        /* (2026-11-06 review) at least LOAD, WEIGHTS and CENTRE OF GRAVITY
           high: only the tanks' rows stop at the bottom. Before, 420:
           shrunk, the rows above the tanks were drawn below the window.
           (2026-11-11 review) through the FUEL BY TANK heading at X-Plane's
           font (wb_rows_height); before, 600, short of it once the cargo's
           total row came */
        XPLMSetWindowResizingLimits(wb_win, 340, wb_rows_height(WBW_ROWS_MIN), 1200, 1600);
        XPLMSetWindowTitle(wb_win, "747-400 Weight and Balance");
        wb_place(wb_win);
    }
    if (fw_ref_vr && XPLMGetDatai(fw_ref_vr)) {
        XPLMSetWindowPositioningMode(wb_win, xplm_WindowVR, -1);
    } else if (XPLMWindowIsInVR(wb_win)) {
        XPLMSetWindowPositioningMode(wb_win, xplm_WindowPositionFree, -1);
        wb_place(wb_win);
    }
    XPLMSetWindowIsVisible(wb_win, 1);
    XPLMBringWindowToFront(wb_win);
}

static int wb_command(XPLMCommandRef cmd, XPLMCommandPhase phase, void *ref)
{
    (void)cmd; (void)ref;
    if (phase == xplm_CommandBegin) wb_show(!wb_shown());
    return 0;
}

/* 0 hidden, 1 in X-Plane's window, 2 popped out, 3 in VR */
static int wb_open_get(void *ref)
{
    (void)ref;
    if (!wb_shown()) return 0;
    if (XPLMWindowIsInVR(wb_win)) return 3;
    return XPLMWindowIsPoppedOut(wb_win) ? 2 : 1;
}
static void wb_open_set(void *ref, int v) { (void)ref; wb_show(v != 0); }
/* the entry's datarefs: written by this window, and writable for the
   flight tests and other add-ons (an entry: req_field and req_value, then
   req_id counted up) */
static int wb_req_id_get(void *ref) { (void)ref; return wb_req_id; }
static void wb_req_id_set(void *ref, int v) { (void)ref; wb_req_id = v; }
static int wb_req_field_get(void *ref) { (void)ref; return wb_req_field; }
static void wb_req_field_set(void *ref, int v) { (void)ref; wb_req_field = v; }
static float wb_req_value_get(void *ref) { (void)ref; return wb_req_value; }
static void wb_req_value_set(void *ref, float v) { (void)ref; wb_req_value = v; }

static void wb_menu_pick(void)
{
    wb_show(!wb_shown());
}

/* VR: the window goes in and out with the headset */
static void wb_message(int msg)
{
    if (!wb_win) return;
    if (msg == XPLM_MSG_ENTERED_VR && XPLMGetWindowIsVisible(wb_win)) {
        XPLMSetWindowPositioningMode(wb_win, xplm_WindowVR, -1);
    } else if (msg == XPLM_MSG_EXITING_VR && XPLMWindowIsInVR(wb_win)) {
        XPLMSetWindowPositioningMode(wb_win, xplm_WindowPositionFree, -1);
        wb_place(wb_win);
    }
}

static void wb_start(XPLMMenuID m)
{
    wb_ref_total = XPLMFindDataRef("sim/flightmodel/weight/m_total");
    wb_ref_fuel = XPLMFindDataRef("sim/flightmodel/weight/m_fuel_total");
    wb_ref_tanks = XPLMFindDataRef("sim/flightmodel/weight/m_fuel");
    wb_ref_payload = XPLMFindDataRef("sim/flightmodel/weight/m_fixed");
    wb_ref_empty = XPLMFindDataRef("sim/aircraft/weight/acf_m_empty");
    wb_ref_max = XPLMFindDataRef("sim/aircraft/weight/acf_m_max");
    wb_ref_cg = XPLMFindDataRef("sim/flightmodel2/misc/cg_offset_z");
    wb_ref_cg_mac = XPLMFindDataRef("sim/flightmodel2/misc/cg_offset_z_mac");
    wb_ref_zfw_cg = XPLMFindDataRef("sim/flightmodel2/misc/zfw_cg_offset_z");
    wb_ref_ground = XPLMFindDataRef("sim/flightmodel/failures/onground_any");
    wb_ref_open = int_ref("laminar/B747/wb/window_open", wb_open_get, wb_open_set);
    wb_ref_req_id = int_ref("laminar/B747/wb/req_id", wb_req_id_get, wb_req_id_set);
    wb_ref_req_field = int_ref("laminar/B747/wb/req_field", wb_req_field_get, wb_req_field_set);
    wb_ref_req_value = XPLMRegisterDataAccessor("laminar/B747/wb/req_value", xplmType_Float, 1,
        NULL, NULL, wb_req_value_get, wb_req_value_set, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
    wb_cmd_toggle = XPLMCreateCommand("laminar/B747/wb/window_toggle", "Show or hide the weight and balance window");
    XPLMRegisterCommandHandler(wb_cmd_toggle, wb_command, 1, NULL);
    if (m) XPLMAppendMenuItem(m, "Weight and balance...", (void *)(intptr_t)WBW_MENU_REF, 0);
}

static void wb_stop(void)
{
    XPLMUnregisterCommandHandler(wb_cmd_toggle, wb_command, 1, NULL);
    XPLMUnregisterDataAccessor(wb_ref_open);
    XPLMUnregisterDataAccessor(wb_ref_req_id);
    XPLMUnregisterDataAccessor(wb_ref_req_field);
    XPLMUnregisterDataAccessor(wb_ref_req_value);
    if (wb_win) XPLMDestroyWindow(wb_win);
    wb_win = NULL;
}
