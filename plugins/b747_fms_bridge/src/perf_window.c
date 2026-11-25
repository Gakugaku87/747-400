/*
 * The takeoff and landing performance window (2026-11-25, the user: the
 * performance calculator "in X-Plane's window"; docs/overhaul/notes/
 * ATA-34-61-FMC.md §191), included by b747_fms_bridge.c after
 * gh_window.c (the failure window's drawing, the weight and balance
 * window's numbers and CG). Plugins > 747-400 > Takeoff and landing
 * performance... or the command laminar/B747/efb/window_toggle shows a
 * floating window as the others'. The EFB's PERFORMANCE pages' entries and
 * answers (FCOM p.1181-1183, 10.45.23-25, "Typical"):
 *   TAKEOFF: the airport, runway (and a start further down it), the
 *   runway's condition, wind, OAT, QNH, weight, CG, flaps, rating, the
 *   assumed temperature, packs and anti-ice; CALC; the limit weights, the
 *   assumed temperature, EPR (N1), V1, VR, V2, trim and VREF 30; SEND to the
 *   FMC's TAKEOFF REF and THRUST LIM pages.
 *   LANDING: the airport, runway, its condition (braking action), wind,
 *   OAT, QNH, weight, flaps, autobrakes, reversers, VREF's additive; CALC;
 *   VREF, the approach speed, the landing distance against the runway's,
 *   the dispatch limit weights, the quick turnaround limit.
 *
 * The FMC works it out (XTLua: B747.68.efb_glue.lua, which describes the
 * arrays): this window asks through
 *
 *   laminar/B747/efb/req_id    (int) counted up after each request
 *   laminar/B747/efb/req_kind  (int) 1 a runway, 2 the takeoff, 3 SEND,
 *                              4 the landing, 5 the FMC's route
 *   laminar/B747/efb/req_i     (int[16]) the airport and runway (4
 *                              characters in base 37: pw_pack), flaps,
 *                              rating, ...
 *   laminar/B747/efb/req_f     (float[16]) OAT, QNH, headwind, weight, ...
 *
 * (all writable, for the flight tests) and reads the FMC's answers
 * laminar/B747/efb/ans_id, rwy, rwy_list, out, msg and route_n. The wind
 * entered as the tower's (degrees magnetic/knots) is turned into the
 * runway's head and cross components here: X-Plane's magnetic variation
 * at the runway (XPLMGetMagneticVariation) and the runway's true bearing
 * from the FMC's data. "H10" or "T5" are the components as the TAKEOFF REF
 * page takes them (FCOM p.1319).
 *
 *   laminar/B747/efb/window_open   (int) 0 hidden, 1 shown in X-Plane's
 *                                  window, 2 popped out, 3 in VR; 1 or 0
 *                                  written shows or hides it
 *   laminar/B747/efb/window_toggle (command) shows or hides it
 *   laminar/B747/efb/calc, send, fill (commands) the window's CALC, SEND
 *                                  and FMC/SIM buttons on the page shown
 *                                  (key bindings, the flight tests)
 *   laminar/B747/efb/page          (int) 0 the takeoff page, 1 the landing
 *                                  page (writable)
 */
#include <math.h>
#include <ctype.h>
#include "XPLMScenery.h"

#define PWN_MENU_REF 103       /* as b747_fms_bridge.c's */
#define PWN_NI 16
#define PWN_NF 16
#define PWN_NOUT 40
#define PWN_NRWY 16

/* the text fields (the takeoff page's, then the landing page's) and the
   choices */
enum {
    PF_APT, PF_RWY, PF_SHIFT, PF_LEN, PF_SLOPE, PF_WIND, PF_OAT, PF_QNH, PF_WT, PF_CG,
    PF_LAPT, PF_LRWY, PF_LLEN, PF_LSLOPE, PF_LWIND, PF_LOAT, PF_LQNH, PF_LWT, PF_LADD, PF_N
};
enum { PT_COND, PT_FLAPS, PT_RATING, PT_ATM, PT_PACKS, PT_AI, PT_LFLAPS, PT_LCOND, PT_LBRAKE, PT_LREV, PT_N };
enum { PB_CALC, PB_SEND, PB_FILL, PB_N };
/* each page's fields of a kind */
static const int PW_F_APT[2] = {PF_APT, PF_LAPT}, PW_F_RWY[2] = {PF_RWY, PF_LRWY};
static const int PW_F_LEN[2] = {PF_LEN, PF_LLEN}, PW_F_SLOPE[2] = {PF_SLOPE, PF_LSLOPE};
static const int PW_F_WIND[2] = {PF_WIND, PF_LWIND}, PW_F_OAT[2] = {PF_OAT, PF_LOAT};
static const int PW_F_QNH[2] = {PF_QNH, PF_LQNH}, PW_F_WT[2] = {PF_WT, PF_LWT};
/* the hit boxes: fields, choices, buttons, pages */
#define PH_TOG 100
#define PH_BTN 200
#define PH_PAGE 300
#define PWN_HITS 48

static XPLMWindowID pw_win = NULL;
static XPLMCommandRef pw_cmd_toggle = NULL, pw_cmd_btn[3] = {NULL, NULL, NULL};
static XPLMDataRef pw_ref_open = NULL, pw_ref_req_id = NULL, pw_ref_req_kind = NULL, pw_ref_req_i = NULL, pw_ref_req_f = NULL;
static XPLMDataRef pw_ref_page = NULL;
static XPLMDataRef pw_ref_oat = NULL, pw_ref_baro = NULL, pw_ref_wdir = NULL, pw_ref_wspd = NULL;
static int pw_req_id = 0, pw_req_kind = 0;
static int pw_req_i[PWN_NI];
static float pw_req_f[PWN_NF];

static char pw_txt[PF_N][16];
/* the choices: the takeoff's condition (0 dry), flaps, rating, assumed
   temperature, packs (3, 1, 0), anti-ice (0 off, 1 engines, 2 and wings);
   the landing's flaps, condition (0 dry, 1 good, 2 medium, 3 poor braking
   action), autobrakes (0 MAX MANUAL, 1 MAX AUTO, 2 to 5 the selector's 4 to
   1), reversers (engines: 4, 2, 0) */
static int pw_tog[PT_N] = {0, 20, 0, 1, 3, 0, 30, 0, 3, 4};
static int pw_edit = -1;
static char pw_buf[16];
static int pw_page = 0;                 /* 0 takeoff, 1 landing */
static struct { int l, b, r, t, id; } pw_hits[PWN_HITS];
static int pw_nhits = 0;
static int pw_hover_x = -1, pw_hover_y = -1;

/* the request waited for (and its page), the ones queued after it */
static int pw_wait = 0, pw_wait_kind = 0, pw_wait_page = 0;
static float pw_wait_t = 0.0f;
static int pw_queue[6], pw_queue_page[6], pw_nqueue = 0;
/* a page's answers: the runway (with the airport and runway it is for),
   the results, the message */
typedef struct {
    float rwy[PWN_NRWY];
    int rwy_ok, rwy_apt, rwy_rwy;
    char rwy_list[160];
    float magvar;
    float out[PWN_NOUT];
    int out_ok, out_sent;
    char msg[160];
} pw_pg_t;
static pw_pg_t pw_pg[2];
static int pw_filled[2] = {0, 0};
static int pw_text_frames = 0, pw_text_page = 0;

static XPLMDataRef pw_fmc(const char *name) { return XPLMFindDataRef(name); }

static float pw_now(void)
{
    static XPLMDataRef t = NULL;
    if (!t) t = XPLMFindDataRef("sim/time/total_running_time_sec");
    return t ? XPLMGetDataf(t) : 0.0f;
}

/* up to 4 characters in base 37 (B747.68.efb_glue.lua): A-Z 1-26, 0-9
   27-36, the first highest, none 0. At most 1,874,160: whole in a float's
   24 bits, as XTLua reads another plugin's int array (2026-11-25, s435: a
   byte a character lost the last ones, "AIRPORT NOT FOUND") */
