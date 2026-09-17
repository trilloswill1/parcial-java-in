<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%!
private static final String[] ESTADOS_CITA = { "PENDIENTE", "CONFIRMADA", "CANCELADA", "REALIZADA" };

private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private String claseEstado(String estado) {
    if ("PENDIENTE".equals(estado))  return "bg-warning text-dark";
    if ("CONFIRMADA".equals(estado)) return "bg-info text-dark";
    if ("CANCELADA".equals(estado))  return "bg-secondary";
    return "bg-success";
}

private String formatoFecha(Timestamp ts) {
    if (ts == null) return "";
    return new SimpleDateFormat("dd/MM/yyyy").format(ts);
}

private String formatoHora(Timestamp ts) {
    if (ts == null) return "";
    return new SimpleDateFormat("HH:mm").format(ts);
}
%>
<%
String[] rolesPermitidos = { "INMOBILIARIA" };
String tituloPagina = "Citas de mi Inmobiliaria";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String filtroEstado = limpiar(request.getParameter("estado"));
boolean filtroEstadoValido = false;
for (String e : ESTADOS_CITA) {
    if (e.equals(filtroEstado)) { filtroEstadoValido = true; break; }
}
if (!filtroEstadoValido) filtroEstado = "";

String errorCitas = null;
List<String[]> citas = new ArrayList<String[]>();

if (errorConexion != null) {
    errorCitas = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        String sql =
            "SELECT c.id_cita, c.fecha_hora, c.estado AS cita_estado, c.notas, " +
            "p.id_propiedad, p.titulo, " +
            "cd.nombre AS ciudad_nombre, " +
            "u.nombre AS cliente_nombre, u.apellido AS cliente_apellido, u.correo, u.telefono " +
            "FROM cita c " +
            "JOIN propiedad p ON p.id_propiedad = c.id_propiedad " +
            "JOIN ciudad cd ON cd.id_ciudad = p.id_ciudad " +
            "JOIN usuario u ON u.id_usuario = c.id_usuario " +
            "WHERE p.id_inmobiliaria = (SELECT id_inmobiliaria FROM inmobiliaria WHERE id_usuario = ? LIMIT 1)";
        if (!filtroEstado.isEmpty()) {
            sql += " AND c.estado = ?";
        }
        sql += " ORDER BY c.fecha_hora DESC, c.id_cita DESC";
        ps = conexion.prepareStatement(sql);
        ps.setInt(1, idUsuarioSesion);
        if (!filtroEstado.isEmpty()) {
            ps.setString(2, filtroEstado);
        }
        rs = ps.executeQuery();
        while (rs.next()) {
            String idCita = String.valueOf(rs.getInt("id_cita"));
            String fechaHora = formatoFecha(rs.getTimestamp("fecha_hora"));
            String hora = formatoHora(rs.getTimestamp("fecha_hora"));
            String estado = rs.getString("cita_estado");
            String notas = rs.getString("notas");
            String idPropiedad = String.valueOf(rs.getInt("id_propiedad"));
            String titulo = rs.getString("titulo");
            String ciudad = rs.getString("ciudad_nombre");
            String cliente = rs.getString("cliente_nombre") + " " + rs.getString("cliente_apellido");
            String correo = rs.getString("correo");
            String telefono = rs.getString("telefono");
            citas.add(new String[] { idCita, fechaHora, hora, estado, notas,
                                     idPropiedad, titulo, ciudad, cliente, correo, telefono });
        }
    } catch (SQLException ex) {
        errorCitas = "Ocurrió un error al consultar las citas. Inténtalo más tarde.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Citas de mi Inmobiliaria</h1>
    <a href="<%= ctx %>/inmobiliaria/panel.jsp" class="btn btn-outline-secondary">Volver al panel</a>
</div>

<% if ("1".equals(request.getParameter("actualizada"))) { %>
<div class="alert alert-success" role="alert">La cita fue actualizada correctamente.</div>
<% } %>

<form method="get" action="<%= ctx %>/inmobiliaria/citas.jsp" class="row g-2 align-items-center mb-3">
    <div class="col-auto">
        <label for="estado" class="col-form-label">Estado:</label>
    </div>
    <div class="col-auto">
        <select id="estado" name="estado" class="form-select">
            <option value="">Todas</option>
            <% for (String e : ESTADOS_CITA) { %>
            <option value="<%= e %>" <%= e.equals(filtroEstado) ? "selected" : "" %>><%= e %></option>
            <% } %>
        </select>
    </div>
    <div class="col-auto">
        <button type="submit" class="btn btn-primary">Filtrar</button>
        <% if (!filtroEstado.isEmpty()) { %>
        <a href="<%= ctx %>/inmobiliaria/citas.jsp" class="btn btn-outline-secondary">Limpiar</a>
        <% } %>
    </div>
</form>

<% if (errorCitas != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorCitas) %></div>
<% } else if (citas.isEmpty()) { %>
<div class="alert alert-info" role="alert">No hay citas registradas para las propiedades de tu inmobiliaria<% if (!filtroEstado.isEmpty()) { %> con estado <%= escapar(filtroEstado) %><% } %>.</div>
<% } else { %>
<div class="table-responsive">
    <table class="table table-striped table-hover align-middle">
        <thead class="table-light">
            <tr>
                <th>Cliente</th>
                <th>Correo</th>
                <th>Teléfono</th>
                <th>Propiedad</th>
                <th>Ciudad</th>
                <th>Fecha</th>
                <th>Hora</th>
                <th>Estado</th>
                <th>Notas</th>
                <th></th>
            </tr>
        </thead>
        <tbody>
            <% for (String[] c : citas) { %>
            <tr>
                <td><strong><%= escapar(c[8]) %></strong></td>
                <td><%= escapar(c[9]) %></td>
                <td><%= c[10] == null || c[10].isEmpty() ? "<span class='text-muted'>N/D</span>" : escapar(c[10]) %></td>
                <td>
                    <a href="<%= ctx %>/inmobiliaria/ver-propiedad.jsp?id=<%= c[5] %>"><%= escapar(c[6]) %></a>
                </td>
                <td><%= escapar(c[7]) %></td>
                <td><%= escapar(c[1]) %></td>
                <td><%= escapar(c[2]) %></td>
                <td><span class="badge <%= claseEstado(c[3]) %>"><%= escapar(c[3]) %></span></td>
                <td class="text-muted"><%= escapar(c[4]) %></td>
                <td>
                    <a href="<%= ctx %>/inmobiliaria/detalle-cita.jsp?id=<%= c[0] %>" class="btn btn-sm btn-outline-primary">Ver detalle</a>
                </td>
            </tr>
            <% } %>
        </tbody>
    </table>
</div>
<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>