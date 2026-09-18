# Installing tsviewer

`tsviewer` is a lightweight GTK3 scientific time-series viewer written in C99.

The program is built from source using the supplied `Makefile`.

## Requirements

Building `tsviewer` requires:

- A C compiler supporting C99, such as GCC
- GTK+ 3 development libraries and header files
- Cairo development libraries
- `pkg-config`
- GNU Make
- The standard C math library

GTK3 normally brings in Cairo and the other graphical libraries required by the application.

These are the requirements for building on Linux. Building a Windows executable is described separately under **Windows** below.

## Linux

The exact package names depend on the Linux distribution.

### openSUSE / SUSE Linux Enterprise

Install the required development tools and GTK3 development package:

```text
sudo zypper install gcc make pkg-config gtk3-devel
```

### Fedora / RHEL-family distributions

```text
sudo dnf install gcc make pkgconf-pkg-config gtk3-devel
```

### Debian / Ubuntu

```text
sudo apt install build-essential pkg-config libgtk-3-dev
```

## Verify GTK3 development environment

Before building, you can verify that `pkg-config` can locate GTK3:

```text
pkg-config --modversion gtk+-3.0
```

A version number should be printed.

You can also verify the compiler flags detected for GTK3:

```text
pkg-config --cflags gtk+-3.0
```

and the required linker flags:

```text
pkg-config --libs gtk+-3.0
```

If `pkg-config` reports that `gtk+-3.0` cannot be found, the GTK3 development package is either not installed or is not visible in the current `pkg-config` search path.

## Build

Clone the repository:

```text
git clone https://github.com/fred-ogden/tsviewer.git
cd tsviewer
```

Build the program:

```text
make
```

The resulting executable is:

```text
tsviewer
```

Test the executable:

```text
./tsviewer --help
```

## Try the examples

Example data files are included in the `examples` directory.

For example:

```text
./tsviewer examples/model1_temperatures.csv examples/model2_temperatures.csv
```

This opens two model-output data sets simultaneously and provides a useful demonstration of the multi-file comparison capabilities of `tsviewer`.

Additional examples are described in:

```text
examples/README.md
```

## Clean the build

To remove generated build files:

```text
make clean
```

Rebuild with:

```text
make
```

## Windows

A Windows executable is produced by cross-compiling on Linux with the mingw-w64 toolchain. There is no native Windows build procedure; the `Makefile` is not intended to be run under MSYS2 or Cygwin.

Everything specific to Windows lives in the `windows` directory and is described in `windows/README.md`. The program source itself contains three lines of Windows-specific code.

### Cross-compilation requirements

In addition to GNU Make, cross-compiling requires a mingw-w64 cross compiler targeting `x86_64-w64-mingw32`, together with `wget`, `unzip` and `zip`. Building the installer additionally requires NSIS.

```text
sudo apt install gcc-mingw-w64 wget unzip zip nsis                 # Debian/Ubuntu
sudo dnf install mingw64-gcc wget unzip zip mingw32-nsis           # Fedora
sudo zypper install mingw64-cross-gcc wget unzip zip               # openSUSE
```

The GTK3 headers and DLLs for Windows are downloaded automatically and do not need to be installed on the build machine.

Verify the cross compiler before building:

```text
x86_64-w64-mingw32-gcc --version
```

A version number should be printed. If the command is not found, the mingw-w64 package is either not installed or its compiler is published under a different name by the distribution.

### Build

```text
make windows
```

The first invocation downloads a prebuilt GTK3 bundle, roughly 11 MB, into the `windows` directory. Subsequent builds reuse it.

The result is a self-contained folder, `windows/dist`, holding `tsviewer.exe`, the GTK3 runtime DLLs, the example data files and two small helper programs. `tsviewer.exe` will not start unless the DLLs are beside it, so the whole folder is what must reach the Windows machine.

### Package as a single file

Copying that folder to a Windows machine is tedious, so it can be packaged as one file instead:

