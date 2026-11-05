/*
 * The ND's route line (6-1/6-2 step 6d2; docs/overhaul/notes/
 * ATA-34-61-FMC.md §132; FCOM p.1147-1148), included by b747_fms_bridge.c.
 *
 * X-Plane's EFIS map drew the flight plan's line straight from row to row
 * with turns of its own (a turn of more than 135 degrees broke up: s198's
 * ATMUG). The map stays for the weather radar (X-Plane's basemap draws
 * none), its line gone: the FMC makes X-Plane's current waypoint its plan's
 * last row (X-Plane's map draws the legs from its current waypoint on). This
 * draws the FMC's path:
 *
 *   laminar/B747/nd/line/n, lat, lon, pen   the FMC's points (the FMS
 *       module: B747.68.nd_line_model.lua), each piece from a point whose
 *       pen is its style: 1 the active route (magenta, continuous), 2 the
 *       modification (white, short dashes), 3 an inactive route (cyan, long
 *       dashes), 4 the lateral offset's path (magenta, short dashes), 5
 *       an activated route not yet executed (step 6d4, FCOM p.1251: cyan
 *       and white dashes in turn), 6 (2026-11-04) FIX INFO's radial lines
 *       (green dashes: FCOM p.1150)
 *   laminar/B747/nd/circle/n, lat, lon, radius, pen   (2026-11-04) the
 *       FMS module's circles (at most 8; the radius in NM): 6 FIX INFO's
 *       distances (green dashes, PLAN too), 7 OFFPATH DES's clean energy
 *       management circle (blue: the ND's cyan, long dashes), 8 its drag
 *       circle (white, long dashes), the energy circles in MAP and MAP CTR
 *       only (FCOM p.1150)
 *   laminar/B747/nd/line/view   each ND's map (the ND module, as it places
 *       the route's symbols): the view (0 none, 1 MAP, 2 MAP CTR, 3 PLAN),
 *       the centre's latitude and longitude, the true direction up, pixels
 *       per NM; the Captain's [0] to [4], the F/O's [5] to [9]
 *
 * in the panel's gauges phase after its instruments (the symbols are the 3D
 * cockpit's objects, in front of the panel), in the panel's coordinates:
 * the bearing and distance from the map's centre as the ND module's
 * getHeading and getDistance (the earth 3440 NM), from the airplane symbol
 * (MAP; the CRT's PLAN from its centre waypoint there) or the display's
 * centre (MAP CTR, PLAN's range circles: laminar/B747/nd/<side>/centred,
 * 2026-11-05: FCOM p.1027-1029; before, the CTR switch) at the panel's positions of
 * the ND's course lines and trend vector (the acf's groups: the Captain's
 * 335.25, the F/O's 1022.25; -95 expanded, 173.5 up centred; moved with the
 * display's position laminar/B747/flt_inst/display/<side>/nd_pos; the gauges
 * phase's coordinates NDL_PANEL_DY above the acf's: measured), clipped
 * to the map's visible part (B747.61.nd_data.lua's inside: expanded the
 * range arc ahead within the display's sides, MAP CTR the centred mask's
 * circle, PLAN the symbols' circle, NDL_PLAN_CTR_R centred). A leg's great circle in pieces of at
 * most NDL_SUB_PX pixels. Drawn on the display's power (the ND groups'
 * laminar/B747/electrical/display_has_power), at its brightness (the
 * glass's rheostat: the Captain's 2, the F/O's 3), in the panel passes of
 * laminar/B747/nd/line/passes (bit n: sim/graphics/view/panel_render_type
 * n; 5: the 2D panel and the 3D panel's lit pass, the glass's). PLAN's
 * airplane symbol too (FCOM p.1147: the position and the track; X-Plane's
 * EFIS map drew one, its basemap none).
 *
 * The geometry's calibration (the tests'): laminar/B747/nd/line/cal_dx,
 * cal_dy (pixels), cal_scale, width (pixels), test (bit 0 the Captain's, bit
 * 1 the F/O's in green: beside X-Plane's own line on an EFIS map); pnl_l,
 * pnl_b (the panel's left and bottom in the last drawing, read only).
 */
#include <math.h>
#include <GL/gl.h>
#include "XPLMDisplay.h"
#include "XPLMGraphics.h"

