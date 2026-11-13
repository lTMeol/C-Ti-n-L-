#!/usr/bin/env python3
"""
obfuscate_lua.py - làm rối (obfuscate) file .lua của mod DST.

Cách dùng:
    # file trong scripts/ (được require bởi modmain)
    python obfuscate_lua.py scripts --out dist

    # modmain.lua (chạy trong môi trường mod, cần thêm --modmain)
    python obfuscate_lua.py modmain.lua --modmain --out dist

    # kiểu "nhị phân thô" (mở ra thấy toàn ký tự rác như mod trên Workshop)
    python obfuscate_lua.py scripts --raw --out dist
    python obfuscate_lua.py modmain.lua --modmain --raw --out dist

File gốc KHÔNG bị sửa; bản đã làm rối được ghi vào thư mục --out với cùng
đường dẫn tương đối. KHÔNG làm rối modinfo.lua (game cần đọc dạng chữ thường).

Hai kiểu đầu ra:
  * mặc định : payload là chuỗi "\\ddd" (chỉ gồm ký tự ASCII, an toàn với editor/git).
  * --raw    : payload là byte thô nhét thẳng trong chuỗi Lua. Nhìn giống ảnh
               bạn gửi, nhưng KHÔNG được mở rồi lưu lại bằng editor, và phải để
               git coi là file binary (xem hướng dẫn ở cuối câu trả lời).

Đây chỉ là làm rối, KHÔNG phải mã hoá thật: game phải tự giải mã để chạy, nên ai
đọc được loader đều giải ngược lại được.
"""

import argparse
import os
import random
import sys

BOM = b"\xef\xbb\xbf"

# Byte không được để thô trong chuỗi Lua "..." (kết thúc chuỗi/dòng, escape,
# hoặc Ctrl-Z làm Windows hiểu là hết file khi đọc ở text mode)
RAW_UNSAFE = {0, 10, 13, 26, 34, 92}


# ---------------------------------------------------------------- kiểu mặc định
def encode(src: bytes, key: list) -> bytes:
    n = len(key)
    out = bytearray(len(src))
    for i, b in enumerate(src, start=1):  # i bắt đầu từ 1 để khớp Lua
        out[i - 1] = (b + key[(i - 1) % n] + (i % 251)) % 256
    return bytes(out)


def to_lua_lines(data: bytes, per_line: int = 48) -> str:
    lines = []
    for pos in range(0, len(data), per_line):
        chunk = data[pos:pos + per_line]
        lines.append('    "' + "".join("\\%03d" % b for b in chunk) + '"')
    return ",\n".join(lines)


STUB_SCRIPT = """local d = table.concat({{
{data}
}})
local k = {{{key}}}
local n = #k
local t = {{}}
for i = 1, #d do
    t[i] = string.char((d:byte(i) - k[(i - 1) % n + 1] - i % 251) % 256)
end
local f, e = loadstring(table.concat(t), "@{chunk}")
assert(f, e)
setfenv(f, getfenv(1))
return f(...)
"""

# modmain.lua chạy trong môi trường mod nên lấy hàm hệ thống qua GLOBAL
STUB_MODMAIN = """local G = GLOBAL
local d = G.table.concat({{
{data}
}})
local k = {{{key}}}
local n = #k
local t = {{}}
for i = 1, #d do
    t[i] = G.string.char((d:byte(i) - k[(i - 1) % n + 1] - i % 251) % 256)
end
local f, e = G.loadstring(G.table.concat(t), "@{chunk}")
G.assert(f, e)
G.setfenv(f, G.getfenv(1))
return f(...)
"""


# ------------------------------------------------------------------ kiểu --raw
# Keystream: s = (s*75 + 74) % 65537 (số nhỏ nên Lua double tính chính xác)
def raw_encode(src: bytes, seed: int) -> bytes:
    s = seed
    out = bytearray(len(src))
    for i, b in enumerate(src):
        s = (s * 75 + 74) % 65537
        out[i] = (b + s) % 256
    return bytes(out)


def raw_literal(data: bytes) -> bytes:
    """Byte thô, chỉ escape \\ddd cho các byte không an toàn. Luôn là MỘT dòng."""
    out = bytearray()
    for b in data:
        if b in RAW_UNSAFE:
            out += b"\\%03d" % b
        else:
            out.append(b)
    return bytes(out)


RAW_HEAD_SCRIPT = b"local d = \""
RAW_TAIL_SCRIPT = """"
local s = {seed}
local t = {{}}
for i = 1, #d do
    s = (s * 75 + 74) % 65537
    t[i] = string.char((d:byte(i) - s) % 256)
end
local f, e = loadstring(table.concat(t), "@{chunk}")
assert(f, e)
setfenv(f, getfenv(1))
return f(...)
"""

RAW_HEAD_MODMAIN = b"local G = GLOBAL\nlocal d = \""
RAW_TAIL_MODMAIN = """"
local s = {seed}
local t = {{}}
for i = 1, #d do
    s = (s * 75 + 74) % 65537
    t[i] = G.string.char((d:byte(i) - s) % 256)
end
local f, e = G.loadstring(G.table.concat(t), "@{chunk}")
G.assert(f, e)
G.setfenv(f, G.getfenv(1))
return f(...)
"""


def obfuscate_file(path: str, out_path: str, modmain: bool, raw: bool, chunk: str) -> None:
    with open(path, "rb") as fh:
        src = fh.read()
    if src.startswith(BOM):
        src = src[len(BOM):]  # BOM làm loadstring báo lỗi

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)

    if raw:
        seed = random.randrange(1, 65537)
        head = RAW_HEAD_MODMAIN if modmain else RAW_HEAD_SCRIPT
        tail = (RAW_TAIL_MODMAIN if modmain else RAW_TAIL_SCRIPT).format(seed=seed, chunk=chunk)
        blob = head + raw_literal(raw_encode(src, seed)) + tail.encode("ascii")
        with open(out_path, "wb") as fh:
            fh.write(blob)
        return

    key = [random.randrange(1, 256) for _ in range(random.randrange(8, 17))]
    stub = (STUB_MODMAIN if modmain else STUB_SCRIPT).format(
        data=to_lua_lines(encode(src, key)),
        key=", ".join(str(x) for x in key),
        chunk=chunk,
    )
    with open(out_path, "w", encoding="ascii", newline="\n") as fh:
        fh.write(stub)


def collect(inputs):
    """Trả về list (đường dẫn thật, đường dẫn tương đối)."""
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
            files.append((p, os.path.basename(p) if not os.path.dirname(p) else p))
    return files


def main() -> int:
    ap = argparse.ArgumentParser(description="Làm rối file Lua của mod DST")
    ap.add_argument("inputs", nargs="+", help="file .lua hoặc thư mục")
    ap.add_argument("--out", default="dist", help="thư mục đầu ra (mặc định: dist)")
    ap.add_argument("--modmain", action="store_true",
                    help="dùng cho modmain.lua (chạy trong môi trường mod)")
    ap.add_argument("--raw", action="store_true",
                    help="payload là byte thô (nhìn như ký tự rác), không phải chuỗi \\ddd")
    args = ap.parse_args()

    count = 0
    for full, rel in collect(args.inputs):
        name = os.path.basename(full).lower()
        if name == "modinfo.lua":
            print("Bỏ qua modinfo.lua (game cần đọc dạng chữ thường)")
            continue
        out_path = os.path.join(args.out, rel)
        obfuscate_file(full, out_path, args.modmain, args.raw, rel.replace("\\", "/"))
        print("OK  %s -> %s" % (full, out_path))
        count += 1

    if count == 0:
        print("Không có file nào được xử lý.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
