$ErrorActionPreference = 'Stop'
$scriptId = '1BcZCsDSmp-wU4gHPfeA24u7VqzyUxXEnI_9IEzDwew1pqRMXm8b5wV9a'
$deploymentId = 'AKfycbwyh-a1jGYe0ZpRu9IjImgMwVUoygIeZz0B-C5Cf3MWSS1vyiYCk3r9TgsEvQ_RlQ_y'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$work = Join-Path $env:USERPROFILE ('Documents\Solicitudes-Formulario-Traslado-' + $stamp)
$backup = Join-Path $env:USERPROFILE ('Documents\RESPALDO-SOLICITUDES-FORMULARIO-' + $stamp)
Write-Host 'ACTUALIZAR FORMULARIO DE TRASLADOS' -ForegroundColor Cyan
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
  $deployments = & clasp deployments
  if ($LASTEXITCODE -ne 0 -or -not (($deployments | Out-String).Contains($deploymentId))) { throw 'No se encontró la implementación.' }
  $nodeCode = @'
function editar(texto,cambios){
  for(const [antes,despues] of cambios){
    if(texto.split(antes).length!==2)throw Error('Versión incompatible: '+antes);
    texto=texto.replace(antes,()=>despues);
  }
  return texto;
}
function transformar(html,backend){
  if(html.includes('id="estados-solicitante"') && backend.includes('function completarRecursosSolicitudes_'))return {html,backend};
  return {html:editar(html,[
  [
    "function renderRequests(){",
    "function estadoVisibleSolicitud(s){\n  const estado=String(s.ESTADO||'').toUpperCase().trim();\n  if(['PENDIENTE','EN_REVISION','PREASIGNADA'].includes(estado))return ['EN REVISIÓN','revision'];\n  if(['ACEPTADA','ACEPTADO','CONFIRMADA','APROBADA'].includes(estado))return ['ACEPTADO','aceptado'];\n  if(['RECHAZADO','RECHAZADA'].includes(estado))return ['RECHAZADO','rechazado'];\n  return [estado.replace(/_/g,' '),'otro'];\n}\nfunction etiquetaSolicitud(s){\n  const [texto,clase]=estadoVisibleSolicitud(s);\n  return '<span class=\"pill sol-'+clase+'\">'+esc(texto)+'</span>';\n}\nfunction recursosSolicitud(s){\n  if(estadoVisibleSolicitud(s)[1]!=='aceptado')return '';\n  if(!s.asignado)return '<p class=\"muted\">Chofer y vehículo pendientes de asignación.</p>';\n  return '<p><b>Chofer</b> · '+esc(s.asignado.chofer||'Pendiente')+'<br><b>Vehículo</b> · '+esc(s.asignado.vehiculo||'Pendiente')+'</p>';\n}\nfunction renderRequests(){"
  ],
  [
    "<span class=\"pill\">${esc(s.ESTADO)}</span></div><p>",
    "${etiquetaSolicitud(s)}</div><p>"
  ],
  [
    "${esc(s.ID_SOLICITUD)}</div><div class=\"actions\">",
    "${esc(s.ID_SOLICITUD)}</div>${recursosSolicitud(s)}<div class=\"actions\">"
  ],
  [
    "</head>",
    "<style id=\"estados-solicitante\">\n#requests .pill{display:inline-flex;align-items:center;justify-content:center;text-align:center}\n#requests .sol-revision{background:#fff3cd;color:#795000;border-color:#ecd389}\n#requests .sol-aceptado{background:#e1f4e8;color:#146139;border-color:#afddbd}\n#requests .sol-rechazado{background:#fce8e8;color:#942a2a;border-color:#efbbbb}\n#requests .sol-otro{background:#edf1f4;color:#455565;border-color:#d1d9df}\n</style>\n</head>"
  ]
]),backend:editar(backend,[
  [
    "function obtenerInicioSolicitudes(token){",
    "function completarRecursosSolicitudes_(solicitudes){\n  const visibles=new Map(solicitudes.filter(s=>['CONFIRMADA','ACEPTADA','ACEPTADO','APROBADA'].includes(solF4Norm_(s.ESTADO))).map(s=>[s.ID_SOLICITUD,s]));\n  if(!visibles.size)return;\n  const filas=solRows_('ASIGNACIONES').filter(a=>visibles.has(a.ID_SOLICITUD)&&solF4LocalActivo_(a));\n  if(!filas.length)return;\n  const choferes=new Map(),vehiculos=new Map();\n  try{\n    const ss=solF4Maestro_();\n    solF4Leer_(ss,'CHOFERES',['ID_CHOFER','NOMBRE']).forEach(c=>choferes.set(c.ID_CHOFER,c.NOMBRE));\n    solF4Leer_(ss,'VEHICULOS',['ID_VEHICULO','DOMINIO','INTERNO']).forEach(v=>vehiculos.set(v.ID_VEHICULO,[v.DOMINIO,v.INTERNO].filter(Boolean).join(' · ')));\n  }catch(e){console.warn('Maestro no disponible para consultar nombres.');}\n  for(const a of filas){\n    visibles.get(a.ID_SOLICITUD).asignado={\n      chofer:choferes.get(a.ID_CHOFER_MAESTRO)||a.ID_CHOFER_MAESTRO||'',\n      vehiculo:vehiculos.get(a.ID_VEHICULO_MAESTRO)||a.ID_VEHICULO_MAESTRO||''\n    };\n  }\n}\nfunction obtenerInicioSolicitudes(token){"
  ],
  [
    "return {usuario:solUserPublic_(u),solicitudes,agenda:",
    "completarRecursosSolicitudes_(solicitudes);\n  return {usuario:solUserPublic_(u),solicitudes,agenda:"
  ]
])};
}
const fs=require('fs');
const codigo=fs.readdirSync('.').find(n=>/^codigo\.(gs|js)$/i.test(n));
if(!codigo)throw Error('Falta el archivo de backend Codigo.');
const resultado=transformar(fs.readFileSync('Index.html','utf8'),fs.readFileSync(codigo,'utf8'));
for(const match of resultado.html.matchAll(/<script>([\s\S]*?)<\/script>/gi))new Function(match[1]);
new Function(resultado.backend);
fs.writeFileSync('Index.html',resultado.html);
fs.writeFileSync(codigo,resultado.backend);
'@
  $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
  $nodeCode | node -
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo adaptar el formulario vigente.' }
  & clasp push
  if ($LASTEXITCODE -ne 0) { throw 'Falló la subida del formulario.' }
  & clasp deploy -i $deploymentId -d 'Estados y recursos asignados en Mis solicitudes'
  if ($LASTEXITCODE -ne 0) { throw 'Código subido. Falló la publicación.' }
  Write-Host 'Mis solicitudes actualizado en la misma URL.'
} finally { Pop-Location }
