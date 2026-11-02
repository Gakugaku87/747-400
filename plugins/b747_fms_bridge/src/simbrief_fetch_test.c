/*
 * The FMS bridge's SimBrief fetch (simbrief_fetch.c) from the command line,
 * without X-Plane (notes/ATA-34-61-FMC.md §131):
 *   gcc -O2 -Wall -std=c99 -o simbrief_fetch_test.exe simbrief_fetch_test.c -lwinhttp
 *   simbrief_fetch_test.exe <Pilot ID> <folder\>
 * prints the result (2 done, 4 no answer, 5 SimBrief's refusal, 6 the OFP
 * without an X-Plane plan, 7 not saved) and exits with it.
 */
#include "simbrief_fetch.c"

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: simbrief_fetch_test <Pilot ID> <folder\\>\n");
        return 1;
    }
    int r = sb_fetch_ofp(atoi(argv[1]), argv[2]);
    printf("result %d\n", r);
    return r;
}
