@echo off

cd /d "%~dp0"

set ANALYZE=%LOCALAPPDATA%\mise\shims\luau-analyze.exe

if not exist "%ANALYZE%" set ANALYZE=luau-analyze

"%ANALYZE%" vault.luau git\init.luau git\locales.luau git\i18n.luau git\projects.luau git\parse.luau git\header.luau git\footer.luau git\commits.luau git\branches.luau git\sync.luau git\decorations.luau git\settings.luau session\init.luau community-themes\init.luau telescope\init.luau telescope\fs.luau telescope\projects.luau telescope-files\init.luau harpoon\init.luau mise\init.luau telescope-grep\init.luau telescope-todos\init.luau plugins.registry.luau

exit /b %ERRORLEVEL%

