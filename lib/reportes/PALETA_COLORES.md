# 🎨 Paleta de Colores Unificada - Reportes Contables

## Colores Principales

### 🔵 Azul - Color Primario
**Uso:** Encabezados principales, botones primarios, navegación, elementos destacados

```dart
Colors.blue.shade700    // Azul oscuro principal
Colors.blue.shade600    // Azul medio para botones
Colors.blue.shade500    // Azul medio para gradientes
Colors.blue.shade300    // Azul claro para bordes
Colors.blue.shade50     // Azul muy claro para fondos
```

**Aplicaciones:**
- Barra de herramientas superior
- Botones de acción (Período, Filtrar, etc.)
- Encabezados de reportes
- Indicadores de saldo deudor
- Color de marca de la aplicación

---

### 🟢 Verde - Valores Positivos
**Uso:** Saldos deudores, activos, utilidades, debe, valores positivos

```dart
Colors.green.shade700   // Verde oscuro para textos importantes
Colors.green.shade600   // Verde medio
Colors.green.shade500   // Verde medio para gradientes
Colors.green.shade300   // Verde claro para bordes
Colors.green.shade100   // Verde muy claro para fondos suaves
Colors.green.shade50    // Verde casi blanco para fondos
```

**Aplicaciones:**
- Columna "Debe" en libro mayor
- Sección "Activos" en balance general
- "Utilidad" en estado de resultados
- Saldos positivos
- Indicadores de crecimiento

---

### 🔴 Rojo - Valores Negativos
**Uso:** Saldos acreedores, pasivos, pérdidas, haber, valores negativos

```dart
Colors.red.shade700     // Rojo oscuro para textos importantes
Colors.red.shade600     // Rojo medio
Colors.red.shade500     // Rojo medio para gradientes
Colors.red.shade300     // Rojo claro para bordes
Colors.red.shade100     // Rojo muy claro para fondos suaves
Colors.red.shade50      // Rojo casi blanco para fondos
```

**Aplicaciones:**
- Columna "Haber" en libro mayor
- Sección "Pasivos" en balance general
- "Pérdida" en estado de resultados
- Costos y gastos
- Alertas y errores

---

### 🟠 Naranja - Información Secundaria
**Uso:** Alertas suaves, información adicional, saldos acreedores alternativos

```dart
Colors.orange.shade700  // Naranja oscuro para textos
Colors.orange.shade600  // Naranja medio
Colors.orange.shade500  // Naranja claro
```

**Aplicaciones:**
- Saldo acreedor en libro mayor
- Gastos operativos
- Información de advertencia (no crítica)
- Etiquetas secundarias

---

### 🟣 Púrpura - Casos Especiales
**Uso:** Utilidades operativas, métricas especiales

```dart
Colors.purple.shade700  // Púrpura oscuro
Colors.purple.shade600  // Púrpura medio
```

**Aplicaciones:**
- Utilidad operativa en estado de resultados
- Métricas calculadas especiales

---

## Colores Neutrales

### ⚪ Grises - UI General

```dart
Colors.grey.shade800    // Texto primario oscuro
Colors.grey.shade700    // Texto secundario
Colors.grey.shade600    // Texto terciario
Colors.grey.shade400    // Iconos deshabilitados
Colors.grey.shade300    // Bordes y divisores
Colors.grey.shade200    // Bordes suaves
Colors.grey.shade100    // Fondos de secciones
Colors.white            // Fondo principal
Colors.black87          // Texto muy oscuro
```

---

## Aplicación por Reporte

### 📘 Libro Diario
- **Primario:** Azul
- **Debe:** Verde
- **Haber:** Rojo
- **Encabezado:** Gradiente Azul

### 📗 Libro Mayor
- **Primario:** Azul
- **Debe:** Verde
- **Haber:** Rojo
- **Saldo Deudor:** Azul
- **Saldo Acreedor:** Naranja
- **Encabezado:** Gradiente Azul

### 📊 Balance General
- **Primario:** Azul
- **Activos:** Verde
- **Pasivos:** Rojo
- **Patrimonio:** Azul
- **Encabezado:** Gradiente Azul
- **Balance OK:** Verde
- **Balance Error:** Rojo

### 📈 Estado de Resultados
- **Primario:** Azul
- **Ingresos:** Verde
- **Costos:** Rojo
- **Gastos:** Naranja
- **Utilidad Bruta:** Azul
- **Utilidad Operativa:** Púrpura
- **Utilidad/Pérdida Neta:** Verde/Rojo (según resultado)
- **Encabezado:** Gradiente Azul

---

## Consistencia con Dashboard

El dashboard usa:
```dart
AppBar: Colors.blue.shade700
Drawer gradient: Colors.blue.shade700 a Colors.blue.shade500
Selección: Colors.blue.shade50 con borde Colors.blue.shade300
```

**Todos los reportes mantienen esta misma paleta azul como color principal** para consistencia visual en toda la aplicación.

---

## Principios de Diseño

1. **Azul siempre primario** - Nunca usar verde/naranja/púrpura como color principal
2. **Verde = Positivo** - Activos, debe, utilidades, crecimientos
3. **Rojo = Negativo** - Pasivos, haber, pérdidas, costos
4. **Naranja = Secundario** - Info adicional, advertencias suaves
5. **Consistencia** - Mismo color para mismo concepto en todos los reportes
6. **Contraste** - Siempre verificar legibilidad
7. **Accesibilidad** - Usar shade700 o superior para textos sobre fondos claros

---

**Última actualización:** 3 de noviembre de 2025
