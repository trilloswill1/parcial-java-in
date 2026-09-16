<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%!
private static final String[] TIPOS_SOLICITUD = { "COMPRA", "ALQUILER" };
private static final String[] ESTADOS_SOLICITUD = { "EN_REVISION", "APROBADA", "RECHAZADA", "COMPLETADA" };
private static final String TARGET_INMO =
    "SELECT id_inmobiliaria FROM inmobiliaria WHERE id_usuario = ? LIMIT 1";

private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private String claseEstado(String estado) {
    if ("EN_REVISION".equals(estado)) return "bg-warning text-dark";
    if ("APROBADA".equals(estado))    return "bg-info text-dark";
    if ("RECHAZADA".equals(estado))   return "bg-danger";
    return "bg-success";
}

private String formatoFecha(Timestamp ts) {
    if (ts == null) return "";
    return new SimpleDateFormat("dd/MM/yyyy HH:mm").format(ts);
}
%>
<%
String[] rolesPermitidos = { "INMOBILIARIA" };
String tituloPagina = "Solicitudes de mi Inmobiliaria";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String filtroEstado = limpiar(request.getParameter("estado"));
boolean filtroEstadoValido = false;
for (String e : ESTADOS_SOLICITUD) {
    if (e.equals(filtroEstado)) { filtroEstadoValido = true; break; }
}
if (!filtroEstadoValido) filtroEstado = "";

String filtroTipo = limpiar(request.getParameter("tipo"));
boolean filtroTipoValido = false;
for (String t : TIPOS_SOLICITUD) {
    if (t.equals(filtroTipo)) { filtroTipoValido = true; break; }
}
if (!filtroTipoValido) filtroTipo = "";

String errorSolicitudes = null;
boolean errorSinInmobiliaria = false;
List<String[]> solicitudes = new ArrayList<String[]>();

if (errorConexion != null) {
    errorSolicitudes = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement psInmo = null;
    ResultSet rsInmo = null;
    boolean tieneInmobiliaria = false;
    try {
        psInmo = conexion.prepareStatement(TARGET_INMO);
        psInmo.setInt(1, idUsuarioSesion);
        rsInmo = psInmo.executeQuery();
        tieneInmobiliaria = rsInmo.next();
        cerrar(rsInmo, psInmo);
    } catch (SQLException ex) {
        errorSolicitudes = "Ocurrió un error al verificar tu inmobiliaria. Inténtalo más tarde.";
    }

    if (errorSolicitudes == null && !tieneInmobiliaria) {
        errorSinInmobiliaria = true;
    }

    if (errorSolicitudes == null && tieneInmobiliaria) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            String sql =
                "SELECT s.id_solicitud, s.tipo, s.estado, s.fecha_solicitud, s.notas, " +
                "p.id_propiedad, p.titulo, " +
                "u.nombre, u.apellido, u.correo, u.telefono, i.razon_social " +
                "FROM solicitud s " +
                "JOIN propiedad p ON p.id_propiedad = s.id_propiedad " +
                "JOIN usuario u ON u.id_usuario = s.id_usuario " +
                "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
                "WHERE p.id_inmobiliaria = (" + TARGET_INMO + ")";
            if (!filtroEstado.isEmpty()) {
                sql += " AND s.estado = ?";
            }
            if (!filtroTipo.isEmpty()) {
                sql += " AND s.tipo = ?";
            }
            sql += " ORDER BY s.fecha_solicitud DESC, s.id_solicitud DESC";
            ps = conexion.prepareStatement(sql);
            ps.setInt(1, idUsuarioSesion);
            int idx = 2;
            if (!filtroEstado.isEmpty()) {
                ps.setString(idx++, filtroEstado);
            }
            if (!filtroTipo.isEmpty()) {
                ps.setString(idx, filtroTipo);
            }
            rs = ps.executeQuery();
            while (rs.next()) {
                String idSol = String.valueOf(rs.getInt("id_solicitud"));
                String tipo = rs.getString("tipo");
                String estado = rs.getString("estado");
                String fecha = formatoFecha(rs.getTimestamp("fecha_solicitud"));
                String notas = rs.getString("notas");
                String idProp = String.valueOf(rs.getInt("id_propiedad"));
                String titulo = rs.getString("titulo");
                String cliente = rs.getString("nombre") + " " + rs.getString("apellido");
                String correo = rs.getString("correo");
                String telefono = rs.getString("telefono");
                String razon = rs.getString("razon_social");
                solicitudes.add(new String[] { idSol, tipo, estado, fecha, notas,
                                               idProp, titulo, cliente, correo, telefono, razon });
            }
        } catch (SQLException ex) {
            errorSolicitudes = "Ocurrió un error al consultar las solicitudes. Inténtalo más tarde.";
        } finally {
            cerrar(rs, ps, conexion);
        }
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Solicitudes de mi Inmobiliaria</h1>
    <a href="<%= ctx %>/inmobiliaria/panel.jsp" class="btn btn-outline-secondary">Volver al panel</a>
