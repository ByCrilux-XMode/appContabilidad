# Reportes Contables

Este módulo contiene los reportes contables principales de la aplicación.

## Reportes Disponibles

### 1. Libro Diario
**Ubicación:** `lib/reportes/libroDiario.dart`

Muestra un registro cronológico de todos los asientos contables con:
- Fecha del asiento
- Descripción general
- Detalle de movimientos (cuenta, debe, haber)
- Totales por asiento
- Filtro por rango de fechas

**Características:**
- Vista en tarjetas expandibles
- Validación de que debe = haber
- Formato de moneda en bolivianos
- Colores diferenciados para debe (verde) y haber (rojo)

### 2. Libro Mayor
**Ubicación:** `lib/reportes/libroMayor.dart`

Presenta los movimientos agrupados por cuenta contable con:
- Lista de todas las cuentas con movimientos
- Movimientos ordenados cronológicamente por cuenta
- Cálculo de saldo acumulado
- Totales de debe, haber y saldo final

**Características:**
- Filtro por cuenta específica
- Filtro por rango de fechas
- Identificación de cuentas deudoras y acreedoras
- Vista detallada con saldo acumulado en cada movimiento

### 3. Balance General
**Ubicación:** `lib/reportes/balanceGeneral.dart`

Estado de situación financiera que muestra:
- **Activos:** Cuentas de tipo activo con sus saldos
- **Pasivos:** Cuentas de tipo pasivo con sus saldos
- **Patrimonio:** Cuentas de capital y patrimonio

**Características:**
- Clasificación automática de cuentas por tipo
- Validación de ecuación contable: Activo = Pasivo + Patrimonio
- Selección de fecha de corte
- Indicador visual de balance cuadrado/descuadrado
- Solo muestra cuentas con saldo diferente de cero

### 4. Estado de Resultados
**Ubicación:** `lib/reportes/estadoResultados.dart`

Reporte de pérdidas y ganancias que incluye:
- **Ingresos:** Ventas y otros ingresos
- **Costos:** Costo de ventas
- **Gastos:** Gastos operativos
- **Utilidades calculadas:**
  - Utilidad Bruta (Ingresos - Costos)
  - Utilidad Operativa (Utilidad Bruta - Gastos)
  - Utilidad/Pérdida Neta

**Características:**
- Selección de período (fecha inicio y fin)
- Cálculo automático de utilidades
- Porcentaje de margen de utilidad
- Indicadores visuales de utilidad/pérdida
- Por defecto muestra el mes actual

## Integración con el Dashboard

Los reportes están integrados en el menú principal del dashboard:
- Icono de libro para Libro Diario
- Icono de libro múltiple para Libro Mayor
- Icono de evaluación para Balance General
- Icono de análisis para Estado de Resultados

## Tecnologías Utilizadas

- **Flutter:** Framework de desarrollo
- **HTTP:** Consumo de API REST
- **IntL:** Formato de fechas y números en español
- **Material Design:** Componentes de UI

## Formato de Datos

Todos los reportes utilizan:
- Formato de moneda: Bolivianos (Bs.)
- Formato de fecha: dd/MM/yyyy
- Locale: es_BO (Español - Bolivia)
- Precisión decimal: 2 decimales

## Notas de Implementación

1. Los reportes consumen datos de la API configurada en `config.dart`
2. Requieren autenticación mediante token Bearer
3. Los endpoints utilizados:
   - `/asiento` - Para asientos contables
   - `/movimiento` - Para movimientos contables
   - `/cuenta` - Para cuentas contables

4. Todos los reportes incluyen:
   - Indicador de carga mientras se obtienen datos
   - Manejo de errores con SnackBar
   - Estados vacíos informativos
   - Diseño responsive
