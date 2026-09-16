<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.math.BigDecimal" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.util.HashMap, java.util.Map" %>
<%!
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
String tituloPagina = "Registrar Propiedad";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
String[] estados = { "DISPONIBLE", "RESERVADA", "VENDIDA", "ALQUILADA" };

// Valores del formulario (sticky)
String fTitulo = null, fTipo = "", fCiudad = "", fDireccion = "", fMatricula = "";
String fPrecio = "", fArea = "", fHabitaciones = "", fBanos = "", fEstado = "DISPONIBLE", fDescripcion = "";

// Catálogos para selects
List<String[]> tipos = new ArrayList<String[]>();
List<String[]> ciudades = new ArrayList<String[]>();
List<String[]> caracteristicas = new ArrayList<String[]>();

Integer idInmobiliaria = null;
String mensajeError = null;

// Imágenes: 3 filas nuevas de URLs
String[] imagenKeys = { "nueva_1", "nueva_2", "nueva_3" };
String[] imagenUrls = { "", "", "" };
String imgPrincipalKey = "";

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
    } catch (SQLException ex) {
        mensajeError = "No se pudieron cargar los datos necesarios para el formulario.";
    } finally {
        cerrar(rs, ps);
    }
}

List<String> carSeleccionadas = new ArrayList<String>();
Map<String,String> carCantidades = new HashMap<String,String>();

