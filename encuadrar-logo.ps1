# Solicitudes Municipales: corregir encuadre del logo Ambiente Lomas.
# El PNG original es 2000x2000 y la marca ocupa la franja horizontal superior.
# Ajuste exclusivo de CSS del Index.html actual; no cambia código, contraseñas ni hojas.
$ErrorActionPreference='Stop'
$scriptId='1BcZCsDSmp-wU4gHPfeA24u7VqzyUxXEnI_9IEzDwew1pqRMXm8b5wV9a'
$deploymentId='AKfycbwyh-a1jGYe0ZpRu9IjImgMwVUoygIeZz0B-C5Cf3MWSS1vyiYCk3r9TgsEvQ_RlQ_y'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$work=Join-Path $env:USERPROFILE ('Documents\Solicitudes-Logo-Encuadre-'+$stamp)
$backup=Join-Path $env:USERPROFILE ('Documents\RESPALDO-SOLICITUDES-ENCUADRE-'+$stamp)
Write-Host 'SOLICITUDES MUNICIPALES | Recorte de espacio blanco del logo' -ForegroundColor Cyan
Write-Host 'Solo CSS. No se modifican formularios, contraseñas, usuarios ni backend.' -ForegroundColor Green
if(-not(Get-Command clasp -ErrorAction SilentlyContinue)){throw 'No se encontró clasp. No se cambió nada.'}
New-Item -ItemType Directory -Path $work,$backup -Force|Out-Null
Push-Location $work
try {
  & clasp clone $scriptId
  if($LASTEXITCODE -ne 0){throw 'No se pudo clonar el Apps Script. Cancelado.'}
  $clasp=Get-Content '.clasp.json' -Raw | ConvertFrom-Json
  if([string]$clasp.scriptId -ne $scriptId){throw 'Script ID incorrecto. Cancelado.'}
  Get-ChildItem -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $backup -Recurse -Force
  }
  Write-Host ('Respaldo completo: '+$backup) -ForegroundColor Green
  $index=Join-Path $work 'Index.html'
  if(-not(Test-Path $index)){throw 'No se encontró Index.html. Cancelado.'}
  $before=[IO.File]::ReadAllText($index)
  $anchor='/* AL_THEME_V1_END */'
  $marker='/* AL_LOGO_CROP_V2 */'
  if($before.Contains($marker)){Write-Host 'Este recorte ya está instalado. No se duplican estilos.';return}
  if($before.Split([string[]]@($anchor),[StringSplitOptions]::None).Count -ne 2){
    throw 'No se encontró el tema original Ambiente Lomas. No se modificó nada.'
  }
  $override=@'
/* AL_LOGO_CROP_V2 */
/* Imagen de origen cuadrada: encuadre horizontal de la marca.
   Sin estiramiento ni desborde y con blanco integrado al encabezado. */
header .amb-brand-logo{
  width:176px !important;
  height:54px !important;
  max-height:none !important;
  object-fit:cover !important;
  object-position:50% 24% !important;
  transform:none !important;
  transform-origin:center !important;
  mix-blend-mode:multiply !important;
}
@media(max-width:700px){
  header .amb-brand-logo{
    width:132px !important;
    height:42px !important;
    max-width:35vw !important;
    object-position:50% 24% !important;
    transform:none !important;
  }
}
'@
  $after=$before.Replace($anchor,$override+[Environment]::NewLine+$anchor)
  if($after -ceq $before){throw 'No se produjo el cambio CSS. Cancelado.'}
  $oldScripts=[regex]::Matches($before,'(?s)<script(?:\s[^>]*)?>.*?</script>')
  $newScripts=[regex]::Matches($after,'(?s)<script(?:\s[^>]*)?>.*?</script>')
  if($oldScripts.Count -ne $newScripts.Count){throw 'Cambio de JavaScript detectado. Cancelado.'}
  for($i=0;$i -lt $oldScripts.Count;$i++){
    if($oldScripts[$i].Value -cne $newScripts[$i].Value){throw 'El JavaScript cambió. Cancelado.'}
  }
  $noCssBefore=[regex]::Replace($before,'(?s)<style[^>]*>.*?</style>','')
  $noCssAfter=[regex]::Replace($after,'(?s)<style[^>]*>.*?</style>','')
  if($noCssBefore -cne $noCssAfter){throw 'El parche modificó contenido fuera de CSS. Cancelado.'}
  $utf8=New-Object System.Text.UTF8Encoding -ArgumentList $false
  [IO.File]::WriteAllText($index,$after,$utf8)
  Write-Host 'CSS actualizado y JavaScript intacto.' -ForegroundColor Green
  $deployments=& clasp deployments
  if($LASTEXITCODE -ne 0 -or -not(($deployments|Out-String).Contains($deploymentId))){
    throw 'No se encontró la implementación correcta. NO se subió nada.'
  }
  & clasp push
  if($LASTEXITCODE -ne 0){throw 'Falló la subida de código. Revisá el respaldo.'}
  & clasp deploy -i $deploymentId -d 'Encuadre de logo Ambiente Lomas sin borde blanco'
  if($LASTEXITCODE -ne 0){throw 'Código subido, pero no se pudo actualizar la implementación.'}
  Write-Host 'Logo encuadrado. La URL /exec sigue siendo la misma.' -ForegroundColor Green
  Write-Host ('https://script.google.com/macros/s/'+$deploymentId+'/exec')
}finally{Pop-Location}
