Unicode True
!include "MUI2.nsh"
!include "x64.nsh"

!ifndef SOURCE_DIR
  !error "Use Tools/package.py to supply SOURCE_DIR"
!endif
!ifndef OUTPUT_FILE
  !error "OUTPUT_FILE is required"
!endif
!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "0.2.0-dev"
!endif

Name "Tribes of Fire"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\TribesOfFire"
InstallDirRegKey HKCU "Software\felipealx\TribesOfFire" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
VIProductVersion "0.2.0.0"
VIAddVersionKey "ProductName" "Tribes of Fire"
VIAddVersionKey "CompanyName" "felipealx"
VIAddVersionKey "FileDescription" "Tribes of Fire per-user installer"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "LegalCopyright" "felipealx"

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "PortugueseBR"
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "Tribes of Fire requires Windows x64."
    Abort
  ${EndIf}
  SetShellVarContext current
FunctionEnd

Section "Tribes of Fire" SecGame
  SetOutPath "$INSTDIR"
  File "${SOURCE_DIR}/TribesOfFire.exe"
  File "${SOURCE_DIR}/README.md"
  File "${SOURCE_DIR}/ARCHITECTURE.md"
  File "${SOURCE_DIR}/PROGRESS.md"
  File "${SOURCE_DIR}/CREDITS.md"
  SetOutPath "$INSTDIR\LICENSES"
  File "${SOURCE_DIR}/LICENSES/Godot-LICENSE.txt"
  File "${SOURCE_DIR}/LICENSES/Godot-COPYRIGHT.txt"
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\Tribes of Fire"
  CreateShortcut "$SMPROGRAMS\Tribes of Fire\Tribes of Fire.lnk" "$INSTDIR\TribesOfFire.exe"
  CreateShortcut "$SMPROGRAMS\Tribes of Fire\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\felipealx\TribesOfFire" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\TribesOfFire" "DisplayName" "Tribes of Fire"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\TribesOfFire" "Publisher" "felipealx"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\TribesOfFire" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\TribesOfFire" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\TribesOfFire" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\TribesOfFire" "NoRepair" 1
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  Delete "$INSTDIR\TribesOfFire.exe"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\ARCHITECTURE.md"
  Delete "$INSTDIR\PROGRESS.md"
  Delete "$INSTDIR\CREDITS.md"
  Delete "$INSTDIR\LICENSES\Godot-LICENSE.txt"
  Delete "$INSTDIR\LICENSES\Godot-COPYRIGHT.txt"
  RMDir "$INSTDIR\LICENSES"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\Tribes of Fire\Tribes of Fire.lnk"
  Delete "$SMPROGRAMS\Tribes of Fire\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Tribes of Fire"
  DeleteRegKey HKCU "Software\felipealx\TribesOfFire"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\TribesOfFire"
  ; Godot user:// save data is intentionally preserved.
SectionEnd
