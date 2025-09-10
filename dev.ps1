# Lancement DEV (hot reload) -> http://localhost:8080
docker compose -f docker-compose.dev.yml up -d --build
Start-Process http://localhost:8080