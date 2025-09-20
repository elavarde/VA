param (
    [ValidateSet("up", "down", "logs", "status", "restart", "rebuild", "resolve")]
    [string]$Action = "up"
)

$composeFile = "docker-compose.dev.yml"
$envFile = ".env.dev"

function CheckHealth {
    Write-Host "`n[Vérification de la santé des services]" -ForegroundColor Gray

    $services = @(
        @{ name = "mysql"; port = 3306 },
        @{ name = "chroma"; url = "http://localhost:8001/api/v2/heartbeat" },
        @{ name = "api";    url = "http://localhost:8000/api/health" }
    )

    foreach ($svc in $services) {
        try {
            if ($svc.port) {
                $containerName = "va-$($svc.name)-1"
                $result = docker inspect --format="{{.State.Health.Status}}" $containerName
                Write-Host "✅ $($svc.name.ToUpper()) : $result"
            } else {
                $res = Invoke-WebRequest -Uri $svc.url -UseBasicParsing -TimeoutSec 5
                if ($res.StatusCode -eq 200) {
                    Write-Host "✅ $($svc.name.ToUpper()) : OK"
                } else {
                    Write-Host "⚠️ $($svc.name.ToUpper()) : Réponse inattendue ($($res.StatusCode))"
                }
            }
        } catch {
            Write-Host "❌ $($svc.name.ToUpper()) : inaccessible" -ForegroundColor Red
        }
    }
    Write-Host ""
}

function ComposeUp {
    Write-Host "[Démarrage de l'environnement DEV]" -ForegroundColor Cyan
    docker compose -f $composeFile --env-file $envFile up -d
    Start-Sleep -Seconds 5
    CheckHealth
}

function ComposeDown {
    Write-Host "[Arrêt de l'environnement DEV]" -ForegroundColor Yellow
    docker compose -f $composeFile --env-file $envFile down --remove-orphans
}

function ComposeLogs {
    Write-Host "[Logs en direct (API + Front)]" -ForegroundColor Green
    docker compose -f $composeFile logs -f api front
}

function ComposeStatus {
    Write-Host "[État des conteneurs DEV]" -ForegroundColor Magenta
    docker ps --filter "name=va"
}

function ComposeRestart {
    Write-Host "[Redémarrage des services DEV]" -ForegroundColor Blue
    ComposeDown
    Start-Sleep -Seconds 2
    ComposeUp
}

function ComposeRebuild {
    Write-Host "[Rebuild complet sans cache]" -ForegroundColor DarkCyan
    docker compose -f $composeFile --env-file $envFile build --no-cache
    ComposeUp
}

function PrismaResolve {
    Write-Host "[Résolution de la migration Prisma dans Docker]" -ForegroundColor DarkYellow

    $containerName = "va-api-1"
    $schemaPath = "/app/prisma/schema.prisma"

    # Vérifie que le conteneur est actif
    $status = docker inspect --format="{{.State.Status}}" $containerName 2>$null
    if ($status -ne "running") {
        Write-Host "❌ Le conteneur $containerName n'est pas actif. Lance la stack avec 'dev.ps1 up'." -ForegroundColor Red
        return
    }

    # Exécute Prisma migrate resolve dans le conteneur
    docker exec -w /app $containerName npx prisma migrate resolve --applied baseline

    Write-Host "✅ Migration 'baseline' marquée comme appliquée dans Prisma." -ForegroundColor Green
}

switch ($Action) {
    "up"       { ComposeUp }
    "down"     { ComposeDown }
    "logs"     { ComposeLogs }
    "status"   { ComposeStatus }
    "restart"  { ComposeRestart }
    "rebuild"  { ComposeRebuild }
    "resolve"  { PrismaResolve }
}
