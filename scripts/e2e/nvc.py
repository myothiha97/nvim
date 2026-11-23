#!/usr/bin/env python3
"""Exploration CLI. nvc start NAME CWD [args..] | keys NAME KEYS | lua NAME CODE | screen NAME | mouse NAME ROW COL [btn] [double] | kill NAME"""
import sys, time
import nvh
cmd, name = sys.argv[1], sys.argv[2]
if cmd == "start":
    n = nvh.Nvim(sys.argv[3], sys.argv[4:], name=name)
    n.wait("return vim.g.e2e_verylazy or (function() local c=require('lazy.core.config').plugins['which-key.nvim']; return c and c._.loaded ~= nil end)()", 40, "VeryLazy")
    time.sleep(1.5); print(n.screen()); sys.exit()
if cmd == "kill":
    nvh.sh(nvh.TMUX + ["kill-session", "-t", name]); sys.exit()
n = nvh.attach(name)
if cmd == "keys":
    n.keys(sys.argv[3]); time.sleep(float(sys.argv[4]) if len(sys.argv) > 4 else 0.8); print(n.screen())
elif cmd == "lua":
    print(n.lua(sys.argv[3], timeout=30))
elif cmd == "screen":
    print(n.screen(ansi=len(sys.argv) > 3))
elif cmd == "mouse":
    n.mouse(int(sys.argv[3]), int(sys.argv[4]), sys.argv[5] if len(sys.argv) > 5 else "left", sys.argv[6] if len(sys.argv) > 6 else "click"); time.sleep(0.6); print(n.screen())