static int pw_pack(const char *s)
{
    int v = 0, n = 0;
    for (; *s && n < 4; s++) {
        int c = toupper((unsigned char)*s), d = 0;
        if (c == ' ') continue;
        if (c >= 'A' && c <= 'Z') d = c - 'A' + 1;
        else if (c >= '0' && c <= '9') d = c - '0' + 27;
        v = v * 37 + d;
        n++;
    }
    for (; n < 4; n++) v *= 37;
    return v;
}

/* a packed identifier's text */
static void pw_unpack(int v, char *out, size_t n)
{
    char s[8];
    int k = 0;
    for (int p = 3; p >= 0; p--) {
        int div = p == 3 ? 50653 : p == 2 ? 1369 : p == 1 ? 37 : 1;
        int d = (v / div) % 37;
        if (d >= 1 && d <= 26) s[k++] = (char)('A' + d - 1);
        else if (d >= 27) s[k++] = (char)('0' + d - 27);
    }
    s[k] = 0;
    fw_copy(out, n, s);
}

/* a field's number; `ok` 0 when blank or not a number */
static double pw_num(const char *s, int *ok)
{
    char *end = NULL;
    while (*s == ' ') s++;
    if (!*s) { *ok = 0; return 0.0; }
    double v = strtod(s, &end);
    *ok = end && end != s && *end == 0;
    return v;
}

/* the QNH (hPa) of a page's field: hPa, or inches of mercury below 40 */
static float pw_qnh(int p, int *ok)
{
    double v = pw_num(pw_txt[PW_F_QNH[p]], ok);
    if (*ok && v < 40.0) v *= 33.8639;
    if (*ok && (v < 850.0 || v > 1100.0)) *ok = 0;
    return (float)v;
}

/* the weight (kg) of a page's field: tonnes below 1,000 */
static float pw_weight(int p, int *ok)
{
    double v = pw_num(pw_txt[PW_F_WT[p]], ok);
    if (*ok && v < 1000.0) v *= 1000.0;
    if (*ok && (v < 100000.0 || v > 500000.0)) *ok = 0;
    return (float)v;
}

/* the page's runway answer is for the airport and runway in its fields */
static int pw_rwy_current(int p)
{
    pw_pg_t *g = &pw_pg[p];
    return g->rwy_ok && g->rwy_apt == pw_pack(pw_txt[PW_F_APT[p]]) && g->rwy_rwy == pw_pack(pw_txt[PW_F_RWY[p]]);
}

/* X-Plane's variation at a place as magnetic less true (degrees): its sign
   taken from X-Plane's own conversion at the user's place
   (XPLMDegTrueToDegMagnetic, true north's magnetic heading there) against
   XPLMGetMagneticVariation there (the SDK does not give the sign; s435 at
   RJAA: sim/flightmodel/position/magnetic_variation +7.8, mag_psi psi +8) */
static float pw_mag_less_true(double lat, double lon)
{
    static XPLMDataRef plat = NULL, plon = NULL;
    if (!plat) {
        plat = XPLMFindDataRef("sim/flightmodel/position/latitude");
        plon = XPLMFindDataRef("sim/flightmodel/position/longitude");
    }
    float sign = 1.0f;
    if (plat && plon) {
        float here = XPLMGetMagneticVariation(XPLMGetDatad(plat), XPLMGetDatad(plon));
        float north = XPLMDegTrueToDegMagnetic(0.0f);
        if (north > 180.0f) north -= 360.0f;
        if (fabsf(here) > 0.5f && fabsf(north + here) < fabsf(north - here)) sign = -1.0f;
    }
    return sign * XPLMGetMagneticVariation(lat, lon);
}

/* the runway's magnetic heading (the FMC's true bearing, X-Plane's
   variation there) */
static float pw_rwy_mag(int p)
{
    return fmodf(pw_pg[p].rwy[8] + pw_pg[p].magvar + 720.0f, 360.0f);
}

/* a page's wind field's head (+) and cross (from the right +) components
   (kt): blank calm, "H10"/"T5" the head or tail component, "250/12" the
   tower's (degrees magnetic/knots: needs the runway); 0 not understood */
static int pw_wind(int p, float *head, float *cross)
{
    const char *s = pw_txt[PW_F_WIND[p]];
    *head = 0.0f;
    *cross = 0.0f;
    while (*s == ' ') s++;
    if (!*s) return 1;
    if (*s == 'H' || *s == 'T' || *s == 'h' || *s == 't') {
        int ok = 0;
        double v = pw_num(s + 1, &ok);
        if (!ok || v < 0 || v > 99) return 0;
        *head = (float)((*s == 'H' || *s == 'h') ? v : -v);
        return 1;
    }
    int d = 0, sp = 0;
    char extra = 0;
    if (sscanf(s, "%d/%d%c", &d, &sp, &extra) == 2 && d >= 0 && d <= 360 && sp >= 0 && sp < 200) {
        if (!pw_rwy_current(p)) return 0;
        double diff = ((double)d - pw_pg[p].magvar - pw_pg[p].rwy[8]) * 3.14159265358979 / 180.0;
        *head = (float)(sp * cos(diff));
        *cross = (float)(sp * sin(diff));
        return 1;
    }
    return 0;
}

/* the request's arrays from a page's fields */
static void pw_fill_request(int p)
{
    int ok = 0;
    memset(pw_req_i, 0, sizeof pw_req_i);
    memset(pw_req_f, 0, sizeof pw_req_f);
    pw_req_i[0] = pw_pack(pw_txt[PW_F_APT[p]]);
    pw_req_i[1] = pw_pack(pw_txt[PW_F_RWY[p]]);
    if (p == 0) {
        pw_req_i[2] = pw_tog[PT_FLAPS];
        pw_req_i[3] = pw_tog[PT_RATING];
        pw_req_i[4] = pw_tog[PT_ATM];
        pw_req_i[5] = pw_tog[PT_PACKS];
        pw_req_i[6] = pw_tog[PT_AI];
        pw_req_i[7] = pw_tog[PT_COND];
    } else {
        pw_req_i[2] = pw_tog[PT_LFLAPS];
        pw_req_i[7] = pw_tog[PT_LCOND];
        pw_req_i[8] = pw_tog[PT_LBRAKE];
        pw_req_i[9] = pw_tog[PT_LREV];
    }
    double v = pw_num(pw_txt[PW_F_OAT[p]], &ok);
    pw_req_f[0] = ok ? (float)v : 15.0f;
    float q = pw_qnh(p, &ok);
    pw_req_f[1] = ok ? q : 1013.25f;
    float head = 0.0f, cross = 0.0f;
    if (pw_wind(p, &head, &cross)) pw_req_f[2] = head;
    float w = pw_weight(p, &ok);
    pw_req_f[3] = ok ? w : 0.0f;
    if (p == 0) {
        v = pw_num(pw_txt[PF_CG], &ok);
        pw_req_f[4] = ok ? (float)v : 0.0f;
        v = pw_num(pw_txt[PF_SHIFT], &ok);
        pw_req_f[5] = ok && v > 0 ? (float)v : 0.0f;
    } else {
        v = pw_num(pw_txt[PF_LADD], &ok);
        pw_req_f[8] = ok && v >= 0 ? (float)v : 5.0f;
    }
    v = pw_num(pw_txt[PW_F_LEN[p]], &ok);
    pw_req_f[6] = ok && v > 0 ? (float)v : 0.0f;
    v = pw_num(pw_txt[PW_F_SLOPE[p]], &ok);
    pw_req_f[7] = ok ? (float)v : -99.0f;
    pw_req_f[9] = cross;
}

static void pw_send(int kind, int p)
{
    pw_fill_request(p);
    pw_req_kind = kind;
    pw_req_id++;
    pw_wait = pw_req_id;
    pw_wait_kind = kind;
    pw_wait_page = p;
    pw_wait_t = pw_now();
}

