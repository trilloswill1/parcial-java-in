<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.time.LocalDate, java.time.format.DateTimeParseException" %>
<%!
private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}
%>
<%
String[] rolesPermitidos = { "ADMINISTRADOR", "CLIENTE", "INMOBILIARIA" };
String tituloPagina = "Mi Perfil";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

boolean esPost = "POST".equalsIgnoreCase(request.getMethod());

String dDireccion       = limpiar(request.getParameter("direccion"));
String dCiudad          = limpiar(request.getParameter("ciudad_residencia"));
String dFecha           = limpiar(request.getParameter("fecha_nacimiento"));
String dDocumento       = limpiar(request.getParameter("documento_identidad"));
String dFotoUrl         = limpiar(request.getParameter("foto_url"));

String mensajeError = null;
String mensajeOk    = null;
if ("ok".equals(limpiar(request.getParameter("guardado")))) {
    mensajeOk = "Tu perfil se guardó correctamente.";
}

if (esPost) {
    if (!dFecha.isEmpty()) {
        LocalDate fecha = null;
        try { fecha = LocalDate.parse(dFecha); } catch (DateTimeParseException ignorada) { fecha = null; }
        if (fecha == null) {
            mensajeError = "La fecha de nacimiento no tiene un formato válido.";
        } else if (fecha.isAfter(LocalDate.now())) {
            mensajeError = "La fecha de nacimiento no puede ser futura.";
        }
    }
    if (mensajeError == null && !dDocumento.isEmpty() && !dDocumento.matches("[0-9]+")) {
        mensajeError = "El documento de identidad debe contener solo números.";
    }
}

if (esPost && mensajeError == null && errorConexion != null) {
    mensajeError = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
}

if (esPost && mensajeError == null && errorConexion == null) {
    PreparedStatement ps = null;
    ResultSet rs = null;
    boolean exito = false;
    try {
        ps = conexion.prepareStatement("SELECT 1 FROM perfil WHERE id_usuario = ?");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();
        boolean existe = rs.next();
        cerrar(rs, ps);

        if (existe) {
            ps = conexion.prepareStatement(
                "UPDATE perfil SET direccion = ?, ciudad_residencia = ?, fecha_nacimiento = ?, " +
                "documento_identidad = ?, foto_url = ? WHERE id_usuario = ?");
            ps.setString(1, dDireccion.isEmpty() ? null : dDireccion);
            ps.setString(2, dCiudad.isEmpty() ? null : dCiudad);
            if (dFecha.isEmpty()) {
                ps.setNull(3, Types.DATE);
            } else {
                ps.setDate(3, Date.valueOf(dFecha));
            }
            ps.setString(4, dDocumento.isEmpty() ? null : dDocumento);
            ps.setString(5, dFotoUrl.isEmpty() ? null : dFotoUrl);
            ps.setInt(6, idUsuarioSesion);
            ps.executeUpdate();
        } else {
            ps = conexion.prepareStatement(
                "INSERT INTO perfil (id_usuario, direccion, ciudad_residencia, fecha_nacimiento, " +
                "documento_identidad, foto_url) VALUES (?, ?, ?, ?, ?, ?)");
            ps.setInt(1, idUsuarioSesion);
            ps.setString(2, dDireccion.isEmpty() ? null : dDireccion);
            ps.setString(3, dCiudad.isEmpty() ? null : dCiudad);
            if (dFecha.isEmpty()) {
                ps.setNull(4, Types.DATE);
            } else {
                ps.setDate(4, Date.valueOf(dFecha));
            }
            ps.setString(5, dDocumento.isEmpty() ? null : dDocumento);
            ps.setString(6, dFotoUrl.isEmpty() ? null : dFotoUrl);
            ps.executeUpdate();
        }
        exito = true;
    } catch (SQLException ex) {
        mensajeError = "No se pudo guardar tu perfil. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, ps, conexion);
    }
    if (exito) {
        response.sendRedirect(ctx + "/mi-perfil.jsp?guardado=ok");
        return;
    }
}

boolean cargarDeBD = !(esPost && mensajeError != null);
String vDireccion = dDireccion;
String vCiudad = dCiudad;
String vFecha = dFecha;
String vDocumento = dDocumento;
String vFotoUrl = dFotoUrl;
String correo = null, nombre = null, apellido = null;

