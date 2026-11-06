/*
 * The ground handling window (2026-11-05 the user: "a Ground Handling
 * window in the plugin, the GPU, the ASU and the chocks put on and taken
 * off from there"), included by b747_fms_bridge.c after failures_window.c
 * (its drawing, colours and buttons). Plugins > 747-400 > Ground
 * handling... or the command laminar/B747/gh/window_toggle shows a floating
 * window, as the failure window's. Each row is a ground service's state and
 * a button that gives the airplane's own command for it, as the CDU's
 * GROUND HANDLING pages do (the sim's, not the airplane's):
 *
 *   GROUND POWER   laminar/B747/electrical/connect_power (B747.03.xt.
 *                  electrical.lua: X-Plane's truck, or a cart without one;
 *                  on the ground standing); connected: ext_pwr1_avail,
 *                  asked for: ext_pwr_requested
 *   GROUND AIR     laminar/B747/air/ground_air/connect (the air module:
 *                  notes/ATA-36.md §11); connected: ground_air/connected
 *   CHOCKS         laminar/B747/gear/chocks_toggle (B744.fms.pages.lua: as
 *                  GROUND HANDLING's L2; out, a refuelling stops); in:
 *                  laminar/B747/gear/chocked
 *
 *   laminar/B747/gh/window_open   (int) 0 hidden, 1 shown in X-Plane's
 *                                 window, 2 popped out, 3 in VR; 1 or 0
 *                                 written shows or hides it
 *   laminar/B747/gh/window_toggle (command) shows or hides it
 */
#define GHW_MENU_REF 102       /* as b747_fms_bridge.c's */
#define GHW_ROWS 3

static XPLMWindowID gh_win = NULL;
static XPLMCommandRef gh_cmd_toggle = NULL;
static XPLMDataRef gh_ref_open = NULL;
/* (2026-11-06 review) the mouse's place and the frame it was there: X-Plane
   asks the cursor only while the mouse is over the window, so a button
   stayed lit after the mouse had left (the failure window's fw_hover_frame) */
static int gh_hover_x = -1, gh_hover_y = -1, gh_hover_frame = -100, gh_frame = 0;
/* each row's button as last drawn (l, b, r, t; none when r <= l) */
static int gh_box[GHW_ROWS][4];
static const char *GHW_CMD[GHW_ROWS] = {
    "laminar/B747/electrical/connect_power",
    "laminar/B747/air/ground_air/connect",
    "laminar/B747/gear/chocks_toggle",
};

/* the airplane's datarefs (XTLua's: made when its plugins load, again with
   each aircraft load): found as drawn; -1 when there is none */
static float gh_get(const char *name)
{
    XPLMDataRef r = XPLMFindDataRef(name);
    return r ? XPLMGetDataf(r) : -1.0f;
}

/* a row: its name, its state, its button */
static void gh_row(int x0, int x_state, int x_btn, int r, int y, int fh, int k, const char *name, const char *state, float *c, const char *btn)
{
    fw_text(x0, y, FWN_LIGHT, name);
    fw_text(x_state, y, c, state);
    int bl = x_btn, br = r, bb = y - 5, bt = y + fh + 4;
    gh_box[k][0] = bl; gh_box[k][1] = bb; gh_box[k][2] = br; gh_box[k][3] = bt;
    int hover = gh_frame - gh_hover_frame <= 2 && fw_in(gh_hover_x, gh_hover_y, bl, bb, br, bt);
    fw_button(bl, bb, br, bt, btn, FWN_WHITE, FWN_BUTTON, hover);
}