/* a request for a page now, or after the one waited for */
static void pw_ask(int kind, int p)
{
    if (!pw_wait) {
        pw_send(kind, p);
        return;
    }
    for (int i = 0; i < pw_nqueue; i++)
        if (pw_queue[i] == kind && pw_queue_page[i] == p) return;
    if (pw_nqueue < 6) {
        pw_queue[pw_nqueue] = kind;
        pw_queue_page[pw_nqueue] = p;
        pw_nqueue++;
    }
}

/* the sim's values into a page's fields: the takeoff's all (at the airport
   now), the landing's weight only (the destination's weather is the
   crew's: ATIS) */
static void pw_fill_sim(int p)
{
    float w = wb_getf(wb_ref_total);
    if (w > 0) snprintf(pw_txt[PW_F_WT[p]], sizeof pw_txt[0], "%.0f", w);
    if (p != 0) return;
    if (pw_ref_oat) snprintf(pw_txt[PF_OAT], sizeof pw_txt[PF_OAT], "%.0f", XPLMGetDataf(pw_ref_oat));
    if (pw_ref_baro) snprintf(pw_txt[PF_QNH], sizeof pw_txt[PF_QNH], "%.0f", XPLMGetDataf(pw_ref_baro) * 33.8639f);
    if (pw_ref_wdir && pw_ref_wspd) {
        float spd = XPLMGetDataf(pw_ref_wspd);
        int d = (int)(XPLMGetDataf(pw_ref_wdir) + 0.5f) % 360;
        if (d <= 0) d += 360;
        if (spd < 1.0f) pw_txt[PF_WIND][0] = 0;
        else snprintf(pw_txt[PF_WIND], sizeof pw_txt[PF_WIND], "%03d/%d", d, (int)(spd + 0.5f));
    }
    snprintf(pw_txt[PF_CG], sizeof pw_txt[PF_CG], "%.1f", wb_mac_pct(wb_getf(wb_ref_cg)));
}

/* the FMC's route into a page's fields (laminar/B747/efb/route_n: the
   origin, its runway, the destination, its runway, the flaps, the rating;
   the numbers, not the string, which reaches this plugin a frame or so
   later: s435) */
static void pw_fill_route(int p, const float *r)
{
    char apt[8], rwy[8];
    pw_unpack((int)(r[p ? 2 : 0] + 0.5f), apt, sizeof apt);
    pw_unpack((int)(r[p ? 3 : 1] + 0.5f), rwy, sizeof rwy);
    if (apt[0]) fw_copy(pw_txt[PW_F_APT[p]], sizeof pw_txt[0], apt);
    if (rwy[0]) fw_copy(pw_txt[PW_F_RWY[p]], sizeof pw_txt[0], rwy);
    if (p == 0) {
        int flaps = (int)(r[4] + 0.5f), rating = (int)(r[5] + 0.5f);
        if (flaps == 10 || flaps == 20) pw_tog[PT_FLAPS] = flaps;
        if (rating >= 0 && rating <= 2) pw_tog[PT_RATING] = rating;
    }
}

/* an XTLua string answer reaches this plugin a frame or so after the
   numbers (s435): read again for a while after each answer */
static void pw_read_texts(int p)
{
    pw_pg_t *g = &pw_pg[p];
    XPLMDataRef m = pw_fmc("laminar/B747/efb/msg");
    if (m) {
        int n = XPLMGetDatab(m, g->msg, 0, sizeof g->msg - 1);
        g->msg[n > 0 ? n : 0] = 0;
    }
    XPLMDataRef rl = pw_fmc("laminar/B747/efb/rwy_list");
    if (rl) {
        int n = XPLMGetDatab(rl, g->rwy_list, 0, sizeof g->rwy_list - 1);
        g->rwy_list[n > 0 ? n : 0] = 0;
    }
}

/* a request this window did not make (the flight tests', another
   add-on's, written straight into req_*): its answer shown with its entries
   (the arrays are this window's datarefs) */
static int pw_seen_ans = -1;
static void pw_adopt(void)
{
    float o[PWN_NOUT];
    XPLMDataRef od = pw_fmc("laminar/B747/efb/out"), rw = pw_fmc("laminar/B747/efb/rwy");
    if (!od || !rw) return;
    XPLMGetDatavf(od, o, 0, PWN_NOUT);
    int kind = (int)(o[0] + 0.5f);
    if (kind != 2 && kind != 3 && kind != 4) return;
    int p = kind == 4 ? 1 : 0;
    pw_pg_t *g = &pw_pg[p];
    pw_unpack(pw_req_i[0], pw_txt[PW_F_APT[p]], sizeof pw_txt[0]);
    pw_unpack(pw_req_i[1], pw_txt[PW_F_RWY[p]], sizeof pw_txt[0]);
    snprintf(pw_txt[PW_F_OAT[p]], sizeof pw_txt[0], "%.0f", pw_req_f[0]);
    snprintf(pw_txt[PW_F_QNH[p]], sizeof pw_txt[0], "%.0f", pw_req_f[1]);
    if (fabsf(pw_req_f[2]) < 0.5f) pw_txt[PW_F_WIND[p]][0] = 0;
    else snprintf(pw_txt[PW_F_WIND[p]], sizeof pw_txt[0], "%s%.0f", pw_req_f[2] < 0 ? "T" : "H", fabsf(pw_req_f[2]));
    snprintf(pw_txt[PW_F_WT[p]], sizeof pw_txt[0], "%.0f", pw_req_f[3]);
    if (p == 0) {
        pw_tog[PT_FLAPS] = pw_req_i[2] == 10 ? 10 : 20;
        pw_tog[PT_RATING] = pw_req_i[3] >= 0 && pw_req_i[3] <= 2 ? pw_req_i[3] : 0;
        pw_tog[PT_ATM] = pw_req_i[4] != 0;
        pw_tog[PT_PACKS] = pw_req_i[5] == 0 || pw_req_i[5] == 1 ? pw_req_i[5] : 3;
        pw_tog[PT_AI] = pw_req_i[6] >= 0 && pw_req_i[6] <= 2 ? pw_req_i[6] : 0;
        snprintf(pw_txt[PF_CG], sizeof pw_txt[0], "%.1f", pw_req_f[4]);
        if (pw_req_f[5] > 0.5f) snprintf(pw_txt[PF_SHIFT], sizeof pw_txt[0], "%.0f", pw_req_f[5]);
        else pw_txt[PF_SHIFT][0] = 0;
    } else {
        pw_tog[PT_LFLAPS] = pw_req_i[2] == 25 ? 25 : 30;
        pw_tog[PT_LCOND] = pw_req_i[7] & 3;
        pw_tog[PT_LBRAKE] = pw_req_i[8] >= 0 && pw_req_i[8] <= 5 ? pw_req_i[8] : 3;
        pw_tog[PT_LREV] = pw_req_i[9] == 2 || pw_req_i[9] == 0 ? pw_req_i[9] : 4;
        snprintf(pw_txt[PF_LADD], sizeof pw_txt[0], "%.0f", pw_req_f[8]);
    }
    XPLMGetDatavf(rw, g->rwy, 0, PWN_NRWY);
    g->rwy_ok = g->rwy[0] > 0.5f;
    g->rwy_apt = pw_req_i[0];
    g->rwy_rwy = pw_req_i[1];
    if (g->rwy_ok) g->magvar = pw_mag_less_true(g->rwy[9], g->rwy[10]);
    memcpy(g->out, o, sizeof o);
    g->out_ok = o[1] > 0.5f;
    g->out_sent = kind == 3 && o[29] > 0.5f;
    pw_filled[p] = 1;
    pw_page = p;
    pw_read_texts(p);
    pw_text_frames = 30;
    pw_text_page = p;
}

