; NSIS installer script for tsviewer.
;
; This is not built directly.  windows/windows.mk invokes it:
;
;     make windows-installer
;
; It packages the contents of the windows/dist directory produced by
; "make windows" into a single setup executable.

Unicode true
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

!ifndef VERSION
  !define VERSION "0.0"
!endif
!ifndef DIST
  !define DIST "dist-windows"
!endif
!ifndef OUTFILE
  !define OUTFILE "tsviewer-setup.exe"
!endif
!ifndef LICENSE
  !define LICENSE "..\LICENSE-2.0.txt"
!endif

!define APPNAME   "tsviewer"
!define PUBLISHER "Fred Ogden"
!define HOMEPAGE  "https://github.com/fred-ogden/tsviewer"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"

Name "${APPNAME} ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\${APPNAME}"
InstallDirRegKey HKLM "Software\${APPNAME}" "InstallDir"
RequestExecutionLevel admin

VIProductVersion "${VERSION}.0.0"
VIAddVersionKey "ProductName"     "${APPNAME}"
VIAddVersionKey "ProductVersion"  "${VERSION}"
VIAddVersionKey "FileVersion"     "${VERSION}"
VIAddVersionKey "FileDescription" "Interactive Scientific Time-Series Viewer"
VIAddVersionKey "CompanyName"     "${PUBLISHER}"
VIAddVersionKey "LegalCopyright"  "Licensed under the Apache License 2.0"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_LINK "tsviewer on GitHub"
!define MUI_FINISHPAGE_LINK_LOCATION "${HOMEPAGE}"

!insertmacro MUI_PAGE_LICENSE "${LICENSE}"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; tsviewer is started with the name of a data file, so it is registered as an
; extra right-click entry on data files rather than as a default handler for
; them.  The system PATH is deliberately left untouched: NSIS truncates strings
; at 1024 characters, which would corrupt a long PATH.  The Start Menu command
; prompt below sets PATH for its own session instead.

; InstallDirRegKey above is evaluated before any SetRegView, so on 64-bit
; Windows it would look in the 32-bit Wow6432Node view and miss an existing
; install.  Read the real location here so that upgrades default to it.
Function .onInit
    SetRegView 64
    ReadRegStr $0 HKLM "Software\${APPNAME}" "InstallDir"
    ${If} $0 != ""
        StrCpy $INSTDIR $0
    ${EndIf}
FunctionEnd

Function un.onInit
    SetRegView 64
FunctionEnd

Section "tsviewer (required)" SEC_CORE
    SectionIn RO
    SetRegView 64
    SetOutPath "$INSTDIR"
    File /r "${DIST}\*"

    WriteRegStr HKLM "Software\${APPNAME}" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\${APPNAME}" "Version" "${VERSION}"

    WriteUninstaller "$INSTDIR\uninstall.exe"
    WriteRegStr   HKLM "${UNINSTKEY}" "DisplayName"     "${APPNAME} ${VERSION}"
    WriteRegStr   HKLM "${UNINSTKEY}" "DisplayVersion"  "${VERSION}"
    WriteRegStr   HKLM "${UNINSTKEY}" "Publisher"       "${PUBLISHER}"
    WriteRegStr   HKLM "${UNINSTKEY}" "URLInfoAbout"    "${HOMEPAGE}"
    WriteRegStr   HKLM "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr   HKLM "${UNINSTKEY}" "DisplayIcon"     "$INSTDIR\tsviewer.exe"
    WriteRegStr   HKLM "${UNINSTKEY}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr   HKLM "${UNINSTKEY}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
    WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
    WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1

    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "${UNINSTKEY}" "EstimatedSize" "$0"
SectionEnd

