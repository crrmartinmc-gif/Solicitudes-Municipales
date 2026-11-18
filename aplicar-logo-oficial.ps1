# Aplica el logo horizontal aprobado en la app de Solicitudes de Traslado.
# Unicamente modifica HTML/CSS de Index.html en el Apps Script vigente.
# Conserva credenciales, código del backend, datos y la misma URL /exec.
$ErrorActionPreference = 'Stop'
$scriptId = '1BcZCsDSmp-wU4gHPfeA24u7VqzyUxXEnI_9IEzDwew1pqRMXm8b5wV9a'
$deploymentId = 'AKfycbwyh-a1jGYe0ZpRu9IjImgMwVUoygIeZz0B-C5Cf3MWSS1vyiYCk3r9TgsEvQ_RlQ_y'
$logoUrl = 'https://raw.githubusercontent.com/crrmartinmc-gif/Solicitudes-Municipales/main/assets/logo-ambiente-lomas-horizontal.png'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$work = Join-Path $env:USERPROFILE ('Documents\Solicitudes-Logo-Oficial-' + $stamp)
$backup = Join-Path $env:USERPROFILE ('Documents\RESPALDO-SOLICITUDES-LOGO-OFICIAL-' + $stamp)
Write-Host 'SOLICITUDES DE TRASLADO - LOGO AMBIENTE LOMAS HORIZONTAL' -ForegroundColor Cyan
Write-Host 'Se mantiene la URL de la app; no se modifican contraseñas ni solicitudes.' -ForegroundColor Green
if (-not (Get-Command clasp -ErrorAction SilentlyContinue)) {
  throw 'No se encontró clasp. No se aplicó ningún cambio.'
}
New-Item -ItemType Directory -Path $work,$backup -Force | Out-Null
Push-Location $work
try {
  & clasp clone $scriptId
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo clonar Apps Script. Sin cambios.' }
  $cfg = Get-Content '.clasp.json' -Raw | ConvertFrom-Json
  if ([string]$cfg.scriptId -ne $scriptId) {
    throw 'El proyecto clonado no es Solicitudes Municipales. Sin cambios.'
  }
  Get-ChildItem -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $backup -Recurse -Force
  }
  Write-Host ('Respaldo completo: ' + $backup) -ForegroundColor Green
  $index = Join-Path $work 'Index.html'
  if (-not (Test-Path $index)) {
    throw 'Falta Index.html. No se modificó ninguna aplicación.'
  }
  $original = [IO.File]::ReadAllText($index)
  $tag = [regex]::Matches($original, '<img\b[^>]*\bclass="amb-brand-logo"[^>]*>', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($tag.Count -ne 1) {
    throw 'El logo del encabezado ya no tiene la estructura prevista. Sin cambios.'
  }
  $oldTag = $tag[0].Value
  if ($oldTag -notmatch '\bsrc="[^"]*"') {
    throw 'El elemento del logo no tiene src como se esperaba. Sin cambios.'
  }
  $newTag = [regex]::Replace($oldTag, 'src="[^"]*"', 'src="' + $logoUrl + '"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $result = $original.Replace($oldTag, $newTag)
  $anchor = '/* AL_THEME_V1_END */'
  if ($result.Split([string[]]@($anchor),[StringSplitOptions]::None).Count -ne 2) {
    throw 'No se detectó el tema de Ambiente Lomas. Sin cambios.'
  }
  $marker = '/* AL_LOGO_HORIZONTAL_V3 */'
  $style = @'
/* AL_LOGO_HORIZONTAL_V3 */
header .amb-brand-logo{
  width:184px!important;
  height:63px!important;
  max-height:none!important;
  object-fit:contain!important;
  object-position:left center!important;
  transform:none!important;
  mix-blend-mode:normal!important;
}
@media(max-width:700px){
  header .amb-brand-logo{
    width:132px!important;
    height:45px!important;
    max-width:35vw!important;
    object-fit:contain!important;
    object-position:left center!important;
    transform:none!important;
  }
}
'@
  if (-not $result.Contains($marker)) {
    $result = $result.Replace($anchor, $style + [Environment]::NewLine + $anchor)
  }
  $beforeScripts = [regex]::Matches($original,'(?is)<script\b[^>]*>.*?</script>')
  $afterScripts = [regex]::Matches($result,'(?is)<script\b[^>]*>.*?</script>')
  if ($beforeScripts.Count -ne $afterScripts.Count) {
    throw 'El archivo modificó bloques JavaScript. Se canceló.'
  }
  for ($i=0; $i -lt $beforeScripts.Count; $i++) {
    if ($beforeScripts[$i].Value -cne $afterScripts[$i].Value) {
      throw 'El JavaScript no coincide con el original. Se canceló.'
    }
  }
  # Verificar que el único cambio no-CSS es la etiqueta del logo.
  $beforeNoCss = [regex]::Replace($original, '(?is)<style\b[^>]*>.*?</style>', '')
  $afterNoCss = [regex]::Replace($result, '(?is)<style\b[^>]*>.*?</style>', '')
  if ($beforeNoCss.Replace($oldTag, $newTag) -cne $afterNoCss) {
    throw 'Se detectaron modificaciones no previstas fuera del logo. Sin cambios.'
  }
  if ($original -ceq $result) {
    Write-Host 'El logo horizontal ya está aplicado en el código.' -ForegroundColor Green
    return
  }
  $deployments = & clasp deployments
  if ($LASTEXITCODE -ne 0 -or -not (($deployments | Out-String).Contains($deploymentId))) {
    throw 'La implementación publicada indicada no pertenece a este proyecto. Se canceló antes de subir.'
  }
  $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
  [IO.File]::WriteAllText($index,$result,$utf8)
  Write-Host 'Índice verificado: únicamente cambió el logo y su encuadre.' -ForegroundColor Green
  & clasp push
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo subir a Apps Script. Se conservó el respaldo.' }
  & clasp deploy -i $deploymentId -d 'Nuevo logo horizontal Ambiente Lomas en Solicitudes de Traslado'
  if ($LASTEXITCODE -ne 0) {
    throw 'Código subido pero no se pudo publicar. Conservá el respaldo.'
  }
  Write-Host 'Logo publicado correctamente en la misma URL de Solicitudes de Traslado.' -ForegroundColor Green
  Write-Host ('https://script.google.com/macros/s/' + $deploymentId + '/exec')
  Write-Host ('Respaldo: ' + $backup)
} finally {
  Pop-Location
}
