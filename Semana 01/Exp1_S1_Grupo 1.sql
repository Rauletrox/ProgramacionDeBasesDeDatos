

-- FIN CARGA DE DATOS -- 

-- HABILITACION DE SALIDA DBMS 
SET SERVEROUTPUT ON;

-- EXTRACCIÓN DE RUT PARA EJECUCIÓN DE CASO 1
SELECT
    c.numrun AS rut,
    c.dvrun  AS dv
FROM CLIENTE c
WHERE UPPER(
        c.pnombre || ' ' ||
        NVL(c.snombre,'') || ' ' ||
        c.appaterno || ' ' ||
        NVL(c.apmaterno,'')
      ) = UPPER('&nombre_completo');

/* ** CASO 1 – PROGRAMA PESOS TODOSUMA ** */
-- VARIABLES BIND USUARIOS
VAR b_run            NUMBER;
VAR b_dv             VARCHAR2(1);

/* ASIGNACIÓN DE VARIABLE POR USUARIO
   SE VA COMENTANDO A MEDIDA QUE SE VA EJECUTANDO */
-- ** KAREN SOGIA RADENAS MANDIOLA **
--EXEC :b_run := 21242003;
--EXEC :b_dv := '4';

-- ** SILVANA MARTINA VALENZUELA DUARTE **
--EXEC :b_run := 22176845;
--EXEC :b_dv := '2';

-- ** DENISSE ALICIA DIAZ MIRANDA **
--EXEC :b_run := 18858542;
--EXEC :b_dv := '6';

-- ** AMANDA ROMINA LIZANA MARAMBIO **
--EXEC :b_run := 22558061;
--EXEC :b_dv := '8';

-- ** LUIS CLAUDIO LUNA JORQUERA **
EXEC :b_run := 21300628;
EXEC :b_dv := '2';

--VARIABLE BIND PUNTOS  
VAR b_peso_extra     NUMBER;
VAR b_extra_t1       NUMBER;
VAR b_extra_t2       NUMBER;
VAR b_extra_t3       NUMBER;

-- ASIGNACIÓN VARIABLE BIND PARA PUNTOS
EXEC :b_peso_extra := 1200;  
EXEC :b_extra_t1   := 100;
EXEC :b_extra_t2   := 300;
EXEC :b_extra_t3   := 550;

-- BLOQUE PL/SQL
DECLARE
  v_nro_cliente          CLIENTE.nro_cliente%TYPE;
  v_nombre_cli           VARCHAR2(200);
  v_tipo_cli             VARCHAR2(50);

  v_monto_total_creditos NUMBER := 0;
  v_tramos_100k          NUMBER := 0;
  v_extra                NUMBER := 0;
  v_pesos_total          NUMBER := 0;

  v_anio_anterior NUMBER := EXTRACT(YEAR FROM SYSDATE) - 1;
BEGIN

-- DATOS CLIENTE 
  SELECT c.nro_cliente,
         UPPER(TRIM(c.pnombre || ' ' || NVL(c.snombre,'') || ' ' ||
             c.appaterno || ' ' || NVL(c.apmaterno,'')
             )),
         tc.nombre_tipo_cliente
    INTO v_nro_cliente,
         v_nombre_cli,
         v_tipo_cli
    FROM CLIENTE c
    JOIN TIPO_CLIENTE tc ON tc.cod_tipo_cliente = c.cod_tipo_cliente
   WHERE c.numrun = :b_run  AND c.dvrun  = :b_dv;

 -- CREDITOS AÑOS ANTERIOR 
  SELECT NVL(SUM(cc.monto_solicitado),0)
    INTO v_monto_total_creditos
    FROM CREDITO_CLIENTE cc
   WHERE cc.nro_cliente = v_nro_cliente
     AND EXTRACT(YEAR FROM cc.fecha_otorga_cred) = v_anio_anterior;

-- TRAMOS 
  v_tramos_100k := TRUNC(v_monto_total_creditos / 100000);

-- PUNTOS EXTRAS POR TIPO DE CLIENTE
  IF UPPER(v_tipo_cli) = 'TRABAJADORES INDEPENDIENTES' THEN
    IF v_monto_total_creditos <= 1000000 THEN
      v_extra := :b_extra_t1;
    ELSIF v_monto_total_creditos BETWEEN 1000001 AND 3000000 THEN
      v_extra := :b_extra_t2;
    ELSE
      v_extra := :b_extra_t3;
    END IF;
  ELSE
    v_extra := 0;
  END IF;

