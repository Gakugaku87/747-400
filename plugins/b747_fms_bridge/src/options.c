/*
 * The sim's options (notes/ATA-34-61-FMC.md §126) and their file, X-Plane's
 * Output/preferences/B747-400_options.prf, without XPLM: b747_fms_bridge.c
 * includes it (the menu, the datarefs and the commands), options_test.c
 * tests it from the command line.
 *
 * Each option has two values: the one in use (its dataref, the menu's check
 * mark) and the one kept in the file. A dataref's write changes the one in
 * use only (the flight test kit turns the options off so, unsaved); the menu
 * and the toggle commands change both and write the file. The file gets the
 * kept values only (2026-11-09 the user: it got the ones in use, so a save
 * in a test, another option chosen or the Pilot ID changed, would have put
 * the test's zeros in the user's file).
 */
#include <stdio.h>
#include <string.h>

/* their names in the file; on or off before the file has them (2026-11-05:
   the CDU's weights and CG from the sim on, the user's asking; 2026-11-09:
   the automatic fuel management off) */
#define NOPTS 4
static const char *opt_key[NOPTS] = {"auto_step_climb", "pause_at_td", "cdu_sim_values", "auto_fuel_mgmt"};
static int opts[NOPTS] = {0, 0, 1, 0};       /* in use */
static int opts_kept[NOPTS] = {0, 0, 1, 0};  /* in the file */

/* "<key> <0 or 1>" lines and "simbrief_id <n>" (into *pilot_id); a key not
   there keeps its value (the defaults above), no file keeps them all */
static void opts_read(const char *path, int *pilot_id)
{
    char line[128], key[64];
    int v;
    FILE *f = fopen(path, "rb");
    if (!f) return;
    while (fgets(line, sizeof line, f)) {
        if (sscanf(line, "%63s %d", key, &v) != 2) continue;
        for (int i = 0; i < NOPTS; i++) {
            if (strcmp(key, opt_key[i]) == 0) opts[i] = opts_kept[i] = v ? 1 : 0;
        }
        if (strcmp(key, "simbrief_id") == 0) *pilot_id = v > 0 ? v : 0;
    }
    fclose(f);
}

/* the kept values and the Pilot ID */
static void opts_write(const char *path, int pilot_id)
{
    FILE *f = fopen(path, "wb");
    if (!f) return;
    for (int i = 0; i < NOPTS; i++) fprintf(f, "%s %d\n", opt_key[i], opts_kept[i]);
    fprintf(f, "simbrief_id %d\n", pilot_id);
    fclose(f);
}

/* an option in use set, kept too if `keep` (the caller writes the file) */
static void opts_change(int i, int v, int keep)
{
    if (i < 0 || i >= NOPTS) return;
    opts[i] = v ? 1 : 0;
    if (keep) opts_kept[i] = opts[i];
}
