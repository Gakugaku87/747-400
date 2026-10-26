/*
 * B747 FMS bridge (6-1/6-2 step 5e; docs/overhaul/notes/ATA-34-61-FMC.md §23):
 * the FMC's flight plan, current and displayed waypoints to X-Plane's FMS
 * from X-Plane's own thread.
 *
 * The FMC (XTLua) wrote xtlua/loadtoFMS and xtlua/currentFMSID, which XTLua
 * applies at once on its own thread with no lock against X-Plane's (XTLua's
 * xpmtdatarefs.cpp: the FMS cleared and loaded, the FMS JSON parsed); X-Plane
 * crashed three times on 2026-10-26 right after them. XTLua writes ordinary
 * datarefs from X-Plane's thread (its update), so the FMC writes these
 * instead, and this plugin calls the FMS from its flight loop:
 *
 *   laminar/B747/fms/xp/plan       (data) an X-Plane flight plan (.fms, v1100),
 *                                   loaded into the pilot's FMS once written;
 *                                   a first line "CURRENT n" (ours, left out
 *                                   of the load) sets the current entry after
 *                                   the load (X-Plane starts a plan at its
 *                                   first entry)
 *   laminar/B747/fms/xp/current    (int)  the entry the FMS flies to, from 1
 *   laminar/B747/fms/xp/displayed  (int)  the entry the FMS shows (the ND's
 *                                   PLAN centre), from 1
 *   laminar/B747/fms/xp/loads      (int)  plans loaded (read only)
 *   laminar/B747/fms/xp/bridge     (int)  1: this plugin is here (read only)
 *
 * Built with docs/overhaul/tools/build_fms_bridge.sh (MinGW-w64, the X-Plane
 * SDK 4.3.0) into ../64/win.xpl.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "XPLMDefs.h"
#include "XPLMDataAccess.h"
#include "XPLMNavigation.h"
#include "XPLMPlugin.h"
#include "XPLMProcessing.h"

#define PLAN_MAX 65536

static char plan[PLAN_MAX];
static int plan_len = 0;
static int plan_new = 0;
static int plan_current = 0;
static int current = 0;
static int current_new = 0;
static int displayed = 0;
static int displayed_new = 0;
static int loads = 0;

static XPLMDataRef refs[5];

/* the plan as last written */
static int plan_get(void *ref, void *out, int offset, int max)
{
    (void)ref;
    if (!out) return plan_len;
    if (offset < 0 || offset >= plan_len || max <= 0) return 0;
    int n = plan_len - offset;
    if (n > max) n = max;
    memcpy(out, plan + offset, (size_t)n);
    return n;
}

/* XTLua writes the whole text from 0; a later part (offset) is ignored */
static void plan_set(void *ref, void *in, int offset, int len)
{
    (void)ref;
    if (!in || offset != 0 || len < 0 || len >= PLAN_MAX) return;
    memcpy(plan, in, (size_t)len);
    plan[len] = 0;
    plan_len = len;
    plan_new = 1;
}

static int current_get(void *ref) { (void)ref; return XPLMGetDestinationFMSEntry() + 1; }
static void current_set(void *ref, int v) { (void)ref; current = v; current_new = 1; }
static int displayed_get(void *ref) { (void)ref; return XPLMGetDisplayedFMSEntry() + 1; }
static void displayed_set(void *ref, int v) { (void)ref; displayed = v; displayed_new = 1; }
static int loads_get(void *ref) { (void)ref; return loads; }
static int bridge_get(void *ref) { (void)ref; return 1; }

/* an entry from 1 to the FMS's, when it has it */
static void set_entry(void (*set)(int), int n)
{
    if (n >= 1 && n <= XPLMCountFMSEntries()) set(n - 1);
}

static float loop(float since_call, float since_loop, int counter, void *ref)
{
    (void)since_call; (void)since_loop; (void)counter; (void)ref;
    if (plan_new) {
        plan_new = 0;
        const char *text = plan;
        unsigned int len = (unsigned int)plan_len;
        plan_current = 0;
        if (strncmp(plan, "CURRENT ", 8) == 0) {
            plan_current = atoi(plan + 8);
            const char *nl = strchr(plan, '\n');
            if (nl) {
                text = nl + 1;
                len = (unsigned int)(plan_len - (int)(text - plan));
            }
        }
        for (int i = XPLMCountFMSEntries() - 1; i >= 0; i--) XPLMClearFMSEntry(i);
        XPLMLoadFMSFlightPlan(0, text, len);
        loads++;
        set_entry(XPLMSetDestinationFMSEntry, plan_current);
    }
    if (current_new) {
        current_new = 0;
        set_entry(XPLMSetDestinationFMSEntry, current);
    }
    if (displayed_new) {
        displayed_new = 0;
        set_entry(XPLMSetDisplayedFMSEntry, displayed);
    }
    return -1.0f;
}

/* an int dataref: its getter and setter (NULL: read only) */
static XPLMDataRef int_ref(const char *name, XPLMGetDatai_f get, XPLMSetDatai_f set)
{
    return XPLMRegisterDataAccessor(name, xplmType_Int, set != NULL,
        get, set,           /* int */
        NULL, NULL,         /* float */
        NULL, NULL,         /* double */
        NULL, NULL,         /* int array */
        NULL, NULL,         /* float array */
        NULL, NULL,         /* data */
        NULL, NULL);        /* refcons */
}

PLUGIN_API int XPluginStart(char *name, char *sig, char *desc)
{
    strcpy(name, "B747 FMS bridge");
    strcpy(sig, "sparky744.b747.fmsbridge");
    strcpy(desc, "The B747's FMC flight plan to X-Plane's FMS from X-Plane's thread.");
    refs[0] = XPLMRegisterDataAccessor("laminar/B747/fms/xp/plan", xplmType_Data, 1,
        NULL, NULL,         /* int */
        NULL, NULL,         /* float */
        NULL, NULL,         /* double */
        NULL, NULL,         /* int array */
        NULL, NULL,         /* float array */
        plan_get, plan_set, /* data */
        NULL, NULL);        /* refcons */
    refs[1] = int_ref("laminar/B747/fms/xp/current", current_get, current_set);
    refs[2] = int_ref("laminar/B747/fms/xp/displayed", displayed_get, displayed_set);
    refs[3] = int_ref("laminar/B747/fms/xp/loads", loads_get, NULL);
    refs[4] = int_ref("laminar/B747/fms/xp/bridge", bridge_get, NULL);
    XPLMRegisterFlightLoopCallback(loop, -1.0f, NULL);
    return 1;
}

PLUGIN_API void XPluginStop(void)
{
    XPLMUnregisterFlightLoopCallback(loop, NULL);
    for (int i = 0; i < 5; i++) XPLMUnregisterDataAccessor(refs[i]);
}

PLUGIN_API int XPluginEnable(void) { return 1; }

PLUGIN_API void XPluginDisable(void) {}

PLUGIN_API void XPluginReceiveMessage(XPLMPluginID from, int msg, void *param)
{
    (void)from; (void)msg; (void)param;
}
