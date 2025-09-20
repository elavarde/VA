# Build front et lancement PROD -> http://localhost:8080
Push-Location .\outil_veille_app
npm install
npm run build
Pop-Location

# Publie le build statique
if (Test-Path .\_deploy\app-dist) { Remove-Item .\_deploy\app-dist\* -Recurse -Force } else { New-Item .\_deploy\app-dist -ItemType Directory | Out-Null }
Copy-Item .\outil_veille_app\dist\* .\_deploy\app-dist -Recurse -Force

docker compose -f docker-compose.prod.yml up -d --build
Start-Process http://localhost:8080