Section "Start Menu shortcuts" SEC_SHORTCUTS
    CreateDirectory "$SMPROGRAMS\${APPNAME}"
    CreateShortcut "$SMPROGRAMS\${APPNAME}\tsviewer Command Prompt.lnk" \
                   "$INSTDIR\tsviewer-prompt.cmd" "" "$INSTDIR\tsviewer.exe" 0
    CreateShortcut "$SMPROGRAMS\${APPNAME}\Example data.lnk" "$INSTDIR\examples"
    CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall tsviewer.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

Section "Open data files with tsviewer (right-click menu)" SEC_SHELL
    SetRegView 64
    ; The verb runs tsviewer-open.exe rather than tsviewer.exe.  Explorer starts
    ; a command-line verb once per selected file, so tsviewer.exe alone would
    ; open one window per file; the helper gathers the selection into one.
    ; MultiSelectModel=Player is still needed, or the verb disappears entirely
    ; once more than 15 files are selected.
    !macro RegisterVerb ext
        WriteRegStr HKLM "Software\Classes\SystemFileAssociations\${ext}\shell\${APPNAME}" \
                    "MUIVerb" "Open with tsviewer"
        WriteRegStr HKLM "Software\Classes\SystemFileAssociations\${ext}\shell\${APPNAME}" \
                    "MultiSelectModel" "Player"
        WriteRegStr HKLM "Software\Classes\SystemFileAssociations\${ext}\shell\${APPNAME}" \
                    "Icon" "$INSTDIR\tsviewer.exe,0"
        WriteRegStr HKLM "Software\Classes\SystemFileAssociations\${ext}\shell\${APPNAME}\command" \
                    "" "$\"$INSTDIR\tsviewer-open.exe$\" $\"%1$\""
    !macroend
    !insertmacro RegisterVerb ".csv"
    !insertmacro RegisterVerb ".dat"
    !insertmacro RegisterVerb ".txt"
    !insertmacro RegisterVerb ".tsv"
SectionEnd

LangString DESC_CORE      ${LANG_ENGLISH} "tsviewer.exe, the GTK3 runtime libraries it needs, and the example data files."
LangString DESC_SHORTCUTS ${LANG_ENGLISH} "A Start Menu command prompt with tsviewer already on the PATH, plus a shortcut to the example data."
LangString DESC_SHELL     ${LANG_ENGLISH} "Adds an 'Open with tsviewer' entry to the right-click menu of .csv, .dat, .txt and .tsv files. Selecting several files at once opens them together in one window. The default program for those files is not changed."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CORE}      $(DESC_CORE)
    !insertmacro MUI_DESCRIPTION_TEXT ${SEC_SHORTCUTS} $(DESC_SHORTCUTS)
    !insertmacro MUI_DESCRIPTION_TEXT ${SEC_SHELL}     $(DESC_SHELL)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
    SetRegView 64

    DeleteRegKey HKLM "Software\Classes\SystemFileAssociations\.csv\shell\${APPNAME}"
    DeleteRegKey HKLM "Software\Classes\SystemFileAssociations\.dat\shell\${APPNAME}"
    DeleteRegKey HKLM "Software\Classes\SystemFileAssociations\.txt\shell\${APPNAME}"
    DeleteRegKey HKLM "Software\Classes\SystemFileAssociations\.tsv\shell\${APPNAME}"
    DeleteRegKey HKLM "${UNINSTKEY}"
    DeleteRegKey HKLM "Software\${APPNAME}"

    Delete "$SMPROGRAMS\${APPNAME}\tsviewer Command Prompt.lnk"
    Delete "$SMPROGRAMS\${APPNAME}\Example data.lnk"
    Delete "$SMPROGRAMS\${APPNAME}\Uninstall tsviewer.lnk"
    RMDir  "$SMPROGRAMS\${APPNAME}"

    ; Only ever remove a directory that actually holds this program
    ${If} ${FileExists} "$INSTDIR\tsviewer.exe"
        Delete "$INSTDIR\uninstall.exe"
        RMDir /r "$INSTDIR"
    ${EndIf}
SectionEnd
