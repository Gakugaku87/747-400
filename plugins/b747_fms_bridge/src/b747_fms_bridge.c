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
 * (6-1/6-2 step 12h; notes/ATA-34-61-FMC.md §122) the sim's airline
 * operations' files: the newest .fms and .xml (SimBrief's X-Plane flight
 * plan and its OFP in XML) in the aircraft folder's simbrief folder, looked
 * for every 2 s (XTLua cannot list a folder); their names written into the
 * folder's _newest.txt ("FMS <name>", "OFP <name>") when they change, which
 * the FMC reads (XTLua's copy of another plugin's text dataref can stay
 * old: s201, 2026-11-01), and here too:
 *
 *   laminar/B747/fms/company/folder    (data) the folder's path, relative to
 *                                       X-Plane's folder when in it (XTLua
 *                                       opens files from there), with its
 *                                       terminating 0 (read only)
 *   laminar/B747/fms/company/fms_file  (data) the newest .fms's path, ""
 *                                       if none (read only)
 *   laminar/B747/fms/company/ofp_file  (data) the newest .xml's (read only)
 *
 * Built with docs/overhaul/tools/build_fms_bridge.sh (MinGW-w64, the X-Plane
 * SDK 4.3.0) into ../64/win.xpl. Windows only (2026-11-01 the user).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include "XPLMDefs.h"
#include "XPLMDataAccess.h"
#include "XPLMNavigation.h"
#include "XPLMPlanes.h"
#include "XPLMPlugin.h"
#include "XPLMProcessing.h"
#include "XPLMUtilities.h"

#define PLAN_MAX 65536
#define PATH_LEN 1024

static char plan[PLAN_MAX];
static int plan_len = 0;
static int plan_new = 0;
static int plan_current = 0;
static int current = 0;
static int current_new = 0;
static int displayed = 0;
static int displayed_new = 0;
static int loads = 0;
static char folder[PATH_LEN / 2];
static char fms_file[PATH_LEN];
static char ofp_file[PATH_LEN];

#define NREFS 8
static XPLMDataRef refs[NREFS];

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

/* a text as a data dataref, its terminating 0 with it (XTLua's strings) */
static int text_get(const char *s, void *out, int offset, int max)
{
    int len = (int)strlen(s) + 1;
    if (!out) return len;
    if (offset < 0 || offset >= len || max <= 0) return 0;
    int n = len - offset;
    if (n > max) n = max;
    memcpy(out, s + offset, (size_t)n);
    return n;
}
static int folder_get(void *ref, void *out, int offset, int max) { (void)ref; return text_get(folder, out, offset, max); }
static int fms_file_get(void *ref, void *out, int offset, int max) { (void)ref; return text_get(fms_file, out, offset, max); }
static int ofp_file_get(void *ref, void *out, int offset, int max) { (void)ref; return text_get(ofp_file, out, offset, max); }

/* the folder `abs`'s newest file "*.ext" (into out as `pub` and its name,
   "" if none) */
static void newest(const char *abs, const char *pub, const char *ext, char *out)
{
    char pattern[PATH_LEN];
    WIN32_FIND_DATAA fd;
    FILETIME best = {0, 0};
    out[0] = 0;
    if (!abs[0]) return;
    snprintf(pattern, sizeof pattern, "%s*.%s", abs, ext);
    HANDLE h = FindFirstFileA(pattern, &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    do {
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) continue;
        if (CompareFileTime(&fd.ftLastWriteTime, &best) > 0) {
            best = fd.ftLastWriteTime;
            snprintf(out, PATH_LEN, "%s%s", pub, fd.cFileName);
        }
    } while (FindNextFileA(h, &fd));
    FindClose(h);
}

/* a path's file name */
static const char *file_name(const char *p)
{
    const char *a = strrchr(p, '\\'), *b = strrchr(p, '/');
    if (b > a) a = b;
    return a ? a + 1 : p;
}

/* the folder's _newest.txt, "FMS <name>" and "OFP <name>" lines, written
   when they change (the FMC reads it: XTLua's copy of a text dataref of
   another plugin's can stay old) */
static char list_written[2 * PATH_LEN + 16];
static void write_list(const char *abs)
{
    char text[2 * PATH_LEN + 16], p[PATH_LEN];
    if (!abs[0]) return;
    snprintf(text, sizeof text, "FMS %s\nOFP %s\n", fms_file[0] ? file_name(fms_file) : "",
        ofp_file[0] ? file_name(ofp_file) : "");
    if (strcmp(text, list_written) == 0) return;
    snprintf(p, sizeof p, "%s_newest.txt", abs);
    FILE *f = fopen(p, "wb");
    if (!f) return;
    fputs(text, f);
    fclose(f);
    snprintf(list_written, sizeof list_written, "%s", text);
}

/* the user's aircraft's folder's simbrief folder, then its newest files;
   the paths given relative to X-Plane's folder when in it (XTLua opens
   files from there: its scripts' "Custom Data/...", "Output/...") */
static float scan(float since_call, float since_loop, int counter, void *ref)
{
    (void)since_call; (void)since_loop; (void)counter; (void)ref;
    char name[512], path[PATH_LEN], root[PATH_LEN / 2], abs[PATH_LEN / 2];
    name[0] = 0;
    path[0] = 0;
    root[0] = 0;
    abs[0] = 0;
    XPLMGetNthAircraftModel(0, name, path);
    XPLMGetSystemPath(root);
    char *sep = strrchr(path, '\\');
    char *sep2 = strrchr(path, '/');
    if (sep2 > sep) sep = sep2;
    if (sep) {
        sep[1] = 0;
        snprintf(abs, sizeof abs, "%ssimbrief\\", path);
    }
    size_t n = strlen(root);
    if (n > 0 && _strnicmp(abs, root, n) == 0) {
        snprintf(folder, sizeof folder, "%s", abs + n);
    } else {
        snprintf(folder, sizeof folder, "%s", abs);
    }
    newest(abs, folder, "fms", fms_file);
    newest(abs, folder, "xml", ofp_file);
    write_list(abs);
    return 2.0f;
}

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

/* a read-only data dataref */
static XPLMDataRef text_ref(const char *name, XPLMGetDatab_f get)
{
    return XPLMRegisterDataAccessor(name, xplmType_Data, 0,
        NULL, NULL,         /* int */
        NULL, NULL,         /* float */
        NULL, NULL,         /* double */
        NULL, NULL,         /* int array */
        NULL, NULL,         /* float array */
        get, NULL,          /* data */
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
    refs[5] = text_ref("laminar/B747/fms/company/folder", folder_get);
    refs[6] = text_ref("laminar/B747/fms/company/fms_file", fms_file_get);
    refs[7] = text_ref("laminar/B747/fms/company/ofp_file", ofp_file_get);
    XPLMRegisterFlightLoopCallback(loop, -1.0f, NULL);
    XPLMRegisterFlightLoopCallback(scan, 1.0f, NULL);
    return 1;
}

PLUGIN_API void XPluginStop(void)
{
    XPLMUnregisterFlightLoopCallback(loop, NULL);
    XPLMUnregisterFlightLoopCallback(scan, NULL);
    for (int i = 0; i < NREFS; i++) XPLMUnregisterDataAccessor(refs[i]);
}

PLUGIN_API int XPluginEnable(void) { return 1; }

PLUGIN_API void XPluginDisable(void) {}

PLUGIN_API void XPluginReceiveMessage(XPLMPluginID from, int msg, void *param)
{
    (void)from; (void)msg; (void)param;
}
