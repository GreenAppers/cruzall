Name "Cruzall"
OutFile "Cruzall-installer.exe"
InstallDir $PROGRAMFILES\GreenAppers\Cruzall

Page directory
Page instfiles
Section "";

RmDir /r "$INSTDIR"
SetOutPath "$INSTDIR"
File /nonfatal /a /r "build\windows\x64\Release\Runner\"

SetOutPath "$INSTDIR"
CreateDirectory "$SMPROGRAMS\GreenAppers"
createShortCut "$SMPROGRAMS\GreenAppers\Cruzall.lnk" "$INSTDIR\Cruzall.exe"

SectionEnd
