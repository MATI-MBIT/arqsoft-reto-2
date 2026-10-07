@echo off
rem ============================================================================
rem arqsoft-reto-2 - el Makefile para Windows: pasa los argumentos a make.ps1.
rem
rem   make help                  la lista de objetivos
rem   make smoke                 humo de ~7 min
rem   make grupo G=e01           un grupo del plan
rem   make veredicto CORRIDA=... el veredicto de una corrida
rem
rem Usa PowerShell 7 si esta instalado y, si no, el Windows PowerShell 5.1
rem que trae Windows. ExecutionPolicy Bypass vale solo para esta llamada.
rem ============================================================================
setlocal
set "PS=powershell"
where pwsh >nul 2>nul && set "PS=pwsh"
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0make.ps1" %*
exit /b %ERRORLEVEL%
