/**
 * MIGRACIÓN AUTORIZADA de APPSECRETARIA: contraseñas reales visibles en USUARIOS.
 *
 * Atención: guardar contraseñas en texto plano es inseguro. Toda persona con
 * lectura de la planilla verá las claves. Este código NO las envía a GitHub
 * ni las devuelve al navegador, a ChatGPT o a logs.
 *
 * Requiere antes actualizar en Codigo.js la definición SOL.HOJAS.USUARIOS
 * para insertar 'CONTRASEÑA' en la posición 3.
 *
 * Ejecutar UNA SOLA VEZ desde el editor del proyecto Apps Script,
 * con la cuenta propietaria y autorización explícita.
 */
function restablecerClavesVisiblesAPPSECRETARIA() {
  const lock=LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const nombres=['graciela','secretaria','empleado.prueba'];
    const nuevaColumna='CONTRASEÑA';
    const props=PropertiesService.getScriptProperties();
    if(props.getProperty('SOL_CLAVES_RESETEADAS_EN')){
      throw new Error('La rotación de contraseñas ya fue ejecutada. No se repetirá.');
    }
    const ss=solSS_();
    if(String(ss.getName()).trim().toUpperCase()!=='APPSECRETARIA'){
      throw new Error('Planilla incorrecta: la operación solo se admite en APPSECRETARIA.');
    }
    const sheet=ss.getSheetByName('USUARIOS');
    if(!sheet)throw new Error('No existe la hoja USUARIOS.');
    const esperado=SOL.HOJAS.USUARIOS;
    if(esperado[1]!=='USUARIO'||esperado[2]!==nuevaColumna||esperado[3]!=='NOMBRE'){
      throw new Error('Primero instalá la versión actualizada del backend.');
    }
    const anterior=esperado.filter(x=>x!==nuevaColumna);
    const actual=sheet.getRange(1,1,1,sheet.getLastColumn()).getDisplayValues()[0];
    if(anterior.length!==actual.length||anterior.some((x,i)=>x!==actual[i])){
      throw new Error('Los encabezados actuales no coinciden con el modelo original. No se modificó nada.');
    }
    const cantidad=sheet.getLastRow()-1;
    if(cantidad<nombres.length)throw new Error('Faltan usuarios. No se modificó nada.');
    const originales=sheet.getRange(2,1,cantidad,anterior.length).getValues();
    const colUsuario=anterior.indexOf('USUARIO'),colEstado=anterior.indexOf('ESTADO');
    const colHash=esperado.indexOf('HASH_CONTRASENA'),colSalt=esperado.indexOf('SALT');
    const indicePorUsuario=new Map();
    originales.forEach((row,i)=>{
      const user=String(row[colUsuario]||'').trim().toLowerCase();
      if(!nombres.includes(user))return;
      if(indicePorUsuario.has(user))throw new Error('Usuario duplicado: '+user);
      if(String(row[colEstado]||'').trim().toUpperCase()!=='ACTIVO')
        throw new Error('La cuenta no está activa: '+user);
      indicePorUsuario.set(user,i);
    });
    nombres.forEach(u=>{
      if(!indicePorUsuario.has(u))throw new Error('No existe la cuenta: '+u);
    });
    // Preparar todo antes de escribir: los valores existentes permanecen intactos.
    const nuevas=originales.map(row=>[...row.slice(0,2),'',...row.slice(2)]);
    nombres.forEach(user=>{
      const row=nuevas[indicePorUsuario.get(user)];
      // Dos UUID aleatorios por cuenta, sin contraseñas fijadas en el repositorio.
      const clave=(Utilities.getUuid()+Utilities.getUuid()).replace(/-/g,'').slice(0,28);
      const salt=Utilities.getUuid();
      row[2]=clave;
      row[colHash]=solHash_(clave,salt);
      row[colSalt]=salt;
    });
    // No modificar la base si falla la copia de seguridad.
    const respaldoNombre='RESPALDO APPSECRETARIA ANTES CLAVES VISIBLES '+Utilities.formatDate(new Date(),SOL.ZONA,'yyyyMMdd-HHmmss');
    const copia=DriveApp.getFileById(ss.getId()).makeCopy(respaldoNombre);
    if(!copia||!copia.getId())throw new Error('No se pudo confirmar el respaldo de la planilla.');

    let columnaInsertada=false;
    try {
      sheet.insertColumnBefore(3);
      columnaInsertada=true;
      sheet.getRange(1,3).setValue(nuevaColumna);
      sheet.getRange(1,2).copyTo(sheet.getRange(1,3),SpreadsheetApp.CopyPasteType.PASTE_FORMAT,false);
      sheet.getRange(2,3,cantidad,1).setNumberFormat('@');
      sheet.getRange(2,1,cantidad,esperado.length).setValues(nuevas);
      sheet.setColumnWidth(3,240);
      SpreadsheetApp.flush();
      const encabezados=sheet.getRange(1,1,1,esperado.length).getDisplayValues()[0];
      if(esperado.some((h,i)=>h!==encabezados[i]))throw new Error('Los encabezados no coinciden después de la actualización.');
      const comprobacion=solRows_('USUARIOS');
      nombres.forEach(user=>{
        const u=comprobacion.find(x=>String(x.USUARIO).trim().toLowerCase()===user);
        if(!u||u['CONTRASEÑA'].length!==28||solHash_(u['CONTRASEÑA'],u.SALT)!==u.HASH_CONTRASENA)
          throw new Error('Falló la comprobación de contraseña de '+user);
      });
      // Publicar después el nuevo código: con este sello, las sesiones antiguas
      // se rechazarán por el backend actualizado.
      props.setProperty('SOL_CLAVES_RESETEADAS_EN',String(Date.now()));
      return {
        ok:true,
        mensaje:'Tres contraseñas restablecidas. Las nuevas claves están exclusivamente en APPSECRETARIA > USUARIOS, columna C.',
        usuarios:nombres,
        respaldoCreado:respaldoNombre,
        publicarNuevaVersion:true
      };
    }catch(error){
      // Revertir filas completas si la hoja aún tiene el mismo número de filas.
      // La copia completa en Drive permanece disponible para recuperación manual.
      try {
        if(columnaInsertada&&sheet.getLastRow()===cantidad+1){
          if(sheet.getRange(1,3).getDisplayValue()===nuevaColumna){
            sheet.deleteColumn(3);
            sheet.getRange(2,1,cantidad,anterior.length).setValues(originales);
            SpreadsheetApp.flush();
          }
        }
      }catch(rollbackError){
        console.error('Reversión automática incompleta. Recuperar desde: '+respaldoNombre);
      }
      throw error;
    }
  }finally{
    lock.releaseLock();
  }
}