#define NDL_MAXP 600
#define NDL_SUB_PX 60.0
#define NDL_SUB_MAX 64
#define NDL_EARTH_NM 3440.0
#define NDL_D2R (3.14159265358979323846 / 180.0)

static XPLMDataRef ndl_n_ref, ndl_lat_ref, ndl_lon_ref, ndl_pen_ref, ndl_view_ref;
static XPLMDataRef ndl_power_ref, ndl_bright_ref, ndl_render_ref, ndl_pos_ref[2];
static XPLMDataRef ndl_plat_ref, ndl_plon_ref, ndl_gs_ref, ndl_trk_ref, ndl_psi_ref, ndl_ctr_ref[2];
static XPLMDataRef ndl_own[8], ndl_pnl_ref[2];
static float ndl_cal_dx = 0.0f, ndl_cal_dy = 0.0f, ndl_cal_scale = 1.0f, ndl_width = 3.5f;
static float ndl_pnl_l = 0.0f, ndl_pnl_b = 0.0f;
static int ndl_test = 0, ndl_passes = 5;
static float ndl_lat[NDL_MAXP], ndl_lon[NDL_MAXP], ndl_pen[NDL_MAXP], ndl_view[10];

/* the panel's geometry: the map's origins, the display's positions' moves.
   The gauges phase's coordinates are the acf's panel positions NDL_PANEL_DY
   higher (measured, s219 2026-11-02: the line through the airplane symbol
   in MAP, the airplane symbol in MAP CTR, the waypoints' stars in PLAN, and
   on X-Plane's own route line on an EFIS map; the panel's bottom as the
   drawing sees it: laminar/B747/nd/line/pnl_b) */
#define NDL_PANEL_DY 259.0f
/* (2026-11-05) PLAN centred (its range circles): the symbols' circle about
   the display's centre (B747.61.nd_data.lua's PLAN_CTR_PX: estimate) */
#define NDL_PLAN_CTR_R 290.0f
static const float ndl_ox[2] = {335.25f, 1022.25f};
static const float ndl_oy_exp = -95.0f + NDL_PANEL_DY, ndl_oy_ctr = 78.5f + NDL_PANEL_DY;
static const float ndl_pos_dx[2][3] = {{0.0f, 1366.0f, 1366.0f}, {0.0f, 683.0f, 683.0f}};
static const float ndl_pos_dy[3] = {0.0f, 0.0f, 683.0f};
static const int ndl_power_index[2] = {3, 2};
static const int ndl_rheostat[2] = {2, 3};
/* the styles' colours and dashes (pixels: a dash, a gap; 0 continuous);
   ACTIVATING's dashes cyan and white in turn (its first cyan; the dashes'
   length: estimate) */
#define NDL_STYLES 9
#define NDL_ACTIVATING 5
/* (2026-11-04) 6 FIX INFO's radial lines and distance circles (green
   dashes), 7 OFFPATH DES's clean energy management circle (blue: the
   ND's cyan, long dashes), 8 its drag circle (white, long dashes): FCOM
   p.1150 (the dashes' lengths: estimate) */
static const float ndl_rgb[NDL_STYLES][3] = {
    {0.0f, 0.0f, 0.0f}, {1.0f, 0.42f, 1.0f}, {1.0f, 1.0f, 1.0f}, {0.0f, 0.85f, 1.0f}, {1.0f, 0.42f, 1.0f},
    {0.0f, 0.85f, 1.0f}, {0.0f, 1.0f, 0.0f}, {0.0f, 0.85f, 1.0f}, {1.0f, 1.0f, 1.0f}};
static const float ndl_dash[NDL_STYLES][2] = {{0, 0}, {0, 0}, {12, 10}, {24, 12}, {12, 10}, {12, 6}, {10, 8},
    {24, 12}, {24, 12}};
/* the circles (laminar/B747/nd/circle/n, lat, lon, radius (NM), pen: the
   FMS module's), each drawn as NDL_CIRCLE_N pieces of its great circles
   from the centre */
