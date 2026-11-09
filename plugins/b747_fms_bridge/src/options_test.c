/*
 * The sim's options and their file (options.c) from the command line,
 * without X-Plane (tests/static/bridge_options_test.lua builds and runs it):
 *   gcc -O2 -Wall -Wextra -std=c99 -o options_test.exe options_test.c
 *   options_test.exe <a folder for its file, ending in \ or />
 * prints each check and exits 0 if all pass.
 */
#include "options.c"

static int fails = 0;

static void check(int ok, const char *what)
{
    printf("%s %s\n", ok ? "ok  " : "FAIL", what);
    if (!ok) fails++;
}

/* the file holds this whole line */
static int file_has(const char *path, const char *want)
{
    char line[128];
    int found = 0;
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    while (!found && fgets(line, sizeof line, f)) {
        line[strcspn(line, "\r\n")] = 0;
        found = strcmp(line, want) == 0;
    }
    fclose(f);
    return found;
}

int main(int argc, char **argv)
{
    char p[1024];
    snprintf(p, sizeof p, "%sB747-400_options_test.prf", argc > 1 ? argv[1] : "");
    /* the user's file of 2026-11-06: step climb on, no fuel option yet */
    FILE *f = fopen(p, "wb");
    if (!f) { printf("FAIL cannot write %s\n", p); return 1; }
    fputs("auto_step_climb 1\npause_at_td 0\ncdu_sim_values 1\nsimbrief_id 123\n", f);
    fclose(f);
    int pilot = 0;
    opts_read(p, &pilot);
    check(opts[0] == 1 && opts_kept[0] == 1, "read: step climb on, in use and kept");
    check(opts[2] == 1 && opts[1] == 0, "read: the CDU's sim values on, the pause off");
    check(opts[3] == 0 && opts_kept[3] == 0, "read: the fuel option, not in the file, off (its default)");
    check(pilot == 123, "read: the Pilot ID");

    /* the flight test kit turns step climb off by its dataref: in use only */
    opts_change(0, 0, 0);
    check(opts[0] == 0 && opts_kept[0] == 1, "a dataref's write: in use only, not kept");
    /* then the fuel option turned on by its command (or the menu): kept */
    opts_change(3, !opts[3], 1);
    opts_write(p, pilot);
    check(opts[3] == 1 && opts_kept[3] == 1, "a command: in use and kept");
    check(file_has(p, "auto_step_climb 1"), "the file keeps step climb on (the test's 0 not saved)");
    check(file_has(p, "auto_fuel_mgmt 1"), "the file has the fuel option on");
    check(file_has(p, "pause_at_td 0") && file_has(p, "cdu_sim_values 1"), "the file keeps the others");
    check(file_has(p, "simbrief_id 123"), "the file keeps the Pilot ID");

    /* the Pilot ID set (the CDU's) with step climb still off in use */
    opts_write(p, 456);
    check(file_has(p, "auto_step_climb 1") && file_has(p, "simbrief_id 456"),
        "a Pilot ID's save keeps step climb on");

    /* the menu turns step climb over from its use (off): on, kept */
    opts_change(0, !opts[0], 1);
    opts_write(p, 456);
    check(opts[0] == 1 && file_has(p, "auto_step_climb 1"), "the menu from off: on, kept on");
    /* and over again: off, kept off */
    opts_change(0, !opts[0], 1);
    opts_write(p, 456);
    check(opts[0] == 0 && file_has(p, "auto_step_climb 0"), "the menu again: off, kept off");

    /* read back into fresh values: the file's */
    for (int i = 0; i < NOPTS; i++) opts[i] = opts_kept[i] = -1;
    pilot = 0;
    opts_read(p, &pilot);
    check(opts[0] == 0 && opts[1] == 0 && opts[2] == 1 && opts[3] == 1 && pilot == 456,
        "read back: the kept values and the Pilot ID");
    for (int i = 0; i < NOPTS; i++) {
        if (opts[i] != opts_kept[i]) { check(0, "read back: in use and kept alike"); break; }
    }

    /* no file: the values as they are */
    remove(p);
    opts_read(p, &pilot);
    check(opts[0] == 0 && opts[3] == 1 && pilot == 456, "no file: the values as they were");

    printf("%s, %d failed\n", fails ? "FAILED" : "all passed", fails);
    return fails ? 1 : 0;
}