static void gh_draw_body(XPLMWindowID w)
{
    int l = 0, t = 0, r = 0, b = 0;
    XPLMGetWindowGeometry(w, &l, &t, &r, &b);
    int fh = 0;
    XPLMGetFontDimensions(xplmFont_Proportional, NULL, &fh, NULL);
    int lh = fh + 16, pad = 14;
    fw_rect(l, b, r, t, FWN_BG);
    int x0 = l + pad, x_state = l + (r - l) * 40 / 100, x_btn = l + (r - l) * 68 / 100, xr = r - pad;
    int y = t - pad - fh;
    for (int k = 0; k < GHW_ROWS; k++) gh_box[k][2] = gh_box[k][0];
    fw_text(x0, y, FWN_WHITE, "GROUND HANDLING");
    y -= lh;

    /* ground power: connected, asked for (X-Plane's truck on its way), none */
    float avail = gh_get("laminar/B747/electrical/ext_pwr1_avail");
    float asked = gh_get("laminar/B747/electrical/ext_pwr_requested");
    if (avail < 0) gh_row(x0, x_state, x_btn, xr, y, fh, 0, "Ground power (GPU)", "-", FWN_GREY, "-");
    else if (avail > 0.5f) gh_row(x0, x_state, x_btn, xr, y, fh, 0, "Ground power (GPU)", "CONNECTED", FWN_GREEN, "DISCONNECT");
    else if (asked > 0.5f) gh_row(x0, x_state, x_btn, xr, y, fh, 0, "Ground power (GPU)", "REQUESTED", FWN_AMBER, "CANCEL");
    else gh_row(x0, x_state, x_btn, xr, y, fh, 0, "Ground power (GPU)", "NOT CONNECTED", FWN_GREY, "CONNECT");
    y -= lh;

    /* ground air */
    float air = gh_get("laminar/B747/air/ground_air/connected");
    if (air < 0) gh_row(x0, x_state, x_btn, xr, y, fh, 1, "Ground air (ASU)", "-", FWN_GREY, "-");
    else if (air > 0.5f) gh_row(x0, x_state, x_btn, xr, y, fh, 1, "Ground air (ASU)", "CONNECTED", FWN_GREEN, "REMOVE");
    else gh_row(x0, x_state, x_btn, xr, y, fh, 1, "Ground air (ASU)", "NOT CONNECTED", FWN_GREY, "CONNECT");
    y -= lh;

    /* the chocks */
    float chocks = gh_get("laminar/B747/gear/chocked");
    if (chocks < 0) gh_row(x0, x_state, x_btn, xr, y, fh, 2, "Chocks", "-", FWN_GREY, "-");
    else if (chocks > 0.5f) gh_row(x0, x_state, x_btn, xr, y, fh, 2, "Chocks", "IN PLACE", FWN_GREEN, "REMOVE");
    else gh_row(x0, x_state, x_btn, xr, y, fh, 2, "Chocks", "REMOVED", FWN_GREY, "PLACE");
    y -= lh;
    fw_text(x0, y, FWN_GREY, "The CDU's GROUND HANDLING does the same");
}

/* culling off while drawing (as the failure window's: X-Plane 12) */
static void gh_draw(XPLMWindowID w, void *ref)
{
    (void)ref;
    gh_frame++;
    GLboolean cull = glIsEnabled(GL_CULL_FACE);
    if (cull) glDisable(GL_CULL_FACE);
    gh_draw_body(w);
    if (cull) glEnable(GL_CULL_FACE);
}

/* back into X-Plane's window, right of the middle */
static void gh_place(XPLMWindowID w)
{
    int sl = 0, st = 0, sr = 0, sb = 0;
    XPLMGetScreenBoundsGlobal(&sl, &st, &sr, &sb);
    int ww = 460, wh = 190, cx = (sl + sr) / 2 + 300, cy = (sb + st) / 2;
    XPLMSetWindowGeometry(w, cx - ww / 2, cy + wh / 2, cx + ww / 2, cy - wh / 2);
}

/* a button: the airplane's command for it, once */
static int gh_click(XPLMWindowID w, int x, int y, XPLMMouseStatus st, void *ref)
{
    (void)w; (void)ref;
    if (st != xplm_MouseDown) return 1;
    for (int k = 0; k < GHW_ROWS; k++) {
        int *b = gh_box[k];
        if (b[2] <= b[0] || !fw_in(x, y, b[0], b[1], b[2], b[3])) continue;
        XPLMCommandRef c = XPLMFindCommand(GHW_CMD[k]);
        if (c) XPLMCommandOnce(c);
        break;
    }
    return 1;
}
static int gh_wheel(XPLMWindowID w, int x, int y, int wheel, int clicks, void *ref)
{
    (void)w; (void)x; (void)y; (void)wheel; (void)clicks; (void)ref;
    return 1;
}
static void gh_key(XPLMWindowID w, char key, XPLMKeyFlags flags, char vkey, void *ref, int losing)
{
    (void)w; (void)key; (void)flags; (void)vkey; (void)ref; (void)losing;
}
/* the mouse over the window: where, for the buttons' hover */
static XPLMCursorStatus gh_cursor(XPLMWindowID w, int x, int y, void *ref)
{
    (void)w; (void)ref;
    gh_hover_x = x;
    gh_hover_y = y;
    gh_hover_frame = gh_frame;
    return xplm_CursorDefault;
}

