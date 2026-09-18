# Windows support

Everything needed to produce a Windows build of `tsviewer` lives in this directory. The program itself is developed and built on Linux; the Windows executable is cross-compiled with mingw-w64.

Nothing here is compiled or read by an ordinary Linux build. The whole directory can be deleted and `make` will still work.

## What the top-level source gives up for this

Three lines in `tsviewer_main.c`:

```text
#ifdef _WIN32
#include "windows/tsviewer_win32_compat.h"
#endif
```

That is the entire footprint. There are no other Windows conditionals anywhere in the program.

## Files

| File | Purpose |
| --- | --- |
| `windows.mk` | The cross-compilation and packaging rules. The top-level `Makefile` pulls them in with `-include windows/windows.mk`. |
| `tsviewer_win32_compat.h` | Compatibility shims, described below. |
| `tsviewer-open.c` | Shell helper that gathers a multi-file Explorer selection into a single viewer window. |
| `tsviewer.nsi` | NSIS script for the installer. |
| `tsviewer-prompt.cmd` | Opens a command prompt with `tsviewer` on the `PATH`. Shipped in both packages. |
| `win32/` | The downloaded GTK3 bundle. Not in version control; `make distclean` removes it. |
| `dist/` | Staging folder assembled by `make windows`. Not in version control. |

## Build

```text
make windows            # staging folder in windows/dist
make windows-zip        # tsviewer-<version>-win64.zip
make windows-installer  # tsviewer-<version>-win64-setup.exe
```

The two packages are written to the top level of the repository. `make distclean` additionally removes the downloaded GTK3 bundle.

See `INSTALL.md` for the required packages and the usual build instructions.

## The compatibility shims

`tsviewer_win32_compat.h` contains two unrelated things, both consequences of the Windows toolchain rather than of the program.

**`timegm()` and `strptime()`.** Both are POSIX and neither exists in mingw-w64, so the program would not link without them. `timegm` becomes the Windows `_mkgmtime`. `strptime` is reimplemented for exactly the directives `parse_timestamp_text()` uses: `%Y %m %d %H %M %S`, `%%`, literal characters and whitespace. It validates field ranges, so out-of-range components such as `2021-13-45` are rejected rather than normalized, which is what glibc does. It was differentially tested against glibc's `strptime` over every format string the program uses.

**Four GTK prototypes.** The prebuilt bundle ships GTK 3.24 DLLs alongside GTK 3.10 headers. `gtk_label_set_xalign`, `gtk_label_set_yalign`, `gtk_text_view_set_top_margin` and `gtk_text_view_set_bottom_margin` are exported by the DLLs but not declared by the headers. Without the prototypes they compile as implicit declarations, which link successfully but pass their `gfloat` arguments with the wrong ABI, silently producing garbage alignment values. The prototypes are guarded by `GTK_CHECK_VERSION`, so they disappear against any GTK new enough to declare them.

## The multi-file context menu

Explorer starts a command-line context menu verb **once for each selected file**, not once for the whole selection. A verb pointing straight at `tsviewer.exe` therefore opens one window per file. No registry setting changes this: `MultiSelectModel` controls how many files the verb is offered for, not how many times Explorer runs the command.

`tsviewer-open.c` works around it. Explorer still starts it once per file, but the instances find one another through a named shared memory block guarded by a named mutex. The first to start becomes the collector; the others add their path and exit. The collector waits until no new file has arrived for 300 ms, then starts a single `tsviewer.exe` with everything collected.

Every failure path falls back to opening just that instance's own file, which is the behaviour of a verb pointing directly at `tsviewer.exe`. The helper cannot make things worse than not having it.

`MultiSelectModel=Player` is still set by the installer, because without it the verb disappears entirely once more than 15 files are selected.

The helper is used only by the right-click menu. Starting `tsviewer.exe` from a command prompt or the Start Menu shortcut does not involve it.

### The file limit

`tsviewer` compares at most `MAX_INPUT_FILES` files. Selecting more opens the first few and reports how many were selected. `windows.mk` reads the limit out of `tsviewer_main.c` and passes it to the helper as a `-D`, so raising it in the program raises it in the helper too.

## Why the PATH is left alone

Neither package modifies the system `PATH`. NSIS truncates strings at 1024 characters, so an installer that read and rewrote a longer `PATH` would silently corrupt it. `tsviewer-prompt.cmd` sets `PATH` for its own window instead.

## Known differences from the Linux build

- The bundle ships no icon theme, so a few stock icons in GTK dialogs are missing. This is cosmetic.
- Timestamps before 1970 are rejected in the compact `YYYYMMDDHHMM` and `YYYYMMDDHHMMSS` formats, because the Windows C library cannot represent them. Every other supported format behaves identically.
- File paths that cannot be represented in the system code page will not open. `tsviewer` uses the narrow C file functions throughout.

## Automated builds

`.github/workflows/windows-release.yml` runs this build when a GitHub release is published and attaches both packages to it. It can also be started by hand from the Actions tab, in which case the packages are left as workflow artifacts.