-- CALCULO DE PESOS
  v_pesos_total := v_tramos_100k * (:b_peso_extra + v_extra);
  
-- SE ELIMINA CLIENTE EN CASO DE ESTAR CREADO PARA EJECUCIÓN CONTINUA
DELETE FROM CLIENTE_TODOSUMA
WHERE NRO_CLIENTE = v_nro_cliente;

IF SQL%ROWCOUNT > 0 THEN
  DBMS_OUTPUT.PUT_LINE('Registro previo eliminado.');
END IF;

-- INSERTAR RESULTADOS
  INSERT INTO CLIENTE_TODOSUMA
    (NRO_CLIENTE,
     RUN_CLIENTE,
     NOMBRE_CLIENTE,
     TIPO_CLIENTE,
     MONTO_SOLIC_CREDITOS,
     MONTO_PESOS_TODOSUMA)
 
  VALUES 
    (v_nro_cliente,
     TO_CHAR(:b_run, 'FM99G999G999') || '-' || :b_dv,
     v_nombre_cli,
     v_tipo_cli,
     v_monto_total_creditos,
     v_pesos_total);

  COMMIT;

-- SALIDA DBMS 
  DBMS_OUTPUT.PUT_LINE('Registro insertado correctamente.');
  DBMS_OUTPUT.PUT_LINE('RUN: ' || TO_CHAR(:b_run, 'FM99G999G999') || '-' || :b_dv);
  DBMS_OUTPUT.PUT_LINE('PESOS TODOSUMA: ' || v_pesos_total);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: Cliente no existe o no tiene créditos el año anterior.');
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: Cliente ya existe en CLIENTE_TODOSUMA.');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: Error en ejecución del bloque.');
END;
/

-- CONFIRMAMOS LA INSERCIÓN DE LOS DATOS REVISANDO LA TABLA
SELECT * FROM CLIENTE_TODOSUMA;

/* ** CASO 2 – POSTERGAR CUOTAS ** */

-- OBTENCIÓN NUMERO DE CLIENTE PARA LOS USUARIOS SOLICITADOS:
SELECT
    c.nro_cliente AS nro_cliente
FROM CLIENTE c
WHERE UPPER(
        c.pnombre || ' ' ||
        NVL(c.snombre,'') || ' ' ||
        c.appaterno || ' ' ||
        NVL(c.apmaterno,'')
      ) = UPPER('&nombre_completo');

-- VARIABLES BIND 
VAR b_nro_cliente       NUMBER;
VAR b_nro_solic_credito NUMBER;
VAR b_cuotas_postergar  NUMBER;

/* ASIGNACIÓN DE VARIABLE POR USUARIO
   SE VA COMENTANDO A MEDIDA QUE SE VA EJECUTANDO */
   
-- SEBASTIAN PATRICIO QUINTANA BERRIOS

--EXEC :b_nro_cliente       := 5;
--EXEC :b_nro_solic_credito := 2001;
--EXEC :b_cuotas_postergar  := 2;

-- KAREN SOFIA PRADENAS MANDIOLA

--EXEC :b_nro_cliente       := 67;
--EXEC :b_nro_solic_credito := 3004;
--EXEC :b_cuotas_postergar  := 1;

-- JULIAN PAUL ARRIAGADA LUJAN

EXEC :b_nro_cliente       := 13;
EXEC :b_nro_solic_credito := 2004;
EXEC :b_cuotas_postergar  := 1;

-- BLOQUE PL/SQL
DECLARE
  v_cod_credito       CREDITO_CLIENTE.cod_credito%TYPE;

  v_ult_nro_cuota     CUOTA_CREDITO_CLIENTE.nro_cuota%TYPE;
  v_ult_fecha_venc    CUOTA_CREDITO_CLIENTE.fecha_venc_cuota%TYPE;
  v_ult_valor_cuota   CUOTA_CREDITO_CLIENTE.valor_cuota%TYPE;

  v_tasa              NUMBER := 0;   
  v_count_cred_aa     NUMBER := 0;   
  v_anio_anterior     NUMBER := EXTRACT(YEAR FROM SYSDATE) - 1;

  v_new_nro_cuota     NUMBER;
  v_new_fecha_venc    DATE;
  v_new_valor_cuota   NUMBER;

