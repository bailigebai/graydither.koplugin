"""Run the plugin's LuaJIT tests against pinned KOReader BlitBuffer source."""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
from pathlib import Path
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "graydither.koplugin"
FIXTURES = ROOT / "tests/fixtures"

def runtime(case=None, plugin_root=PLUGIN):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TEST_ROOT = ROOT.as_posix()
    lua.globals().TEST_PLUGIN = plugin_root.resolve().as_posix()
    lua.globals().TEST_FIXTURES = FIXTURES.as_posix()
    lua.globals().TEST_CASE = case
    lua.execute("""
        package.path = TEST_PLUGIN.."/?.lua;"..TEST_FIXTURES.."/base/?.lua;"..
            TEST_ROOT.."/tests/?.lua;"..package.path
        package.preload["ffi/util"] = function()
            return {idiv = function(a,b) return math.floor(a/b) end}
        end
        package.preload["ffi/posix_h"] = function()
            require("ffi").cdef[[
                void* malloc(size_t); void* calloc(size_t,size_t); void free(void*);
            ]]
            return true
        end
        local BB = require("ffi/blitbuffer")
        BB.enableCBB(false)
        TEST_COUNT = 0
        function test(name, fn)
            if TEST_CASE and not name:find(TEST_CASE,1,true) then return end
            local ok, err = pcall(fn)
            assert(ok, name..": "..tostring(err))
            TEST_COUNT = TEST_COUNT + 1
        end
        function eq(a,b,msg)
            assert(a == b, (msg or "values differ")..": "..tostring(a).." ~= "..tostring(b))
        end
    """)
    return lua

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("specs", nargs="*")
    parser.add_argument("--case")
    parser.add_argument("--plugin-root", type=Path, default=PLUGIN)
    args = parser.parse_args()
    specs = [ROOT/"tests"/name for name in args.specs] if args.specs else sorted((ROOT/"tests").glob("*_spec.lua"))
    if not specs:
        raise SystemExit("No tests selected")
    # Verify third-party fixtures before executing them.
    for item in json.loads((FIXTURES/"provenance.json").read_text(encoding="utf-8")):
        p = ROOT/item["file"]
        if hashlib.sha256(p.read_bytes()).hexdigest() != item["sha256"]:
            raise SystemExit("Fixture hash mismatch: "+str(p))
    total = 0
    failed = False
    for path in specs:
        try:
            lua = runtime(args.case, args.plugin_root)
            lua.execute(path.read_text(encoding="utf-8"), name="@"+path.as_posix())
            count = int(lua.globals().TEST_COUNT)
            total += count
            print(f"PASS {path.name}: {count} tests")
        except Exception as exc:
            failed = True
            print(f"FAIL {path.name}: {exc}", file=sys.stderr)
    lua = runtime(plugin_root=args.plugin_root)
    compile_lua = lua.eval('function(src,name) local f,e=loadstring(src,name); assert(f,e); return true end')
    products = sorted(args.plugin_root.rglob("*.lua"))
    for path in products:
        compile_lua(path.read_text(encoding="utf-8"), "@"+path.as_posix())
    print(f"Total: {total} passed; {len(products)} product Lua files compile; native C blitter disabled")
    print(lua.eval("jit.version"))
    return int(failed)

if __name__ == "__main__":
    raise SystemExit(main())
