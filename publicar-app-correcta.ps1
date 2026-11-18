# SOLICITUDES MUNICIPALES — Re-publicar el código ACTUAL sobre el /exec REAL.
# No cambia contraseña, planilla, código ni URL; solo versión del despliegue.
$ErrorActionPreference = 'Stop'
$scriptId = '1BcZCsDSmp-wU4gHPfeA24u7VqzyUxXEnI_9IEzDwew1pqRMXm8b5wV9a'
$deploymentId = 'AKfycbwyh-a1jGYe0ZpRu9IjImgMwVUoygIeZz0B-C5Cf3MWSS1vyiYCk3r9TgsEvQ_RlQ_y'
$appUrl = 'https://script.google.com/macros/s/' + $deploymentId + '/exec'
$dir = Join-Path $env:USERPROFILE ('Documents\Publicar-Solicitudes-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
Write-Host 'SOLICITUDES MUNICIPALES - ACTUALIZAR IMPLEMENTACION EXISTENTE' -ForegroundColor Green
Write-Host ('URL que SE CONSERVA: '+$appUrl) -ForegroundColor Cyan
Write-Host 'No modifica claves, planillas, archivos ni usuarios.' -ForegroundColor Yellow
if (-not (Get-Command clasp -ErrorAction SilentlyContinue)) { throw 'No encuentro clasp. Instalalo con npm install -g @google/clasp.' }
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Push-Location $dir
try {
  Write-Host 'Verificando el proyecto de Apps Script...' -ForegroundColor Cyan
  & clasp clone $scriptId
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo clonar el proyecto. No se publico nada.' }
  if (-not (Test-Path '.clasp.json')) { throw 'No se genero .clasp.json. Cancelado.' }
  $clasp = Get-Content '.clasp.json' -Raw | ConvertFrom-Json
  if ([string]$clasp.scriptId -ne $scriptId) { throw 'El Script ID clonado no coincide. Cancelado.' }
  $backend = Join-Path $dir 'Codigo.js'
  if (-not (Test-Path $backend)) { $backend = Join-Path $dir 'Código.js' }
  if (-not (Test-Path $backend)) { throw 'No se encuentra Codigo.js. Cancelado.' }
  $s = [IO.File]::ReadAllText($backend)
  if (-not $s.Contains("USUARIOS: ['ID_USUARIO','USUARIO','CONTRASEÑA','NOMBRE'")) {
    throw 'El backend no reconoce la nueva columna CONTRASEÑA. NO publicar esta versión.'
  }
  if (-not $s.Contains('function iniciarSesionSolicitudes(')) {
    throw 'No se encuentra el login de Solicitudes. NO publicar.'
  }
  if (-not (Test-Path 'Claves_Visibles_Usuarios.js')) {
    throw 'Falta el modulo de migracion. NO publicar.'
  }
  Write-Host 'Codigo actual verificado: usuarios, login y esquema de hoja.' -ForegroundColor Green
  $deployments = & clasp deployments
  if ($LASTEXITCODE -ne 0) { throw 'No se pudieron verificar los despliegues. Cancelado.' }
  $list = ($deployments | Out-String)
  Write-Host $list
  if (-not $list.Contains($deploymentId)) {
    throw 'La implementacion indicada por vos NO figura en este proyecto. No se publicara una URL distinta.'
  }
  Write-Host ('Implementacion correcta encontrada: '+$deploymentId) -ForegroundColor Green
  $ok = Read-Host 'Escribi PUBLICAR para actualizar SOLO esta URL /exec (Enter cancela)'
  if ($ok -ne 'PUBLICAR') { Write-Host 'Cancelado: sin modificaciones.'; return }
  & clasp deploy -i $deploymentId -d 'Login actualizado tras migracion de usuarios APPSECRETARIA'
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo actualizar la implementacion. No se toco el codigo ni la planilla.' }
  Write-Host 'Implementacion ACTUALIZADA y URL CONSERVADA.' -ForegroundColor Green
  Write-Host ('Abri: '+$appUrl) -ForegroundColor Green
  Write-Host 'Usa las contrasenas actuales de la columna C, sin volver a restablecerlas.' -ForegroundColor Cyan
} finally { Pop-Location }