BEGIN

-- VALIDACIÓN CREDITO Y TIPO DE CLIENTE
  SELECT cc.cod_credito
    INTO v_cod_credito
    FROM CREDITO_CLIENTE cc
   WHERE cc.nro_solic_credito = :b_nro_solic_credito
     AND cc.nro_cliente       = :b_nro_cliente;

-- ULTIMA CUOTA DEL CREDITO
  SELECT MAX(cu.nro_cuota)
    INTO v_ult_nro_cuota
    FROM CUOTA_CREDITO_CLIENTE cu
   WHERE cu.nro_solic_credito = :b_nro_solic_credito;

  SELECT cu.fecha_venc_cuota,
         cu.valor_cuota
    INTO v_ult_fecha_venc,
         v_ult_valor_cuota
    FROM CUOTA_CREDITO_CLIENTE cu
   WHERE cu.nro_solic_credito = :b_nro_solic_credito
     AND cu.nro_cuota         = v_ult_nro_cuota;

-- TASA CREDITO
  IF v_cod_credito = 1 THEN
    IF :b_cuotas_postergar = 1 THEN
      v_tasa := 0;
    ELSIF :b_cuotas_postergar = 2 THEN
      v_tasa := 0.005;
    ELSE
      DBMS_OUTPUT.PUT_LINE('ERROR: Hipotecario solo permite postergar 1 o 2 cuotas.');
      RETURN;
    END IF;
  ELSIF v_cod_credito = 2 THEN v_tasa := 0.01;
  ELSIF v_cod_credito = 3 THEN v_tasa := 0.02;
  ELSE
    DBMS_OUTPUT.PUT_LINE('ERROR: Tipo de crédito no soportado.');
    RETURN;
  END IF;

 -- CONDONACIÓN
  SELECT COUNT(*)
    INTO v_count_cred_aa
    FROM CREDITO_CLIENTE cc
   WHERE cc.nro_cliente = :b_nro_cliente
     AND EXTRACT(YEAR FROM cc.fecha_otorga_cred) = v_anio_anterior;

  IF v_count_cred_aa > 1 THEN
    UPDATE CUOTA_CREDITO_CLIENTE
       SET fecha_pago_cuota = fecha_venc_cuota,
           monto_pagado     = valor_cuota,
           saldo_por_pagar  = NULL,
           cod_forma_pago   = NULL
     WHERE nro_solic_credito = :b_nro_solic_credito
       AND nro_cuota         = v_ult_nro_cuota;
  END IF;

-- INSERTAR NUEVAS CUOTAS
  FOR i IN 1..:b_cuotas_postergar LOOP
    v_new_nro_cuota   := v_ult_nro_cuota + i;
    v_new_fecha_venc  := ADD_MONTHS(v_ult_fecha_venc, i);
    v_new_valor_cuota := ROUND(v_ult_valor_cuota * (1 + v_tasa), 0);

    INSERT INTO CUOTA_CREDITO_CLIENTE
      (nro_solic_credito,
       nro_cuota,
       fecha_venc_cuota,
       valor_cuota,
       fecha_pago_cuota,
       monto_pagado,
       saldo_por_pagar,
       cod_forma_pago)
    VALUES
      (:b_nro_solic_credito,
       v_new_nro_cuota,
       v_new_fecha_venc,
       v_new_valor_cuota,
       NULL,
       NULL,
       NULL,
       NULL);
  END LOOP;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('OK -> Postergación aplicada.');
  DBMS_OUTPUT.PUT_LINE('Credito: ' || :b_nro_solic_credito ||
                       ' | Nuevas cuotas: ' || :b_cuotas_postergar ||
                       ' | Tasa: ' || (v_tasa*100) || '%');

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: Cliente/Crédito no válido o no existen cuotas.');
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: Ya existen cuotas con esos números (re-ejecución sin limpiar).');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: Error en ejecución del bloque.');
END;
/

-- CONFIRMAMOS LA INSERCIÓN DE LOS DATOS REVISANDO LA TABLA
SELECT nro_solic_credito, nro_cuota, fecha_venc_cuota, valor_cuota,
       fecha_pago_cuota, monto_pagado, saldo_por_pagar, cod_forma_pago
FROM CUOTA_CREDITO_CLIENTE
WHERE nro_solic_credito = &nro_solic
ORDER BY nro_cuota;