/* the FMC's answer, if the request waited for has one */
static void pw_poll(void)
{
    if (pw_text_frames > 0) {
        pw_text_frames--;
        pw_read_texts(pw_text_page);
    }
    if (!pw_wait) {
        XPLMDataRef ans = pw_fmc("laminar/B747/efb/ans_id");
        if (ans) {
            int a = XPLMGetDatai(ans);
            if (pw_seen_ans >= 0 && a != pw_seen_ans && a == pw_req_id) pw_adopt();
            pw_seen_ans = a;
        }
        return;
    }
    XPLMDataRef ans = pw_fmc("laminar/B747/efb/ans_id");
    pw_pg_t *g = &pw_pg[pw_wait_page];
    if (!ans || XPLMGetDatai(ans) != pw_wait) {
        if (pw_now() - pw_wait_t > 5.0f || pw_now() < pw_wait_t) {
            fw_copy(g->msg, sizeof g->msg, ans ? "FMC NOT ANSWERING" : "FMC NOT RUNNING");
            pw_wait = 0;
            pw_nqueue = 0;
        }
        return;
    }
    int kind = pw_wait_kind, p = pw_wait_page;
    pw_seen_ans = pw_wait;
    pw_wait = 0;
    pw_read_texts(p);
    pw_text_frames = 30;
    pw_text_page = p;
    if (kind == 5) {
        float r[8] = {0};
        XPLMDataRef rn = pw_fmc("laminar/B747/efb/route_n");
        if (rn) XPLMGetDatavf(rn, r, 0, 8);
        pw_fill_route(p, r);
        if (pw_txt[PW_F_APT[p]][0]) pw_ask(1, p);
    } else {
        XPLMDataRef rw = pw_fmc("laminar/B747/efb/rwy");
        if (rw) {
            XPLMGetDatavf(rw, g->rwy, 0, PWN_NRWY);
            g->rwy_ok = g->rwy[0] > 0.5f;
            g->rwy_apt = pw_req_i[0];
            g->rwy_rwy = pw_req_i[1];
            if (g->rwy_ok) g->magvar = pw_mag_less_true(g->rwy[9], g->rwy[10]);
        }
        if (kind == 2 || kind == 3 || kind == 4) {
            XPLMDataRef o = pw_fmc("laminar/B747/efb/out");
            if (o) XPLMGetDatavf(o, g->out, 0, PWN_NOUT);
            g->out_ok = o && g->out[1] > 0.5f && (int)(g->out[0] + 0.5f) == kind;
            g->out_sent = kind == 3 && g->out[29] > 0.5f;
        }
    }
    if (pw_nqueue > 0) {
        int next = pw_queue[0], np = pw_queue_page[0];
        for (int i = 1; i < pw_nqueue; i++) {
            pw_queue[i - 1] = pw_queue[i];
            pw_queue_page[i - 1] = pw_queue_page[i];
        }
        pw_nqueue--;
        pw_send(next, np);
    }
}

static void pw_hit(int l, int b, int r, int t, int id)
{
    if (pw_nhits >= PWN_HITS) return;
    pw_hits[pw_nhits].l = l; pw_hits[pw_nhits].b = b; pw_hits[pw_nhits].r = r; pw_hits[pw_nhits].t = t;
    pw_hits[pw_nhits].id = id;
    pw_nhits++;
}

/* a text field: its box (cyan, the text typed while entered) */
static void pw_field(int f, int x, int y, int w, int fh)
{
    int l = x, r = x + w, b = y - 4, t = y + fh + 2;
    pw_hit(l, b, r, t, f);
    if (pw_edit == f) {
        char a[24];
        snprintf(a, sizeof a, "%s_", pw_buf);
        fw_rect(l, b, r, t, FWN_SEL);
        fw_text(l + 5, y, FWN_WHITE, a);
        return;
    }
    fw_outline(l, b, r, t, FWN_RULE);
    fw_text(l + 5, y, pw_txt[f][0] ? FWN_CYAN : FWN_GREY, pw_txt[f][0] ? pw_txt[f] : "-");
}

static const char *pw_tog_text(int t)
{
    static char s[24];
    static const char *ab[6] = {"MAX MAN", "MAX AUTO", "4", "3", "2", "1"};
    static const char *cond[4] = {"DRY", "GOOD", "MEDIUM", "POOR"};
    switch (t) {
    case PT_COND: return "DRY";
    case PT_FLAPS: case PT_LFLAPS: snprintf(s, sizeof s, "%d", pw_tog[t]); return s;
    case PT_RATING:
        if (pw_tog[t] == 0) return "TO";
        return pw_tog[t] == 1 ? "TO 1" : "TO 2";
    case PT_ATM: return pw_tog[t] ? "ON" : "OFF";
    case PT_PACKS: return pw_tog[t] == 3 ? "ON" : pw_tog[t] == 1 ? "1 PACK" : "OFF";
    case PT_AI: return pw_tog[t] == 0 ? "OFF" : pw_tog[t] == 1 ? "ENG" : "ENG+WING";
    case PT_LCOND: return cond[pw_tog[t] & 3];
    case PT_LBRAKE: return ab[pw_tog[t] % 6];
    case PT_LREV: return pw_tog[t] == 4 ? "4 REV" : pw_tog[t] == 2 ? "2 REV" : "NO REV";
    }
    return "";
}

/* a choice: its label and its box (a click the next option) */
static void pw_choice(int t, const char *label, int x, int y, int lw, int w, int fh)
{
    fw_text(x, y, FWN_LIGHT, label);
    int l = x + lw, r = l + w, b = y - 4, tt = y + fh + 2;
    pw_hit(l, b, r, tt, PH_TOG + t);
    int hover = fw_in(pw_hover_x, pw_hover_y, l, b, r, tt);
    fw_button(l, b, r, tt, pw_tog_text(t), FWN_GREEN, FWN_GREEN_BOX, hover);
}

/* a whole number with commas, or "-" for 0 */
static void pw_kg(char *out, size_t n, float v)
{
    if (v <= 0.5f) fw_copy(out, n, "-");
    else wb_num(out, n, v);
}

/* a chart's limit weight: at or past the chart's top (`top` kg: the
   reading's lower bound, the FPPM's weight scale ends there) with "+" */
static void pw_kg_top(char *out, size_t n, float v, float top)
{
    pw_kg(out, n, v);
    size_t k = strlen(out);
    if (v >= top - 0.5f && k + 1 < n) {
        out[k] = '+';
        out[k + 1] = 0;
    }
}

static const char *PW_LIMIT[6] = {"", "FIELD", "CLIMB", "TIRE SPEED", "BRAKE ENERGY", "STRUCTURAL"};
static const char *PW_ATM[7] = {"", "the limit line", "25 % thrust", "field", "climb", "brake energy", "runway not dry"};

/* the airport and runway rows (both pages): the fields, the runways, the
   runway's data or the reason it has none; returns y below them */
static int pw_draw_runway(int p, int x0, int y, int lh, int fh)
{
    char a[200];
    pw_pg_t *g = &pw_pg[p];
    fw_text(x0, y, FWN_LIGHT, "Airport");
    pw_field(PW_F_APT[p], x0 + 70, y, 64, fh);
    fw_text(x0 + 150, y, FWN_LIGHT, "Runway");
    pw_field(PW_F_RWY[p], x0 + 210, y, 52, fh);
    y -= lh;
    if (g->rwy_list[0]) {
        snprintf(a, sizeof a, "Runways: %s", g->rwy_list);
        fw_text(x0, y, FWN_GREY, a);
    }
    y -= lh;
    if (pw_rwy_current(p)) {
        /* the takeoff's whole length; the landing's from the threshold */
        float len = p == 0 ? g->rwy[1] : g->rwy[1] - g->rwy[2];
        snprintf(a, sizeof a, "%s %.0f M  ELEV %.0f FT  SLOPE %+.2f %%  HDG %03.0fM", p == 0 ? "TORA" : "LDA",
            len * 0.3048f, g->rwy[6], g->rwy[7], pw_rwy_mag(p));
        fw_text(x0, y, FWN_GREEN, a);
    } else if (!g->rwy_ok && pw_txt[PW_F_APT[p]][0] && g->msg[0] && !pw_wait) {
        fw_text(x0, y, FWN_AMBER, g->msg);
    }
    return y - lh;
}

