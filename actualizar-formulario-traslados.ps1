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
function transformar(html,backend){
  function cambiar(texto,antes,despues){
    if(texto.split(antes).length!==2)throw Error('No se pudo identificar de forma única: '+antes);
    return texto.replace(antes,()=>despues);
  }
  const edits=[
    ['<label>Destino final<input id="destino"','<label>Destino del primer tramo<input id="destino"'],
    ['<label class="wide">Motivo<textarea id="motivo" maxlength="400"></textarea></label>','<label>Minutos estimados<input id="minutosIniciales" type="number" min="1" max="1440" value="30"></label>'],
    ['<h3>Tramos del recorrido</h3>',''],
    [',tramCount=0;', ';'],
    ["if(tramCount>=20)return note('Máximo 20 tramos');const n=++tramCount;",`const anteriores=$('tramos').children;
  const n=anteriores.length+2;
  if(n>20)return note('Máximo 20 tramos');
  const desde=anteriores.length?anteriores[anteriores.length-1].querySelector('.t-to').value:val('destino');
  `],
    ["this.closest('.stop').remove()", 'quitarTramo(this)'],
    ["$('tramos').appendChild(div);}",`div.querySelector('.t-from').value=desde;
  $('tramos').appendChild(div);
}
function quitarTramo(boton){
  boton.closest('.stop').remove();
  Array.from($('tramos').children).forEach((fila,i)=>{
    fila.dataset.tramo=i+2;
    fila.querySelector('.item-head b').textContent='Tramo '+(i+2);
  });
}`],
    ["const d={modalidad:val('modalidad')",`tramos.unshift({origen:val('origen'),destino:val('destino'),minutos:val('minutosIniciales'),espera:val('modalidad')==='IDA_VUELTA_ESPERA',llegada:'',salida:''});
  const d={modalidad:val('modalidad')`],
    ["destino:val('destino'),motivo:val('motivo'),materiales:", "destino:tramos[tramos.length-1].destino,materiales:"],
    ['tramCount=0;addTramo();', "$('minutosIniciales').value='30';"],
    ['\naddTramo();','\n']
  ];
  for(const [antes,despues] of edits)html=cambiar(html,antes,despues);
  backend=cambiar(backend,"||!solText_(d.motivo,400))throw new Error('Completá origen, destino y motivo.');",")throw new Error('Completá origen y destino.');");
  return {html,backend};
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
  & clasp deploy -i $deploymentId -d 'Solicitud con primer tramo integrado y sin motivo obligatorio'
  if ($LASTEXITCODE -ne 0) { throw 'Código subido. Falló la publicación.' }
  Write-Host 'Formulario publicado en la misma URL.'
} finally { Pop-Location }
