@echo off
cd /d "%~dp0"
set ANALYZE=%LOCALAPPDATA%\mise\shims\luau-analyze.exe
if not exist "%ANALYZE%" set ANALYZE=luau-analyze
"%ANALYZE%" vault.luau git\init.luau git\locales.luau git\i18n.luau git\projects.luau git\parse.luau git\header.luau git\footer.luau git\commits.luau git\branches.luau git\sync.luau git\decorations.luau git\settings.luau auto-session-manager\init.luau catppuccin-theme\init.luau fzf-project-files\init.luau harpoon\init.luau mise\init.luau search-all-projects\init.luau todo-telescope\init.luau plugins.registry.luau
exit /b %ERRORLEVEL%
