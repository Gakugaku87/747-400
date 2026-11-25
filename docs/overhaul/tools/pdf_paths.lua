-- pdf_paths.lua: a PDF page's vector paths and text runs with their
-- coordinates, for reading charts drawn as lines (the FPPM's: 2026-11-25,
-- the takeoff and landing performance window). LuaJIT only: no Python on
-- this PC (the 2026-11-14 FPPM work read the lines with PyMuPDF in a cloud
-- session); the PDF's FlateDecode streams are inflated here (after zlib's
-- puff.c), object streams and page trees read, the page's content (and its
-- form XObjects) interpreted. Not encrypted PDFs (the FCOM's): an error
-- says so (pdftotext reads them).
--
--   luajit docs/overhaul/tools/pdf_paths.lua <pdf> <page from 1> [out]
--
-- Output, one line each, page coordinates in points (origin bottom left):
--   PAGE n width height
--   S lw r,g,b dash : x,y x,y ...    a stroked subpath (curves sampled)
--   F r,g,b : x,y x,y ...            a filled subpath
--   T x y size angle text            a text run at its start (angle in
--                                    degrees, text as UTF-8: by the font's
--                                    ToUnicode map, else its MacRoman or
--                                    WinAnsi encoding, else Latin-1)
--   I x y w h                        an image's box
-- The colours are the PDF's numbers (gray, RGB; CMYK turned RGB).
local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift
local byte, char, sub, find = string.byte, string.char, string.sub, string.find
local floor, abs, sqrt, atan2, deg = math.floor, math.abs, math.sqrt, math.atan2, math.deg

------------------------------------------------------------------------
-- inflate (RFC 1951), after zlib's puff.c
------------------------------------------------------------------------
local LBASE = {[0] = 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258}
local LEXT = {[0] = 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0}
local DBASE = {[0] = 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577}
local DEXT = {[0] = 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13}
local ORDER = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}

local function construct(lengths, n)
    local count, symbol, offs = {}, {}, {}
    for len = 0, 15 do count[len] = 0 end
    for s = 0, n - 1 do count[lengths[s]] = count[lengths[s]] + 1 end
    offs[1] = 0
    for len = 1, 14 do offs[len + 1] = offs[len] + count[len] end
    for s = 0, n - 1 do
        local l = lengths[s]
        if l ~= 0 then
            symbol[offs[l]] = s
            offs[l] = offs[l] + 1
        end
    end
    return {count = count, symbol = symbol}
end

local FIXED_L, FIXED_D
do
    local l, d = {}, {}
    for s = 0, 143 do l[s] = 8 end
    for s = 144, 255 do l[s] = 9 end
    for s = 256, 279 do l[s] = 7 end
    for s = 280, 287 do l[s] = 8 end
    for s = 0, 29 do d[s] = 5 end
    FIXED_L, FIXED_D = construct(l, 288), construct(d, 30)
end