/* the wind's row: the field and its components */
static void pw_draw_wind(int p, int f, int x0, int y, int fh)
{
    char a[64];
    fw_text(x0, y, FWN_LIGHT, "Wind");
    pw_field(f, x0 + 100, y, 80, fh);
    float head = 0.0f, cross = 0.0f;
    if (pw_wind(p, &head, &cross)) {
        snprintf(a, sizeof a, "%s %.0f  X %.0f%s", head < -0.5f ? "TAIL" : "HEAD", fabsf(head), fabsf(cross),
            cross > 0.5f ? " R" : cross < -0.5f ? " L" : "");
        fw_text(x0 + 190, y, FWN_GREEN, a);
    } else {
        fw_text(x0 + 190, y, FWN_GREY, pw_txt[f][0] ? "needs the runway" : "");
    }
}

/* the buttons and the message line; returns y below them */
static int pw_draw_buttons(int p, int x0, int y, int lh, int fh)
{
    pw_pg_t *g = &pw_pg[p];
    int bw = 70, bh = fh + 8;
    const char *bn[PB_N] = {"CALC", "SEND", "FMC/SIM"};
    int ground = wb_on_ground();
    for (int k = 0; k < PB_N; k++) {
        if (p == 1 && k == PB_SEND) continue;
        int bl = x0 + k * (bw + 10), bb = y - 4;
        pw_hit(bl, bb, bl + bw, bb + bh, PH_BTN + k);
        int hover = fw_in(pw_hover_x, pw_hover_y, bl, bb, bl + bw, bb + bh);
        int can = k != PB_SEND || (g->out_ok && ground);
        fw_button(bl, bb, bl + bw, bb + bh, bn[k], can ? FWN_CYAN : FWN_GREY, can ? FWN_CYAN_BOX : FWN_RULE, hover && can);
    }
    y -= lh + 6;
    if (pw_wait) fw_text(x0, y, FWN_GREY, "...");
    else if (g->out_sent && !g->msg[0]) fw_text(x0, y, FWN_GREEN, "SENT TO TAKEOFF REF AND THRUST LIM");
    else if (g->msg[0] && (pw_rwy_current(p) || !pw_txt[PW_F_APT[p]][0])) fw_text(x0, y, FWN_AMBER, g->msg);
    y -= lh;
    fw_text(x0, y, FWN_GREY, "Click a box, type, Enter. Wind: 250/12 (M) or H10/T5");
    return y - lh;
}

static void pw_draw_takeoff(int l, int t, int r, int b, int fh)
{
    int lh = fh + 9, pad = 14;
    int mid = l + (r - l) * 50 / 100;
    int x0 = l + pad, xr = mid + 10, xe = r - pad;
    int y = t - pad - fh - lh - 4;
    char a[200], c[64];
    pw_pg_t *g = &pw_pg[0];

    /* the inputs */
    fw_text(x0, y, FWN_WHITE, "TAKEOFF");
    y -= lh;
    y = pw_draw_runway(0, x0, y, lh, fh);
    fw_text(x0, y, FWN_LIGHT, "Start shift M");
    pw_field(PF_SHIFT, x0 + 100, y, 56, fh);
    fw_text(x0 + 170, y, FWN_LIGHT, "Length M");
    pw_field(PF_LEN, x0 + 240, y, 60, fh);
    y -= lh;
    fw_text(x0, y, FWN_LIGHT, "Slope %");
    pw_field(PF_SLOPE, x0 + 100, y, 56, fh);
    pw_choice(PT_COND, "Runway", x0 + 170, y, 70, 60, fh);
    y -= lh;
    pw_draw_wind(0, PF_WIND, x0, y, fh);
    y -= lh;
    fw_text(x0, y, FWN_LIGHT, "OAT C");
    pw_field(PF_OAT, x0 + 100, y, 56, fh);
    fw_text(x0 + 170, y, FWN_LIGHT, "QNH");
    pw_field(PF_QNH, x0 + 240, y, 60, fh);
    y -= lh;
    fw_text(x0, y, FWN_LIGHT, "Weight KG");
    pw_field(PF_WT, x0 + 100, y, 80, fh);
    fw_text(x0 + 190, y, FWN_LIGHT, "CG %MAC");
    pw_field(PF_CG, x0 + 254, y, 46, fh);
    y -= lh;
    pw_choice(PT_FLAPS, "Flaps", x0, y, 100, 50, fh);
    pw_choice(PT_RATING, "Rating", x0 + 170, y, 70, 60, fh);
    y -= lh;
    pw_choice(PT_ATM, "Assumed temp", x0, y, 100, 50, fh);
    pw_choice(PT_PACKS, "Packs", x0 + 170, y, 70, 60, fh);
    y -= lh;
    pw_choice(PT_AI, "Anti-ice", x0, y, 100, 76, fh);
    y -= lh + 4;
    pw_draw_buttons(0, x0, y, lh, fh);

    /* the answers */
    fw_rect(mid, b + pad, mid + 1, t - pad - lh, FWN_RULE);
    y = t - pad - fh - lh - 4;
    fw_text(xr, y, FWN_WHITE, "RESULT");
    y -= lh;
    if (!g->out_ok) {
        fw_text(xr, y, FWN_GREY, "CALC for the takeoff's data");
        return;
    }
    const float *o = g->out;
    snprintf(a, sizeof a, "Flaps %.0f  %s  %s KG", o[26], o[27] < 0.5f ? "TO" : o[27] < 1.5f ? "TO 1" : "TO 2",
        (wb_num(c, sizeof c, o[28]), c));
    fw_text(xr, y, FWN_LIGHT, a);
    y -= lh;
    snprintf(a, sizeof a, "Field length %.0f M  Press alt %.0f FT", o[22] * 0.3048f, o[2]);
    fw_text(xr, y, FWN_LIGHT, a);
    y -= lh;
    fw_text(xr, y, FWN_WHITE, "LIMIT WEIGHTS");
    fw_text(xe - fw_width("KG"), y, FWN_GREY, "KG");
    y -= lh;
    const char *names[5] = {"Field length", "Climb", "Tire speed", "Brake energy", "Structural"};
    for (int k = 0; k < 5; k++) {
        float v = o[3 + k];
        if (k == 3 && v <= 0.5f) continue;
        /* the field, climb and tire speed charts end at 460 t (the tire
           speed's flaps 20 note adds 19 t: 479 t) */
        pw_kg_top(c, sizeof c, v, k == 2 ? (o[26] > 15.0f ? 479000.0f : 460000.0f) : k < 2 ? 460000.0f : 1e9f);
        int limit = (int)(o[9] + 0.5f) == k + 1;
        fw_text(xr + 10, y, limit ? FWN_WHITE : FWN_LIGHT, names[k]);
        fw_text(xe - fw_width(c), y, limit ? FWN_AMBER : FWN_GREEN, c);
        y -= lh;
    }
    wb_num(c, sizeof c, o[8]);
    snprintf(a, sizeof a, "MAX %s", PW_LIMIT[(int)(o[9] + 0.5f) % 6]);
    fw_text(xr + 10, y, FWN_WHITE, a);
    fw_text(xe - fw_width(c), y, FWN_WHITE, c);
    y -= lh;
    int why = (int)(o[11] + 0.5f);
    if (o[10] > -90.0f) {
        snprintf(a, sizeof a, "ASSUMED TEMP %.0fC", o[10]);
        fw_text(xr, y, FWN_GREEN, a);
        if (why > 0 && why < 7) {
            snprintf(c, sizeof c, "(by %s)", PW_ATM[why]);
            fw_text(xe - fw_width(c), y, FWN_GREY, c);
        }
    } else {
        snprintf(a, sizeof a, "ASSUMED TEMP -%s%s", why == 6 ? "  (runway not dry)" : "",
            pw_tog[PT_ATM] && why != 6 ? "  (none above the OAT)" : "");
        fw_text(xr, y, FWN_LIGHT, a);
    }
    y -= lh;
    if (o[18] > 0.5f) snprintf(a, sizeof a, "N1 %.1f %%", o[17]);
    else snprintf(a, sizeof a, "EPR %.2f", o[17]);
    fw_text(xr, y, FWN_GREEN, a);
    if (o[19] > 0.05f) {
        snprintf(c, sizeof c, "thrust -%.0f %%", o[19]);
        fw_text(xe - fw_width(c), y, FWN_GREY, c);
    }
    y -= lh;
    snprintf(a, sizeof a, "V1 %.0f   VR %.0f   V2 %.0f", o[12], o[13], o[14]);
    fw_text(xr, y, FWN_GREEN, a);
    y -= lh;
    snprintf(a, sizeof a, "VMBE %.0f%s", o[15], o[16] > 0.5f ? "" : "  (not limiting)");
    fw_text(xr, y, FWN_LIGHT, a);
    y -= lh;
    if (o[20] >= 0.0f) snprintf(a, sizeof a, "TRIM %.1f   VREF 30 %.0f", o[20], o[21]);
    else snprintf(a, sizeof a, "TRIM -   VREF 30 %.0f", o[21]);
    fw_text(xr, y, FWN_GREEN, a);
}