```text
make windows-zip        # tsviewer-<version>-win64.zip
make windows-installer  # tsviewer-<version>-win64-setup.exe
```

Both are written to the top level of the repository. The version in the file names is read from `TSVIEWER_VERSION` in the source, so it cannot drift from the program.

The zip is about 9 MB. Extract it anywhere and run it; nothing is installed and nothing is written to the registry, so it can live on a USB stick or a network share.

The installer is about 7 MB. It requires administrator rights, installs into `C:\Program Files\tsviewer`, registers an entry in *Apps & features* for clean removal, and offers two optional components:

- **Start Menu shortcuts.** A *tsviewer Command Prompt* entry that opens a command prompt with `tsviewer` already on the `PATH`, starting in the examples directory, plus a shortcut to that directory.
- **Right-click menu.** An *Open with tsviewer* entry on `.csv`, `.dat`, `.txt` and `.tsv` files. Selecting several files and choosing it opens them together in a single window. The default program for those file types is not changed.

Neither package modifies the system `PATH`; `windows/README.md` explains why, and how to add it by hand.

### Releases

Publishing a GitHub release runs `.github/workflows/windows-release.yml`, which performs this build and attaches both packages to the release. The same workflow can be started by hand from the Actions tab to test a build without publishing anything.

### Console window

The Windows executable is built as a console application, so that `--help` and error messages appear in the command prompt as they do on Linux. A console window therefore accompanies the graphical window when the program is started from the desktop rather than from a command prompt.

To build a pure graphical application with no console window, at the cost of losing all `--help` and error output:

```text
make windows WIN_SUBSYSTEM=-mwindows
```

### Clean the Windows build

`make clean` removes the executables, the staging folder, and any zip or installer built from them, but keeps the downloaded GTK3 bundle. To remove the bundle as well:

```text
make distclean
```

### Known differences from the Linux build

The prebuilt bundle supplies no icon theme, so a small number of stock icons in GTK dialogs may be absent. This is cosmetic and does not affect plotting or any other function.

Timestamps earlier than 1970 are not accepted in the compact `YYYYMMDDHHMM` and `YYYYMMDDHHMMSS` formats on Windows, because the Windows C library cannot represent them. All other supported abscissa formats behave identically to the Linux build.

## Installation in your PATH

It is not necessary to install `tsviewer` system-wide. The executable can be run directly from the repository directory.

If desired, copy it to a directory in your shell's `PATH`, for example:

```text
sudo cp tsviewer /usr/local/bin/
```

Afterward it can be invoked from any directory:

```text
tsviewer data.csv
```

Alternatively, individual users can place the executable in a personal `bin` directory without requiring root privileges.

## Runtime environment

`tsviewer` is a graphical GTK3 application and therefore requires a graphical display environment.

On Linux systems it is intended for use under a normal X11 or compatible GTK desktop environment.

On Windows it runs as an ordinary desktop application, provided the GTK3 DLLs built alongside it remain in the same directory as `tsviewer.exe`.

When running on a remote machine through SSH, graphical forwarding must be configured if the display is to appear on the local workstation.

For example, depending on the SSH configuration:

```text
ssh -X remote-host
```

or:

```text
ssh -Y remote-host
```

The remote system must also have the necessary GTK3 runtime libraries installed.

## Compiler standard

`tsviewer` is written for ISO C99 and is compiled with:

```text
-std=c99
```

It intentionally uses C99 language and library features and should not be expected to compile as strict C89/ANSI C.

## Problems building

If the build fails because GTK3 cannot be found, first check:

```text
pkg-config --modversion gtk+-3.0
```

If that command fails, install the GTK3 **development** package for your Linux distribution.

Installing only the GTK3 runtime libraries is not sufficient for compiling `tsviewer`; the development headers and `pkg-config` metadata are also required.

For other build problems, please open an issue at:

https://github.com/fred-ogden/tsviewer/issues