if (errorConexion != null) {
    if (mensajeError == null) mensajeError = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement("SELECT correo, nombre, apellido FROM usuario WHERE id_usuario = ?");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            correo = rs.getString("correo");
            nombre = rs.getString("nombre");
            apellido = rs.getString("apellido");
        }
        cerrar(rs, ps);

        if (cargarDeBD) {
            ps = conexion.prepareStatement(
                "SELECT direccion, ciudad_residencia, fecha_nacimiento, documento_identidad, foto_url " +
                "FROM perfil WHERE id_usuario = ?");
            ps.setInt(1, idUsuarioSesion);
            rs = ps.executeQuery();
            if (rs.next()) {
                String t = rs.getString("direccion");
                vDireccion = t == null ? "" : t;
                t = rs.getString("ciudad_residencia");
                vCiudad = t == null ? "" : t;
                java.sql.Date fn = rs.getDate("fecha_nacimiento");
                vFecha = fn == null ? "" : fn.toLocalDate().toString();
                t = rs.getString("documento_identidad");
                vDocumento = t == null ? "" : t;
                t = rs.getString("foto_url");
                vFotoUrl = t == null ? "" : t;
            }
        }
    } catch (SQLException ex) {
        if (mensajeError == null) mensajeError = "Ocurrió un error al cargar tu perfil.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-3">
    <h1 class="mb-0">Mi Perfil</h1>
    <%
    String rolPrincipal = (String) session.getAttribute("rol");
    String volverPanel = "/cliente/panel.jsp";
    if ("ADMINISTRADOR".equals(rolPrincipal)) {
        volverPanel = "/admin/panel.jsp";
    } else if ("INMOBILIARIA".equals(rolPrincipal)) {
        volverPanel = "/inmobiliaria/panel.jsp";
    }
    %>
    <a href="<%= ctx %><%= volverPanel %>" class="btn btn-outline-secondary btn-sm">Volver al panel</a>
</div>

<% if (mensajeOk != null) { %>
<div class="alert alert-success" role="alert"><%= escapar(mensajeOk) %></div>
<% } %>
<% if (mensajeError != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(mensajeError) %></div>
<% } %>

<div class="row">
    <div class="col-md-8 col-lg-6">
        <div class="card shadow-sm mb-4">
            <div class="card-body">
                <h5 class="card-title">Datos de la cuenta</h5>
                <p class="mb-1"><strong>Correo:</strong> <%= escapar(correo) %></p>
                <p class="mb-0">
                    <strong>Nombre:</strong> <%= escapar(nombre) %> <%= escapar(apellido) %>
                </p>
            </div>
        </div>

        <form method="post" action="<%= ctx %>/mi-perfil.jsp" class="row g-3">

            <div class="col-12">
                <label for="direccion" class="form-label">Dirección</label>
                <input type="text" class="form-control" id="direccion" name="direccion" maxlength="255"
                       value="<%= escapar(vDireccion) %>" placeholder="Tu dirección de residencia">
            </div>

            <div class="col-12">
                <label for="ciudad_residencia" class="form-label">Ciudad de residencia</label>
                <input type="text" class="form-control" id="ciudad_residencia" name="ciudad_residencia"
                       maxlength="100" value="<%= escapar(vCiudad) %>" placeholder="Ej: Bucaramanga">
            </div>

            <div class="col-md-6">
                <label for="fecha_nacimiento" class="form-label">Fecha de nacimiento</label>
                <input type="date" class="form-control" id="fecha_nacimiento" name="fecha_nacimiento"
                       value="<%= escapar(vFecha) %>">
            </div>

            <div class="col-md-6">
                <label for="documento_identidad" class="form-label">Documento de identidad</label>
                <input type="text" class="form-control" id="documento_identidad" name="documento_identidad"
                       maxlength="30" value="<%= escapar(vDocumento) %>" placeholder="Solo números"
                       inputmode="numeric">
            </div>

            <div class="col-12">
                <label for="foto_url" class="form-label">URL de la foto</label>
                <input type="text" class="form-control" id="foto_url" name="foto_url" maxlength="500"
                       value="<%= escapar(vFotoUrl) %>" placeholder="https://.../foto.jpg">
            </div>

            <div class="col-12 d-grid gap-2">
                <button type="submit" class="btn btn-primary">Guardar cambios</button>
            </div>
        </form>
    </div>
</div>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>