static void pw_draw_landing(int l, int t, int r, int b, int fh)
{
    int lh = fh + 9, pad = 14;
    int mid = l + (r - l) * 50 / 100;
    int x0 = l + pad, xr = mid + 10, xe = r - pad;
    int y = t - pad - fh - lh - 4;
    char a[200], c[64];
    pw_pg_t *g = &pw_pg[1];

    fw_text(x0, y, FWN_WHITE, "LANDING");
    y -= lh;
    y = pw_draw_runway(1, x0, y, lh, fh);
    fw_text(x0, y, FWN_LIGHT, "Length M");
    pw_field(PF_LLEN, x0 + 100, y, 56, fh);
    fw_text(x0 + 170, y, FWN_LIGHT, "Slope %");
    pw_field(PF_LSLOPE, x0 + 240, y, 60, fh);
    y -= lh;
    pw_choice(PT_LCOND, "Braking", x0, y, 100, 76, fh);
    y -= lh;
    pw_draw_wind(1, PF_LWIND, x0, y, fh);
    y -= lh;
    fw_text(x0, y, FWN_LIGHT, "OAT C");
    pw_field(PF_LOAT, x0 + 100, y, 56, fh);
    fw_text(x0 + 170, y, FWN_LIGHT, "QNH");
    pw_field(PF_LQNH, x0 + 240, y, 60, fh);
    y -= lh;
    fw_text(x0, y, FWN_LIGHT, "Weight KG");
    pw_field(PF_LWT, x0 + 100, y, 80, fh);
    fw_text(x0 + 190, y, FWN_LIGHT, "VREF +");
    pw_field(PF_LADD, x0 + 254, y, 46, fh);
    y -= lh;
    pw_choice(PT_LFLAPS, "Flaps", x0, y, 100, 50, fh);
    pw_choice(PT_LREV, "Reverse", x0 + 170, y, 70, 60, fh);
    y -= lh;
    pw_choice(PT_LBRAKE, "Autobrakes", x0, y, 100, 76, fh);
    y -= lh + 4;
    pw_draw_buttons(1, x0, y, lh, fh);

    fw_rect(mid, b + pad, mid + 1, t - pad - lh, FWN_RULE);
    y = t - pad - fh - lh - 4;
    fw_text(xr, y, FWN_WHITE, "RESULT");
    y -= lh;
    if (!g->out_ok) {
        fw_text(xr, y, FWN_GREY, "CALC for the landing's data");
        return;
    }
    const float *o = g->out;
    snprintf(a, sizeof a, "Flaps %.0f  %s KG  Press alt %.0f FT", o[14], (wb_num(c, sizeof c, o[15]), c), o[2]);
    fw_text(xr, y, FWN_LIGHT, a);
    y -= lh;
    snprintf(a, sizeof a, "VREF %.0f   APPROACH %.0f", o[3], o[4]);
    fw_text(xr, y, FWN_GREEN, a);
    y -= lh;
    fw_text(xr, y, FWN_WHITE, "LANDING DISTANCE (FCOM, IN FLIGHT)");
    y -= lh;
    if (o[5] > 0.5f) {
        snprintf(a, sizeof a, "%.0f M  of LDA %.0f M", o[5], o[6]);
        float margin = o[6] - o[5];
        fw_text(xr + 10, y, margin >= 0.0f ? FWN_GREEN : FWN_AMBER, a);
        snprintf(c, sizeof c, "%s%.0f M", margin >= 0.0f ? "margin " : "short ", fabsf(margin));
        fw_text(xe - fw_width(c), y, margin >= 0.0f ? FWN_LIGHT : FWN_AMBER, c);
    } else {
        fw_text(xr + 10, y, FWN_GREY, "-");
    }
    y -= lh;
    fw_text(xr, y, FWN_WHITE, "DISPATCH LIMIT WEIGHTS (FPPM)");
    fw_text(xe - fw_width("KG"), y, FWN_GREY, "KG");
    y -= lh;
    /* field length, climb, the structural (FCOM p.78), then the least:
       normal, with ice, low visibility (FCOM p.1183) */
    const char *names[3] = {"Field length", "Climb", "Structural"};
    const float vals[3] = {o[8], o[9], o[22]};
    for (int k = 0; k < 3; k++) {
        /* the landing field length chart ends at 400 t (FPPM p.71-74) */
        pw_kg_top(c, sizeof c, vals[k], k == 0 ? 400000.0f : 1e9f);
        fw_text(xr + 10, y, FWN_LIGHT, names[k]);
        fw_text(xe - fw_width(c), y, FWN_GREEN, c);
        y -= lh;
    }
    pw_kg(c, sizeof c, o[10]);
    snprintf(a, sizeof a, "NORMAL  (VREF %.0f)", o[11]);
    fw_text(xr + 10, y, FWN_WHITE, a);
    fw_text(xe - fw_width(c), y, o[10] > 0.5f && o[15] > o[10] + 0.5f ? FWN_AMBER : FWN_WHITE, c);
    y -= lh;
    pw_kg(c, sizeof c, o[20]);
    fw_text(xr + 10, y, FWN_LIGHT, "With ice");
    fw_text(xe - fw_width(c), y, FWN_GREEN, c);
    y -= lh;
    pw_kg(c, sizeof c, o[19]);
    fw_text(xr + 10, y, FWN_LIGHT, "Low visibility");
    fw_text(xe - fw_width(c), y, FWN_GREEN, c);
    y -= lh;
    pw_kg(c, sizeof c, o[12]);
    fw_text(xr, y, FWN_LIGHT, "Quick turnaround limit");
    fw_text(xe - fw_width(c), y, FWN_GREEN, c);
    y -= lh;
    if (o[13] > 0.5f) {
        snprintf(a, sizeof a, "(heavier: wait %.0f min before the next takeoff)", o[13]);
        fw_text(xr + 10, y, FWN_GREY, a);
        y -= lh;
    }
    if (o[21] > 0.5f) fw_text(xr, y, FWN_AMBER, "FLAPS 30 SPEED ABOVE 167 KT: FLAPS 25 (FPPM)");
}

static void pw_draw_body(XPLMWindowID w)
{
    int l = 0, t = 0, r = 0, b = 0;
    XPLMGetWindowGeometry(w, &l, &t, &r, &b);
    int fh = 0;
    XPLMGetFontDimensions(xplmFont_Proportional, NULL, &fh, NULL);
    pw_nhits = 0;
    fw_rect(l, b, r, t, FWN_BG);
    /* the pages */
    const char *pages[2] = {"TAKEOFF", "LANDING"};
    int pad = 14, bh = fh + 8;
    for (int k = 0; k < 2; k++) {
        int bl = l + pad + k * 100, bt = t - pad, bb = bt - bh;
        pw_hit(bl, bb, bl + 90, bt, PH_PAGE + k);
        if (pw_page == k) fw_rect(bl, bb, bl + 90, bt, FWN_SEL);
        fw_button(bl, bb, bl + 90, bt, pages[k], pw_page == k ? FWN_WHITE : FWN_LIGHT, FWN_RULE,
            pw_page != k && fw_in(pw_hover_x, pw_hover_y, bl, bb, bl + 90, bt));
    }
    if (pw_page == 0) pw_draw_takeoff(l, t, r, b, fh);
    else pw_draw_landing(l, t, r, b, fh);
}