#define NDL_MAXC 8
#define NDL_CIRCLE_N 72
static XPLMDataRef ndl_cn_ref, ndl_clat_ref, ndl_clon_ref, ndl_cr_ref, ndl_cpen_ref;
static float ndl_clat[NDL_MAXC], ndl_clon[NDL_MAXC], ndl_cr[NDL_MAXC], ndl_cpen[NDL_MAXC];
static int ndl_cn = 0;
/* the side being drawn: its brightness, its colours (not the test's) */
static float ndl_cur_bright = 1.0f;
static int ndl_cur_colours = 1;

static float ndl_get_f(void *ref) { return *(float *)ref; }
static void ndl_set_f(void *ref, float v) { *(float *)ref = v; }
static int ndl_get_i(void *ref) { return *(int *)ref; }
static void ndl_set_i(void *ref, int v) { *(int *)ref = v; }
static XPLMDataRef ndl_float_ref(const char *name, float *v)
{
    return XPLMRegisterDataAccessor(name, xplmType_Float, 1, NULL, NULL, ndl_get_f, ndl_set_f,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, v, v);
}
static XPLMDataRef ndl_int_ref(const char *name, int *v)
{
    return XPLMRegisterDataAccessor(name, xplmType_Int, 1, ndl_get_i, ndl_set_i, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, v, v);
}

/* a number dataref (XTLua's: a float or a double) */
static double ndl_num(XPLMDataRef r)
{
    if (!r) return 0.0;
    if (XPLMGetDataRefTypes(r) & xplmType_Double) return XPLMGetDatad(r);
    return XPLMGetDataf(r);
}

static int ndl_found(void)
{
    if (!ndl_n_ref) ndl_n_ref = XPLMFindDataRef("laminar/B747/nd/line/n");
    if (!ndl_lat_ref) ndl_lat_ref = XPLMFindDataRef("laminar/B747/nd/line/lat");
    if (!ndl_lon_ref) ndl_lon_ref = XPLMFindDataRef("laminar/B747/nd/line/lon");
    if (!ndl_pen_ref) ndl_pen_ref = XPLMFindDataRef("laminar/B747/nd/line/pen");
    if (!ndl_view_ref) ndl_view_ref = XPLMFindDataRef("laminar/B747/nd/line/view");
    if (!ndl_power_ref) ndl_power_ref = XPLMFindDataRef("laminar/B747/electrical/display_has_power");
    if (!ndl_bright_ref) ndl_bright_ref = XPLMFindDataRef("sim/cockpit2/switches/instrument_brightness_ratio");
    if (!ndl_render_ref) ndl_render_ref = XPLMFindDataRef("sim/graphics/view/panel_render_type");
    if (!ndl_pos_ref[0]) ndl_pos_ref[0] = XPLMFindDataRef("laminar/B747/flt_inst/display/capt/nd_pos");
    if (!ndl_pos_ref[1]) ndl_pos_ref[1] = XPLMFindDataRef("laminar/B747/flt_inst/display/fo/nd_pos");
    if (!ndl_pnl_ref[0]) ndl_pnl_ref[0] = XPLMFindDataRef("sim/graphics/view/panel_total_pnl_l");
    if (!ndl_pnl_ref[1]) ndl_pnl_ref[1] = XPLMFindDataRef("sim/graphics/view/panel_total_pnl_b");
    /* (2026-11-05) the map centred: B747.60.nd_model.lua's, CTR or PLAN's
       range circles (FCOM p.1027-1028); before, the CTR switch */
    if (!ndl_ctr_ref[0]) ndl_ctr_ref[0] = XPLMFindDataRef("laminar/B747/nd/capt/centred");
    if (!ndl_ctr_ref[1]) ndl_ctr_ref[1] = XPLMFindDataRef("laminar/B747/nd/fo/centred");
    if (!ndl_cn_ref) ndl_cn_ref = XPLMFindDataRef("laminar/B747/nd/circle/n");
    if (!ndl_clat_ref) ndl_clat_ref = XPLMFindDataRef("laminar/B747/nd/circle/lat");
    if (!ndl_clon_ref) ndl_clon_ref = XPLMFindDataRef("laminar/B747/nd/circle/lon");
    if (!ndl_cr_ref) ndl_cr_ref = XPLMFindDataRef("laminar/B747/nd/circle/radius");
    if (!ndl_cpen_ref) ndl_cpen_ref = XPLMFindDataRef("laminar/B747/nd/circle/pen");
    if (!ndl_plat_ref) {
        ndl_plat_ref = XPLMFindDataRef("sim/flightmodel/position/latitude");
        ndl_plon_ref = XPLMFindDataRef("sim/flightmodel/position/longitude");
        ndl_gs_ref = XPLMFindDataRef("sim/flightmodel/position/groundspeed");
        ndl_trk_ref = XPLMFindDataRef("sim/flightmodel/position/hpath");
        ndl_psi_ref = XPLMFindDataRef("sim/flightmodel/position/psi");
    }
    return ndl_n_ref && ndl_lat_ref && ndl_lon_ref && ndl_pen_ref && ndl_view_ref;
}

