@echo off
cd /d "%~dp0"
set ANALYZE=%LOCALAPPDATA%\mise\shims\luau-analyze.exe
if not exist "%ANALYZE%" set ANALYZE=luau-analyze
"%ANALYZE%" vault.luau git-shared\header.luau auto-session-manager\init.luau catppuccin-theme\init.luau fzf-project-files\init.luau git-enrichment\init.luau git-integration\init.luau harpoon\init.luau mise\init.luau search-all-projects\init.luau todo-telescope\init.luau plugins.registry.luau
exit /b %ERRORLEVEL%
