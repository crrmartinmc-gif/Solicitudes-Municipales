# APPSECRETARIA — Columna CONTRASEÑA visible entre USUARIO y NOMBRE.
# Solo restablece graciela, secretaria y empleado.prueba después de ejecución manual.
# Nunca escribe las nuevas claves en GitHub, CMD ni archivos locales.
$ErrorActionPreference='Stop'
$scriptId='1BcZCsDSmp-wU4gHPfeA24u7VqzyUxXEnI_9IEzDwew1pqRMXm8b5wV9a'
$editor='https://script.google.com/u/0/home/projects/'+$scriptId+'/edit'
$raw='https://raw.githubusercontent.com/crrmartinmc-gif/Solicitudes-Municipales/main/backend/restablecer-claves-visibles.gs'
$deploymentId='AKfycbwyh-a1jGYe0ZpRu9IjImgMwVUoygIeZz0B-C5Cf3MWSS1vyiYCk3r9TgsEvQ_RlQ_y'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$work=Join-Path $env:USERPROFILE ('Documents\Solicitudes-Claves-'+$stamp)
$backup=Join-Path $env:USERPROFILE ('Documents\RESPALDO-SOLICITUDES-CLAVES-'+$stamp)
Write-Host 'APPSECRETARIA — Restablecimiento de contraseñas visibles' -ForegroundColor Cyan
Write-Host 'ATENCIÓN: cualquier usuario con acceso a APPSECRETARIA podrá leer las nuevas claves.' -ForegroundColor Yellow
Write-Host 'Se respaldará código y base antes del restablecimiento.' -ForegroundColor Cyan
if(-not(Get-Command clasp -ErrorAction SilentlyContinue)){throw 'Falta clasp. Instalá npm install -g @google/clasp'}
New-Item -ItemType Directory -Path $work,$backup -Force | Out-Null
Push-Location $work
try {
  & clasp clone $scriptId
  if($LASTEXITCODE -ne 0){throw 'No se pudo clonar Solicitudes Municipales. No se modificó nada.'}
  Get-ChildItem -Force | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $backup -Force -Recurse}
  Write-Host ('Respaldo local: '+$backup) -ForegroundColor Green
  $main=Join-Path $work 'Codigo.js'
  if(-not(Test-Path $main)){$main=Join-Path $work 'Código.js'}
  if(-not(Test-Path $main)){throw 'No se encontró Codigo.js ni Código.js.'}
  $source=[IO.File]::ReadAllText($main)
  if($source.Contains("USUARIOS: ['ID_USUARIO','USUARIO','CONTRASEÑA'")){
    throw 'La columna CONTRASEÑA ya figura en el código. No se ejecutarán cambios duplicados.'
  }
  $oldSchema="USUARIOS: ['ID_USUARIO','USUARIO','NOMBRE'"
  $newSchema="USUARIOS: ['ID_USUARIO','USUARIO','CONTRASEÑA','NOMBRE'"
  $oldCreate="solAdd_('USUARIOS',{ID_USUARIO:id,USUARIO:usuario,NOMBRE:nombre"
  $newCreate="solAdd_('USUARIOS',{ID_USUARIO:id,USUARIO:usuario,'CONTRASEÑA':pass,NOMBRE:nombre"
  $oldLogin="JSON.stringify({id:u.ID_USUARIO}),21600"
  $newLogin="JSON.stringify({id:u.ID_USUARIO,inicio:Date.now()}),21600"
  $oldSession="const s=JSON.parse(raw),u=solRows_('USUARIOS').find(x=>x.ID_USUARIO===s.id&&x.ESTADO==='ACTIVO');"
  $newSession=@'
const s=JSON.parse(raw),u=solRows_('USUARIOS').find(x=>x.ID_USUARIO===s.id&&x.ESTADO==='ACTIVO');
  const rotacion=Number(PropertiesService.getScriptProperties().getProperty('SOL_CLAVES_RESETEADAS_EN')||0);
  if(rotacion&&(!s.inicio||Number(s.inicio)<rotacion))throw new Error('Las claves se restablecieron. Iniciá sesión nuevamente.');