/* a point's place on the map: from the centre, up the display (pixels) */
static void ndl_proj(const float *v, double lat, double lon, float *x, float *y)
{
    double p1 = v[1] * NDL_D2R, p2 = lat * NDL_D2R, dl = (lon - v[2]) * NDL_D2R;
    double sp = sin((p2 - p1) / 2), sl = sin(dl / 2);
    double h = sp * sp + cos(p1) * cos(p2) * sl * sl;
    double d = 2.0 * asin(fmin(1.0, sqrt(h))) * NDL_EARTH_NM;
    double brg = atan2(sin(dl) * cos(p2), cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl));
    double rel = brg - v[3] * NDL_D2R;
    double px = d * v[4] * ndl_cal_scale;
    *x = (float)(px * sin(rel));
    *y = (float)(px * cos(rel));
}

/* (2026-11-05 review) the angle between two points and the initial
   bearing from the first (radians) */
static double ndl_ang(double p1, double l1, double p2, double l2)
{
    double sp = sin((p2 - p1) / 2), sl = sin((l2 - l1) / 2);
    return 2.0 * asin(fmin(1.0, sqrt(sp * sp + cos(p1) * cos(p2) * sl * sl)));
}
static double ndl_brg(double p1, double l1, double p2, double l2)
{
    double dl = l2 - l1;
    return atan2(sin(dl) * cos(p2), cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl));
}

/* (2026-11-05 review) whether the great circle from a to b comes within
   r NM of the map's centre: its ends, or the cross-track distance where
   the nearest point lies between them. A leg that does not is not cut into
   pieces nor projected (before, up to NDL_SUB_MAX pieces of every leg,
   each projected, twice a frame for each side) */
static int ndl_leg_near(const float *v, double la1, double lo1, double la2, double lo2, double r_nm)
{
    double pc = v[1] * NDL_D2R, lc = v[2] * NDL_D2R;
    double p1 = la1 * NDL_D2R, l1 = lo1 * NDL_D2R, p2 = la2 * NDL_D2R, l2 = lo2 * NDL_D2R;
    double r = r_nm / NDL_EARTH_NM;
    double d13 = ndl_ang(p1, l1, pc, lc), d23 = ndl_ang(p2, l2, pc, lc), d12 = ndl_ang(p1, l1, p2, l2);
    if (d13 <= r || d23 <= r) return 1;
    if (d12 < 1e-12) return 0;
    double a = ndl_brg(p1, l1, pc, lc) - ndl_brg(p1, l1, p2, l2);
    double xt = asin(fmax(-1.0, fmin(1.0, sin(d13) * sin(a))));
    if (fabs(xt) > r || cos(a) <= 0.0) return 0;
    double at = acos(fmax(-1.0, fmin(1.0, cos(d13) / cos(xt))));
    return at <= d12;
}

/* the great circle from a to b at f (0 to 1) */
static void ndl_between(double la1, double lo1, double la2, double lo2, double f, double *la, double *lo)
{
    double p1 = la1 * NDL_D2R, l1 = lo1 * NDL_D2R, p2 = la2 * NDL_D2R, l2 = lo2 * NDL_D2R;
    double sp = sin((p2 - p1) / 2), sl = sin((l2 - l1) / 2);
    double d = 2.0 * asin(fmin(1.0, sqrt(sp * sp + cos(p1) * cos(p2) * sl * sl)));
    if (d < 1e-9) { *la = la1; *lo = lo1; return; }
    double a = sin((1 - f) * d) / sin(d), b = sin(f * d) / sin(d);
    double x = a * cos(p1) * cos(l1) + b * cos(p2) * cos(l2);
    double y = a * cos(p1) * sin(l1) + b * cos(p2) * sin(l2);
    double z = a * sin(p1) + b * sin(p2);
    *la = atan2(z, sqrt(x * x + y * y)) / NDL_D2R;
    *lo = atan2(y, x) / NDL_D2R;
}