local function inflate(s, pos)
    local bitbuf, bitcnt, slen = 0, 0, #s
    local out, n = {}, 0
    local function bits(need)
        local val = bitbuf
        while bitcnt < need do
            if pos > slen then error("inflate: out of input") end
            val = bor(val, lshift(byte(s, pos), bitcnt))
            pos = pos + 1
            bitcnt = bitcnt + 8
        end
        bitbuf = rshift(val, need)
        bitcnt = bitcnt - need
        return band(val, lshift(1, need) - 1)
    end
    local function decode(h)
        local code, first, index = 0, 0, 0
        local count, symbol = h.count, h.symbol
        for len = 1, 15 do
            code = bor(code, bits(1))
            local c = count[len]
            if code - c < first then return symbol[index + (code - first)] end
            index = index + c
            first = lshift(first + c, 1)
            code = lshift(code, 1)
        end
        error("inflate: bad code")
    end
    local function codes(lencode, distcode)
        while true do
            local sym = decode(lencode)
            if sym < 256 then
                n = n + 1
                out[n] = sym
            elseif sym == 256 then
                return
            else
                sym = sym - 257
                if sym >= 29 then error("inflate: bad length") end
                local len = LBASE[sym] + bits(LEXT[sym])
                local ds = decode(distcode)
                local dist = DBASE[ds] + bits(DEXT[ds])
                if dist > n then error("inflate: distance too far") end
                for _ = 1, len do
                    n = n + 1
                    out[n] = out[n - dist]
                end
            end
        end
    end
    local function stored()
        bitbuf, bitcnt = 0, 0
        local len = byte(s, pos) + byte(s, pos + 1) * 256
        pos = pos + 4
        for i = 0, len - 1 do
            n = n + 1
            out[n] = byte(s, pos + i)
        end
        pos = pos + len
    end
    local function dynamic()
        local nlen, ndist, ncode = bits(5) + 257, bits(5) + 1, bits(4) + 4
        local lengths = {}
        for i = 0, 18 do lengths[i] = 0 end
        for i = 1, ncode do lengths[ORDER[i]] = bits(3) end
        local lencode = construct(lengths, 19)
        local all, idx = {}, 0
        while idx < nlen + ndist do
            local sym = decode(lencode)
            if sym < 16 then
                all[idx] = sym
                idx = idx + 1
            else
                local len, rep = 0, 0
                if sym == 16 then
                    if idx == 0 then error("inflate: repeat with no first") end
                    len, rep = all[idx - 1], 3 + bits(2)
                elseif sym == 17 then
                    rep = 3 + bits(3)
                else
                    rep = 11 + bits(7)
                end
                for _ = 1, rep do
                    all[idx] = len
                    idx = idx + 1
                end
            end
        end
        local ll, dl = {}, {}
        for i = 0, nlen - 1 do ll[i] = all[i] end
        for i = 0, ndist - 1 do dl[i] = all[nlen + i] end
        codes(construct(ll, nlen), construct(dl, ndist))
    end
    repeat
        local last, typ = bits(1), bits(2)
        if typ == 0 then stored()
        elseif typ == 1 then codes(FIXED_L, FIXED_D)
        elseif typ == 2 then dynamic()
        else error("inflate: bad block type") end
    until last == 1
    local parts = {}
    for i = 1, n, 4096 do parts[#parts + 1] = char(unpack(out, i, math.min(i + 4095, n))) end
    return table.concat(parts)
end

------------------------------------------------------------------------
-- objects
------------------------------------------------------------------------
local function skip_ws(s, i)
    while true do
        local c = byte(s, i)
        if c == nil then return i end
        if c == 37 then
            local e = find(s, "[\r\n]", i)
            if not e then return #s + 1 end
            i = e + 1
        elseif c == 32 or c == 9 or c == 10 or c == 13 or c == 12 or c == 0 then
            i = i + 1
        else
            return i
        end
    end
end

local REGULAR = "^[^%s%(%)<>%[%]{}/%%]+"
local ESC = {n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ["("] = "(", [")"] = ")", ["\\"] = "\\"}

-- one object at i: {t = "dict"|"arr"|"str"|"name"|"num"|"ref"|"bool"|"null"|"kw", v}
local function parse(s, i)
    i = skip_ws(s, i)
    local c = sub(s, i, i)
    if c == "<" then
        if sub(s, i + 1, i + 1) == "<" then
            local d = {}
            i = i + 2
            while true do
                i = skip_ws(s, i)
                if sub(s, i, i + 1) == ">>" then return {t = "dict", v = d}, i + 2 end
                local key, val
                key, i = parse(s, i)
                val, i = parse(s, i)
                d[key.v] = val
            end
        end
        local e = find(s, ">", i, true)
        local hex = sub(s, i + 1, e - 1):gsub("%s", "")
        if #hex % 2 == 1 then hex = hex .. "0" end
        return {t = "str", v = (hex:gsub("..", function(h) return char(tonumber(h, 16)) end))}, e + 1
    elseif c == "[" then
        local a = {}
        i = i + 1
        while true do
            i = skip_ws(s, i)
            if sub(s, i, i) == "]" then return {t = "arr", v = a}, i + 1 end
            local v
            v, i = parse(s, i)
            a[#a + 1] = v
        end
    elseif c == "(" then
        local depth, j, buf = 1, i + 1, {}
        while true do
            local ch = sub(s, j, j)
            if ch == "" then return {t = "str", v = table.concat(buf)}, j end
            if ch == "\\" then
                local nx = sub(s, j + 1, j + 1)
                if ESC[nx] then
                    buf[#buf + 1] = ESC[nx]
                    j = j + 2
                elseif nx:match("[0-7]") then
                    local oct = s:match("^[0-7][0-7]?[0-7]?", j + 1)
                    buf[#buf + 1] = char(tonumber(oct, 8) % 256)
                    j = j + 1 + #oct
                elseif nx == "\r" then
                    j = j + 2
                    if sub(s, j, j) == "\n" then j = j + 1 end
                elseif nx == "\n" then
                    j = j + 2
                else
                    buf[#buf + 1] = nx
                    j = j + 2
                end
            elseif ch == "(" then
                depth = depth + 1
                buf[#buf + 1] = ch
                j = j + 1
            elseif ch == ")" then
                depth = depth - 1
                if depth == 0 then return {t = "str", v = table.concat(buf)}, j + 1 end
                buf[#buf + 1] = ch
                j = j + 1
            else
                buf[#buf + 1] = ch
                j = j + 1
            end
        end
    elseif c == "/" then
        local raw = s:match("^[^%s%(%)<>%[%]{}/%%]*", i + 1)
        return {t = "name", v = (raw:gsub("#(%x%x)", function(h) return char(tonumber(h, 16)) end))}, i + 1 + #raw
    elseif c == "{" or c == "}" then
        return {t = "kw", v = c}, i + 1
    elseif c == "" then
        return nil, i
    end
    local tok = s:match(REGULAR, i)
    if not tok then return {t = "kw", v = c}, i + 1 end
    local ni = i + #tok
    local num = tonumber(tok)
    if num then
        if tok:match("^%d+$") then
            local g, after = s:match("^[ \t\r\n]+(%d+)[ \t\r\n]+R()", ni)
            if g and not s:match("^[^%s%(%)<>%[%]{}/%%]", after) then return {t = "ref", v = num}, after end
        end
        return {t = "num", v = num}, ni
    end
    if tok == "true" then return {t = "bool", v = true}, ni end
    if tok == "false" then return {t = "bool", v = false}, ni end
    if tok == "null" then return {t = "null"}, ni end
    return {t = "kw", v = tok}, ni
end

local function read_file(p)
    local f = assert(io.open(p, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local objs = {}
local function R(v)
    while v and v.t == "ref" do
        local o = objs[v.v]
        v = o and o.value
    end
    return v
end
local function D(v, key)
    v = R(v)
    if not v or v.t ~= "dict" then return nil end
    return R(v.v[key])
end

local function png_unpredict(data, columns)
    local rowlen, out, prev = columns + 1, {}, {}
    for i = 1, columns do prev[i] = 0 end
    for r = 0, floor(#data / rowlen) - 1 do
        local base, row = r * rowlen + 1, {}
        local ft = byte(data, base)
        for i = 1, columns do
            local x = byte(data, base + i)
            local a, b, c = i > 1 and row[i - 1] or 0, prev[i], i > 1 and prev[i - 1] or 0
            local v
            if ft == 1 then v = x + a
            elseif ft == 2 then v = x + b
            elseif ft == 3 then v = x + floor((a + b) / 2)
            elseif ft == 4 then
                local p = a + b - c
                local pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                if pa <= pb and pa <= pc then v = x + a elseif pb <= pc then v = x + b else v = x + c end
            else v = x end
            row[i] = v % 256
        end
        for i = 1, columns do out[#out + 1] = char(row[i]) end
        prev = row
    end
    return table.concat(out)
end

-- a stream object's data, decoded
local function stream_data(o)
    if o.decoded then return o.decoded end
    local d = o.value.v
    local filt = R(d.Filter)
    local list = {}
    if filt and filt.t == "name" then list = {filt.v}
    elseif filt and filt.t == "arr" then for _, f in ipairs(filt.v) do list[#list + 1] = R(f).v end end
    local data = o.raw
    for _, f in ipairs(list) do
        if f == "FlateDecode" or f == "Fl" then
            -- a zlib header (CMF 8 = deflate, CMF*256+FLG a multiple of 31)
            -- skipped, with its dictionary id; without one, raw deflate
            local cmf, flg = byte(data, 1) or 0, byte(data, 2) or 0
            local start = 1
            if band(cmf, 15) == 8 and (cmf * 256 + flg) % 31 == 0 then
                start = band(flg, 32) ~= 0 and 7 or 3
            end
            local ok, res = pcall(inflate, data, start)
            if not ok then
                error(string.format("object %s: %s (%d bytes, Length %s)", tostring(o.num), tostring(res), #data,
                    tostring(R(d.Length) and R(d.Length).v)), 0)
            end
            data = res
            local parms = R(d.DecodeParms)
            local pred = parms and D(parms, "Predictor")
            if pred and pred.v >= 10 then
                local cols = D(parms, "Columns")
                data = png_unpredict(data, cols and cols.v or 1)
            end
        else
            error("unsupported filter " .. tostring(f))
        end
    end
    o.decoded = data
    return data
end

local function load_pdf(path)
    local data = read_file(path)
    -- an encrypted PDF (the FCOM's: the Standard handler, RC4 128-bit) has
    -- its streams enciphered: not read here (pdftotext reads it)
    if find(data, "/Encrypt%s+%d+%s+%d+%s+R") or find(data, "/Encrypt%s*<<") then
        error("encrypted PDF (/Encrypt): not supported; use pdftotext", 0)
    end
    local p = 1
    while true do
        local s0, e0, num = find(data, "(%d+)[ \t\r\n]+%d+[ \t\r\n]+obj", p)
        if not s0 then break end
        num = tonumber(num)
        local val, i = parse(data, e0 + 1)
        local o = {value = val, num = num}
        local j = skip_ws(data, i)
        if val and val.t == "dict" and sub(data, j, j + 5) == "stream" then
            j = j + 6
            if sub(data, j, j) == "\r" then j = j + 1 end
            if sub(data, j, j) == "\n" then j = j + 1 end
            local len = R(val.v.Length)
            local se
            if len and len.t == "num" and find(sub(data, j + len.v, j + len.v + 24), "endstream", 1, true) then
                o.raw = sub(data, j, j + len.v - 1)
                se = j + len.v
            else
                local k = find(data, "endstream", j, true)
                o.raw = sub(data, j, k - 1)
                se = k
            end
            local e = find(data, "endobj", se, true)
            p = e and e + 6 or se + 9
        else
            local e = find(data, "endobj", i, true)
            p = e and e + 6 or i
        end
        objs[num] = o
    end
    -- the objects inside object streams (the top-level ones win)
    local streams = {}
    for _, o in pairs(objs) do
        local t = o.raw and D(o.value, "Type")
        if t and t.v == "ObjStm" then streams[#streams + 1] = o end
    end
    for _, o in ipairs(streams) do
        local s = stream_data(o)
        local first = D(o.value, "First").v
        local nn = D(o.value, "N").v
        local q = 1
        for _ = 1, nn do
            local a, b
            a, q = parse(s, q)
            b, q = parse(s, q)
            if not objs[a.v] then objs[a.v] = {value = (parse(s, first + b.v + 1))} end
        end
    end
end

------------------------------------------------------------------------
-- fonts: codes to text and widths
------------------------------------------------------------------------
local function utf8(cp)
    if cp < 0x80 then return char(cp) end
    if cp < 0x800 then return char(0xC0 + floor(cp / 64), 0x80 + cp % 64) end
    if cp < 0x10000 then return char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64) end
    return char(0xF0 + floor(cp / 262144), 0x80 + floor(cp / 4096) % 64, 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
end
local function utf16hex(h)
    local out, i = {}, 1
    while i + 3 <= #h do
        local u = tonumber(sub(h, i, i + 3), 16)
        i = i + 4
        if u >= 0xD800 and u < 0xDC00 and i + 3 <= #h then
            local l = tonumber(sub(h, i, i + 3), 16)
            i = i + 4
            u = 0x10000 + (u - 0xD800) * 1024 + (l - 0xDC00)
        end
        out[#out + 1] = utf8(u)
    end
    return table.concat(out)
end
local function parse_cmap(text)
    local map = {}
    for block in text:gmatch("beginbfchar(.-)endbfchar") do
        for a, b in block:gmatch("<(%x+)>%s*<(%x+)>") do map[tonumber(a, 16)] = utf16hex(b) end
    end
    for block in text:gmatch("beginbfrange(.-)endbfrange") do
        local i = 1
        while true do
            local a, b, e = block:match("<(%x+)>%s*<(%x+)>%s*()", i)
            if not a then break end
            local lo, hi = tonumber(a, 16), tonumber(b, 16)
            if sub(block, e, e) == "[" then
                local close = find(block, "]", e, true)
                local k = 0
                for d in sub(block, e + 1, close - 1):gmatch("<(%x+)>") do
                    map[lo + k] = utf16hex(d)
                    k = k + 1
                end
                i = close + 1
            else
                local d, e2 = block:match("^<(%x+)>()", e)
                if not d then break end
                local base = tonumber(d, 16)
                for c = lo, hi do map[c] = utf8(base + c - lo) end
                i = e2
            end
        end
    end
    return map
end

-- simple fonts without a ToUnicode map: the base encoding's codes 128-255
-- (2026-11-25: the FPPM's Helvetica is MacRomanEncoding, its degree sign
-- 0xA1 came out as Latin-1's inverted exclamation mark)
local MAC_ROMAN = {[0] = 0xC4, 0xC5, 0xC7, 0xC9, 0xD1, 0xD6, 0xDC, 0xE1, 0xE0, 0xE2, 0xE4, 0xE3, 0xE5, 0xE7, 0xE9, 0xE8,
    0xEA, 0xEB, 0xED, 0xEC, 0xEE, 0xEF, 0xF1, 0xF3, 0xF2, 0xF4, 0xF6, 0xF5, 0xFA, 0xF9, 0xFB, 0xFC,
    0x2020, 0xB0, 0xA2, 0xA3, 0xA7, 0x2022, 0xB6, 0xDF, 0xAE, 0xA9, 0x2122, 0xB4, 0xA8, 0x2260, 0xC6, 0xD8,
    0x221E, 0xB1, 0x2264, 0x2265, 0xA5, 0xB5, 0x2202, 0x2211, 0x220F, 0x3C0, 0x222B, 0xAA, 0xBA, 0x3A9, 0xE6, 0xF8,
    0xBF, 0xA1, 0xAC, 0x221A, 0x192, 0x2248, 0x2206, 0xAB, 0xBB, 0x2026, 0xA0, 0xC0, 0xC3, 0xD5, 0x152, 0x153,
    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0xF7, 0x25CA, 0xFF, 0x178, 0x2044, 0xA4, 0x2039, 0x203A, 0xFB01, 0xFB02,
    0x2021, 0xB7, 0x201A, 0x201E, 0x2030, 0xC2, 0xCA, 0xC1, 0xCB, 0xC8, 0xCD, 0xCE, 0xCF, 0xCC, 0xD3, 0xD4,
    0xF8FF, 0xD2, 0xDA, 0xDB, 0xD9, 0x131, 0x2C6, 0x2DC, 0xAF, 0x2D8, 0x2D9, 0x2DA, 0xB8, 0x2DD, 0x2DB, 0x2C7}
local WIN_ANSI = {[0] = 0x20AC, 0x2022, 0x201A, 0x192, 0x201E, 0x2026, 0x2020, 0x2021, 0x2C6, 0x2030, 0x160, 0x2039,
    0x152, 0x2022, 0x17D, 0x2022, 0x2022, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x2DC, 0x2122,
    0x161, 0x203A, 0x153, 0x2022, 0x17E, 0x178}

local font_cache = {}
local function font_info(fdict)
    if font_cache[fdict] then return font_cache[fdict] end
    local f = {two = false, map = nil, widths = {}, dw = 1000}
    local enc = D(fdict, "Encoding")
    if enc and enc.t == "dict" then enc = R(enc.v.BaseEncoding) end
    if enc and enc.t == "name" then
        if enc.v == "MacRomanEncoding" then f.high = MAC_ROMAN
        elseif enc.v == "WinAnsiEncoding" then f.high = WIN_ANSI end
    end
    local sub_t = D(fdict, "Subtype")
    if sub_t and sub_t.v == "Type0" then
        f.two = true
        f.dw = 1000
        local desc = D(fdict, "DescendantFonts")
        local cid = desc and R(desc.v[1])
        if cid then
            local dw = D(cid, "DW")
            if dw then f.dw = dw.v end
            local w = D(cid, "W")
            if w then
                local a, i = w.v, 1
                while i <= #a do
                    local c1 = R(a[i]).v
                    local nx = R(a[i + 1])
                    if nx.t == "arr" then
                        for k, wv in ipairs(nx.v) do f.widths[c1 + k - 1] = R(wv).v end
                        i = i + 2
                    else
                        local c2, wv = nx.v, R(a[i + 2]).v
                        for c = c1, c2 do f.widths[c] = wv end
                        i = i + 3
                    end
                end
            end
        end
    else
        f.dw = 500
        local fc, ws = D(fdict, "FirstChar"), D(fdict, "Widths")
        if fc and ws then
            for k, wv in ipairs(ws.v) do f.widths[fc.v + k - 1] = R(wv).v end
        end
    end
    local tu = fdict and R(fdict).v.ToUnicode
    if tu and tu.t == "ref" and objs[tu.v] and objs[tu.v].raw then
        local ok, text = pcall(stream_data, objs[tu.v])
        if ok then f.map = parse_cmap(text) end
    end
    font_cache[fdict] = f
    return f
end

-- a string's codes: text and width (text space units, before size)
local function show_codes(f, str)
    local out, w, codes = {}, 0, {}
    if f.two then
        for i = 1, #str - 1, 2 do codes[#codes + 1] = byte(str, i) * 256 + byte(str, i + 1) end
    else
        for i = 1, #str do codes[#codes + 1] = byte(str, i) end
    end
    for _, c in ipairs(codes) do
        local t = f.map and f.map[c]
        if not t then
            local hi = f.high and c >= 128 and f.high[c - 128]
            t = f.two and string.format("<%04X>", c) or utf8(hi or c)
        end
        out[#out + 1] = t
        w = w + (f.widths[c] or f.dw) / 1000
    end
    return table.concat(out), w, codes
end

------------------------------------------------------------------------
-- the content interpreter
------------------------------------------------------------------------
local lines = {}
local function emit(s) lines[#lines + 1] = s end

local function mul(m, n) -- m then n (PDF row vectors: m x n)
    return {m[1] * n[1] + m[2] * n[3], m[1] * n[2] + m[2] * n[4],
        m[3] * n[1] + m[4] * n[3], m[3] * n[2] + m[4] * n[4],
        m[5] * n[1] + m[6] * n[3] + n[5], m[5] * n[2] + m[6] * n[4] + n[6]}
end
local function xf(m, x, y) return m[1] * x + m[3] * y + m[5], m[2] * x + m[4] * y + m[6] end
local function fmt(x) return string.format("%.2f", x) end
local function cmyk(c, m, y, k) return (1 - c) * (1 - k), (1 - m) * (1 - k), (1 - y) * (1 - k) end
local function color_str(c)
    if #c == 1 then return fmt(c[1]) .. "," .. fmt(c[1]) .. "," .. fmt(c[1]) end
    if #c == 3 then return fmt(c[1]) .. "," .. fmt(c[2]) .. "," .. fmt(c[3]) end
    if #c == 4 then
        local r, g, b = cmyk(c[1], c[2], c[3], c[4])
        return fmt(r) .. "," .. fmt(g) .. "," .. fmt(b)
    end
    return "?"
end

local run_content
run_content = function(content, res, ctm0, depth)
    local gs = {ctm = ctm0, lw = 1, sc = {0}, fc = {0}, dash = "-"}
    local stack = {}
    local path, cur = {}, nil
    local stack_ops = {}
    local tm, tlm, font, fsize, tl, tc, tw, th, rise = nil, nil, nil, 1, 0, 0, 0, 1, 0
    local i, n = 1, #content
    local function flush(op)
        local stroke = op == "S" or op == "s" or op == "B" or op == "B*" or op == "b" or op == "b*"
        local fill = op == "f" or op == "F" or op == "f*" or op == "B" or op == "B*" or op == "b" or op == "b*"
        if op == "s" or op == "b" or op == "b*" then
            for _, sp in ipairs(path) do if #sp > 0 then sp[#sp + 1] = sp[1] end end
        end
        for _, sp in ipairs(path) do
            if #sp >= 2 then
                local pts = {}
                for k, pt in ipairs(sp) do pts[k] = fmt(pt[1]) .. "," .. fmt(pt[2]) end
                local ptxt = table.concat(pts, " ")
                if stroke then
                    local m = gs.ctm
                    local lw = gs.lw * sqrt(abs(m[1] * m[4] - m[2] * m[3]))
                    emit("S " .. fmt(lw) .. " " .. color_str(gs.sc) .. " " .. gs.dash .. " : " .. ptxt)
                end
                if fill then emit("F " .. color_str(gs.fc) .. " : " .. ptxt) end
            end
        end
        path, cur = {}, nil
    end
    local function text_out(str)
        if not font then return end
        local f = font_info(font)
        local text, w, codes = show_codes(f, str)
        local trm = mul({fsize * th, 0, 0, fsize, 0, rise}, mul(tm, gs.ctm))
        local x, y = trm[5], trm[6]
        local ang = deg(atan2(trm[2], trm[1]))
        local size = sqrt(trm[3] * trm[3] + trm[4] * trm[4])
        emit("T " .. fmt(x) .. " " .. fmt(y) .. " " .. fmt(size) .. " " .. string.format("%.1f", ang) .. " " .. text)
        local spaces = 0
        if not f.two then for _, c in ipairs(codes) do if c == 32 then spaces = spaces + 1 end end end
        local tx = (w * fsize + tc * #codes + tw * spaces) * th
        tm = mul({1, 0, 0, 1, tx, 0}, tm)
    end
    while true do
        i = skip_ws(content, i)
        if i > n then break end
        local tok
        tok, i = parse(content, i)
        if not tok then break end
        if tok.t ~= "kw" then
            stack_ops[#stack_ops + 1] = tok
        else
            local op, a = tok.v, stack_ops
            local function num(k) return a[k] and a[k].v or 0 end
            if op == "q" then
                stack[#stack + 1] = {ctm = gs.ctm, lw = gs.lw, sc = gs.sc, fc = gs.fc, dash = gs.dash}
            elseif op == "Q" then
                local g = table.remove(stack)
                if g then gs = g end
            elseif op == "cm" then
                gs.ctm = mul({num(1), num(2), num(3), num(4), num(5), num(6)}, gs.ctm)
            elseif op == "w" then
                gs.lw = num(1)
            elseif op == "d" then
                local arr = a[1] and a[1].v or {}
                local parts = {}
                for _, v in ipairs(arr) do parts[#parts + 1] = fmt(R(v).v) end
                gs.dash = #parts > 0 and ("[" .. table.concat(parts, ",") .. "]") or "-"
            elseif op == "G" or op == "RG" or op == "K" or op == "SC" or op == "SCN" then
                local c = {}
                for _, v in ipairs(a) do if v.t == "num" then c[#c + 1] = v.v end end
                gs.sc = c
            elseif op == "g" or op == "rg" or op == "k" or op == "sc" or op == "scn" then
                local c = {}
                for _, v in ipairs(a) do if v.t == "num" then c[#c + 1] = v.v end end
                gs.fc = c
            elseif op == "m" then
                local x, y = xf(gs.ctm, num(1), num(2))
                cur = {{x, y}}
                path[#path + 1] = cur
                cur.ux, cur.uy = num(1), num(2)
                cur.sx, cur.sy = cur.ux, cur.uy
            elseif op == "l" then
                if cur then
                    local x, y = xf(gs.ctm, num(1), num(2))
                    cur[#cur + 1] = {x, y}
                    cur.ux, cur.uy = num(1), num(2)
                end
            elseif op == "c" or op == "v" or op == "y" then
                if cur then
                    local x0, y0 = cur.ux, cur.uy
                    local x1, y1, x2, y2, x3, y3
                    if op == "c" then x1, y1, x2, y2, x3, y3 = num(1), num(2), num(3), num(4), num(5), num(6)
                    elseif op == "v" then x1, y1, x2, y2, x3, y3 = x0, y0, num(1), num(2), num(3), num(4)
                    else x1, y1, x2, y2, x3, y3 = num(1), num(2), num(3), num(4), num(3), num(4) end
                    for k = 1, 8 do
                        local t = k / 8
                        local u = 1 - t
                        local bx = u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3
                        local by = u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3
                        local x, y = xf(gs.ctm, bx, by)
                        cur[#cur + 1] = {x, y}
                    end
                    cur.ux, cur.uy = x3, y3
                end
            elseif op == "h" then
                -- the current point goes back to the subpath's start (a curve
                -- after h without m starts there)
                if cur and #cur > 0 then
                    cur[#cur + 1] = {cur[1][1], cur[1][2]}
                    cur.ux, cur.uy = cur.sx, cur.sy
                end
            elseif op == "re" then
                local x, y, w, h = num(1), num(2), num(3), num(4)
                local sp = {}
                for _, pt in ipairs({{x, y}, {x + w, y}, {x + w, y + h}, {x, y + h}, {x, y}}) do
                    local px, py = xf(gs.ctm, pt[1], pt[2])
                    sp[#sp + 1] = {px, py}
                end
                sp.ux, sp.uy = x, y
                sp.sx, sp.sy = x, y
                path[#path + 1] = sp
                cur = sp
            elseif op == "S" or op == "s" or op == "f" or op == "F" or op == "f*" or op == "B" or op == "B*"
                or op == "b" or op == "b*" or op == "n" then
                flush(op)
            elseif op == "BT" then
                tm, tlm = {1, 0, 0, 1, 0, 0}, {1, 0, 0, 1, 0, 0}
            elseif op == "ET" then
                tm = nil
            elseif op == "Tf" then
                local fonts = D(res, "Font")
                font = fonts and fonts.v[a[1].v]
                font = font and R(font) and font
                fsize = num(2)
            elseif op == "Tc" then tc = num(1)
            elseif op == "Tw" then tw = num(1)
            elseif op == "Tz" then th = num(1) / 100
            elseif op == "TL" then tl = num(1)
            elseif op == "Ts" then rise = num(1)
            elseif op == "Td" or op == "TD" then
                if op == "TD" then tl = -num(2) end
                tlm = mul({1, 0, 0, 1, num(1), num(2)}, tlm or {1, 0, 0, 1, 0, 0})
                tm = tlm
            elseif op == "Tm" then
                tlm = {num(1), num(2), num(3), num(4), num(5), num(6)}
                tm = tlm
            elseif op == "T*" then
                tlm = mul({1, 0, 0, 1, 0, -tl}, tlm or {1, 0, 0, 1, 0, 0})
                tm = tlm
            elseif op == "Tj" or op == "'" or op == "\"" then
                if op ~= "Tj" then
                    tlm = mul({1, 0, 0, 1, 0, -tl}, tlm or {1, 0, 0, 1, 0, 0})
                    tm = tlm
                end
                local s = a[#a]
                if tm and s and s.t == "str" then text_out(s.v) end
            elseif op == "TJ" then
                local arr = a[1] and a[1].v or {}
                if tm then
                    local buf = {}
                    local first_x
                    for _, el in ipairs(arr) do
                        if el.t == "str" then buf[#buf + 1] = el.v
                        elseif el.t == "num" and #buf == 0 then
                            tm = mul({1, 0, 0, 1, -el.v / 1000 * fsize * th, 0}, tm)
                        elseif el.t == "num" then
                            -- a big gap splits the run
                            if el.v < -300 then
                                text_out(table.concat(buf))
                                buf = {}
                            end
                            tm = mul({1, 0, 0, 1, -el.v / 1000 * fsize * th, 0}, tm)
                        end
                    end
                    if #buf > 0 then text_out(table.concat(buf)) end
                    first_x = first_x
                end
            elseif op == "Do" then
                local xo = D(res, "XObject")
                local ref = xo and xo.v[a[1].v]
                local o = ref and ref.t == "ref" and objs[ref.v]
                if o and o.raw then
                    local st = D(o.value, "Subtype")
                    if st and st.v == "Form" and depth < 8 then
                        local mtx = D(o.value, "Matrix")
                        local m = {1, 0, 0, 1, 0, 0}
                        if mtx then for k = 1, 6 do m[k] = R(mtx.v[k]).v end end
                        local r2 = D(o.value, "Resources") or res
                        run_content(stream_data(o), r2, mul(m, gs.ctm), depth + 1)
                    elseif st and st.v == "Image" then
                        local x0, y0 = xf(gs.ctm, 0, 0)
                        local x1, y1 = xf(gs.ctm, 1, 1)
                        emit("I " .. fmt(x0) .. " " .. fmt(y0) .. " " .. fmt(x1 - x0) .. " " .. fmt(y1 - y0))
                    end
                end
            elseif op == "BI" then
                local e = find(content, "[%s]EI[%s]", i)
                i = e and e + 3 or n + 1
            end
            stack_ops = {}
        end
    end
end

------------------------------------------------------------------------
local pdf, page_no, out_path = arg[1], tonumber(arg[2]), arg[3]
if not pdf or not page_no then
    io.stderr:write("usage: luajit pdf_paths.lua <pdf> <page from 1> [out]\n")
    os.exit(2)
end
load_pdf(pdf)
local catalog
for _, o in pairs(objs) do
    local t = o.value and o.value.t == "dict" and R(o.value.v.Type)
    if t and t.v == "Catalog" then catalog = o.value end
end
assert(catalog, "no catalog")
local pages = {}
local function walk(node, inh)
    node = R(node)
    local d = node.v
    local here = {Resources = d.Resources or inh.Resources, MediaBox = d.MediaBox or inh.MediaBox}
    local t = R(d.Type)
    if t and t.v == "Pages" then
        for _, kid in ipairs(R(d.Kids).v) do walk(kid, here) end
    else
        pages[#pages + 1] = {dict = node, res = R(here.Resources), box = R(here.MediaBox)}
    end
end
walk(catalog.v.Pages, {})
local pg = assert(pages[page_no], "no page " .. page_no .. " (of " .. #pages .. ")")
local box = pg.box and pg.box.v or {}
local function bv(k) return box[k] and R(box[k]).v or 0 end
emit("PAGE " .. page_no .. " " .. fmt(bv(3) - bv(1)) .. " " .. fmt(bv(4) - bv(2)))
local contents = D(pg.dict, "Contents")
local parts = {}
if contents and contents.t == "arr" then
    for _, r in ipairs(contents.v) do parts[#parts + 1] = stream_data(objs[r.v]) end
elseif contents then
    local ref = pg.dict.v.Contents
    parts[1] = stream_data(objs[ref.v])
end
run_content(table.concat(parts, "\n"), pg.res, {1, 0, 0, 1, -bv(1), -bv(2)}, 0)
local text = table.concat(lines, "\n") .. "\n"
if out_path then
    local f = assert(io.open(out_path, "wb"))
    f:write(text)
    f:close()
    print(#lines .. " lines to " .. out_path)
else
    io.write(text)
end
