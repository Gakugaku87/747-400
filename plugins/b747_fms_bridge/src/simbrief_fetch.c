/*
 * SimBrief's latest OFP by the Pilot ID (2026-11-02 the user; notes/
 * ATA-34-61-FMC.md §131), without X-Plane: b747_fms_bridge.c includes it
 * (and runs sb_fetch_ofp on a thread of its own), simbrief_fetch_test.c too
 * (a console program: the same fetch from the command line).
 *
 * The OFP from SimBrief's https://www.simbrief.com/api/xml.fetcher.php?
 * userid=N (its <fetch><status> Success), then its X-Plane 11/12 flight plan
 * (the OFP's <fms_downloads>: <directory> and the <xpe> <link>; SimBrief
 * redirects it, WinHTTP follows), saved in the folder as
 * <origin><destination>.fms and .xml (the plan first: the FMC pairs the
 * newest of each), each through a .part and a rename.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <windows.h>
#include <winhttp.h>

#ifndef PATH_LEN
#define PATH_LEN 1024
#endif

/* the fetch's result (laminar/B747/fms/company/simbrief_status) */
enum { SBF_NONE, SBF_FETCHING, SBF_OK, SBF_NO_ID, SBF_NO_ANSWER, SBF_REFUSED, SBF_NO_PLAN, SBF_NOT_SAVED };
#define SBF_MAX (32 * 1024 * 1024)
static volatile LONG sb_cancel = 0;

/* an HTTPS GET (`out` malloc'd and 0-terminated, NULL if none): the HTTP
   status, 0 without an answer; redirects followed (WinHTTP's own) */
static int http_get(const wchar_t *host, const wchar_t *path, char **out, size_t *len)
{
    int code = 0;
    *out = NULL;
    *len = 0;
    HINTERNET s = WinHttpOpen(L"B747-400 FMS bridge", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!s) return 0;
    WinHttpSetTimeouts(s, 10000, 10000, 15000, 30000);
    HINTERNET c = WinHttpConnect(s, host, INTERNET_DEFAULT_HTTPS_PORT, 0);
    HINTERNET r = c ? WinHttpOpenRequest(c, L"GET", path, NULL, WINHTTP_NO_REFERER,
        WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE) : NULL;
    if (r && WinHttpSendRequest(r, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0)
        && WinHttpReceiveResponse(r, NULL)) {
        DWORD st = 0, sz = sizeof st, avail = 0;
        WinHttpQueryHeaders(r, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX, &st, &sz, WINHTTP_NO_HEADER_INDEX);
        char *buf = NULL;
        size_t cap = 0;
        int ok = 1;
        while (!sb_cancel && WinHttpQueryDataAvailable(r, &avail) && avail > 0) {
            if (*len + avail + 1 > cap) {
                size_t ncap = cap ? cap : 65536;
                while (ncap < *len + avail + 1) ncap *= 2;
                char *nb = ncap <= SBF_MAX ? realloc(buf, ncap) : NULL;
                if (!nb) { ok = 0; break; }
                buf = nb;
                cap = ncap;
            }
            DWORD got = 0;
            if (!WinHttpReadData(r, buf + *len, avail, &got)) { ok = 0; break; }
            *len += got;
        }
        if (ok && buf && !sb_cancel) {
            buf[*len] = 0;
            *out = buf;
            code = (int)st;
        } else {
            free(buf);
            *len = 0;
        }
    }
    if (r) WinHttpCloseHandle(r);
    if (c) WinHttpCloseHandle(c);
    WinHttpCloseHandle(s);
    return code;
}

/* the text of the first <tag> after `from` (cut to n), NULL if none */
static const char *xml_text(const char *from, const char *tag, char *out, size_t n)
{
    char open[64], close[64];
    snprintf(open, sizeof open, "<%s>", tag);
    snprintf(close, sizeof close, "</%s>", tag);
    const char *a = from ? strstr(from, open) : NULL;
    if (!a) return NULL;
    a += strlen(open);
    const char *b = strstr(a, close);
    if (!b) return NULL;
    size_t k = (size_t)(b - a);
    if (k >= n) k = n - 1;
    memcpy(out, a, k);
    out[k] = 0;
    return b + strlen(close);
}