/* the part of t in [lo, hi] where v + t d is at or beyond `bound` (sgn 1)
   or at or below it (sgn -1); 0 when none */
static int ndl_half(float v, float d, float bound, float sgn, float *lo, float *hi)
{
    float f = sgn * (v - bound), g = sgn * d;
    if (fabsf(g) < 1e-9f) return f >= 0.0f;
    float t = -f / g;
    if (g > 0.0f) { if (t > *lo) *lo = t; }
    else if (t < *hi) *hi = t;
    return *lo < *hi;
}

/* the part [t0, t1] of a-b on the map's visible part; 0 when none */
static int ndl_clip(int view, float ax, float ay, float bx, float by, float *t0, float *t1)
{
    float lo = 0.0f, hi = 1.0f, dx = bx - ax, dy = by - ay, r;
    if (view == 1) {
        if (!ndl_half(ay, dy, 0.0f, 1.0f, &lo, &hi)) return 0;
        if (!ndl_half(ax, dx, -329.0f, 1.0f, &lo, &hi)) return 0;
        if (!ndl_half(ax, dx, 348.0f, -1.0f, &lo, &hi)) return 0;
        r = 465.0f;
    } else {
        r = view == 2 ? 225.0f : (view == 4 ? NDL_PLAN_CTR_R : 450.0f / 640.0f * 465.0f);
    }
    float A = dx * dx + dy * dy, B = 2.0f * (ax * dx + ay * dy), C = ax * ax + ay * ay - r * r;
    if (A < 1e-9f) {
        if (C > 0.0f) return 0;
    } else {
        float D = B * B - 4.0f * A * C;
        if (D < 0.0f) return 0;
        float s = sqrtf(D);
        float u0 = (-B - s) / (2.0f * A), u1 = (-B + s) / (2.0f * A);
        if (u0 > lo) lo = u0;
        if (u1 < hi) hi = u1;
    }
    if (lo >= hi) return 0;
    *t0 = lo;
    *t1 = hi;
    return 1;
}

/* a line w pixels wide from a to b (half its width past each end: the
   joints filled) */
static void ndl_quad(float ax, float ay, float bx, float by, float w)
{
    float dx = bx - ax, dy = by - ay, len = sqrtf(dx * dx + dy * dy);
    if (len < 1e-3f) return;
    float ux = dx / len, uy = dy / len, h = w * 0.5f;
    float nx = -uy * h, ny = ux * h;
    ax -= ux * h; ay -= uy * h; bx += ux * h; by += uy * h;
    glVertex2f(ax + nx, ay + ny);
    glVertex2f(bx + nx, by + ny);
    glVertex2f(bx - nx, by - ny);
    glVertex2f(ax - nx, ay - ny);
}

/* a piece's segment a-b on the map (s: the piece's length before it, for
   the dashes), offset to the panel at (ox, oy) */
static void ndl_segment(int view, int style, float ax, float ay, float bx, float by, float s,
                        float ox, float oy, float w)
{
    float t0, t1;
    if (!ndl_clip(view, ax, ay, bx, by, &t0, &t1)) return;
    float dx = bx - ax, dy = by - ay;
    float dash = ndl_dash[style][0], gap = ndl_dash[style][1];
    if (dash <= 0.0f) {
        ndl_quad(ox + ax + t0 * dx, oy + ay + t0 * dy, ox + ax + t1 * dx, oy + ay + t1 * dy, w);
        return;
    }
    float len = sqrtf(dx * dx + dy * dy);
    if (len < 1e-3f) return;
    float p = dash + gap, u0 = s + t0 * len, u1 = s + t1 * len;
    for (float k = floorf(u0 / p) * p; k < u1; k += p) {
        float a = fmaxf(k, u0), b = fminf(k + dash, u1);
        if (a >= b) continue;
        if (style == NDL_ACTIVATING && ndl_cur_colours) {
            const float *c = ((long)floorf(k / p + 0.5f) & 1) ? ndl_rgb[2] : ndl_rgb[NDL_ACTIVATING];
            glColor4f(c[0] * ndl_cur_bright, c[1] * ndl_cur_bright, c[2] * ndl_cur_bright, 1.0f);
        }
        float ta = (a - s) / len, tb = (b - s) / len;
        ndl_quad(ox + ax + ta * dx, oy + ay + ta * dy, ox + ax + tb * dx, oy + ay + tb * dy, w * 0.8f);
    }
}

