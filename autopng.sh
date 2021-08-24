#!/bin/sh
ls *.zig lib/*.zig | entr -c sh -c "zig build run"
