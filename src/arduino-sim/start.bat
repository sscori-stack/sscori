@echo off
cd /d "%~dp0"
echo ============================================
echo   Arduino LED Simulator
echo   http://localhost:8000 에서 실행됩니다.
echo   종료하려면 이 창을 닫으세요.
echo ============================================
echo.
start http://localhost:8000
python -m http.server 8000