/* the point d NM from (lat, lon) on the true course crs (degrees) */
static void ndl_course_point(double lat, double lon, double crs, double d, double *la, double *lo)
{
    double p1 = lat * NDL_D2R, l1 = lon * NDL_D2R, t = crs * NDL_D2R, a = d / NDL_EARTH_NM;
    double p2 = asin(sin(p1) * cos(a) + cos(p1) * sin(a) * cos(t));
    double l2 = l1 + atan2(sin(t) * sin(a) * cos(p1), cos(a) - sin(p1) * sin(p2));
    *la = p2 / NDL_D2R;
    *lo = fmod(l2 / NDL_D2R + 540.0, 360.0) - 180.0;
}

/* (2026-11-04) the circles of the map's side (inside GL_QUADS) */
static void ndl_circles(const float *v, int view, float ox, float oy, float bright)
{
    for (int c = 0; c < ndl_cn; c++) {
        int style = (int)(ndl_cpen[c] + 0.5f);
        if (style < 1 || style >= NDL_STYLES || ndl_cr[c] <= 0.0f) continue;
        /* the energy management circles in MAP and MAP CTR only (FCOM
           p.1150; FIX INFO's in PLAN too) */
        if (view >= 3 && style != 6) continue;
        const float *rgb = ndl_rgb[style];
        glColor4f(rgb[0] * bright, rgb[1] * bright, rgb[2] * bright, 1.0f);
        float px = 0.0f, py = 0.0f, s = 0.0f;
        for (int k = 0; k <= NDL_CIRCLE_N; k++) {
            double la, lo;
            ndl_course_point(ndl_clat[c], ndl_clon[c], 360.0 * k / NDL_CIRCLE_N, ndl_cr[c], &la, &lo);
            float x, y;
            ndl_proj(v, la, lo, &x, &y);
            if (k > 0) {
                ndl_segment(view, style, px, py, x, y, s, ox, oy, ndl_width);
                s += sqrtf((x - px) * (x - px) + (y - py) * (y - py));
            }
            px = x;
            py = y;
        }
    }
}

/* PLAN's airplane symbol (FCOM p.1147: the airplane's position and track,
   white; X-Plane's map drew one): its outline nose up, pixels from the
   position (estimate: the MAP triangle's length, FCOM's figure's shape) */
static const float ndl_plane[][2] = {
    {0, 22}, {2.6f, 17}, {2.6f, 5}, {20, -5}, {20, -8.5f}, {2.6f, -2.5f}, {2.6f, -13}, {8.5f, -18.5f},
    {8.5f, -21}, {0, -18}, {-8.5f, -21}, {-8.5f, -18.5f}, {-2.6f, -13}, {-2.6f, -2.5f}, {-20, -8.5f},
    {-20, -5}, {-2.6f, 5}, {-2.6f, 17}};
#define NDL_PLANE_N ((int)(sizeof ndl_plane / sizeof ndl_plane[0]))
static void ndl_airplane(const float *v, int view, float ox, float oy, float bright)
{
    double lat = XPLMGetDatad(ndl_plat_ref), lon = XPLMGetDatad(ndl_plon_ref);
    float gs = XPLMGetDataf(ndl_gs_ref);
    /* the track; the heading on the ground below 30 kt (estimate) */
    float trk = gs > 15.0f ? XPLMGetDataf(ndl_trk_ref) : XPLMGetDataf(ndl_psi_ref);
    float x, y;
    ndl_proj(v, lat, lon, &x, &y);
    float r = view == 4 ? NDL_PLAN_CTR_R : 450.0f / 640.0f * 465.0f;
    if (x * x + y * y > r * r) return;
    double a = (trk - v[3]) * NDL_D2R;
    float c = (float)cos(a), s = (float)sin(a);
    glColor4f(bright, bright, bright, 1.0f);
    for (int k = 0; k < NDL_PLANE_N; k++) {
        const float *p = ndl_plane[k], *q = ndl_plane[(k + 1) % NDL_PLANE_N];
        /* turned clockwise by the track off the display's up */
        ndl_quad(ox + x + p[0] * c + p[1] * s, oy + y - p[0] * s + p[1] * c,
                 ox + x + q[0] * c + q[1] * s, oy + y - q[0] * s + q[1] * c, 2.0f);
    }
}

