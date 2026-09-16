<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.math.BigDecimal" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.util.HashMap, java.util.Map, java.util.HashSet, java.util.Set" %>
<%!
private static final int MAX_IMAGENES = 3;

private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private Integer parseEntero(String valor) {
    if (valor == null) return null;
    try { return Integer.valueOf(Integer.parseInt(valor.trim())); } catch (NumberFormatException ex) { return null; }
}

private BigDecimal parseDecimal(String valor) {
    if (valor == null) return null;
    try { return new BigDecimal(valor.trim()); } catch (NumberFormatException ex) { return null; }
}

private boolean esEnteroValido(Integer valor) { return valor != null && valor.intValue() >= 0; }

private String ipCliente(HttpServletRequest req) {
    String ip = req.getRemoteAddr();
    if (ip == null || ip.trim().isEmpty()) return null;
    ip = ip.trim();
    if (ip.length() > 45) ip = ip.substring(0, 45);
    return ip;
}
%>
<%
String[] rolesPermitidos = { "INMOBILIARIA" };
String tituloPagina = "Editar Propiedad";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
String[] estados = { "DISPONIBLE", "RESERVADA", "VENDIDA", "ALQUILADA" };

int idPropiedad = 0;
try { idPropiedad = Integer.parseInt(limpiar(request.getParameter("id"))); }
catch (NumberFormatException ignorada) { idPropiedad = 0; }

String mensajeError = null;
boolean encontrada = false;
Integer idInmobiliaria = null;

// Valores del formulario
String fTitulo = null, fTipo = null, fCiudad = null, fDireccion = null, fMatricula = null;
String fPrecio = null, fArea = null, fHabitaciones = null, fBanos = null, fEstado = "DISPONIBLE", fDescripcion = null;

List<String[]> tipos = new ArrayList<String[]>();
List<String[]> ciudades = new ArrayList<String[]>();
List<String[]> caracteristicas = new ArrayList<String[]>();
List<String> carSeleccionadas = new ArrayList<String>();
Map<String,String> carCantidades = new HashMap<String,String>();

// Imágenes existentes: {id, url, es_principal, orden}
List<String[]> imgsBD = new ArrayList<String[]>();
// Imágenes para mostrar: {key, url, tipo} con tipo = "exist" | "nuevo"
List<String[]> imgsDisplay = new ArrayList<String[]>();
String imgPrincipalKey = "";
Set<String> elimKeys = new HashSet<String>();

boolean esPost = "POST".equalsIgnoreCase(request.getMethod());