static void pw_draw(XPLMWindowID w, void *ref)
{
    (void)ref;
    GLboolean cull = glIsEnabled(GL_CULL_FACE);
    if (cull) glDisable(GL_CULL_FACE);
    pw_draw_body(w);
    if (cull) glEnable(GL_CULL_FACE);
}

static void pw_place(XPLMWindowID w)
{
    int sl = 0, st = 0, sr = 0, sb = 0;
    XPLMGetScreenBoundsGlobal(&sl, &st, &sr, &sb);
    int fh = 0;
    XPLMGetFontDimensions(xplmFont_Proportional, NULL, &fh, NULL);
    int ww = 760, wh = 14 * 2 + (fh + 9) * 19 + fh + 8;
    if (wh > st - sb - 40) wh = st - sb - 40;
    int cx = (sl + sr) / 2, cy = (sb + st) / 2;
    XPLMSetWindowGeometry(w, cx - ww / 2, cy + wh / 2, cx + ww / 2, cy - wh / 2);
}

static void pw_edit_end(void)
{
    if (pw_edit < 0) return;
    pw_edit = -1;
    if (pw_win && XPLMHasKeyboardFocus(pw_win)) XPLMTakeKeyboardFocus(0);
}

/* the field's entry kept; a new airport or runway looked up */
static void pw_edit_commit(void)
{
    if (pw_edit < 0) return;
    int f = pw_edit, p = f >= PF_LAPT ? 1 : 0;
    for (char *s = pw_buf; *s; s++) *s = (char)toupper((unsigned char)*s);
    fw_copy(pw_txt[f], sizeof pw_txt[f], pw_buf);
    pw_edit_end();
    pw_pg[p].out_ok = 0;
    pw_pg[p].out_sent = 0;
    pw_pg[p].msg[0] = 0;
    if ((f == PW_F_APT[p] || f == PW_F_RWY[p]) && pw_txt[PW_F_APT[p]][0]) {
        if (f == PW_F_APT[p]) pw_pg[p].rwy_list[0] = 0;
        pw_ask(1, p);
    }
}

/* a page's entries from the FMC and the sim */
static void pw_fill(int p)
{
    pw_fill_sim(p);
    pw_pg[p].out_ok = 0;
    pw_pg[p].out_sent = 0;
    pw_pg[p].msg[0] = 0;
    pw_ask(5, p);
}

/* a button of the page shown */
static void pw_button(int k)
{
    int p = pw_page;
    if (k == PB_CALC) {
        pw_pg[p].out_sent = 0;
        if (!pw_rwy_current(p)) pw_ask(1, p);
        pw_ask(p == 0 ? 2 : 4, p);
    } else if (k == PB_SEND) {
        if (p == 0 && pw_pg[0].out_ok && wb_on_ground()) pw_ask(3, 0);
    } else if (k == PB_FILL) {
        pw_fill(p);
    }
}

static void pw_toggle(int t)
{
    switch (t) {
    case PT_COND: pw_tog[t] = 0; break;
    case PT_FLAPS: pw_tog[t] = pw_tog[t] == 10 ? 20 : 10; break;
    case PT_RATING: pw_tog[t] = (pw_tog[t] + 1) % 3; break;
    case PT_ATM: pw_tog[t] = !pw_tog[t]; break;
    case PT_PACKS: pw_tog[t] = pw_tog[t] == 3 ? 1 : pw_tog[t] == 1 ? 0 : 3; break;
    case PT_AI: pw_tog[t] = (pw_tog[t] + 1) % 3; break;
    case PT_LFLAPS: pw_tog[t] = pw_tog[t] == 30 ? 25 : 30; break;
    case PT_LCOND: pw_tog[t] = (pw_tog[t] + 1) % 4; break;
    case PT_LBRAKE: pw_tog[t] = (pw_tog[t] + 1) % 6; break;
    case PT_LREV: pw_tog[t] = pw_tog[t] == 4 ? 2 : pw_tog[t] == 2 ? 0 : 4; break;
    }
    int p = t >= PT_LFLAPS ? 1 : 0;
    pw_pg[p].out_ok = 0;
    pw_pg[p].out_sent = 0;
}

static void pw_set_page(int p)
{
    pw_edit_end();
    pw_page = p ? 1 : 0;
    if (!pw_filled[pw_page]) {
        pw_filled[pw_page] = 1;
        pw_fill(pw_page);
    }
}

static int pw_click(XPLMWindowID w, int x, int y, XPLMMouseStatus st, void *ref)
{
    (void)ref;
    if (st != xplm_MouseDown) return 1;
    for (int i = 0; i < pw_nhits; i++) {
        if (!fw_in(x, y, pw_hits[i].l, pw_hits[i].b, pw_hits[i].r, pw_hits[i].t)) continue;
        int id = pw_hits[i].id;
        if (pw_edit >= 0 && pw_edit != id) pw_edit_commit();
        if (id < PF_N) {
            pw_edit = id;
            pw_buf[0] = 0;
            XPLMTakeKeyboardFocus(w);
        } else if (id >= PH_PAGE) {
            pw_set_page(id - PH_PAGE);
        } else if (id >= PH_BTN) {
            pw_button(id - PH_BTN);
        } else if (id >= PH_TOG) {
            pw_toggle(id - PH_TOG);
        }
        return 1;
    }
    pw_edit_commit();
    return 1;
}

static int pw_wheel(XPLMWindowID w, int x, int y, int wheel, int clicks, void *ref)
{
    (void)w; (void)x; (void)y; (void)wheel; (void)clicks; (void)ref;
    return 1;
}

/* letters, digits, + - . / ; Backspace, Enter; Escape or the focus lost:
   none */
static void pw_key(XPLMWindowID w, char key, XPLMKeyFlags flags, char vkey, void *ref, int losing)
{
    (void)w; (void)ref;
    if (losing) {
        pw_edit = -1;
        return;
    }
    if (pw_edit < 0 || !(flags & xplm_DownFlag)) return;
    unsigned char vk = (unsigned char)vkey;
    size_t n = strlen(pw_buf);
    if (vk == XPLM_VK_RETURN || vk == XPLM_VK_ENTER || vk == XPLM_VK_NUMPAD_ENT || key == '\r' || key == '\n') {
        pw_edit_commit();
    } else if (vk == XPLM_VK_ESCAPE) {
        pw_edit_end();
    } else if (vk == XPLM_VK_BACK || vk == XPLM_VK_DELETE) {
        if (n > 0) pw_buf[n - 1] = 0;
    } else if ((isalnum((unsigned char)key) || key == '.' || key == '-' || key == '+' || key == '/')
        && n + 1 < sizeof pw_buf && n + 1 < sizeof pw_txt[0]) {
        pw_buf[n] = key;
        pw_buf[n + 1] = 0;
    }
}

static XPLMCursorStatus pw_cursor(XPLMWindowID w, int x, int y, void *ref)
{
    (void)w; (void)ref;
    pw_hover_x = x;
    pw_hover_y = y;
    return xplm_CursorDefault;
}

static int pw_shown(void)
{
    return pw_win && XPLMGetWindowIsVisible(pw_win);
}