static void ndl_side(int side, int n, float bright)
{
    const float *v = ndl_view + side * 5;
    int view = (int)(v[0] + 0.5f);
    if (view < 1 || view > 3 || v[4] <= 0.0f) return;
    int pos = ndl_pos_ref[side] ? (int)(XPLMGetDataf(ndl_pos_ref[side]) + 0.5f) : 0;
    if (pos < 0) pos = 0;
    if (pos > 2) pos = 2;
    /* the origin as the panel's: up with MAP CTR and PLAN's range circles
       (2026-11-05: the displays' centred; the CRT's PLAN expanded: FCOM
       p.1027-1029); PLAN centred is view 4 here (its symbols' circle) */
    int ctr = view == 2;
    if (view == 3) ctr = ndl_ctr_ref[side] ? ndl_num(ndl_ctr_ref[side]) > 0.5 : 1;
    if (view == 3 && ctr) view = 4;
    float ox = ndl_ox[side] + ndl_pos_dx[side][pos] + ndl_cal_dx;
    float oy = (ctr ? ndl_oy_ctr : ndl_oy_exp) + ndl_pos_dy[pos] + ndl_cal_dy;
    if (view >= 3 && ndl_plat_ref) {
        glBegin(GL_QUADS);
        ndl_airplane(v, view, ox, oy, bright);
        glEnd();
    }
    int style = 0;
    float px = 0.0f, py = 0.0f, s = 0.0f;
    ndl_cur_bright = bright;
    ndl_cur_colours = !((ndl_test >> side) & 1);
    /* (2026-11-05 review) the visible part's radius as ndl_clip's (MAP's
       range arc, MAP CTR's mask, PLAN's circles) and a margin, in NM */
    float r_px = view == 1 ? 465.0f : (view == 2 ? 225.0f : (view == 4 ? NDL_PLAN_CTR_R : 450.0f / 640.0f * 465.0f));
    double r_nm = (r_px + 40.0) / (v[4] * (ndl_cal_scale > 0.01f ? ndl_cal_scale : 0.01f));
    glBegin(GL_QUADS);
    for (int k = 0; k < n; k++) {
        int pen = (int)(ndl_pen[k] + 0.5f);
        if (pen != 0) {
            style = (pen >= 1 && pen < NDL_STYLES) ? pen : 0;
            ndl_proj(v, ndl_lat[k], ndl_lon[k], &px, &py);
            s = 0.0f;
            const float *c = ((ndl_test >> side) & 1) ? (const float[3]){0.0f, 1.0f, 0.0f} : ndl_rgb[style];
            glColor4f(c[0] * bright, c[1] * bright, c[2] * bright, 1.0f);
            continue;
        }
        if (style == 0 || k == 0) continue;
        /* the leg's great circle in pieces */
        float qx, qy;
        ndl_proj(v, ndl_lat[k], ndl_lon[k], &qx, &qy);
        float lpx = sqrtf((qx - px) * (qx - px) + (qy - py) * (qy - py));
        if (!ndl_leg_near(v, ndl_lat[k - 1], ndl_lon[k - 1], ndl_lat[k], ndl_lon[k], r_nm)) {
            /* out of sight: its chord for the dashes' phase */
            s += lpx;
            px = qx;
            py = qy;
            continue;
        }
        int m = (int)ceilf(lpx / (float)NDL_SUB_PX);
        if (m < 1) m = 1;
        if (m > NDL_SUB_MAX) m = NDL_SUB_MAX;
        for (int j = 1; j <= m; j++) {
            float bx = qx, by = qy;
            if (j < m) {
                double la, lo;
                ndl_between(ndl_lat[k - 1], ndl_lon[k - 1], ndl_lat[k], ndl_lon[k], (double)j / m, &la, &lo);
                ndl_proj(v, la, lo, &bx, &by);
            }
            ndl_segment(view, style, px, py, bx, by, s, ox, oy, ndl_width);
            s += sqrtf((bx - px) * (bx - px) + (by - py) * (by - py));
            px = bx;
            py = by;
        }
    }
    /* (2026-11-04) the circles */
    ndl_circles(v, view, ox, oy, bright);
    glEnd();
}