static int gh_shown(void)
{
    return gh_win && XPLMGetWindowIsVisible(gh_win);
}

static void gh_show(int on)
{
    if (!on) {
        if (gh_win) XPLMSetWindowIsVisible(gh_win, 0);
        return;
    }
    if (!gh_win) {
        XPLMCreateWindow_t p;
        memset(&p, 0, sizeof p);
        p.structSize = sizeof p;
        p.left = 600;
        p.top = 400;
        p.right = 1060;
        p.bottom = 210;
        p.visible = 0;
        p.drawWindowFunc = gh_draw;
        p.handleMouseClickFunc = gh_click;
        p.handleRightClickFunc = gh_click;
        p.handleMouseWheelFunc = gh_wheel;
        p.handleKeyFunc = gh_key;
        p.handleCursorFunc = gh_cursor;
        p.refcon = NULL;
        p.layer = xplm_WindowLayerFloatingWindows;
        p.decorateAsFloatingWindow = xplm_WindowDecorationRoundRectangle;
        gh_win = XPLMCreateWindowEx(&p);
        if (!gh_win) return;
        XPLMSetWindowPositioningMode(gh_win, xplm_WindowPositionFree, -1);
        XPLMSetWindowResizingLimits(gh_win, 380, 170, 1000, 600);
        XPLMSetWindowTitle(gh_win, "747-400 Ground Handling");
        gh_place(gh_win);
    }
    if (fw_ref_vr && XPLMGetDatai(fw_ref_vr)) {
        XPLMSetWindowPositioningMode(gh_win, xplm_WindowVR, -1);
    } else if (XPLMWindowIsInVR(gh_win)) {
        XPLMSetWindowPositioningMode(gh_win, xplm_WindowPositionFree, -1);
        gh_place(gh_win);
    }
    XPLMSetWindowIsVisible(gh_win, 1);
    XPLMBringWindowToFront(gh_win);
}

static int gh_command(XPLMCommandRef cmd, XPLMCommandPhase phase, void *ref)
{
    (void)cmd; (void)ref;
    if (phase == xplm_CommandBegin) gh_show(!gh_shown());
    return 0;
}

/* 0 hidden, 1 in X-Plane's window, 2 popped out, 3 in VR */
static int gh_open_get(void *ref)
{
    (void)ref;
    if (!gh_shown()) return 0;
    if (XPLMWindowIsInVR(gh_win)) return 3;
    return XPLMWindowIsPoppedOut(gh_win) ? 2 : 1;
}
static void gh_open_set(void *ref, int v) { (void)ref; gh_show(v != 0); }

static void gh_menu_pick(void)
{
    gh_show(!gh_shown());
}

/* VR: the window goes in and out with the headset */
static void gh_message(int msg)
{
    if (!gh_win) return;
    if (msg == XPLM_MSG_ENTERED_VR && XPLMGetWindowIsVisible(gh_win)) {
        XPLMSetWindowPositioningMode(gh_win, xplm_WindowVR, -1);
    } else if (msg == XPLM_MSG_EXITING_VR && XPLMWindowIsInVR(gh_win)) {
        XPLMSetWindowPositioningMode(gh_win, xplm_WindowPositionFree, -1);
        gh_place(gh_win);
    }
}

static void gh_start(XPLMMenuID m)
{
    gh_ref_open = int_ref("laminar/B747/gh/window_open", gh_open_get, gh_open_set);
    gh_cmd_toggle = XPLMCreateCommand("laminar/B747/gh/window_toggle", "Show or hide the ground handling window");
    XPLMRegisterCommandHandler(gh_cmd_toggle, gh_command, 1, NULL);
    if (m) XPLMAppendMenuItem(m, "Ground handling...", (void *)(intptr_t)GHW_MENU_REF, 0);
}

static void gh_stop(void)
{
    XPLMUnregisterCommandHandler(gh_cmd_toggle, gh_command, 1, NULL);
    XPLMUnregisterDataAccessor(gh_ref_open);
    if (gh_win) XPLMDestroyWindow(gh_win);
    gh_win = NULL;
}