static void pw_show(int on)
{
    if (!on) {
        pw_edit_end();
        if (pw_win) XPLMSetWindowIsVisible(pw_win, 0);
        return;
    }
    if (!pw_win) {
        XPLMCreateWindow_t p;
        memset(&p, 0, sizeof p);
        p.structSize = sizeof p;
        p.left = 100;
        p.top = 700;
        p.right = 860;
        p.bottom = 200;
        p.visible = 0;
        p.drawWindowFunc = pw_draw;
        p.handleMouseClickFunc = pw_click;
        p.handleRightClickFunc = pw_click;
        p.handleMouseWheelFunc = pw_wheel;
        p.handleKeyFunc = pw_key;
        p.handleCursorFunc = pw_cursor;
        p.refcon = NULL;
        p.layer = xplm_WindowLayerFloatingWindows;
        p.decorateAsFloatingWindow = xplm_WindowDecorationRoundRectangle;
        pw_win = XPLMCreateWindowEx(&p);
        if (!pw_win) return;
        XPLMSetWindowPositioningMode(pw_win, xplm_WindowPositionFree, -1);
        XPLMSetWindowResizingLimits(pw_win, 700, 420, 1600, 1400);
        XPLMSetWindowTitle(pw_win, "747-400 Takeoff and Landing Performance");
        pw_place(pw_win);
    }
    if (fw_ref_vr && XPLMGetDatai(fw_ref_vr)) {
        XPLMSetWindowPositioningMode(pw_win, xplm_WindowVR, -1);
    } else if (XPLMWindowIsInVR(pw_win)) {
        XPLMSetWindowPositioningMode(pw_win, xplm_WindowPositionFree, -1);
        pw_place(pw_win);
    }
    XPLMSetWindowIsVisible(pw_win, 1);
    XPLMBringWindowToFront(pw_win);
    /* the first time a page shows: the FMC's route and the sim's values */
    pw_set_page(pw_page);
}

static int pw_command(XPLMCommandRef cmd, XPLMCommandPhase phase, void *ref)
{
    (void)cmd; (void)ref;
    if (phase == xplm_CommandBegin) pw_show(!pw_shown());
    return 0;
}

/* the buttons' commands (the page shown) */
static int pw_btn_command(XPLMCommandRef cmd, XPLMCommandPhase phase, void *ref)
{
    (void)cmd;
    if (phase == xplm_CommandBegin) pw_button((int)(intptr_t)ref);
    return 0;
}

/* the FMC's answers every frame, the window shown or not */
static float pw_loop(float since, float since_loop, int counter, void *ref)
{
    (void)since; (void)since_loop; (void)counter; (void)ref;
    pw_poll();
    return -1.0f;
}

static int pw_open_get(void *ref)
{
    (void)ref;
    if (!pw_shown()) return 0;
    if (XPLMWindowIsInVR(pw_win)) return 3;
    return XPLMWindowIsPoppedOut(pw_win) ? 2 : 1;
}
static void pw_open_set(void *ref, int v) { (void)ref; pw_show(v != 0); }
static int pw_page_get(void *ref) { (void)ref; return pw_page; }
static void pw_page_set(void *ref, int v) { (void)ref; pw_set_page(v != 0); }
static int pw_req_id_get(void *ref) { (void)ref; return pw_req_id; }
static void pw_req_id_set(void *ref, int v) { (void)ref; pw_req_id = v; }
static int pw_req_kind_get(void *ref) { (void)ref; return pw_req_kind; }
static void pw_req_kind_set(void *ref, int v) { (void)ref; pw_req_kind = v; }

static int pw_req_i_get(void *ref, int *out, int off, int max)
{
    (void)ref;
    if (!out) return PWN_NI;
    int n = 0;
    for (int i = off; i < PWN_NI && n < max; i++) out[n++] = pw_req_i[i];
    return n;
}
static void pw_req_i_set(void *ref, int *in, int off, int count)
{
    (void)ref;
    for (int i = 0; i < count && off + i < PWN_NI; i++) pw_req_i[off + i] = in[i];
}
static int pw_req_f_get(void *ref, float *out, int off, int max)
{
    (void)ref;
    if (!out) return PWN_NF;
    int n = 0;
    for (int i = off; i < PWN_NF && n < max; i++) out[n++] = pw_req_f[i];
    return n;
}
static void pw_req_f_set(void *ref, float *in, int off, int count)
{
    (void)ref;
    for (int i = 0; i < count && off + i < PWN_NF; i++) pw_req_f[off + i] = in[i];
}

static void pw_menu_pick(void)
{
    pw_show(!pw_shown());
}

static void pw_message(int msg)
{
    if (!pw_win) return;
    if (msg == XPLM_MSG_ENTERED_VR && XPLMGetWindowIsVisible(pw_win)) {
        XPLMSetWindowPositioningMode(pw_win, xplm_WindowVR, -1);
    } else if (msg == XPLM_MSG_EXITING_VR && XPLMWindowIsInVR(pw_win)) {
        XPLMSetWindowPositioningMode(pw_win, xplm_WindowPositionFree, -1);
        pw_place(pw_win);
    }
}

static void pw_start(XPLMMenuID m)
{
    pw_ref_oat = XPLMFindDataRef("sim/weather/aircraft/temperature_ambient_deg_c");
    if (!pw_ref_oat) pw_ref_oat = XPLMFindDataRef("sim/weather/temperature_ambient_c");
    pw_ref_baro = XPLMFindDataRef("sim/weather/barometer_sealevel_inhg");
    pw_ref_wdir = XPLMFindDataRef("sim/cockpit2/gauges/indicators/wind_heading_deg_mag");
    pw_ref_wspd = XPLMFindDataRef("sim/cockpit2/gauges/indicators/wind_speed_kts");
    snprintf(pw_txt[PF_LADD], sizeof pw_txt[PF_LADD], "5");
    pw_ref_open = int_ref("laminar/B747/efb/window_open", pw_open_get, pw_open_set);
    pw_ref_page = int_ref("laminar/B747/efb/page", pw_page_get, pw_page_set);
    pw_ref_req_id = int_ref("laminar/B747/efb/req_id", pw_req_id_get, pw_req_id_set);
    pw_ref_req_kind = int_ref("laminar/B747/efb/req_kind", pw_req_kind_get, pw_req_kind_set);
    pw_ref_req_i = XPLMRegisterDataAccessor("laminar/B747/efb/req_i", xplmType_IntArray, 1,
        NULL, NULL, NULL, NULL, NULL, NULL, pw_req_i_get, pw_req_i_set, NULL, NULL, NULL, NULL, NULL, NULL);
    pw_ref_req_f = XPLMRegisterDataAccessor("laminar/B747/efb/req_f", xplmType_FloatArray, 1,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, pw_req_f_get, pw_req_f_set, NULL, NULL, NULL, NULL);
    pw_cmd_toggle = XPLMCreateCommand("laminar/B747/efb/window_toggle", "Show or hide the takeoff and landing performance window");
    XPLMRegisterCommandHandler(pw_cmd_toggle, pw_command, 1, NULL);
    const char *bc[3] = {"laminar/B747/efb/calc", "laminar/B747/efb/send", "laminar/B747/efb/fill"};
    const char *bd[3] = {"The performance window's CALC (the page shown)",
        "The performance window's SEND (the takeoff's, to TAKEOFF REF and THRUST LIM)",
        "The performance window's FMC/SIM (the page's entries from the FMC and the sim)"};
    for (int k = 0; k < 3; k++) {
        pw_cmd_btn[k] = XPLMCreateCommand(bc[k], bd[k]);
        XPLMRegisterCommandHandler(pw_cmd_btn[k], pw_btn_command, 1, (void *)(intptr_t)k);
    }
    XPLMRegisterFlightLoopCallback(pw_loop, -1.0f, NULL);
    if (m) XPLMAppendMenuItem(m, "Takeoff and landing performance...", (void *)(intptr_t)PWN_MENU_REF, 0);
}

static void pw_stop(void)
{
    XPLMUnregisterFlightLoopCallback(pw_loop, NULL);
    for (int k = 0; k < 3; k++) XPLMUnregisterCommandHandler(pw_cmd_btn[k], pw_btn_command, 1, (void *)(intptr_t)k);
    XPLMUnregisterCommandHandler(pw_cmd_toggle, pw_command, 1, NULL);
    XPLMUnregisterDataAccessor(pw_ref_open);
    XPLMUnregisterDataAccessor(pw_ref_page);
    XPLMUnregisterDataAccessor(pw_ref_req_id);
    XPLMUnregisterDataAccessor(pw_ref_req_kind);
    XPLMUnregisterDataAccessor(pw_ref_req_i);
    XPLMUnregisterDataAccessor(pw_ref_req_f);
    if (pw_win) XPLMDestroyWindow(pw_win);
    pw_win = NULL;
}
