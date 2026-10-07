@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem Diagnostic helper for the render pipeline.
rem
rem The website shows a generic "3D Render not available" message, which hides
rem the real error from the arbiter/RCCService. This script calls the arbiter's
rem /render endpoint directly and prints what it actually returns, so you can
rem tell which layer is broken: arbiter reachability, 2D body shot, or 3D render.
rem
rem The arbiter must already be running (start it with vedora.bat).
rem
rem Usage:
rem   diagnose-render.bat            (renders user 1)
rem   diagnose-render.bat 42         (renders user 42)

set "ARBITER=http://127.0.0.1:3521"
set "AUTH=VedoraInternal-dev-secret"
set "USERID=%~1"
if "%USERID%"=="" set "USERID=1"

echo ==========================================================
echo  Vedora render diagnostic
echo  Arbiter: %ARBITER%
echo  User:    %USERID%
echo ==========================================================
echo.

echo [1/3] Checking the arbiter is reachable...
powershell -NoProfile -Command ^
    "try { Invoke-WebRequest -UseBasicParsing -Uri '%ARBITER%/render/statistics' -Headers @{ 'rblx-authorization' = '%AUTH%' } -TimeoutSec 5 | Select-Object -ExpandProperty Content } catch { Write-Host ('  [FAIL] ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 (
    echo       The arbiter is not answering on %ARBITER%.
    echo       Start it with vedora.bat and check the "Vedora RCC Arbiter" window.
    goto :done
)
echo.

echo [2/3] Rendering a 2D body shot (uses the same RCC worker as 3D)...
call :render "AvatarHeadshot" "{\"Kind\":\"AvatarHeadshot\",\"UserId\":%USERID%,\"Width\":300,\"Height\":300,\"Priority\":\"Background\",\"WorkKey\":\"diag:headshot\"}"
echo.

echo [3/3] Rendering the 3D avatar...
call :render "Avatar3D" "{\"Kind\":\"Avatar3D\",\"UserId\":%USERID%,\"Width\":352,\"Height\":352,\"Priority\":\"Background\",\"WorkKey\":\"diag:3d\"}"
echo.

echo Notes:
echo  - If step 2 fails too, the problem is not specific to 3D: RCC itself is
echo    failing to render. Read the arbiter window for the RCC output.
echo  - If step 2 works and step 3 fails, the 3D OBJ operation is the problem.
echo  - Avatar3D returns JSON model data (OBJ/MTL/texture URLs), not a picture,
echo    so diag-render-Avatar3D.json is what you inspect. Open its obj/mtl/
echo    textures URLs to confirm the render produced a model.
goto :done

rem ---------------------------------------------------------------
rem :render <label> <jsonBody>
rem  POSTs to /render, saves the raw response to diag-render-<label>.txt,
rem  then decodes the base64 Data field into diag-render-<label>.<png|jpg|json|bin>
rem  and prints the HTTP status plus the arbiter error message (if any).
rem ---------------------------------------------------------------
:render
echo   POST /render  ^(%~1^)
powershell -NoProfile -Command ^
    "$body = '%~2';" ^
    "try {" ^
    "  $r = Invoke-WebRequest -UseBasicParsing -Method Post -Uri '%ARBITER%/render' -Headers @{ 'rblx-authorization' = '%AUTH%' } -ContentType 'application/json' -Body $body -TimeoutSec 120;" ^
    "  Set-Content -Path 'diag-render-%~1.txt' -Value $r.Content;" ^
    "  Write-Host ('  [OK] HTTP ' + $r.StatusCode + ' - raw response saved to diag-render-%~1.txt');" ^
    "  $d = $r.Content | ConvertFrom-Json;" ^
    "  if ($d.Data) {" ^
    "    $ct = [string]$d.ContentType;" ^
    "    $ext = 'bin';" ^
    "    if ($ct -match 'png') { $ext = 'png' } elseif ($ct -match 'jpe?g') { $ext = 'jpg' } elseif ($ct -match 'json') { $ext = 'json' };" ^
    "    $out = Join-Path (Get-Location).Path ('diag-render-%~1.' + $ext);" ^
    "    [IO.File]::WriteAllBytes($out, [Convert]::FromBase64String([string]$d.Data));" ^
    "    Write-Host ('  ContentType: ' + $ct + ' - base64 length: ' + $d.Data.Length);" ^
    "    Write-Host ('  Data saved to ' + $out);" ^
    "  } else { Write-Host '  [WARN] Response has no Data field.' }" ^
    "} catch {" ^
    "  $resp = $_.Exception.Response;" ^
    "  if ($resp) {" ^
    "    $status = [int]$resp.StatusCode;" ^
    "    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream());" ^
    "    $text = $reader.ReadToEnd();" ^
    "    Set-Content -Path 'diag-render-%~1.txt' -Value $text;" ^
    "    Write-Host ('  [FAIL] HTTP ' + $status + ' - response saved to diag-render-%~1.txt');" ^
    "    Write-Host ('  ' + $text);" ^
    "  } else { Write-Host ('  [FAIL] ' + $_.Exception.Message) }" ^
    "}"
goto :eof

:done
echo.
echo Done. Attach the diag-render-*.txt files when reporting a render problem.
endlocal
