--=====================================================================
--       DESPUÉS DE LA CREACIÓN Y EL POBLAMIENTO DE LAS TABLAS
--=====================================================================

/***************************************************************************
Realización de los cálculos de puntos All The Best por transacciones de tarjetas CATB
****************************************************************************/

-- ACTIVAMOS DMS

SET SERVEROUTPUT ON;

-- TRUNCAMOS LAS TABLAS 

TRUNCATE TABLE detalle_puntos_tarjeta_catb;
TRUNCATE TABLE resumen_puntos_tarjeta_catb;

-- VARIABLE BIND (paramétricas) 

VAR b_fec_ini VARCHAR2(10);
VAR b_fec_fin VARCHAR2(10);

EXEC :b_fec_ini := TO_CHAR(TRUNC(ADD_MONTHS(SYSDATE,-12),'YYYY'),'DD-MM-YYYY');
EXEC :b_fec_fin := TO_CHAR(TRUNC(SYSDATE,'YYYY'),'DD-MM-YYYY');

DECLARE
    v_fec_ini DATE := TO_DATE(:b_fec_ini,'DD-MM-YYYY');
    v_fec_fin DATE := TO_DATE(:b_fec_fin,'DD-MM-YYYY');

  -- VARRAY DE PUNTAJES
  
  TYPE t_puntajes IS VARRAY(4) OF NUMBER;
  v_puntajes t_puntajes := t_puntajes(250,300,550,700);

  -- RECORD PL/SQL
  
  TYPE r_trans IS RECORD(
    numrun                  cliente.numrun%TYPE,
    dvrun                   cliente.dvrun%TYPE,
    cod_tipo_cliente        cliente.cod_tipo_cliente%TYPE,
    nro_tarjeta             tarjeta_cliente.nro_tarjeta%TYPE,
    nro_transaccion         transaccion_tarjeta_cliente.nro_transaccion%TYPE,
    fecha_transaccion       transaccion_tarjeta_cliente.fecha_transaccion%TYPE,
    monto_transaccion       transaccion_tarjeta_cliente.monto_transaccion%TYPE,
    tipo_transaccion        tipo_transaccion_tarjeta.nombre_tptran_tarjeta%TYPE
  );

    v_trans r_trans;

  -- CURSOR EXPLÍCITO

  CURSOR cur_trans IS
    SELECT c.numrun, c.dvrun, c.cod_tipo_cliente,
           tc.nro_tarjeta, t.nro_transaccion,
           t.fecha_transaccion, t.monto_transaccion,
           tt.nombre_tptran_tarjeta
    FROM cliente c
    JOIN tarjeta_cliente tc ON tc.numrun = c.numrun
    JOIN transaccion_tarjeta_cliente t ON t.nro_tarjeta = tc.nro_tarjeta
    JOIN tipo_transaccion_tarjeta tt ON tt.cod_tptran_tarjeta = t.cod_tptran_tarjeta
    WHERE t.fecha_transaccion >= v_fec_ini
      AND t.fecha_transaccion <  v_fec_fin
    ORDER BY t.fecha_transaccion, c.numrun;

  v_puntos_base NUMBER;
  v_puntos_total NUMBER;

    BEGIN
      OPEN cur_trans;
      LOOP
        FETCH cur_trans INTO v_trans;
        EXIT WHEN cur_trans%NOTFOUND;
    
        -- Cálculo de puntos base
        v_puntos_base := TRUNC(v_trans.monto_transaccion / 100000) * v_puntajes(1);
        v_puntos_total := v_puntos_base;
    
        INSERT INTO detalle_puntos_tarjeta_catb
        VALUES (
          v_trans.numrun, v_trans.dvrun, v_trans.nro_tarjeta,
          v_trans.nro_transaccion, v_trans.fecha_transaccion,
          v_trans.tipo_transaccion, v_trans.monto_transaccion,
          v_puntos_total
        );
      END LOOP;
      CLOSE cur_trans;
    
      COMMIT;
    END;
    /

/************************************************************************
Generación de Detalle y Resumen de aportes SBIF 
************************************************************************
*/

-- Solo si no lo ejecuté arriba y quiero iniciar con este paso
-- SET SERVEROUTPUT ON;


-- TRUNCADO DE TABLAS

  TRUNCATE TABLE detalle_aporte_sbif;
  TRUNCATE TABLE resumen_aporte_sbif;

-- VARIABLE BIND (paramétrica) 

VAR b_anno_inicio NUMBER;
VAR b_anno_fin NUMBER;
--EXEC :b_anno := EXTRACT(YEAR FROM SYSDATE);

EXEC :b_anno_inicio := 2024;
EXEC :b_anno_fin := 2026;

BEGIN
  DBMS_OUTPUT.PUT_LINE(
    'Se consultará desde el año ' || :b_anno_inicio || ' hasta el año ' || :b_anno_fin
  );
END;
/

DECLARE
    v_fec_ini DATE := TO_DATE('01/01/' || :b_anno_inicio, 'DD/MM/YYYY');
    v_fec_fin DATE := ADD_MONTHS(TO_DATE('01/01/' || :b_anno_fin, 'DD/MM/YYYY'),12);
  
  v_porc_aporte TRAMO_APORTE_SBIF.porc_aporte_sbif%TYPE;
  v_aporte      NUMBER(14);

   -- VARRAY DE TIPOS DE TRANSACCIÓN
   
  TYPE t_tipos_trans IS VARRAY(2) OF VARCHAR2(40);
  v_tipos_trans t_tipos_trans := t_tipos_trans('Avance en Efectivo','Súper Avance en Efectivo');

  -- RECORD PL/SQL

  TYPE r_det IS RECORD(
    numrun              cliente.numrun%TYPE,
    dvrun               cliente.dvrun%TYPE,
    nro_tarjeta         tarjeta_cliente.nro_tarjeta%TYPE,
    nro_transaccion     transaccion_tarjeta_cliente.nro_transaccion%TYPE,
    fecha_trans         transaccion_tarjeta_cliente.fecha_transaccion%TYPE,
    tipo_trans          tipo_transaccion_tarjeta.nombre_tptran_tarjeta%TYPE,
    monto_trans         transaccion_tarjeta_cliente.monto_total_transaccion%TYPE
  );

  v_reg r_det;
  
  -- Excepción Definida por el usuario
  
  ex_aporte_invalido EXCEPTION;

