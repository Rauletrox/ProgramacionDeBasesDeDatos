/*Una vez que se terminaron de poblar los datos continuo con el código*/

-------------------------------------------------------------------------------
--------------------------- CASO sin numero -----------------------------------
-------------------------------------------------------------------------------

/* ACTIVANDO SALIDAS DEL DBMS_OUTPUT (Lo hago de inmediato para que no se me olvide)
Si lo ejecuto no me debería mostrar ningún mensaje, pero no me debería dar ningún error */

SET SERVEROUTPUT ON;

-- Aquí realizaré una declaración de mi variable Bind
VARIABLE v_fecha_proceso VARCHAR2(10);

-- Al iniciar el programa me preguntará que ingrese una fecha de entrada dd/mm/yyyy
-- Ejemplo 10/11/1984 (es la fecha de mi cumpleaños, es solo un ejemplo
EXEC :v_fecha_proceso := '18/01/2026';


DECLARE
    /* DECLARACIÓN DE VARIABLES*/
    -- Se utiliza TO_CHAR para capturar el valor de la variable bind como texto (Como lo solicitó la Profe)
    v_fecha_txt      VARCHAR2(10) := TO_CHAR(:v_fecha_proceso);
    v_fecha_proc_internal DATE := TO_DATE(v_fecha_txt, 'DD/MM/YYYY');
    
    -- Variables con %TYPE
    v_id_emp        empleado.id_emp%TYPE;
    v_numrun        empleado.numrun_emp%TYPE;
    v_dvrun         empleado.dvrun_emp%TYPE;
    
    -- Variables escalares
    v_pnombre       VARCHAR2(50);
    v_appaterno     VARCHAR2(50);
    v_sueldo        NUMBER;
    v_fec_nac       DATE;
    v_fec_contrato  DATE;
    v_estado_civil  NUMBER;
    v_nom_completo  VARCHAR2(100);
    
    -- Variables para construir las credenciales 
    v_usuario       VARCHAR2(20);
    v_clave         VARCHAR2(30);
    v_letras_est_civ VARCHAR2(2);
    v_annos_trab    NUMBER;
    
    -- Variables para el control de las transacciones 
    v_total_emp     NUMBER;
    v_contador      NUMBER := 0;

BEGIN
    /* LIMPIEZA DE TABLA*/
    -- Borrado de los datos previos para permitir que se re-ejecute el código
    DELETE FROM USUARIO_CLAVE;

    -- Inicio el conteo para la validación de integridad
    SELECT COUNT(*) INTO v_total_emp 
    FROM empleado 
    WHERE id_emp BETWEEN 100 AND 320;

    /* INICIO CON LOS CICLO DE PROCESAMIENTO */
    FOR rec_emp IN (SELECT * FROM empleado WHERE id_emp BETWEEN 100 AND 320 ORDER BY id_emp ASC) LOOP
        
        -- Comienzo con la asignación de datos
        v_id_emp := rec_emp.id_emp;
        v_numrun := rec_emp.numrun_emp;
        v_dvrun := rec_emp.dvrun_emp;
        v_pnombre := rec_emp.pnombre_emp;
        v_appaterno := rec_emp.appaterno_emp;
        v_sueldo := rec_emp.sueldo_base;
        v_fec_nac := rec_emp.fecha_nac;
        v_fec_contrato := rec_emp.fecha_contrato;
        v_estado_civil := rec_emp.id_estado_civil;
        v_nom_completo := rec_emp.pnombre_emp || ' ' || rec_emp.snombre_emp || ' ' || 
                          rec_emp.appaterno_emp || ' ' || rec_emp.apmaterno_emp;

        /* REGLAS DE NEGOCIO */
        -- Realización del cálculo de antigüedad
        v_annos_trab := FLOOR(MONTHS_BETWEEN(v_fecha_proc_internal, v_fec_contrato) / 12);
        
        -- Generación del de NOMBRE_USUARIO
        v_usuario := LOWER(SUBSTR(CASE v_estado_civil 
                                    WHEN 10 THEN 'CASADO' WHEN 20 THEN 'DIVORCIADO'
                                    WHEN 30 THEN 'SOLTERO' WHEN 40 THEN 'VIUDO'
                                    WHEN 50 THEN 'SEPARADO' ELSE 'ACUERDO' END, 1, 1)) || 
                     SUBSTR(v_pnombre, 1, 3) ||                      
                     LENGTH(v_pnombre) ||                            
                     '*' ||                                          
                     SUBSTR(TO_CHAR(v_sueldo), -1) ||                
                     v_dvrun ||                                      
                     v_annos_trab;                                   
        
        IF v_annos_trab < 10 THEN v_usuario := v_usuario || 'X'; END IF;

        -- Aquí aplico una lógica condicional para establecer las letras de los apellido
        IF v_estado_civil IN (10, 60) THEN 
            v_letras_est_civ := LOWER(SUBSTR(v_appaterno, 1, 2));
        ELSIF v_estado_civil IN (20, 30) THEN 
            v_letras_est_civ := LOWER(SUBSTR(v_appaterno, 1, 1) || SUBSTR(v_appaterno, -1));
        ELSIF v_estado_civil = 40 THEN 
            v_letras_est_civ := LOWER(SUBSTR(v_appaterno, -3, 2));
        ELSE
            v_letras_est_civ := LOWER(SUBSTR(v_appaterno, -2));
        END IF;

        -- Aquí comienzo con lo complejo que es la generación de las CLAVE_USUARIO (Usando TO_CHAR para el mes y año actual de proceso)
        v_clave := SUBSTR(TO_CHAR(v_numrun), 3, 1) ||                
                   (TO_NUMBER(TO_CHAR(v_fec_nac, 'YYYY')) + 2) ||    
                   (SUBSTR(TO_CHAR(v_sueldo), -3) - 1) ||            
                   v_letras_est_civ ||                               
                   v_id_emp ||                                       
                   TO_CHAR(v_fecha_proc_internal, 'MMYYYY');                       

        -- Aquí comienzo con la inserción de los resultados 
        INSERT INTO USUARIO_CLAVE (id_emp, numrun_emp, dvrun_emp, nombre_empleado, nombre_usuario, clave_usuario)
        VALUES (v_id_emp, v_numrun, v_dvrun, v_nom_completo, v_usuario, v_clave);
        
        v_contador := v_contador + 1;
    END LOOP;

    /* CIERRE DE TRANSACCIÓN*/
    IF v_contador = v_total_emp THEN
        COMMIT; 
        DBMS_OUTPUT.PUT_LINE('EL PROCESO A FINALIZADO CON ÉXITO. EL REGISTROS ES EL N°' || v_contador);
    ELSE
        ROLLBACK; 
        DBMS_OUTPUT.PUT_LINE('A OCURRIDO UN ERROR EN EL PROCESO: SE EJECUTA PROCEDE A EJECUTAR EL ROLLBACK... ROLLBACK EJECUTADO');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK; 
        DBMS_OUTPUT.PUT_LINE('A OCURRIDO UN ERROR CRÍTICO: ' || SQLERRM);
END;
/

-- Realizo la consulta Select para la validación de la ejecución.
SELECT * FROM USUARIO_CLAVE ORDER BY id_emp ASC;


