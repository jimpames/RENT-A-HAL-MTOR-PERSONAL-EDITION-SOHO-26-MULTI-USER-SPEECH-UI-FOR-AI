@echo off
REM ==========================================================================
REM  RENT-A-HAL Personal Edition — Live API Demo for Win 11
REM  Hits the production instance at https://rentahal.com
REM  All endpoints are verified from app.py source code
REM
REM  Requirements: Windows 11 with curl (built-in since Win10 1803)
REM  Run from cmd.exe — just double-click or:    rentahal_demo.bat
REM
REM  No API keys needed. No login. No auth. Just curl. ¯\_(ツ)_/¯
REM ==========================================================================

setlocal enabledelayedexpansion
title RENT-A-HAL Personal Edition - Live API Demo
color 0A

set HOST=https://rentahal.com

echo.
echo  ===============================================================
echo   RENT-A-HAL Personal Edition - LIVE API DEMO
echo   Hitting: %HOST%
echo   Backend: Llama 3 8B Instruct on RTX 4060
echo   TTS:     Kokoro GPU microservice
echo   Hosted:  Jim Ames @ N2NHU Lab, Newburgh NY USA
echo  ===============================================================
echo.
pause


REM ==========================================================================
REM  DEMO 1: Is it alive?
REM  GET /api/setup_status -> shows which LLM and TTS providers are ready
REM  This is the simplest possible "are you up?" check.
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 1: Is the realm alive? (GET /api/setup_status)
echo  ---------------------------------------------------------------
echo.

curl -sS %HOST%/api/setup_status

echo.
echo.
pause


REM ==========================================================================
REM  DEMO 2: What's the configuration?
REM  GET /api/config -> frontend config (which voices, which feeds, etc.)
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 2: What's the realm configured to do? (GET /api/config)
echo  ---------------------------------------------------------------
echo.

curl -sS %HOST%/api/config

echo.
echo.
pause


REM ==========================================================================
REM  DEMO 3: Little Johnny's First AI App  *** THE BIG ONE ***
REM  POST /api/ask with a JSON body -> Llama 3 8B answers
REM  No API key. No SDK. No SaaS. Just one HTTP request.
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 3: Ask Llama 3 8B Instruct (POST /api/ask)
echo   *** This is Little Johnny's first AI app ***
echo  ---------------------------------------------------------------
echo.
echo   Asking: "Tell me one fun fact about Saturn in one sentence."
echo.

curl -sS -X POST %HOST%/api/ask ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"Tell me one fun fact about Saturn in one sentence.\"}"

echo.
echo.
pause


REM ==========================================================================
REM  DEMO 4: Weather (no LLM tokens spent)
REM  POST /api/ask with a weather phrase -> intent classifier routes to
REM  the weather realm. Free, fast, structured.
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 4: Weather realm (POST /api/ask - routes to weather)
echo   Zero LLM tokens. Pure structured data.
echo  ---------------------------------------------------------------
echo.
echo   Asking: "weather in Tokyo"
echo.

curl -sS -X POST %HOST%/api/ask ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"weather in Tokyo\"}"

echo.
echo.
pause


REM ==========================================================================
REM  DEMO 5: Today's News
REM  GET /api/news -> headlines as JSON, ready to render anywhere
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 5: Today's news headlines (GET /api/news?limit=5)
echo  ---------------------------------------------------------------
echo.

curl -sS "%HOST%/api/news?limit=5"

echo.
echo.
pause


REM ==========================================================================
REM  DEMO 6: News feeds configured on the realm
REM  GET /api/news/feeds -> list of RSS feeds the realm pulls from
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 6: Configured news feeds (GET /api/news/feeds)
echo  ---------------------------------------------------------------
echo.

curl -sS %HOST%/api/news/feeds

echo.
echo.
pause


REM ==========================================================================
REM  DEMO 7: The Show-Off Demo - One-liner haiku from Llama 3
REM  Demonstrates that you can pipe rentahal.com into any shell script
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 7: The Show-Off - Llama 3 writes a haiku about coding
echo  ---------------------------------------------------------------
echo.
echo   Asking Llama 3 8B for a haiku about Python...
echo.