if (errorConexion != null) {
    mensajeError = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT id_inmobiliaria FROM inmobiliaria WHERE id_usuario = ? LIMIT 1");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            idInmobiliaria = Integer.valueOf(rs.getInt("id_inmobiliaria"));
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement("SELECT id_tipo, nombre FROM tipo_propiedad ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            tipos.add(new String[] { String.valueOf(rs.getInt("id_tipo")), rs.getString("nombre") });
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement("SELECT id_ciudad, nombre FROM ciudad ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            ciudades.add(new String[] { String.valueOf(rs.getInt("id_ciudad")), rs.getString("nombre") });
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement("SELECT id_caracteristica, nombre FROM caracteristica ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            caracteristicas.add(new String[] { String.valueOf(rs.getInt("id_caracteristica")), rs.getString("nombre") });
        }
        cerrar(rs, ps);

        if (idPropiedad <= 0) {
            mensajeError = "Propiedad no especificada.";
        } else {
            // Carga la propiedad SÓLO si pertenece a la inmobiliaria del usuario autenticado
            ps = conexion.prepareStatement(
                "SELECT p.titulo, p.descripcion, p.precio, p.area_m2, p.num_habitaciones, p.num_banos, " +
                "p.estado, p.direccion, p.matricula_inmobiliaria, p.id_tipo, p.id_ciudad " +
                "FROM propiedad p " +
                "WHERE p.id_propiedad = ? AND p.id_inmobiliaria = " +
                "(SELECT id_inmobiliaria FROM inmobiliaria WHERE id_usuario = ? LIMIT 1)");
            ps.setInt(1, idPropiedad);
            ps.setInt(2, idUsuarioSesion);
            rs = ps.executeQuery();
            if (rs.next()) {
                encontrada = true;
                fTitulo = rs.getString("titulo");
                fDescripcion = rs.getString("descripcion");
                if (fDescripcion == null) fDescripcion = "";
                BigDecimal precioBd = rs.getBigDecimal("precio");
                fPrecio = precioBd == null ? "" : precioBd.toPlainString();
                BigDecimal areaBd = rs.getBigDecimal("area_m2");
                fArea = areaBd == null ? "" : areaBd.toPlainString();
                fHabitaciones = String.valueOf(rs.getInt("num_habitaciones"));
                fBanos = String.valueOf(rs.getInt("num_banos"));
                fEstado = rs.getString("estado");
                fDireccion = rs.getString("direccion");
                fMatricula = rs.getString("matricula_inmobiliaria");
                fTipo = String.valueOf(rs.getInt("id_tipo"));
                fCiudad = String.valueOf(rs.getInt("id_ciudad"));
                tituloPagina = "Editar: " + rs.getString("titulo");
            } else {
                mensajeError = "Propiedad no encontrada o no autorizada.";
            }
            cerrar(rs, ps);

            if (encontrada) {
                ps = conexion.prepareStatement(
                    "SELECT id_imagen, url_imagen, es_principal, orden FROM imagen_propiedad " +
                    "WHERE id_propiedad = ? ORDER BY es_principal DESC, orden");
                ps.setInt(1, idPropiedad);
                rs = ps.executeQuery();
                while (rs.next()) {
                    imgsBD.add(new String[] {
                        String.valueOf(rs.getInt("id_imagen")),
                        rs.getString("url_imagen"),
                        String.valueOf(rs.getInt("es_principal")),
                        String.valueOf(rs.getInt("orden"))
                    });
                }
                cerrar(rs, ps);

                ps = conexion.prepareStatement(
                    "SELECT pc.id_caracteristica, pc.cantidad FROM propiedad_caracteristica pc " +
                    "WHERE pc.id_propiedad = ?");
                ps.setInt(1, idPropiedad);
                rs = ps.executeQuery();
                while (rs.next()) {
                    String idC = String.valueOf(rs.getInt("id_caracteristica"));
                    carSeleccionadas.add(idC);
                    carCantidades.put(idC, String.valueOf(rs.getInt("cantidad")));
                }
            }
        }
    } catch (SQLException ex) {
        if (idPropiedad <= 0) {
            mensajeError = "No se pudo consultar la propiedad. Inténtalo nuevamente.";
        } else {
            mensajeError = "Propiedad no encontrada o no autorizada.";
        }
    } finally {
        cerrar(rs, ps);
    }
}

// Construye la lista de filas de imágenes para mostrar (existentes + hasta 3 en total)
for (String[] img : imgsBD) {
    imgsDisplay.add(new String[] { img[0], img[1], "exist" });
}
int huecos = MAX_IMAGENES - imgsBD.size();
for (int i = 1; i <= huecos; i++) {
    imgsDisplay.add(new String[] { "nueva_" + i, "", "nuevo" });
}

if (!esPost) {
    for (String[] img : imgsBD) {
        if ("1".equals(img[2])) { imgPrincipalKey = img[0]; break; }
    }
}

boolean guardar = false;

if (esPost) {
    fTitulo   = limpiar(request.getParameter("titulo"));
    fTipo     = limpiar(request.getParameter("id_tipo"));
    fCiudad   = limpiar(request.getParameter("id_ciudad"));
    fDireccion = limpiar(request.getParameter("direccion"));
    fMatricula = limpiar(request.getParameter("matricula_inmobiliaria"));
    fPrecio   = limpiar(request.getParameter("precio"));
    fArea     = limpiar(request.getParameter("area_m2"));
    fHabitaciones = limpiar(request.getParameter("num_habitaciones"));
    fBanos    = limpiar(request.getParameter("num_banos"));
    fEstado   = limpiar(request.getParameter("estado"));
    fDescripcion = request.getParameter("descripcion");
    if (fDescripcion == null) fDescripcion = "";

    carSeleccionadas = new ArrayList<String>();
    carCantidades = new HashMap<String,String>();
    String[] carVals = request.getParameterValues("caracteristicas");
    if (carVals != null) {
        for (String cv : carVals) {
            String idC = cv.trim();
            if (idC.isEmpty()) continue;
            carSeleccionadas.add(idC);
            carCantidades.put(idC, limpiar(request.getParameter("cantidad_" + idC)));
        }
    }

    imgPrincipalKey = limpiar(request.getParameter("img_principal"));
    String[] elimVals = request.getParameterValues("img_eliminar");
    elimKeys = new HashSet<String>();
    if (elimVals != null) {
        for (String ev : elimVals) elimKeys.add(ev.trim());
    }
    for (String[] fila : imgsDisplay) {
        fila[1] = limpiar(request.getParameter("img_url_" + fila[0]));
    }

    if (!encontrada) {
        mensajeError = "Propiedad no encontrada o no autorizada.";
    } else {
        List<String> errores = new ArrayList<String>();

        if (fTitulo.isEmpty()) errores.add("El título es obligatorio.");
        else if (fTitulo.length() > 200) errores.add("El título debe tener máximo 200 caracteres.");

        if (fTipo.isEmpty()) errores.add("Selecciona el tipo de propiedad.");
        else { try { Integer.parseInt(fTipo); } catch (NumberFormatException ex) { errores.add("El tipo de propiedad no es válido."); } }

        if (fCiudad.isEmpty()) errores.add("Selecciona la ciudad.");
        else { try { Integer.parseInt(fCiudad); } catch (NumberFormatException ex) { errores.add("La ciudad no es válida."); } }

        if (fDireccion.isEmpty()) errores.add("La dirección es obligatoria.");
        else if (fDireccion.length() > 255) errores.add("La dirección debe tener máximo 255 caracteres.");

        if (fMatricula.isEmpty()) errores.add("La matrícula inmobiliaria es obligatoria.");
        else if (fMatricula.length() > 50) errores.add("La matrícula debe tener máximo 50 caracteres.");

        BigDecimal vPrecio = null;
        if (fPrecio.isEmpty()) errores.add("El precio es obligatorio.");
        else {
            vPrecio = parseDecimal(fPrecio);
            if (vPrecio == null) errores.add("El precio no es un número válido.");
            else if (vPrecio.signum() <= 0) errores.add("El precio debe ser mayor que cero.");
        }

        BigDecimal vArea = null;
        if (!fArea.isEmpty()) {
            vArea = parseDecimal(fArea);
            if (vArea == null) errores.add("El área no es un número válido.");
            else if (vArea.signum() < 0) errores.add("El área no puede ser negativa.");
        }

        Integer vHab = null;
        if (!fHabitaciones.isEmpty()) {
            vHab = parseEntero(fHabitaciones);
            if (!esEnteroValido(vHab)) errores.add("El número de habitaciones debe ser un entero mayor o igual a cero.");
        }

        Integer vBanos = null;
        if (!fBanos.isEmpty()) {
            vBanos = parseEntero(fBanos);
            if (!esEnteroValido(vBanos)) errores.add("El número de baños debe ser un entero mayor o igual a cero.");
        }

        String vEstado = "DISPONIBLE";
        if (!fEstado.isEmpty()) {
            boolean valido = false;
            for (String es : estados) { if (es.equals(fEstado)) { valido = true; break; } }
            if (valido) vEstado = fEstado;
        }

        for (String idC : carSeleccionadas) {
            String cant = carCantidades.get(idC);
            Integer cVal = parseEntero(cant == null ? "1" : cant);
            if (!esEnteroValido(cVal) || cVal.intValue() < 1) {
                errores.add("La cantidad de cada característica debe ser un entero mayor o igual a 1.");
                break;
            }
        }

        for (String[] fila : imgsDisplay) {
            boolean esExistente = "exist".equals(fila[2]);
            boolean marcadaEliminar = esExistente && elimKeys.contains(fila[0]);
            if (esExistente && !marcadaEliminar) {
                if (fila[1].isEmpty()) {
                    errores.add("La URL de una imagen existente no puede quedar vacía. Usa la casilla Eliminar si quieres quitarla.");
                    break;
                }
            }
            if (fila[1].length() > 500) {
                errores.add("La URL de una imagen supera los 500 caracteres.");
                break;
            }
        }

        if (errores.isEmpty()) {
            if (idInmobiliaria == null || conexion == null) {
                mensajeError = "No se pudo actualizar la propiedad: no tienes una inmobiliaria asociada o no hay conexión con la base de datos.";
            } else {
                guardar = true;
            }
        } else {
            StringBuilder sb = new StringBuilder();
            for (String e : errores) sb.append(e).append("<br>");
            mensajeError = sb.toString();
        }
    }
}

if (guardar) {
    PreparedStatement psU = null;
    ResultSet rsU = null;
    PreparedStatement psAud = null;
    try {
        conexion.setAutoCommit(false);

        String sql = "UPDATE propiedad SET id_tipo = ?, id_ciudad = ?, titulo = ?, descripcion = ?, " +
            "precio = ?, area_m2 = ?, num_habitaciones = ?, num_banos = ?, direccion = ?, " +
            "matricula_inmobiliaria = ?, estado = ? " +
            "WHERE id_propiedad = ? AND id_inmobiliaria = ?";
        psU = conexion.prepareStatement(sql);
        psU.setInt(1, Integer.parseInt(fTipo));
        psU.setInt(2, Integer.parseInt(fCiudad));
        psU.setString(3, fTitulo);
        if (fDescripcion.trim().isEmpty()) {
            psU.setNull(4, Types.LONGVARCHAR);
        } else {
            psU.setString(4, fDescripcion.trim());
        }
        BigDecimal vPrecio = parseDecimal(fPrecio);
        psU.setBigDecimal(5, vPrecio);
        BigDecimal vArea = fArea.isEmpty() ? null : parseDecimal(fArea);
        if (vArea == null) {
            psU.setNull(6, Types.DECIMAL);
        } else {
            psU.setBigDecimal(6, vArea);
        }
        Integer vHab = fHabitaciones.isEmpty() ? Integer.valueOf(0) : parseEntero(fHabitaciones);
        psU.setInt(7, vHab == null ? 0 : vHab.intValue());
        Integer vBanos = fBanos.isEmpty() ? Integer.valueOf(0) : parseEntero(fBanos);
        psU.setInt(8, vBanos == null ? 0 : vBanos.intValue());
        psU.setString(9, fDireccion);
        psU.setString(10, fMatricula);
        String vEstado = "DISPONIBLE";
        for (String es : estados) { if (es.equals(fEstado)) { vEstado = es; break; } }
        psU.setString(11, vEstado);
        psU.setInt(12, idPropiedad);
        psU.setInt(13, idInmobiliaria.intValue());
        int actualizadas = psU.executeUpdate();
        if (actualizadas == 0) {
            deshacer(conexion);
            mensajeError = "Propiedad no encontrada o no autorizada.";
        } else {
            cerrar(null, psU);

            PreparedStatement psDel = conexion.prepareStatement(
                "DELETE FROM propiedad_caracteristica WHERE id_propiedad = ?");
            psDel.setInt(1, idPropiedad);
            psDel.executeUpdate();
            cerrar(null, psDel);

            if (!carSeleccionadas.isEmpty()) {
                PreparedStatement psCar = conexion.prepareStatement(
                    "INSERT INTO propiedad_caracteristica (id_propiedad, id_caracteristica, cantidad) VALUES (?,?,?)");
                for (String idC : carSeleccionadas) {
                    int cant = 1;
                    Integer cVal = parseEntero(carCantidades.get(idC) == null ? "1" : carCantidades.get(idC));
                    if (cVal != null && cVal.intValue() >= 1) cant = cVal.intValue();
                    psCar.setInt(1, idPropiedad);
                    psCar.setInt(2, Integer.parseInt(idC));
                    psCar.setInt(3, cant);
                    psCar.addBatch();
                }
                psCar.executeBatch();
                cerrar(null, psCar);
            }

            // Imágenes: eliminar, actualizar o insertar
            Map<String,String> principalBD = new HashMap<String,String>();
            for (String[] img : imgsBD) {
                principalBD.put(img[0], img[2]);
            }
            boolean hayPrincipal = false;
            for (String[] img : imgsBD) {
                if ("1".equals(img[2])) { hayPrincipal = true; break; }
            }
            boolean principalDefinida = !imgPrincipalKey.isEmpty();
            int nuevoOrden = imgsBD.size() + 1;

            for (String[] fila : imgsDisplay) {
                String key = fila[0];
                String url = fila[1];
                boolean esExistente = "exist".equals(fila[2]);
                if (esExistente) {
                    if (elimKeys.contains(key)) {
                        PreparedStatement psDelImg = conexion.prepareStatement(
                            "DELETE FROM imagen_propiedad WHERE id_imagen = ? AND id_propiedad = ?");
                        psDelImg.setInt(1, Integer.parseInt(key));
                        psDelImg.setInt(2, idPropiedad);
                        psDelImg.executeUpdate();
                        cerrar(null, psDelImg);
                    } else {
                        int esPrincipal = 0;
                        if (principalDefinida) {
                            if (imgPrincipalKey.equals(key)) esPrincipal = 1;
                        } else if ("1".equals(principalBD.get(key))) {
                            esPrincipal = 1;
                        }
                        PreparedStatement psUpdImg = conexion.prepareStatement(
                            "UPDATE imagen_propiedad SET url_imagen = ?, es_principal = ? WHERE id_imagen = ? AND id_propiedad = ?");
                        psUpdImg.setString(1, url);
                        psUpdImg.setInt(2, esPrincipal);
                        psUpdImg.setInt(3, Integer.parseInt(key));
                        psUpdImg.setInt(4, idPropiedad);
                        psUpdImg.executeUpdate();
                        cerrar(null, psUpdImg);
                    }
                } else {
                    if (url.isEmpty()) continue;
                    int esPrincipal = 0;
                    if (principalDefinida) {
                        if (imgPrincipalKey.equals(key)) esPrincipal = 1;
                    } else if (!hayPrincipal && nuevoOrden == imgsBD.size() + 1) {
                        esPrincipal = 1;
                    }
                    PreparedStatement psNuevaImg = conexion.prepareStatement(
                        "INSERT INTO imagen_propiedad (id_propiedad, url_imagen, es_principal, orden) VALUES (?,?,?,?)");
                    psNuevaImg.setInt(1, idPropiedad);
                    psNuevaImg.setString(2, url);
                    psNuevaImg.setInt(3, esPrincipal);
                    psNuevaImg.setInt(4, nuevoOrden);
                    psNuevaImg.executeUpdate();
                    cerrar(null, psNuevaImg);
                    nuevoOrden++;
                }
            }

            // Registro de auditoría (misma transacción)
            psAud = conexion.prepareStatement(
                "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                "VALUES (?, ?, ?, ?, ?, ?)");
            psAud.setInt(1, idUsuarioSesion.intValue());
            psAud.setString(2, "propiedad");
            psAud.setInt(3, idPropiedad);
            psAud.setString(4, "UPDATE");
            psAud.setString(5, "Modificación de propiedad: " + fTitulo);
            String ipEditar = ipCliente(request);
            if (ipEditar == null) {
                psAud.setNull(6, Types.VARCHAR);
            } else {
                psAud.setString(6, ipEditar);
            }
            psAud.executeUpdate();
            cerrar(null, psAud);

            conexion.commit();
            response.sendRedirect(ctx + "/inmobiliaria/propiedades.jsp?editada=1");
            return;
        }
    } catch (SQLException ex) {
        deshacer(conexion);
        if (ex instanceof SQLIntegrityConstraintViolationException) {
            mensajeError = "La matrícula inmobiliaria ingresada ya está registrada en otra propiedad.";
        } else {
            mensajeError = "No se pudo actualizar la propiedad. Inténtalo nuevamente.";
        }
    } finally {
        cerrar(rsU, psU, psAud, conexion);
    }
} else {
    cerrar(null, null, conexion);
}

boolean mostrarFormulario = encontrada && idPropiedad > 0;
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-3">
    <h1 class="mb-0">Editar propiedad</h1>
    <a href="<%= ctx %>/inmobiliaria/propiedades.jsp" class="btn btn-outline-secondary">Volver al listado</a>
</div>

<% if (mensajeError != null) { %>
<div class="alert alert-danger" role="alert"><%= mensajeError %></div>
<% } %>

<% if (!mostrarFormulario) { %>
<a href="<%= ctx %>/inmobiliaria/propiedades.jsp" class="btn btn-outline-secondary">Ir a mis propiedades</a>
<% } else { %>

<form method="post" action="<%= ctx %>/inmobiliaria/editar-propiedad.jsp" class="row g-4">
    <input type="hidden" name="id" value="<%= idPropiedad %>">

    <div class="col-12 col-lg-8">
        <div class="card shadow-sm">
            <div class="card-header bg-white fw-bold">Datos generales</div>
            <div class="card-body row g-3">
                <div class="col-12">
                    <label for="titulo" class="form-label">Título *</label>
                    <input type="text" class="form-control" id="titulo" name="titulo" required maxlength="200"
                           value="<%= escapar(fTitulo) %>">
                </div>
                <div class="col-12 col-md-6">
                    <label for="id_tipo" class="form-label">Tipo de propiedad *</label>
                    <select class="form-select" id="id_tipo" name="id_tipo" required>
                        <option value="">-- Selecciona --</option>
                        <% for (String[] tp : tipos) { %>
                        <option value="<%= tp[0] %>" <%= fTipo != null && fTipo.equals(tp[0]) ? "selected" : "" %>><%= escapar(tp[1]) %></option>
                        <% } %>
                    </select>
                </div>
                <div class="col-12 col-md-6">
                    <label for="id_ciudad" class="form-label">Ciudad *</label>
                    <select class="form-select" id="id_ciudad" name="id_ciudad" required>
                        <option value="">-- Selecciona --</option>
                        <% for (String[] cd : ciudades) { %>
                        <option value="<%= cd[0] %>" <%= fCiudad != null && fCiudad.equals(cd[0]) ? "selected" : "" %>><%= escapar(cd[1]) %></option>
                        <% } %>
                    </select>
                </div>
                <div class="col-12">
                    <label for="direccion" class="form-label">Dirección *</label>
                    <input type="text" class="form-control" id="direccion" name="direccion" required maxlength="255"
                           value="<%= escapar(fDireccion) %>">
                </div>
                <div class="col-12 col-md-6">
                    <label for="matricula_inmobiliaria" class="form-label">Matrícula inmobiliaria *</label>
                    <input type="text" class="form-control" id="matricula_inmobiliaria" name="matricula_inmobiliaria"
                           required maxlength="50" value="<%= escapar(fMatricula) %>">
                </div>
                <div class="col-12 col-md-6">
                    <label for="estado" class="form-label">Estado</label>
                    <select class="form-select" id="estado" name="estado">
                        <% for (String es : estados) { %>
                        <option value="<%= es %>" <%= fEstado != null && fEstado.equals(es) ? "selected" : "" %>><%= es %></option>
                        <% } %>
                    </select>
                </div>
                <div class="col-12 col-md-4">
                    <label for="precio" class="form-label">Precio (COP) *</label>
                    <input type="number" step="0.01" min="0" class="form-control" id="precio" name="precio" required
                           value="<%= escapar(fPrecio) %>">
                </div>
                <div class="col-12 col-md-4">
                    <label for="area_m2" class="form-label">Área (m²)</label>
                    <input type="number" step="0.01" min="0" class="form-control" id="area_m2" name="area_m2"
                           value="<%= escapar(fArea) %>">
                </div>
                <div class="col-12 col-md-4">
                    <label for="num_habitaciones" class="form-label">Habitaciones</label>
                    <input type="number" min="0" step="1" class="form-control" id="num_habitaciones"
                           name="num_habitaciones" value="<%= escapar(fHabitaciones) %>">
                </div>
                <div class="col-12 col-md-6">
                    <label for="num_banos" class="form-label">Baños</label>
                    <input type="number" min="0" step="1" class="form-control" id="num_banos" name="num_banos"
                           value="<%= escapar(fBanos) %>">
                </div>
                <div class="col-12 col-md-6">
                    <label for="descripcion" class="form-label">Descripción</label>
                    <textarea class="form-control" id="descripcion" name="descripcion" rows="4"><%= escapar(fDescripcion) %></textarea>
                </div>
            </div>
        </div>
    </div>

    <div class="col-12 col-lg-4">
        <div class="card shadow-sm mb-4">
            <div class="card-header bg-white fw-bold">Características</div>
            <div class="card-body">
                <p class="text-muted small">Marca las características existentes. Si la seleccionas podrás indicar la cantidad.</p>
                <% for (String[] car : caracteristicas) { %>
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox"
                           value="<%= car[0] %>" id="caract_<%= car[0] %>" name="caracteristicas"
                           <%= carSeleccionadas.contains(car[0]) ? "checked" : "" %>>
                    <label class="form-check-label" for="caract_<%= car[0] %>"><%= escapar(car[1]) %></label>
                    <input type="number" min="1" step="1" class="form-control form-control-sm d-inline-block mt-1"
                           style="width: 110px;" name="cantidad_<%= car[0] %>"
                           value="<%= carCantidades.containsKey(car[0]) ? escapar(carCantidades.get(car[0])) : "1" %>">
                </div>
                <% } %>
            </div>
        </div>

        <div class="card shadow-sm">
            <div class="card-header bg-white fw-bold">Imágenes</div>
            <div class="card-body">
                <p class="text-muted small">Edita las URLs registradas, marca una como principal o elimina imágenes (sin sistema de subida de archivos).</p>
                <% for (String[] fila : imgsDisplay) { %>
                <div class="mb-3">
                    <label class="form-label small"><%= "exist".equals(fila[2]) ? "Imagen " + (imgsDisplay.indexOf(fila) + 1) : "Imagen nueva " + (imgsDisplay.indexOf(fila) + 1) %></label>
                    <div class="input-group">
                        <span class="input-group-text" title="Imagen principal">
                            <input class="form-check-input mt-0" type="radio" name="img_principal"
                                   value="<%= fila[0] %>"
                                   <%= imgPrincipalKey.equals(fila[0]) ? "checked" : "" %>>
                        </span>
                        <input type="text" class="form-control" name="img_url_<%= fila[0] %>"
                               maxlength="500" value="<%= escapar(fila[1]) %>"
                               placeholder="https://... o /img/props/...">
                    </div>
                    <% if ("exist".equals(fila[2])) { %>
                    <div class="form-check mt-1">
                        <input class="form-check-input" type="checkbox" id="elim_<%= fila[0] %>"
                               name="img_eliminar" value="<%= fila[0] %>"
                               <%= elimKeys.contains(fila[0]) ? "checked" : "" %>>
                        <label class="form-check-label small text-danger" for="elim_<%= fila[0] %>">Eliminar esta imagen</label>
                    </div>
                    <% } %>
                </div>
                <% } %>
            </div>
        </div>
    </div>

    <div class="col-12 d-flex gap-2">
        <button type="submit" class="btn btn-primary">Guardar cambios</button>
        <a href="<%= ctx %>/inmobiliaria/propiedades.jsp" class="btn btn-outline-secondary">Cancelar</a>
    </div>
</form>

<% } %>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>