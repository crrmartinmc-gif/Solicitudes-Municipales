# REDISEÑO AMBIENTE LOMAS — Solicitudes Municipales.
# Solo actualiza CSS y encabezado/logo dentro del Index.html ACTUAL de Apps Script.
# Nunca reescribe Código.js, base de datos, funciones, reservas ni asignaciones.
$ErrorActionPreference='Stop'
$scriptId='1BcZCsDSmp-wU4gHPfeA24u7VqzyUxXEnI_9IEzDwew1pqRMXm8b5wV9a'
$cssUrl='https://raw.githubusercontent.com/crrmartinmc-gif/Solicitudes-Municipales/main/ambiente-lomas-theme.css'
$logo='https://raw.githubusercontent.com/crrmartinmc-gif/Solicitudes-Municipales/main/assets/logo-ambiente-lomas-horizontal.png'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$work=Join-Path $env:USERPROFILE ('Documents\Solicitudes-Estilo-'+$stamp)
$backup=Join-Path $env:USERPROFILE ('Documents\RESPALDO-SOLICITUDES-DISENO-'+$stamp)
Write-Host 'AMBIENTE LOMAS | Rediseño Solicitudes Municipales' -ForegroundColor Green
Write-Host 'Solo visual: blanco y verde, logo Ambiente Lomas y estilo App Choferes.' -ForegroundColor Cyan
Write-Host 'No se modifica el backend, las hojas ni el circuito de solicitudes.' -ForegroundColor Yellow
if(-not (Get-Command clasp -ErrorAction SilentlyContinue)){
  throw 'Falta clasp. Instalalo con npm install -g @google/clasp'
}
New-Item -ItemType Directory -Path $work,$backup -Force | Out-Null
Push-Location $work
try {
  & clasp clone $scriptId
  if($LASTEXITCODE -ne 0){throw 'No se pudo clonar Solicitudes Municipales. Ningún cambio aplicado.'}
  Get-ChildItem -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $backup -Force -Recurse
  }
  Write-Host ('Respaldo completo: '+$backup) -ForegroundColor Green
  $index=Join-Path $work 'Index.html'
  if(-not (Test-Path $index)){throw 'No se encontró Index.html. Instalación cancelada.'}
  $original=[IO.File]::ReadAllText($index)
  if($original.Contains('AL_THEME_V1_START')){
    Write-Host 'La identidad Ambiente Lomas ya fue incorporada. No se duplicarán estilos.'
    return
  }
  # Exige exactamente un bloque <style> y cierre de HEAD del archivo actual.
  $stylesEnd='</style></head>'
  if($original.Split([string[]]@($stylesEnd),[StringSplitOptions]::None).Count -ne 2){
    throw 'La estructura del Index.html cambió. No se aplicaron cambios.'
  }
  $headerPattern='<header>\s*<div>\s*<h1>Traslados Municipales</h1>\s*<div class="muted">[^<]*</div>\s*</div>'
  $matches=[regex]::Matches($original,$headerPattern)
  if($matches.Count -ne 1){throw 'No se encontró el encabezado previsto. No se modificó la aplicación.'}
  $css=(Invoke-WebRequest -UseBasicParsing -Uri $cssUrl).Content
  if($css -is [byte[]]){$css=[Text.Encoding]::UTF8.GetString($css)}
  if(-not $css.Contains('AMBIENTE LOMAS') -or -not $css.Contains('#login')){
    throw 'Estilos descargados incompletos. No se aplicó el cambio.'
  }
  $newHeader='<header><div class="amb-brand"><img class="amb-brand-logo" src="'+$logo+'" alt="Ambiente Lomas" referrerpolicy="no-referrer" loading="eager"><div class="amb-brand-copy"><h1>Solicitudes de Traslado</h1><div class="muted">Municipio de Lomas de Zamora · Ambiente Lomas</div></div></div>'
  $changed=$original.Replace($stylesEnd,[Environment]::NewLine+'/* AL_THEME_V1_START */'+[Environment]::NewLine+$css+[Environment]::NewLine+'/* AL_THEME_V1_END */'+[Environment]::NewLine+$stylesEnd)
  $changed=[regex]::Replace($changed,$headerPattern,[System.Text.RegularExpressions.MatchEvaluator]{param($m) $newHeader},[System.Text.RegularExpressions.RegexOptions]::None)
  if($changed -eq $original){throw 'No se produjo ningún cambio. Cancelado.'}
  # Ninguna función JS ni ID de formulario se pierde o cambia.
  $oldScript=[regex]::Match($original,'<script>([\s\S]*?)</script>')
  $newScript=[regex]::Match($changed,'<script>([\s\S]*?)</script>')
  if(-not $oldScript.Success -or -not $newScript.Success -or $oldScript.Value -cne $newScript.Value){
    throw 'Se detectó una diferencia en JavaScript: se cancela la instalación.'
  }
  $oldIds=[regex]::Matches($original,'\bid="([^"]+)"') | ForEach-Object {$_.Groups[1].Value} | Sort-Object
  $newIds=[regex]::Matches($changed,'\bid="([^"]+)"') | ForEach-Object {$_.Groups[1].Value} | Sort-Object
  if((Compare-Object $oldIds $newIds).Count -ne 0){
    throw 'Se detectó un cambio en IDs de formulario: se cancela la instalación.'
  }
  $utf8=New-Object System.Text.UTF8Encoding -ArgumentList $false
  [IO.File]::WriteAllText($index,$changed,$utf8)
  Write-Host 'Validación: funciones JavaScript, IDs y backend intactos.' -ForegroundColor Green
  Write-Host 'Archivos preparados para subir:'
  & clasp status
  Write-Host ('Respaldo: '+$backup)
  $ok=Read-Host 'Para aplicar SOLO el DISEÑO en Apps Script escribí APLICAR (Enter cancela)'
  if($ok -ne 'APLICAR'){Write-Host 'Cancelado. No se subió ningún cambio.';return}
  & clasp push
  if($LASTEXITCODE -ne 0){throw 'No se pudo subir el diseño. Conservá el respaldo.'}
  Write-Host 'Diseño actualizado en el código de Apps Script. La URL pública NO cambió.' -ForegroundColor Green
  Write-Host 'Podés probar desde Implementar > Probar implementaciones (/dev).' -ForegroundColor Cyan
  Write-Host 'Para actualizar /exec, abrir Implementar > Administrar implementaciones y elegir Nueva versión.' -ForegroundColor Cyan
  Write-Host ('Respaldo: '+$backup) -ForegroundColor Green
}finally{Pop-Location}
