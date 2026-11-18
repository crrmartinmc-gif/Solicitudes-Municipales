# ICONO OFICIAL SOLICITUDES DE TRASLADO — AMBIENTE LOMAS
# Cambia solamente el favicon de la aplicación web Google Apps Script.
# Conserva la URL publica confirmada, los usuarios, los viajes y la agenda.
# No cambia Index.html, planillas, contraseñas ni otras funciones.
$ErrorActionPreference='Stop'
$scriptId='1BcZCsDSmp-wU4gHPfeA24u7VqzyUxXEnI_9IEzDwew1pqRMXm8b5wV9a'
$deploymentId='AKfycbwyh-a1jGYe0ZpRu9IjImgMwVUoygIeZz0B-C5Cf3MWSS1vyiYCk3r9TgsEvQ_RlQ_y'
$icon='https://raw.githubusercontent.com/crrmartinmc-gif/Solicitudes-Municipales/main/assets/icono-solicitudes-192.png'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$dir=Join-Path $env:USERPROFILE ('Documents\Solicitudes-Icono-'+$stamp)
$backup=Join-Path $env:USERPROFILE ('Documents\RESPALDO-SOLICITUDES-ICONO-'+$stamp)
Write-Host 'AMBIENTE LOMAS | Icono aprobado de Solicitudes de Traslado' -ForegroundColor Cyan
Write-Host 'Se cambiara SOLO el favicon; no se modifica ningun viaje, usuario ni clave.' -ForegroundColor Green
Write-Host 'Se publicara sobre la MISMA URL /exec confirmada por vos.' -ForegroundColor Yellow
if(-not (Get-Command clasp -ErrorAction SilentlyContinue)){throw 'No encuentro clasp; cancelado sin cambios.'}
New-Item -ItemType Directory -Path $dir,$backup -Force|Out-Null
Push-Location $dir
try {
  & clasp clone $scriptId
  if($LASTEXITCODE -ne 0){throw 'No se pudo descargar el proyecto. Sin cambios.'}
  $conf=Get-Content '.clasp.json' -Raw | ConvertFrom-Json
  if([string]$conf.scriptId -ne $scriptId){throw 'Script ID incorrecto. Cancelado.'}
  Get-ChildItem -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $backup -Recurse -Force
  }
  Write-Host ('Respaldo completo creado: '+$backup) -ForegroundColor Green
  $main=Join-Path $dir 'Codigo.js'
  if(-not(Test-Path $main)){$main=Join-Path $dir 'Código.js'}
  if(-not(Test-Path $main)){throw 'No se encontro Codigo.js. Sin cambios.'}
  $source=[IO.File]::ReadAllText($main)
  # Apps Script ignora etiquetas favicon colocadas en Index.html. Debe
  # configurarse con HtmlOutput.setFaviconUrl() en doGet.
  $expected="function doGet(){return HtmlService.createHtmlOutputFromFile('Index').setTitle('Solicitudes de Traslados Municipales').addMetaTag('viewport','width=device-width, initial-scale=1');}"
  if($source.Contains(".setFaviconUrl('"+$icon+"')")){
    Write-Host 'El codigo ya contiene el icono aprobado. Comprobaremos el despliegue.' -ForegroundColor Green
    $changed=$false
  }else{
    if($source.Split([string[]]@($expected),[StringSplitOptions]::None).Count -ne 2){
      throw 'La funcion doGet actual no tiene el formato esperado. No se modifico nada.'
    }
    $updated="function doGet(){return HtmlService.createHtmlOutputFromFile('Index').setTitle('Solicitudes de Traslados Municipales').addMetaTag('viewport','width=device-width, initial-scale=1').setFaviconUrl('"+$icon+"');}"
    $newSource=$source.Replace($expected,$updated)
    if($newSource.Replace($updated,$expected) -cne $source){
      throw 'La verificacion del cambio falló. No se subió codigo.'
    }
    $utf8=New-Object System.Text.UTF8Encoding -ArgumentList $false
    [IO.File]::WriteAllText($main,$newSource,$utf8)
    $changed=$true
    Write-Host 'Se agrego HtmlOutput.setFaviconUrl sin modificar ninguna otra funcion.' -ForegroundColor Green
  }
  $deployments=& clasp deployments
  if($LASTEXITCODE -ne 0 -or -not (($deployments|Out-String).Contains($deploymentId))){
    throw 'La URL de implementacion confirmada no pertenece a este proyecto. Cancelado SIN publicar otra URL.'
  }
  if($changed){
    & clasp push
    if($LASTEXITCODE -ne 0){throw 'Falló la actualización del código; conservá el respaldo.'}
    Write-Host 'Codigo actualizado. Publicando sobre la misma URL...' -ForegroundColor Green
  }
  & clasp deploy -i $deploymentId -d 'Icono aprobado Solicitudes de Traslado Ambiente Lomas'
  if($LASTEXITCODE -ne 0){throw 'La publicación falló. Revisá el respaldo y la implementación.'}
  Write-Host 'ICONO PUBLICADO. La URL de la aplicación NO cambió.' -ForegroundColor Green
  Write-Host ('https://script.google.com/macros/s/'+$deploymentId+'/exec') -ForegroundColor Cyan
  Write-Host 'Cerrá la pestaña, volvé a abrir el enlace y comprobá el icono.' -ForegroundColor Cyan
  Write-Host ('Respaldo: '+$backup) -ForegroundColor Green
}finally{Pop-Location}