static int ndl_draw(XPLMDrawingPhase phase, int before, void *ref)
{
    (void)phase; (void)before; (void)ref;
    if (!ndl_found()) return 1;
    int pass = ndl_render_ref ? XPLMGetDatai(ndl_render_ref) : 0;
    if (pass < 0 || pass > 7 || !((ndl_passes >> pass) & 1)) return 1;
    if (ndl_pnl_ref[0]) ndl_pnl_l = (float)XPLMGetDatai(ndl_pnl_ref[0]);
    if (ndl_pnl_ref[1]) ndl_pnl_b = (float)XPLMGetDatai(ndl_pnl_ref[1]);
    int n = (int)(ndl_num(ndl_n_ref) + 0.5);
    if (n < 2) n = 0;
    if (n > NDL_MAXP) n = NDL_MAXP;
    if (n > 0) {
        XPLMGetDatavf(ndl_lat_ref, ndl_lat, 0, n);
        XPLMGetDatavf(ndl_lon_ref, ndl_lon, 0, n);
        XPLMGetDatavf(ndl_pen_ref, ndl_pen, 0, n);
    }
    XPLMGetDatavf(ndl_view_ref, ndl_view, 0, 10);
    ndl_cn = 0;
    if (ndl_cn_ref && ndl_clat_ref && ndl_clon_ref && ndl_cr_ref && ndl_cpen_ref) {
        ndl_cn = (int)(ndl_num(ndl_cn_ref) + 0.5);
        if (ndl_cn < 0) ndl_cn = 0;
        if (ndl_cn > NDL_MAXC) ndl_cn = NDL_MAXC;
        if (ndl_cn > 0) {
            XPLMGetDatavf(ndl_clat_ref, ndl_clat, 0, ndl_cn);
            XPLMGetDatavf(ndl_clon_ref, ndl_clon, 0, ndl_cn);
            XPLMGetDatavf(ndl_cr_ref, ndl_cr, 0, ndl_cn);
            XPLMGetDatavf(ndl_cpen_ref, ndl_cpen, 0, ndl_cn);
        }
    }
    XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0);
    for (int side = 0; side < 2; side++) {
        if (ndl_power_ref) {
            float p = 0.0f;
            XPLMGetDatavf(ndl_power_ref, &p, ndl_power_index[side], 1);
            if (p < 0.1f) continue;
        }
        float bright = 1.0f;
        if (ndl_bright_ref) {
            XPLMGetDatavf(ndl_bright_ref, &bright, ndl_rheostat[side], 1);
            if (bright < 0.0f) bright = 0.0f;
            if (bright > 1.0f) bright = 1.0f;
        }
        ndl_side(side, n, bright);
    }
    return 1;
}

static void ndl_start(void)
{
    ndl_own[0] = ndl_float_ref("laminar/B747/nd/line/cal_dx", &ndl_cal_dx);
    ndl_own[1] = ndl_float_ref("laminar/B747/nd/line/cal_dy", &ndl_cal_dy);
    ndl_own[2] = ndl_float_ref("laminar/B747/nd/line/cal_scale", &ndl_cal_scale);
    ndl_own[3] = ndl_float_ref("laminar/B747/nd/line/width", &ndl_width);
    ndl_own[4] = ndl_int_ref("laminar/B747/nd/line/test", &ndl_test);
    ndl_own[5] = ndl_int_ref("laminar/B747/nd/line/passes", &ndl_passes);
    ndl_own[6] = ndl_float_ref("laminar/B747/nd/line/pnl_l", &ndl_pnl_l);
    ndl_own[7] = ndl_float_ref("laminar/B747/nd/line/pnl_b", &ndl_pnl_b);
    XPLMRegisterDrawCallback(ndl_draw, xplm_Phase_Gauges, 0, NULL);
}

static void ndl_stop(void)
{
    XPLMUnregisterDrawCallback(ndl_draw, xplm_Phase_Gauges, 0, NULL);
    for (int i = 0; i < 8; i++) XPLMUnregisterDataAccessor(ndl_own[i]);
}