/* min to max of letters, digits, "_", "-" and "." (an airport, a file) */
static int plain(const char *s, size_t min, size_t max)
{
    size_t n = strlen(s);
    if (n < min || n > max) return 0;
    for (size_t i = 0; i < n; i++) {
        char ch = s[i];
        if (!((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')
            || ch == '_' || ch == '-' || ch == '.')) return 0;
    }
    return 1;
}

/* a whole file through a .part and a rename (the bridge's scan of the
   folder never sees half of one) */
static int write_file(const char *path, const char *data, size_t len)
{
    char tmp[PATH_LEN + 8];
    snprintf(tmp, sizeof tmp, "%s.part", path);
    FILE *f = fopen(tmp, "wb");
    if (!f) return 0;
    size_t w = fwrite(data, 1, len, f);
    if (fclose(f) != 0 || w != len) { remove(tmp); return 0; }
    if (!MoveFileExA(tmp, path, MOVEFILE_REPLACE_EXISTING)) { remove(tmp); return 0; }
    return 1;
}

/* the OFP of Pilot ID `id` and its X-Plane plan into `folder` (ending in a
   separator): SBF_OK, SBF_NO_ANSWER, SBF_REFUSED (no OFP), SBF_NO_PLAN (the OFP
   saved, no X-Plane plan) or SBF_NOT_SAVED */
static int sb_fetch_ofp(int id, const char *folder)
{
    wchar_t wpath[512], whost[128];
    char *xml = NULL, *fms = NULL;
    size_t xml_len = 0, fms_len = 0;
    swprintf(wpath, 512, L"/api/xml.fetcher.php?userid=%d", id);
    if (http_get(L"www.simbrief.com", wpath, &xml, &xml_len) != 200 || !xml) {
        free(xml);
        return SBF_NO_ANSWER;
    }
    char st[64], orig[16], dest[16], dir[256], link[256], p[PATH_LEN];
    const char *o = strstr(xml, "<origin>"), *d = strstr(xml, "<destination>");
    if (!xml_text(xml, "status", st, sizeof st) || strcmp(st, "Success") != 0
        || !xml_text(o, "icao_code", orig, sizeof orig) || !xml_text(d, "icao_code", dest, sizeof dest)
        || !plain(orig, 3, 4) || !plain(dest, 3, 4)) {
        free(xml);
        return SBF_REFUSED;
    }
    int result = SBF_NO_PLAN;
    const char *dl = strstr(xml, "<fms_downloads>");
    const char *xpe = dl ? strstr(dl, "<xpe>") : NULL;
    if (xml_text(dl, "directory", dir, sizeof dir) && xml_text(xpe, "link", link, sizeof link)
        && strncmp(dir, "https://", 8) == 0 && plain(link, 1, 200)) {
        /* "https://host/path/" + the link */
        const char *slash = strchr(dir + 8, '/');
        size_t hn = slash ? (size_t)(slash - (dir + 8)) : 0;
        if (slash && hn > 0 && hn < 128) {
            char host[128], rest[512];
            memcpy(host, dir + 8, hn);
            host[hn] = 0;
            snprintf(rest, sizeof rest, "%s%s", slash, link);
            MultiByteToWideChar(CP_UTF8, 0, host, -1, whost, 128);
            MultiByteToWideChar(CP_UTF8, 0, rest, -1, wpath, 512);
            if (http_get(whost, wpath, &fms, &fms_len) == 200 && fms && fms_len > 2
                && (fms[0] == 'I' || fms[0] == 'A')) {
                snprintf(p, sizeof p, "%s%s%s.fms", folder, orig, dest);
                result = write_file(p, fms, fms_len) ? SBF_OK : SBF_NOT_SAVED;
            }
        }
    }
    snprintf(p, sizeof p, "%s%s%s.xml", folder, orig, dest);
    if (!write_file(p, xml, xml_len)) result = SBF_NOT_SAVED;
    free(xml);
    free(fms);
    return result;
}