'@
  $changes=@(
    @($oldSchema,$newSchema),
    @($oldCreate,$newCreate),
    @($oldLogin,$newLogin),
    @($oldSession,$newSession)
  )
  foreach($pair in $changes){
    $old=$pair[0];$new=$pair[1]
    if($source.Split([string[]]@($old),[StringSplitOptions]::None).Count -ne 2){
      throw ('No coincide el backend actual en '+$old.Substring(0,[Math]::Min(55,$old.Length))+'. No se subió nada.')
    }
    $source=$source.Replace($old,$new)
  }
  $migration=Join-Path $work 'Claves_Visibles_Usuarios.js'
  Invoke-WebRequest -UseBasicParsing -Uri $raw -OutFile $migration
  if(-not([IO.File]::ReadAllText($migration)).Contains('function restablecerClavesVisiblesAPPSECRETARIA()')){
    throw 'Módulo incompleto. No se aplicó.'
  }
  $utf8=New-Object System.Text.UTF8Encoding -ArgumentList $false
  [IO.File]::WriteAllText($main,$source,$utf8)
  if(Get-Command node -ErrorAction SilentlyContinue){
    & node --check $main
    if($LASTEXITCODE -ne 0){throw 'El backend tiene un error de sintaxis. No se subió.'}
    & node --check $migration
    if($LASTEXITCODE -ne 0){throw 'El módulo tiene un error de sintaxis. No se subió.'}
  }
  Write-Host 'Verificado: solo se adaptaron los usuarios y la gestión de sesión.' -ForegroundColor Green
  & clasp status
  $ok=Read-Host 'Escribí APLICAR para subir el código (todavía NO cambia las claves ni la hoja)'
  if($ok -ne 'APLICAR'){Write-Host 'Cancelado sin subir.';return}
  & clasp push
  if($LASTEXITCODE -ne 0){throw 'Falló clasp push. Conservá el respaldo.'}
  Write-Host 'Código subido. TODAVÍA NO se cambiaron contraseñas.' -ForegroundColor Green
  Write-Host ('Abrí '+$editor) -ForegroundColor Cyan
  Write-Host 'Seleccioná restablecerClavesVisiblesAPPSECRETARIA y hacé clic en Ejecutar.' -ForegroundColor Yellow
  Write-Host 'Autorizá permisos de Drive cuando Google los solicite.' -ForegroundColor Yellow
  Write-Host 'La función crea un respaldo de APPSECRETARIA en Drive.' -ForegroundColor Yellow
  Write-Host 'Revisá APPSECRETARIA > USUARIOS: columna C = CONTRASEÑA.' -ForegroundColor Yellow
  Write-Host 'NO compartas capturas con las contraseñas a la vista.' -ForegroundColor Yellow
  $ready=Read-Host 'Cuando veas ejecución CORRECTA y las tres claves en la hoja, escribí PUBLICAR (Enter cancela)'
  if($ready -ne 'PUBLICAR'){
    Write-Host 'Si ya cambiaste la hoja, publicá enseguida la nueva versión desde Apps Script.' -ForegroundColor Yellow
    return
  }
  $deploys=(& clasp deployments | Out-String)
  Write-Host $deploys
  if(-not $deploys.Contains($deploymentId)){
    Write-Host 'La implementación original no está en este proyecto. Publicá desde Implementar > Administrar implementaciones.' -ForegroundColor Yellow
    return
  }
  & clasp deploy -i $deploymentId -d 'APPSECRETARIA usuarios contraseñas visibles y hash de acceso'
  if($LASTEXITCODE -ne 0){throw 'No se pudo publicar. Actualizá manualmente la implementación cuanto antes.'}
  Write-Host 'Implementación actualizada conservando la URL.' -ForegroundColor Green
  Write-Host 'Cerrá sesión y volvé a ingresar con las NUEVAS contraseñas de la columna C.' -ForegroundColor Cyan
  Write-Host ('Respaldo del código original: '+$backup)
}finally{Pop-Location}