</div>

<form method="get" action="<%= ctx %>/inmobiliaria/solicitudes.jsp" class="row g-2 align-items-center mb-3">
    <div class="col-auto">
        <label for="tipo" class="col-form-label">Tipo:</label>
    </div>
    <div class="col-auto">
        <select id="tipo" name="tipo" class="form-select">
            <option value="">Todos</option>
            <% for (String t : TIPOS_SOLICITUD) { %>
            <option value="<%= t %>" <%= t.equals(filtroTipo) ? "selected" : "" %>><%= t %></option>
            <% } %>
        </select>
    </div>
    <div class="col-auto">
        <label for="estado" class="col-form-label">Estado:</label>
    </div>
    <div class="col-auto">
        <select id="estado" name="estado" class="form-select">
            <option value="">Todos</option>
            <% for (String e : ESTADOS_SOLICITUD) { %>
            <option value="<%= e %>" <%= e.equals(filtroEstado) ? "selected" : "" %>><%= e %></option>
            <% } %>
        </select>
    </div>
    <div class="col-auto">
        <button type="submit" class="btn btn-primary">Filtrar</button>
        <% if (!filtroTipo.isEmpty() || !filtroEstado.isEmpty()) { %>
        <a href="<%= ctx %>/inmobiliaria/solicitudes.jsp" class="btn btn-outline-secondary">Limpiar</a>
        <% } %>
    </div>
</form>

<% if (errorSolicitudes != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorSolicitudes) %></div>
<% } else if (errorSinInmobiliaria) { %>
<div class="alert alert-warning" role="alert">
    Tu usuario aún no tiene una inmobiliaria asociada en el sistema, por lo que no puedes gestionar solicitudes. Contacta al administrador.
</div>
<% } else if (solicitudes.isEmpty()) { %>
<div class="alert alert-info" role="alert">
    No hay solicitudes registradas para las propiedades de tu inmobiliaria.
    <% if (!filtroTipo.isEmpty() || !filtroEstado.isEmpty()) { %>
    Con los filtros aplicados no hay coincidencias.
    <% } %>
</div>
<% } else { %>
<div class="table-responsive">
    <table class="table table-striped table-hover align-middle">
        <thead class="table-light">
            <tr>
                <th>Solicitud</th>
                <th>Cliente</th>
                <th>Correo</th>
                <th>Teléfono</th>
                <th>Propiedad</th>
                <th>Tipo</th>
                <th>Estado</th>
                <th>Fecha</th>
                <th></th>
            </tr>
        </thead>
        <tbody>
            <% for (String[] s : solicitudes) { %>
            <tr>
                <td><strong>#<%= s[0] %></strong></td>
                <td><%= escapar(s[7]) %></td>
                <td><%= escapar(s[8]) %></td>
                <td><%= s[9] == null || s[9].isEmpty() ? "<span class='text-muted'>N/D</span>" : escapar(s[9]) %></td>
                <td>
                    <a href="<%= ctx %>/inmobiliaria/ver-propiedad.jsp?id=<%= s[5] %>"><%= escapar(s[6]) %></a>
                </td>
                <td><%= escapar(s[1]) %></td>
                <td><span class="badge <%= claseEstado(s[2]) %>"><%= escapar(s[2]) %></span></td>
                <td><%= escapar(s[3]) %></td>
                <td>
                    <a href="<%= ctx %>/inmobiliaria/detalle-solicitud.jsp?id=<%= s[0] %>" class="btn btn-sm btn-outline-primary">Ver detalle</a>
                </td>
            </tr>
            <% } %>
        </tbody>
    </table>
</div>
<% } %>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>