-- CURSOR (Sin Parámetros)

    CURSOR cur_grupos IS
    SELECT DISTINCT
           TO_CHAR(t.fecha_transaccion,'MMYYYY') mes_anno,
           tt.nombre_tptran_tarjeta tipo_transaccion
    FROM transaccion_tarjeta_cliente t
    JOIN tipo_transaccion_tarjeta tt
      ON tt.cod_tptran_tarjeta = t.cod_tptran_tarjeta
    WHERE t.fecha_transaccion >= v_fec_ini
      AND t.fecha_transaccion <  v_fec_fin
      AND tt.nombre_tptran_tarjeta IN
          ('Avance en Efectivo','Súper Avance en Efectivo')
    ORDER BY mes_anno, tipo_transaccion;

-- CURSOR (Con Parámetros)

  CURSOR cur_detalle (p_mes VARCHAR2, p_tipo VARCHAR2) IS
    SELECT
      c.numrun,
      c.dvrun,
      t.nro_tarjeta,
      t.nro_transaccion,
      t.fecha_transaccion,
      tt.nombre_tptran_tarjeta,
      t.monto_total_transaccion
    FROM transaccion_tarjeta_cliente t
    JOIN tipo_transaccion_tarjeta tt
      ON tt.cod_tptran_tarjeta = t.cod_tptran_tarjeta
    JOIN tarjeta_cliente tc
      ON tc.nro_tarjeta = t.nro_tarjeta
    JOIN cliente c
      ON c.numrun = tc.numrun
    WHERE TO_CHAR(t.fecha_transaccion,'MMYYYY') = p_mes
      AND tt.nombre_tptran_tarjeta = p_tipo
    ORDER BY t.fecha_transaccion, c.numrun;

BEGIN

-- Recorremos el VARRAY
FOR i IN 1 .. v_tipos_trans.COUNT LOOP

    FOR g IN cur_grupos LOOP
      IF g.tipo_transaccion = v_tipos_trans(i) THEN

        DECLARE
          v_sum_monto  NUMBER(14) := 0;
          v_sum_aporte NUMBER(14) := 0;
        BEGIN
         

          FOR d IN cur_detalle(g.mes_anno, g.tipo_transaccion) LOOP
            v_reg.numrun          := d.numrun;
            v_reg.dvrun           := d.dvrun;
            v_reg.nro_tarjeta     := d.nro_tarjeta;
            v_reg.nro_transaccion := d.nro_transaccion;
            v_reg.fecha_trans     := d.fecha_transaccion;
            v_reg.tipo_trans      := d.nombre_tptran_tarjeta;
            v_reg.monto_trans     := d.monto_total_transaccion;

            BEGIN
              
              -- EXCEPCIÓN PREDEFINIDA POR ORACLE: NO_DATA_FOUND
              
              SELECT porc_aporte_sbif
                INTO v_porc_aporte
                FROM tramo_aporte_sbif
               WHERE v_reg.monto_trans
                     BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;

              IF v_porc_aporte <= 0 THEN
                RAISE ex_aporte_invalido;
              END IF;

            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                v_porc_aporte := 0;
              WHEN ex_aporte_invalido THEN
                v_porc_aporte := 0;
            END;

            v_aporte := ROUND(v_reg.monto_trans * (v_porc_aporte / 100));

            INSERT INTO detalle_aporte_sbif
              (numrun, dvrun, nro_tarjeta, nro_transaccion,
               fecha_transaccion, tipo_transaccion,
               monto_transaccion, aporte_sbif)
            VALUES
              (v_reg.numrun, v_reg.dvrun, v_reg.nro_tarjeta,
               v_reg.nro_transaccion, v_reg.fecha_trans,
               v_reg.tipo_trans, v_reg.monto_trans, v_aporte);

            v_sum_monto  := v_sum_monto  + v_reg.monto_trans;
            v_sum_aporte := v_sum_aporte + v_aporte;
          END LOOP;

          
          INSERT INTO resumen_aporte_sbif
            (mes_anno, tipo_transaccion,
             monto_total_transacciones, aporte_total_abif)
          VALUES
            (g.mes_anno, g.tipo_transaccion,
             v_sum_monto, v_sum_aporte);

        END;
      END IF;
    END LOOP;
  END LOOP;

  COMMIT;

-- EXCEPCIÓN NO PREDEFINIDA (genérica)

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/


--==================================================================
--                 CONSULTAS SELECT A LAS TABLAS
--==================================================================

-- FIGURA 1: TABLA DETALLE_PAORTE_SBIF

SELECT
    numrun,
    dvrun,
    nro_tarjeta,
    nro_transaccion,
    fecha_transaccion,
    tipo_transaccion,
    monto_transaccion AS monto_total_transaccion,
    aporte_sbif
FROM detalle_aporte_sbif
ORDER BY fecha_transaccion ASC,
         numrun ASC;


-- FIGURA 2: TABLA RESUMEN_APORTE_SBIF

SELECT
    mes_anno,
    tipo_transaccion,
    monto_total_transacciones,
    aporte_total_abif
FROM resumen_aporte_sbif
ORDER BY mes_anno ASC,
         tipo_transaccion ASC;