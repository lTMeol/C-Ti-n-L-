#!/usr/bin/env python3
"""
deobfuscate_lua.py - khôi phục file .lua đã làm rối bằng obfuscate_lua.py.

Cách dùng:
    # một file
    python deobfuscate_lua.py scripts/cosu_element_tuning.lua --out src

    # cả thư mục (tự bỏ qua file không phải bản làm rối)
    python deobfuscate_lua.py dist --out src

    # modmain.lua (dạng --modmain cũng tự nhận biết, không cần cờ)
    python deobfuscate_lua.py modmain.lua --out src

Tự nhận biết cả hai kiểu của obfuscate_lua.py:
  * mặc định : payload là chuỗi "\\ddd" + mảng khóa  local k = {...}
  * --raw    : payload là byte thô + keystream      local s = <seed>

File vào KHÔNG bị sửa; kết quả ghi vào --out với cùng đường dẫn tương đối.
Đọc file bằng chế độ nhị phân nên không làm hỏng byte thô.
"""

import argparse
import os
import re
import sys


# ------------------------------------------------------------ đọc chuỗi Lua
def parse_lua_string(data: bytes, start: int):
    """Đọc chuỗi Lua "..." bắt đầu SAU dấu nháy mở. Trả về (bytes, vị trí sau dấu nháy đóng).

    obfuscate_lua.py luôn escape các byte 0, 10, 13, 26, 34, 92 dạng \\ddd
    (đúng 3 chữ số), nên dấu " thô đầu tiên gặp phải chính là dấu đóng chuỗi.
    """
    out = bytearray()
    i = start
    n = len(data)
    while i < n:
        c = data[i]
        if c == 0x22:  # "
            return bytes(out), i + 1
        if c == 0x5C:  # backslash -> \ddd
            m = re.match(rb"\d{1,3}", data[i + 1:i + 4])
            if not m:
                raise ValueError("escape lạ tại byte %d" % i)
            out.append(int(m.group()) & 0xFF)
            i += 1 + len(m.group())
        else:
            out.append(c)
            i += 1
    raise ValueError("chuỗi Lua không đóng")


# ------------------------------------------------------------------ giải mã
def decode_default(d: bytes, key: list) -> bytes:
    n = len(key)
    out = bytearray(len(d))
    for i, b in enumerate(d, start=1):
        out[i - 1] = (b - key[(i - 1) % n] - (i % 251)) % 256
    return bytes(out)


def decode_raw(d: bytes, seed: int) -> bytes:
    s = seed
    out = bytearray(len(d))
    for i, b in enumerate(d):
        s = (s * 75 + 74) % 65537
        out[i] = (b - s) % 256
    return bytes(out)


def deobfuscate(blob: bytes):
    """Gỡ MỘT lớp. Trả về (nội dung, kiểu) hoặc (None, lý do)."""
    if blob.startswith(b"\xef\xbb\xbf"):
        blob = blob[3:]

    # chữ ký chung của stub do obfuscate_lua.py tạo ra
    if b"loadstring" not in blob or b"setfenv" not in blob:
        return None, "không phải file do obfuscate_lua.py tạo ra"

    # ---- kiểu --raw: local d = "<byte thô>"\nlocal s = <seed>
    m = re.match(rb'(?:local G = GLOBAL\r?\n)?local d = "', blob)
    if m:
        try:
            payload, end = parse_lua_string(blob, m.end())
        except ValueError as e:
            return None, "lỗi đọc payload raw: %s" % e
        ms = re.match(rb"\s*local s = (\d+)", blob[end:])
        if not ms:
            return None, "không thấy seed (local s = ...)"
        return decode_raw(payload, int(ms.group(1))), "raw"

    # ---- kiểu mặc định: table.concat({ "\ddd...", ... }) + local k = {...}
    m = re.match(rb"(?:local G = GLOBAL\r?\n)?local d = (?:G\.)?table\.concat\(\{", blob)
    if m:
        close = blob.find(b"})", m.end())
        if close < 0:
            return None, "không thấy phần đóng của payload"
        body = blob[m.end():close]
        payload = bytearray()
        pos = 0
        while True:
            q = body.find(b'"', pos)
            if q < 0:
                break
            piece, pos = parse_lua_string(body, q + 1)
            payload += piece
        mk = re.search(rb"local k = \{([^}]*)\}", blob[close:])
        if not mk:
            return None, "không thấy mảng khóa (local k = {...})"
        key = [int(x) for x in re.findall(rb"\d+", mk.group(1))]
        if not key:
            return None, "mảng khóa rỗng"
        return decode_default(bytes(payload), key), "default"

    return None, "có loadstring nhưng không đúng định dạng của obfuscate_lua.py"


def unwrap(blob: bytes, max_layers: int = 20):
    """Gỡ liên tục cho tới khi không còn là bản làm rối. Trả về (nội dung, [các lớp]) hoặc (None, lý do)."""
    layers = []
    while len(layers) < max_layers:
        data, kind = deobfuscate(blob)
        if data is None:
            if not layers:
                return None, kind
            return blob, layers  # hết lớp: blob hiện tại là bản đọc được
        layers.append(kind)
        blob = data
    return None, "quá %d lớp, có thể bị lặp" % max_layers


# ---------------------------------------------------------------------- CLI
def collect(inputs):
    files = []
    for p in inputs:
        if os.path.isdir(p):
            base = os.path.dirname(os.path.normpath(p))
            for root, _, names in os.walk(p):
                for name in sorted(names):
                    if name.lower().endswith(".lua"):
                        full = os.path.join(root, name)
                        files.append((full, os.path.relpath(full, base or ".")))
        else:
            # đường dẫn tuyệt đối -> chỉ lấy tên file, tránh os.path.join ghi đè lên file gốc
            rel = os.path.basename(p) if (os.path.isabs(p) or not os.path.dirname(p)) else p
            files.append((p, rel))
    return files


def looks_like_lua(data: bytes) -> bool:
    """Kiểm tra nhanh: kết quả có phải văn bản Lua (UTF-8, không byte rác)."""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return all(ch == "\n" or ch == "\r" or ch == "\t" or ch >= " " for ch in text)


def main() -> int:
    ap = argparse.ArgumentParser(description="Khôi phục file Lua đã làm rối bằng obfuscate_lua.py")
    ap.add_argument("inputs", nargs="+", help="file .lua hoặc thư mục")
    ap.add_argument("--out", default="src", help="thư mục đầu ra (mặc định: src)")
    args = ap.parse_args()

    ok = 0
    for full, rel in collect(args.inputs):
        if os.path.basename(full).lower() == "modinfo.lua":
            continue
        with open(full, "rb") as fh:
            blob = fh.read()
        data, kind = unwrap(blob)
        if data is None:
            print("BỎ QUA %s (%s)" % (full, kind))
            continue
        if not looks_like_lua(data):
            print("LỖI    %s: giải mã xong nhưng không ra văn bản UTF-8 hợp lệ" % full, file=sys.stderr)
            continue
        out_path = os.path.join(args.out, rel)
        if os.path.abspath(out_path) == os.path.abspath(full):
            print("BỎ QUA %s (đầu ra trùng file gốc, hãy dùng --out khác)" % full, file=sys.stderr)
            continue
        os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
        with open(out_path, "wb") as fh:
            fh.write(data)
        print("OK     %s -> %s  [%s]" % (full, out_path, " + ".join(kind)))
        ok += 1

    if ok == 0:
        print("Không có file nào được khôi phục.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())