@echo off
rem Runs the Creature Lab batch tool against ComfyUI.
rem Usage: run_creature_batch.bat [jobs file, repo-relative]  (default: art\creatures\review\baseline_jobs.json)
setlocal
set ROOT=%~dp0..\..
set JOBS=%~1
if "%JOBS%"=="" set JOBS=art/creatures/review/baseline_jobs.json
"%ROOT%\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe" --headless --path "%ROOT%\prototype" --script res://tools/creature_batch.gd -- jobs=%JOBS%
echo.
echo Batch done. Results: art\creatures\review\status.json
pause