if (esPost) {
    fTitulo   = limpiar(request.getParameter("titulo"));
    fTipo     = limpiar(request.getParameter("id_tipo"));
    fCiudad   = limpiar(request.getParameter("id_ciudad"));
    fDireccion= limpiar(request.getParameter("direccion"));
    fMatricula= limpiar(request.getParameter("matricula_inmobiliaria"));
    fPrecio   = limpiar(request.getParameter("precio"));
    fArea     = limpiar(request.getParameter("area_m2"));
    fHabitaciones = limpiar(request.getParameter("num_habitaciones"));
    fBanos    = limpiar(request.getParameter("num_banos"));
    fEstado   = limpiar(request.getParameter("estado"));
    fDescripcion = request.getParameter("descripcion");
    if (fDescripcion == null) fDescripcion = "";

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
    for (int idx = 0; idx < imagenKeys.length; idx++) {
        imagenUrls[idx] = limpiar(request.getParameter("img_url_" + imagenKeys[idx]));
    }

    // ----- Validaciones -----
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

    for (int idx = 0; idx < imagenKeys.length; idx++) {
        if (imagenUrls[idx].length() > 500) {
            errores.add("La URL de una imagen supera los 500 caracteres.");
            break;
        }
    }

    boolean guardar = false;
    if (errores.isEmpty()) {
        if (idInmobiliaria == null || conexion == null) {
            mensajeError = "No se pudo guardar la propiedad: no tienes una inmobiliaria asociada o no hay conexión con la base de datos.";
        } else {
            guardar = true;
        }
    } else {
        StringBuilder sb = new StringBuilder();
        for (String e : errores) sb.append(e).append("<br>");
        mensajeError = sb.toString();
    }

    if (guardar) {
        PreparedStatement psI = null;
        ResultSet rsI = null;
        PreparedStatement psAud = null;
        try {
            conexion.setAutoCommit(false);

            String sql = "INSERT INTO propiedad " +
                "(id_inmobiliaria, id_tipo, id_ciudad, titulo, descripcion, precio, area_m2, " +
                "num_habitaciones, num_banos, direccion, matricula_inmobiliaria, estado) " +
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)";
            psI = conexion.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            psI.setInt(1, idInmobiliaria.intValue());
            psI.setInt(2, Integer.parseInt(fTipo));
            psI.setInt(3, Integer.parseInt(fCiudad));
            psI.setString(4, fTitulo);
            if (fDescripcion.trim().isEmpty()) {
                psI.setNull(5, Types.LONGVARCHAR);
            } else {
                psI.setString(5, fDescripcion.trim());
            }
            psI.setBigDecimal(6, vPrecio);
            if (vArea == null) {
                psI.setNull(7, Types.DECIMAL);
            } else {
                psI.setBigDecimal(7, vArea);
            }
            psI.setInt(8, vHab == null ? 0 : vHab.intValue());
            psI.setInt(9, vBanos == null ? 0 : vBanos.intValue());
            psI.setString(10, fDireccion);
            psI.setString(11, fMatricula);
            psI.setString(12, vEstado);
            psI.executeUpdate();

            rsI = psI.getGeneratedKeys();
            int nuevoId = -1;
            if (rsI.next()) nuevoId = rsI.getInt(1);
            cerrar(rsI, psI);

            if (!carSeleccionadas.isEmpty()) {
                PreparedStatement psCar = conexion.prepareStatement(
                    "INSERT INTO propiedad_caracteristica (id_propiedad, id_caracteristica, cantidad) VALUES (?,?,?)");
                for (String idC : carSeleccionadas) {
                    int cant = 1;
                    Integer cVal = parseEntero(carCantidades.get(idC) == null ? "1" : carCantidades.get(idC));
                    if (cVal != null && cVal.intValue() >= 1) cant = cVal.intValue();
                    psCar.setInt(1, nuevoId);
                    psCar.setInt(2, Integer.parseInt(idC));
                    psCar.setInt(3, cant);
                    psCar.addBatch();
                }
                psCar.executeBatch();
                cerrar(null, psCar);
            }

            int orden = 1;
            boolean principalDefinida = !imgPrincipalKey.isEmpty();
            PreparedStatement psImg = conexion.prepareStatement(
                "INSERT INTO imagen_propiedad (id_propiedad, url_imagen, es_principal, orden) VALUES (?,?,?,?)");
            boolean hayImagenes = false;
            for (int idx = 0; idx < imagenKeys.length; idx++) {
                String url = imagenUrls[idx];
                if (url.isEmpty()) continue;
                hayImagenes = true;
                int esPrincipal = (principalDefinida && imgPrincipalKey.equals(imagenKeys[idx])) ? 1 : 0;
                if (!principalDefinida && orden == 1) esPrincipal = 1;
                psImg.setInt(1, nuevoId);
                psImg.setString(2, url);
                psImg.setInt(3, esPrincipal);
                psImg.setInt(4, orden);
                psImg.addBatch();
                orden++;
            }
            if (hayImagenes) {
                psImg.executeBatch();
            }
            cerrar(null, psImg);

            // Registro de auditoría (misma transacción)
            psAud = conexion.prepareStatement(
                "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                "VALUES (?, ?, ?, ?, ?, ?)");
            psAud.setInt(1, idUsuarioSesion.intValue());
            psAud.setString(2, "propiedad");
            psAud.setInt(3, nuevoId);
            psAud.setString(4, "INSERT");
            psAud.setString(5, "Creación de propiedad: " + fTitulo);
            String ipCrear = ipCliente(request);
            if (ipCrear == null) {
                psAud.setNull(6, Types.VARCHAR);
            } else {
                psAud.setString(6, ipCrear);
            }
            psAud.executeUpdate();
            cerrar(null, psAud);

            conexion.commit();
            response.sendRedirect(ctx + "/inmobiliaria/propiedades.jsp?creada=1");
            return;
        } catch (SQLException ex) {
            deshacer(conexion);
            if (ex instanceof SQLIntegrityConstraintViolationException) {
                mensajeError = "La matrícula inmobiliaria ingresada ya está registrada en otra propiedad.";
            } else {
                mensajeError = "No se pudo guardar la propiedad. Inténtalo nuevamente.";
            }
        } finally {
            cerrar(rsI, psI, psAud, conexion);
        }
    } else {
        cerrar(null, null, conexion);
    }
} else {
    cerrar(null, null, conexion);
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-3">
    <h1 class="mb-0">Registrar propiedad</h1>
    <a href="<%= ctx %>/inmobiliaria/propiedades.jsp" class="btn btn-outline-secondary">Volver al listado</a>
</div>

<% if (mensajeError != null) { %>
<div class="alert alert-danger" role="alert"><%= mensajeError %></div>
<% } %>

<% if (idInmobiliaria == null && errorConexion == null) { %>
<div class="alert alert-warning" role="alert">
    Tu usuario aún no tiene una inmobiliaria asociada en el sistema. No puedes registrar propiedades.
</div>
<% } %>

<form method="post" action="<%= ctx %>/inmobiliaria/crear-propiedad.jsp" class="row g-4">
    <div class="col-12 col-lg-8">
        <div class="card shadow-sm">
            <div class="card-header bg-white fw-bold">Datos generales</div>
            <div class="card-body row g-3">
                <div class="col-12">
                    <label for="titulo" class="form-label">Título *</label>
                    <input type="text" class="form-control" id="titulo" name="titulo" required maxlength="200"
                           value="<%= escapar(fTitulo) %>" placeholder="Ej. Apartamento con vista al parque">
                </div>
                <div class="col-12 col-md-6">
                    <label for="id_tipo" class="form-label">Tipo de propiedad *</label>
                    <select class="form-select" id="id_tipo" name="id_tipo" required>
                        <option value="">-- Selecciona --</option>
                        <% for (String[] tp : tipos) { %>
                        <option value="<%= tp[0] %>" <%= fTipo.equals(tp[0]) ? "selected" : "" %>><%= escapar(tp[1]) %></option>
                        <% } %>
                    </select>
                </div>
                <div class="col-12 col-md-6">
                    <label for="id_ciudad" class="form-label">Ciudad *</label>
                    <select class="form-select" id="id_ciudad" name="id_ciudad" required>
                        <option value="">-- Selecciona --</option>
                        <% for (String[] cd : ciudades) { %>
                        <option value="<%= cd[0] %>" <%= fCiudad.equals(cd[0]) ? "selected" : "" %>><%= escapar(cd[1]) %></option>
                        <% } %>
                    </select>
                </div>
                <div class="col-12">
                    <label for="direccion" class="form-label">Dirección *</label>
                    <input type="text" class="form-control" id="direccion" name="direccion" required maxlength="255"
                           value="<%= escapar(fDireccion) %>" placeholder="Calle, carrera, conjunto o urbanización">
                </div>
                <div class="col-12 col-md-6">
                    <label for="matricula_inmobiliaria" class="form-label">Matrícula inmobiliaria *</label>
                    <input type="text" class="form-control" id="matricula_inmobiliaria" name="matricula_inmobiliaria"
                           required maxlength="50" value="<%= escapar(fMatricula) %>"
                           placeholder="Número único de matrícula">
                </div>
                <div class="col-12 col-md-6">
                    <label for="estado" class="form-label">Estado</label>
                    <select class="form-select" id="estado" name="estado">
                        <% for (String es : estados) { %>
                        <option value="<%= es %>" <%= fEstado.equals(es) ? "selected" : "" %>><%= es %></option>
                        <% } %>
                    </select>
                </div>
                <div class="col-12 col-md-4">
                    <label for="precio" class="form-label">Precio (COP) *</label>
                    <input type="number" step="0.01" min="0" class="form-control" id="precio" name="precio" required
                           value="<%= escapar(fPrecio) %>" placeholder="Ej. 280000000">
                </div>
                <div class="col-12 col-md-4">
                    <label for="area_m2" class="form-label">Área (m²)</label>
                    <input type="number" step="0.01" min="0" class="form-control" id="area_m2" name="area_m2"
                           value="<%= escapar(fArea) %>" placeholder="Ej. 120">
                </div>
                <div class="col-12 col-md-6">
                    <label for="num_habitaciones" class="form-label">Habitaciones</label>
                    <input type="number" min="0" step="1" class="form-control" id="num_habitaciones"
                           name="num_habitaciones" value="<%= escapar(fHabitaciones) %>" placeholder="Ej. 3">
                </div>
                <div class="col-12 col-md-6">
                    <label for="num_banos" class="form-label">Baños</label>
                    <input type="number" min="0" step="1" class="form-control" id="num_banos" name="num_banos"
                           value="<%= escapar(fBanos) %>" placeholder="Ej. 2">
                </div>
                <div class="col-12">
                    <label for="descripcion" class="form-label">Descripción</label>
                    <textarea class="form-control" id="descripcion" name="descripcion" rows="4"
                              placeholder="Describe la propiedad..."><%= escapar(fDescripcion) %></textarea>
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
                <p class="text-muted small">Registra las URLs de las imágenes (sin sistema de subida de archivos). Marca una como principal.</p>
                <% for (int idx = 0; idx < imagenKeys.length; idx++) { %>
                <div class="mb-3">
                    <label class="form-label small">Imagen <%= idx + 1 %></label>
                    <div class="input-group">
                        <span class="input-group-text">
                            <input class="form-check-input mt-0" type="radio" name="img_principal"
                                   value="<%= imagenKeys[idx] %>"
                                   <%= imgPrincipalKey.equals(imagenKeys[idx]) ? "checked" : "" %>>
                        </span>
                        <input type="text" class="form-control" name="img_url_<%= imagenKeys[idx] %>"
                               maxlength="500" value="<%= escapar(imagenUrls[idx]) %>"
                               placeholder="https://... o /img/props/...">
                    </div>
                </div>
                <% } %>
            </div>
        </div>
    </div>

    <div class="col-12 d-flex gap-2">
        <button type="submit" class="btn btn-success">Guardar propiedad</button>
        <a href="<%= ctx %>/inmobiliaria/propiedades.jsp" class="btn btn-outline-secondary">Cancelar</a>
    </div>
</form>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>