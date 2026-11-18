/* Pruebas con planilla SIMULADA: jamás toca cuentas o Google Sheets reales. */
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('backend/restablecer-claves-visibles.gs','utf8');
const install=fs.readFileSync('instalar-claves-visibles.ps1','utf8');
const header=['ID_USUARIO','USUARIO','NOMBRE','ID_DEPENDENCIA','ROL','ESTADO','HASH_CONTRASENA','SALT','FECHA_ALTA','ULTIMO_ACCESO'];
const expected=['ID_USUARIO','USUARIO','CONTRASEÑA',...header.slice(2)];
const users=[
 ['USR-01','graciela','Graciela','','ADMINISTRADOR','ACTIVO','old-g','old-salt-g','',''],
 ['USR-02','secretaria','Secretaría Ambiente','','SECRETARIA','ACTIVO','old-s','old-salt-s','',''],
 ['USR-03','empleado.prueba','Empleado de Prueba','DEP-01','EMPLEADO','ACTIVO','old-e','old-salt-e','',''],
 ['USR-04','otro','Otro usuario','DEP-01','EMPLEADO','ACTIVO','old-o','old-salt-o','','']
];
let head=[...header],rows=users.map(x=>[...x]),serial=0,backups=0,tests=0,reads=0;
const check=(x,m)=>{assert.ok(x,m);tests++};
const cell=(v)=>String(v==null?'':v);
const getRange=(r,c,n=1,m=1)=>({
 getDisplayValues:()=>Array.from({length:n},(_,i)=>(r+i===1?head:rows[r+i-2]).slice(c-1,c-1+m).map(cell)),
 getValues:()=>Array.from({length:n},(_,i)=>(r+i===1?head:rows[r+i-2]).slice(c-1,c-1+m)),
 getDisplayValue:()=>cell((r===1?head:rows[r-2])[c-1]),
 setValue:v=>(r===1?head:rows[r-2])[c-1]=v,
 setValues:vals=>{for(let i=0;i<vals.length;i++){const row=r+i===1?head:rows[r+i-2];for(let j=0;j<vals[i].length;j++)row[c-1+j]=vals[i][j];}},
 setNumberFormat:()=>{},copyTo:()=>{}
});
const sheet={
 getLastRow:()=>rows.length+1,getLastColumn:()=>head.length,getRange,
 insertColumnBefore:c=>{head.splice(c-1,0,'');rows.forEach(a=>a.splice(c-1,0,''))},
 deleteColumn:c=>{head.splice(c-1,1);rows.forEach(a=>a.splice(c-1,1))},
 setColumnWidth:()=>{}
};
const ss={getName:()=> 'APPSECRETARIA',getSheetByName:n=>n==='USUARIOS'?sheet:null,getId:()=> 'SIMULADA'};
const map=new Map();
const ctx={String,Map,Date,Number,Error,Array,JSON,console,
 SOL:{HOJAS:{USUARIOS:expected},ZONA:'America/Argentina/Buenos_Aires'},
 LockService:{getScriptLock:()=>({waitLock:()=>{},releaseLock:()=>{}})},
 PropertiesService:{getScriptProperties:()=>({getProperty:k=>map.get(k)||'',setProperty:(k,v)=>map.set(k,v)})},
 Utilities:{getUuid:()=>{serial++;return ('aa'+String(serial).padStart(10,'0')+'ffff8888ccccddddeeeeffff1111').slice(0,32)},
 formatDate:()=> '20261118-013000'},
 SpreadsheetApp:{flush:()=>{},CopyPasteType:{PASTE_FORMAT:'FORMATO'}},
 DriveApp:{getFileById:()=>({makeCopy:name=>{backups++;return {getId:()=> 'COPY-'+backups,getName:()=>name}}})},
 solSS_:()=>ss,
 solHash_:(pw,salt)=>'HASH:'+pw+':'+salt,
 solRows_:()=>{reads++;return rows.map((row,i)=>Object.fromEntries(expected.map((h,j)=>[h,row[j]])))}
};
vm.createContext(ctx);
vm.runInContext(source,ctx);
const r=ctx.restablecerClavesVisiblesAPPSECRETARIA();
check(r.ok===true&&r.usuarios.length===3,'restablecimiento autorizado');
check(backups===1,'copia de seguridad antes de mutación');
check(head[1]==='USUARIO'&&head[2]==='CONTRASEÑA'&&head[3]==='NOMBRE','columna en posición correcta');
for(const name of ['graciela','secretaria','empleado.prueba']){
 const row=rows.find(u=>u[1]===name);
 check(row[2].length===28,'clave suficientemente larga '+name);
 check(row[7]==='HASH:'+row[2]+':'+row[8],'hash consistente '+name);
 check(!row.includes('old-g')&&!row.includes('old-s')&&!row.includes('old-e'),'clave antigua reemplazada '+name);
}
const other=rows.find(r=>r[1]==='otro');
check(other[2]===''&&other[7]==='old-o'&&other[8]==='old-salt-o','otras cuentas intactas');
check(!!map.get('SOL_CLAVES_RESETEADAS_EN'),'sello de seguridad para invalidar sesiones viejas');
try{ctx.restablecerClavesVisiblesAPPSECRETARIA();throw Error('second succeeded')}
catch(e){check(/ya fue ejecutada/.test(e.message),'impide ejecutar dos veces')}
check(backups===1,'no crea respaldo extra en reintento');
check(!install.includes("pass='")&&!install.includes('password=abc'),'sin claves hardcodeadas');
check(install.includes('SOL_CLAVES_RESETEADAS_EN'),'sesiones antiguas quedan invalidadas');
check(install.includes("['ID_USUARIO','USUARIO','CONTRASEÑA','NOMBRE'"),'schema actualizado');
check(install.includes("USUARIO:usuario,'CONTRASEÑA':pass"),'futuras cuentas también tendrán clave visible');
check(install.includes("clasp push"),'se instala sobre código vigente');
console.log('OK: '+tests+' controles sobre planilla simulada; ninguna clave de usuarios reales fue consultada.');
