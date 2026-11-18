# SOLICITUDES MUNICIPALES: agranda solamente el logo Ambiente Lomas.
# Conserva Codigo.js, funciones JS, campos, usuarios y contrasenas.
# Actualiza la implementacion /exec REAL (sin generar otra URL).
$ErrorActionPreference='Stop'
$scriptId='1BcZCsDSmp-wU4gHPfeA24u7VqzyUxXEnI_9IEzDwew1pqRMXm8b5wV9a'
$deployment='AKfycbwyh-a1jGYe0ZpRu9IjImgMwVUoygIeZz0B-C5Cf3MWSS1vyiYCk3r9TgsEvQ_RlQ_y'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$dir=Join-Path $env:USERPROFILE ('Documents\Solicitudes-Logo-'+$stamp)
$backup=Join-Path $env:USERPROFILE ('Documents\RESPALDO-SOLICITUDES-LOGO-'+$stamp)
Write-Host 'AMBIENTE LOMAS | Logo mas grande en Solicitudes de Traslado' -ForegroundColor Cyan
Write-Host 'Solo se toca el estilo del logo en Index.html.' -ForegroundColor Green
Write-Host 'No se tocan credenciales, solicitudes, planillas ni Codigo.js.' -ForegroundColor Yellow
if(-not(Get-Command clasp -ErrorAction SilentlyContinue)){throw 'No encuentro clasp en CMD. Cancelado.'}
New-Item -ItemType Directory -Path $dir,$backup -Force | Out-Null
Push-Location $dir
try {
  & clasp clone $scriptId
  if($LASTEXITCODE -ne 0){throw 'No se pudo clonar Apps Script. Cancelado.'}
  $conf=Get-Content '.clasp.json' -Raw | ConvertFrom-Json
  if([string]$conf.scriptId -ne $scriptId){throw 'Script ID diferente al esperado. Cancelado.'}
  Get-ChildItem -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $backup -Force -Recurse
  }
  Write-Host ('Respaldo completo: '+$backup) -ForegroundColor Green
  $index=Join-Path $dir 'Index.html'
  if(-not(Test-Path $index)){throw 'No se encontro Index.html. No se modifico nada.'}
  $old=[IO.File]::ReadAllText($index)
  $anchor='/* AL_THEME_V1_END */'
  $marker='/* AL_LOGO_BIG_V1 */'
  if($old.Contains($marker)){throw 'El logo ya tiene este ajuste. No se duplicara.'}
  if($old.Split([string[]]@($anchor),[StringSplitOptions]::None).Count -ne 2){
    throw 'No se encontro el tema Ambiente Lomas esperado. Cancelado para no tocar otras partes.'
  }
  $override=@'
/* AL_LOGO_BIG_V1 */
/* El archivo PNG tiene espacio interno: se amplifica sin desplazar los formularios. */
header .amb-brand-logo{
  transform:scale(2);
  transform-origin:left center;
  pointer-events:none;
}
@media(max-width:700px){
  header .amb-brand-logo{transform:scale(1.55)}
}
'@
  $updated=$old.Replace($anchor, $override+[Environment]::NewLine+$anchor)
  $oldJs=[regex]::Match($old,'<script>([\s\S]*?)</script>')
  $newJs=[regex]::Match($updated,'<script>([\s\S]*?)</script>')
  if(-not $oldJs.Success -or $oldJs.Value -cne $newJs.Value){
    throw 'Cambio inesperado en JavaScript. No se subio nada.'
  }
  $oldNoCss=[regex]::Replace($old,'(?s)<style>.*?</style>','')
  $newNoCss=[regex]::Replace($updated,'(?s)<style>.*?</style>','')
  if($oldNoCss -cne $newNoCss){throw 'Se detecto contenido modificado fuera de CSS. Cancelado.'}
  $utf8=New-Object System.Text.UTF8Encoding -ArgumentList $false
  [IO.File]::WriteAllText($index,$updated,$utf8)
  Write-Host 'Cambio preparado: logo ampliado, codigo funcional intacto.' -ForegroundColor Green
  Write-Host ('Respaldo del Index anterior: '+$backup)
  & clasp status
  Write-Host 'La modificación solo afecta CSS. Subiendo sin pedir pasos adicionales...' -ForegroundColor Green
  & clasp push
  if($LASTEXITCODE -ne 0){throw 'Fallo la subida a Apps Script; conservamos el respaldo.'}
  Write-Host 'Index.html actualizado en Apps Script. Verificando implementacion...' -ForegroundColor Green
  $list=& clasp deployments
  if($LASTEXITCODE -ne 0){throw 'No se pudieron revisar implementaciones; codigo subido, sin publicar.'}
  if(-not (($list|Out-String).Contains($deployment))){
    throw 'La implementacion /exec correcta no figura en el proyecto. NO se publico otra URL.'
  }
  Write-Host ('URL sin cambios: https://script.google.com/macros/s/'+$deployment+'/exec') -ForegroundColor Cyan
  Write-Host 'Actualizando automáticamente la misma URL /exec...' -ForegroundColor Cyan
  & clasp deploy -i $deployment -d 'Logo Ambiente Lomas ampliado en Solicitudes Municipales'
  if($LASTEXITCODE -ne 0){throw 'La publicacion fallo; conservamos el respaldo y codigo actualizado.'}
  Write-Host 'LOGO ACTUALIZADO en la misma app. Recarga el navegador.' -ForegroundColor Green
  Write-Host ('Respaldo: '+$backup)
}finally{Pop-Location}
