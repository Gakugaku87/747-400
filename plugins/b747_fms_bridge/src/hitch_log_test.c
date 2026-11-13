/*
 * The hitch log (hitch_log.c) from the command line, without X-Plane
 * (tests/static/bridge_hitch_test.lua builds and runs it; 2026-11-13, the
 * 2026-11-12 review D-6, 案 22):
 *   gcc -O2 -Wall -Wextra -std=c99 -o hitch_log_test.exe hitch_log_test.c
 *   hitch_log_test.exe <a folder for its Output\B747_hitches.txt, ending in \ or />
 * prints each check and exits 0 if all pass. X-Plane's functions are
 * stand-ins: the system path is the folder, the sim's time a variable.
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PATH_LEN 1024
typedef void *XPLMDataRef;
#define xplmType_Float 2
static char stub_root[PATH_LEN];
static float stub_sim = 0.0f;
static float (*stub_getf)(void *) = NULL;
static void (*stub_setf)(void *, float) = NULL;
static void XPLMGetSystemPath(char *p) { strcpy(p, stub_root); }
static float XPLMGetDataf(XPLMDataRef r) { (void)r; return stub_sim; }
static XPLMDataRef XPLMFindDataRef(const char *n) { (void)n; return (XPLMDataRef)&stub_sim; }
static XPLMDataRef XPLMRegisterDataAccessor(const char *name, int type, int writable, void *ri, void *wi,
    float (*rf)(void *), void (*wf)(void *, float), void *rd, void *wd, void *rvi, void *wvi,
    void *rvf, void *wvf, void *rb, void *wb, void *rr, void *wr)
{
    (void)name; (void)type; (void)writable; (void)ri; (void)wi; (void)rd; (void)wd; (void)rvi; (void)wvi;
    (void)rvf; (void)wvf; (void)rb; (void)wb; (void)rr; (void)wr;
    stub_getf = rf;
    stub_setf = wf;
    return (XPLMDataRef)&stub_getf;
}
static void XPLMUnregisterDataAccessor(XPLMDataRef r) { (void)r; }

#include "hitch_log.c"

static int fails = 0;

static void check(int ok, const char *what)
{
    printf("%s %s\n", ok ? "ok  " : "FAIL", what);
    if (!ok) fails++;
}

static long file_size(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fclose(f);
    return n;
}

static int file_lines(const char *path, char *first, size_t nf, char *last, size_t nl)
{
    char line[600];
    int n = 0;
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    first[0] = last[0] = 0;
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\r\n")] = 0;
        if (n == 0) snprintf(first, nf, "%s", line);
        snprintf(last, nl, "%s", line);
        n++;
    }
    fclose(f);
    return n;
}

int main(int argc, char **argv)
{
    if (argc < 2) { printf("usage: hitch_log_test.exe <folder\\>\n"); return 2; }
    snprintf(stub_root, sizeof stub_root, "%s", argv[1]);
    char out[PATH_LEN + 64], path[PATH_LEN + 64];
    snprintf(out, sizeof out, "%sOutput", stub_root);
    CreateDirectoryA(out, NULL);
    snprintf(path, sizeof path, "%sOutput\\B747_hitches.txt", stub_root);
    remove(path);
    hl_start();
    check(stub_getf != NULL && stub_setf != NULL, "laminar/B747/diag/hitch_gap_s registered");

    char line[400];
    check(hl_frame_line(line, sizeof line, 0.5, 1, "") == 1 && strcmp(line, "frame 0.50 s after the one before") == 0,
        "a frame 0.5 s after the one before, the sim's time moving: written");
    check(hl_frame_line(line, sizeof line, 0.2, 1, "") == 0, "0.2 s (under 0.25 s): not written");
    check(hl_frame_line(line, sizeof line, 3.0, 0, "") == 0, "the sim's time not moving (paused): not written");
    check(hl_frame_line(line, sizeof line, 0.5, 1, "X-Plane FMS plan load 0.120 s (12 entries)") == 1
        && strstr(line, "; the bridge in it: X-Plane FMS plan load 0.120 s (12 entries)") != NULL,
        "the bridge's work in the frame's line");
    check(hl_frame_line(line, sizeof line, 25.0, 1, "") == 1 && strstr(line, "frame 25.00 s") != NULL
        && strstr(line, "(20 s or more") != NULL,
        "25 s: written, marked (before: left out at 20 s or more)");
    check(hl_frame_line(line, sizeof line, 19.9, 1, "") == 1 && strstr(line, "(20 s or more") == NULL,
        "19.9 s: written, not marked");
    stub_setf(NULL, 0.1f);
    check(stub_getf(NULL) > 0.09f && hl_frame_line(line, sizeof line, 0.15, 1, "") == 1,
        "the threshold written lower (0.1 s): 0.15 s written");
    stub_setf(NULL, 0.25f);

    /* the frame loop: a frame 0.3 s after the one before, the sim's time
       moving, with the bridge's work in it */
    char first[600], last[600];
    hl_frame();
    stub_sim += 1.0f;
    hl_work("test work", hl_now(), 3);
    Sleep(300);
    hl_frame();
    int n = file_lines(path, first, sizeof first, last, sizeof last);
    check(n == 1 && strstr(last, "bridge: frame 0.") != NULL
        && strstr(last, "; the bridge in it: test work 0.000 s (3 entries)") != NULL,
        "the frame loop: a 0.3 s frame written with the bridge's work in it");
    hl_frame();
    check(file_lines(path, first, sizeof first, last, sizeof last) == 1, "the next frame at once, the sim's time still: nothing more");
    remove(path);

    /* no lines-a-session cap (before: 300) */
    for (int i = 0; i < 400; i++) {
        snprintf(line, sizeof line, "test line %d", i);
        hl_write(line);
    }
    n = file_lines(path, first, sizeof first, last, sizeof last);
    check(n == 400, "400 lines in a session: all written (before: 300)");
    check(strstr(last, "bridge: test line 399") != NULL, "the last one: test line 399");

    /* the file past HL_FILE_MAX: its newest lines kept */
    FILE *f = fopen(path, "ab");
    for (int i = 0; f && i < 4000; i++) fprintf(f, "2026-11-13 00:00:00.000 bridge: filler line %04d .......................................\n", i);
    if (f) fclose(f);
    check(file_size(path) > HL_FILE_MAX, "a file past 256 KB");
    hl_write("the newest line");
    long size = file_size(path);
    check(size > 0 && size <= HL_FILE_KEEP + 200, "trimmed to its newest 128 KB or so");
    n = file_lines(path, first, sizeof first, last, sizeof last);
    check(strncmp(first, "(older lines dropped", 20) == 0, "its first line says so");
    check(strstr(last, "bridge: the newest line") != NULL, "the newest line kept, last");
    /* every line after the first a whole one */
    f = fopen(path, "rb");
    int whole = 1, k = 0;
    while (f && fgets(line, sizeof line, f)) {
        if (k > 0 && !(line[0] >= '0' && line[0] <= '9' && strstr(line, " bridge: ") != NULL)) whole = 0;
        k++;
    }
    if (f) fclose(f);
    check(whole && k == n, "whole lines only");
    hl_write("one more");
    check(file_size(path) == size + (long)strlen("2026-11-13 00:00:00.000 bridge: one more\n"),
        "under 256 KB again: the next line appended, nothing dropped");

    hl_stop();
    remove(path);
    printf("%s, %d failed\n", fails ? "some failed" : "all passed", fails);
    return fails ? 1 : 0;
}
