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

static XPLMWindowID wb_win = NULL;
static XPLMCommandRef wb_cmd_toggle = NULL;
static XPLMDataRef wb_ref_open = NULL;
static XPLMDataRef wb_ref_total = NULL, wb_ref_fuel = NULL, wb_ref_tanks = NULL, wb_ref_payload = NULL;
static XPLMDataRef wb_ref_empty = NULL, wb_ref_max = NULL;
static XPLMDataRef wb_ref_cg = NULL, wb_ref_cg_mac = NULL, wb_ref_zfw_cg = NULL;

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

/* back into X-Plane's window, left of the middle */
static void wb_place(XPLMWindowID w)
{
    int sl = 0, st = 0, sr = 0, sb = 0;
    XPLMGetScreenBoundsGlobal(&sl, &st, &sr, &sb);
    int ww = 420, wh = 440, cx = (sl + sr) / 2 - 300, cy = (sb + st) / 2;
    XPLMSetWindowGeometry(w, cx - ww / 2, cy + wh / 2, cx + ww / 2, cy - wh / 2);
}

static int wb_click(XPLMWindowID w, int x, int y, XPLMMouseStatus st, void *ref)
{
    (void)w; (void)x; (void)y; (void)st; (void)ref;
    return 1;
}
static int wb_wheel(XPLMWindowID w, int x, int y, int wheel, int clicks, void *ref)
{
    (void)w; (void)x; (void)y; (void)wheel; (void)clicks; (void)ref;
    return 1;
}
static void wb_key(XPLMWindowID w, char key, XPLMKeyFlags flags, char vkey, void *ref, int losing)
{
    (void)w; (void)key; (void)flags; (void)vkey; (void)ref; (void)losing;
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
        if (wb_win) XPLMSetWindowIsVisible(wb_win, 0);
        return;
    }
    if (!wb_win) {
        XPLMCreateWindow_t p;
        memset(&p, 0, sizeof p);
        p.structSize = sizeof p;
        p.left = 100;
        p.top = 620;
        p.right = 520;
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
        XPLMSetWindowResizingLimits(wb_win, 320, 360, 1200, 1400);
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
    wb_ref_open = int_ref("laminar/B747/wb/window_open", wb_open_get, wb_open_set);
    wb_cmd_toggle = XPLMCreateCommand("laminar/B747/wb/window_toggle", "Show or hide the weight and balance window");
    XPLMRegisterCommandHandler(wb_cmd_toggle, wb_command, 1, NULL);
    if (m) XPLMAppendMenuItem(m, "Weight and balance...", (void *)(intptr_t)WBW_MENU_REF, 0);
}

static void wb_stop(void)
{
    XPLMUnregisterCommandHandler(wb_cmd_toggle, wb_command, 1, NULL);
    XPLMUnregisterDataAccessor(wb_ref_open);
    if (wb_win) XPLMDestroyWindow(wb_win);
    wb_win = NULL;
}
