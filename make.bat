@echo off


C:\masm32\bin\ml.exe /nologo /c /Zi /coff %1.asm
C:\masm32\bin\link.exe /NOLOGO /SUBSYSTEM:CONSOLE %1.obj
