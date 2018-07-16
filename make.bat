@echo off


C:\Irvine\masm32\bin\ml.exe /nologo /c /Zi /coff %1.asm
C:\Irvine\masm32\bin\link.exe /NOLOGO /SUBSYSTEM:CONSOLE %1.obj