curl -sS -X POST %HOST%/api/ask ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"Write a haiku about Python programming. Just the haiku, no preamble.\"}"

echo.
echo.
pause


REM ==========================================================================
REM  DEMO 8: Math without a calculator (LLM as universal tool)
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 8: Math via LLM (POST /api/ask)
echo  ---------------------------------------------------------------
echo.
echo   Asking: "If a train leaves Newburgh NY at 60 mph and another"
echo            "leaves Tokyo at 80 mph, in how many hours does the"
echo            "8th grader give up trying to figure it out?"
echo.

curl -sS -X POST %HOST%/api/ask ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"If a train leaves Newburgh NY at 60 mph and another leaves Tokyo at 80 mph, in how many hours does the 8th grader give up trying to figure it out? Answer humorously in one sentence.\"}"

echo.
echo.
pause


REM ==========================================================================
REM  DEMO 9: Save Llama's response to a file
REM  Shows that the JSON output is pipeable / scriptable
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 9: Save Llama's answer to llama_answer.json
REM ===========================================================================
echo  ---------------------------------------------------------------
echo.
echo   Asking and saving to file...

curl -sS -X POST %HOST%/api/ask ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"In exactly 3 bullet points, why is open-source AI important?\"}" ^
  -o llama_answer.json

echo.
echo   Saved to: llama_answer.json
echo   Contents:
echo.
type llama_answer.json
echo.
echo.
pause


REM ==========================================================================
REM  DEMO 10: Response timing - measure latency
REM  Use curl's -w flag to print timing stats
REM ==========================================================================
echo.
echo  ---------------------------------------------------------------
echo   DEMO 10: Network + LLM latency from your Win11 box
echo  ---------------------------------------------------------------
echo.
echo   Round trip: your PC -^> Cloudflare -^> ngrok -^> Win11 in
echo               Newburgh -^> Llama 3 -^> back to you
echo.

curl -sS -X POST %HOST%/api/ask ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"Say the single word HELLO in all caps.\"}" ^
  -w "\n\n   DNS lookup:     %%{time_namelookup} seconds\n   TCP connect:    %%{time_connect} seconds\n   TLS handshake:  %%{time_appconnect} seconds\n   First byte:     %%{time_starttransfer} seconds\n   TOTAL TIME:     %%{time_total} seconds\n"

echo.
echo.
pause


REM ==========================================================================
REM  DONE
REM ==========================================================================
echo.
echo  ===============================================================
echo   That was 10 LIVE API calls against a Llama 3 8B instance
echo   hosted on a single RTX 4060 in Jim Ames's lab in Newburgh NY.
echo.
echo   No API keys.  No SDKs.  No SaaS.  No cloud middlemen.
echo.
echo   Just curl + JSON + a household GPU + open-source AI.
echo.
echo   Little Johnny can build his first AI app in 5 lines of HTML:
echo.
echo     ^<button onclick=^"ask()^"^>Tell me a joke^</button^>
echo     ^<div id=^"out^"^>^</div^>
echo     ^<script^>
echo     async function ask() {
echo       const r = await fetch(^"https://rentahal.com/api/ask^", {
echo         method: ^"POST^",
echo         headers: { ^"Content-Type^": ^"application/json^" },
echo         body: JSON.stringify({ text: ^"tell me a joke^" })
echo       });
echo       out.textContent = (await r.json()).answer;
echo     }
echo     ^</script^>
echo.
echo   That's it. Welcome to local-first AI.
echo  ===============================================================
echo.
echo   Read the manual:  RENT-A-HAL-Personal-Edition-Manual.md
echo   Repo snapshot:    RENTAHAL_FULL_snapshot_2026-06-17.zip
echo   Live system:      https://rentahal.com
echo.
echo  Live long and prosper.
echo.
pause
endlocal
