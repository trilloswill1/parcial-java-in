<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.text.DecimalFormat" %>
<%!
private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}
%>
<%
String[] rolesPermitidos = { "ADMINISTRADOR" };
String tituloPagina = "Reportes";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String errorReportes = null;
List<String[]> r1 = new ArrayList<String[]>();
List<String[]> r2 = new ArrayList<String[]>();
List<String[]> r3 = new ArrayList<String[]>();
List<String[]> r4 = new ArrayList<String[]>();
List<String[]> r5 = new ArrayList<String[]>();
List<String[]> r6 = new ArrayList<String[]>();

if (errorConexion != null) {
    errorReportes = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    Statement st = null;
    ResultSet rs = null;
    try {
        DecimalFormat df = new DecimalFormat("###,###,##0");

        st = conexion.createStatement();

        // Reporte 1: INNER JOIN entre propiedad, ciudad, tipo_propiedad e inmobiliaria
        rs = st.executeQuery(
            "SELECT p.id_propiedad, p.titulo, p.precio, p.estado, " +
            "       c.nombre AS ciudad, tp.nombre AS tipo, i.razon_social AS inmobiliaria " +
            "FROM propiedad p " +
            "INNER JOIN ciudad c ON p.id_ciudad = c.id_ciudad " +
            "INNER JOIN tipo_propiedad tp ON p.id_tipo = tp.id_tipo " +
            "INNER JOIN inmobiliaria i ON p.id_inmobiliaria = i.id_inmobiliaria " +
            "ORDER BY p.fecha_publicacion DESC");
        while (rs.next()) {
            r1.add(new String[] {
                String.valueOf(rs.getInt("id_propiedad")),
                rs.getString("titulo"),
                df.format(rs.getBigDecimal("precio")),
                rs.getString("estado"),
                rs.getString("ciudad"),
                rs.getString("tipo"),
                rs.getString("inmobiliaria")
            });
        }
        cerrar(rs, null);

        // Reporte 2: INNER JOIN entre solicitud, usuario (cliente), propiedad e inmobiliaria
        rs = st.executeQuery(
            "SELECT s.id_solicitud, u.nombre AS cliente_nombre, u.apellido AS cliente_apellido, " +
            "       p.titulo AS propiedad, i.razon_social AS inmobiliaria, " +
            "       s.tipo, s.estado, s.fecha_solicitud " +
            "FROM solicitud s " +
            "INNER JOIN usuario u ON s.id_usuario = u.id_usuario " +
            "INNER JOIN propiedad p ON s.id_propiedad = p.id_propiedad " +
            "INNER JOIN inmobiliaria i ON p.id_inmobiliaria = i.id_inmobiliaria " +
            "ORDER BY s.fecha_solicitud DESC");
        while (rs.next()) {
            r2.add(new String[] {
                String.valueOf(rs.getInt("id_solicitud")),
                rs.getString("cliente_nombre") + " " + rs.getString("cliente_apellido"),
                rs.getString("propiedad"),
                rs.getString("inmobiliaria"),
                rs.getString("tipo"),
                rs.getString("estado"),
                String.valueOf(rs.getTimestamp("fecha_solicitud"))
            });
        }
        cerrar(rs, null);

        // Reporte 3: Relación N:M usuario_rol (usuario <-> rol)
        rs = st.executeQuery(
            "SELECT u.nombre, u.apellido, u.correo, r.nombre AS rol " +
            "FROM usuario u " +
            "INNER JOIN usuario_rol ur ON u.id_usuario = ur.id_usuario " +
            "INNER JOIN rol r ON ur.id_rol = r.id_rol " +
            "ORDER BY u.nombre");
        while (rs.next()) {
            r3.add(new String[] {
                rs.getString("nombre"),
                rs.getString("apellido"),
                rs.getString("correo"),
                rs.getString("rol")
            });
        }
        cerrar(rs, null);

        // Reporte 4: LEFT JOIN de propiedades disponibles sin citas agendadas
        rs = st.executeQuery(
            "SELECT p.id_propiedad, p.titulo, p.estado " +
            "FROM propiedad p " +
            "LEFT JOIN cita c ON p.id_propiedad = c.id_propiedad " +
            "WHERE c.id_cita IS NULL AND p.estado = 'DISPONIBLE'");
        while (rs.next()) {
            r4.add(new String[] {
                String.valueOf(rs.getInt("id_propiedad")),
                rs.getString("titulo"),
                rs.getString("estado")
            });
        }
        cerrar(rs, null);

        // Reporte 5: GROUP BY + HAVING de propiedades disponibles por ciudad
        rs = st.executeQuery(
            "SELECT c.nombre AS ciudad, COUNT(p.id_propiedad) AS total_disponibles " +
            "FROM ciudad c " +
            "INNER JOIN propiedad p ON p.id_ciudad = c.id_ciudad AND p.estado = 'DISPONIBLE' " +
            "GROUP BY c.nombre " +
            "HAVING COUNT(p.id_propiedad) >= 1 " +
            "ORDER BY total_disponibles DESC");
        while (rs.next()) {
            r5.add(new String[] {
                rs.getString("ciudad"),
                String.valueOf(rs.getInt("total_disponibles"))
            });
        }
        cerrar(rs, null);

        // Reporte 6 (extra): Citas agrupadas por estado
        rs = st.executeQuery(
            "SELECT estado, COUNT(*) AS total FROM cita GROUP BY estado");
        while (rs.next()) {
            r6.add(new String[] {
                rs.getString("estado"),
                String.valueOf(rs.getInt("total"))
            });
        }
    } catch (SQLException ex) {
        errorReportes = "No se pudieron cargar los reportes. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, st, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-4">
    <h1 class="mb-0">Reportes</h1>
    <a href="<%= ctx %>/admin/panel.jsp" class="btn btn-outline-secondary btn-sm">Volver al panel</a>
</div>

<% if (errorReportes != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorReportes) %></div>
<% } %>

<% if (errorReportes == null) { %>

<h2 class="h5 mt-4">Reporte 1 - INNER JOIN entre propiedad, ciudad, tipo_propiedad e inmobiliaria</h2>
<div class="table-responsive">
    <table class="table table-striped table-hover table-sm align-middle">
        <thead>
            <tr>
                <th>ID</th><th>Título</th><th>Precio</th><th>Estado</th>
                <th>Ciudad</th><th>Tipo</th><th>Inmobiliaria</th>
            </tr>
        </thead>
        <tbody>
            <% if (r1.isEmpty()) { %>
            <tr><td colspan="7" class="text-center text-muted">Sin datos</td></tr>
            <% } else { %>
            <% for (String[] fila : r1) { %>
            <tr>
                <td><%= fila[0] %></td>
                <td><%= escapar(fila[1]) %></td>
                <td>$ <%= fila[2] %></td>
                <td><%= escapar(fila[3]) %></td>
                <td><%= escapar(fila[4]) %></td>
                <td><%= escapar(fila[5]) %></td>
                <td><%= escapar(fila[6]) %></td>
            </tr>
            <% } %>
            <% } %>
        </tbody>
    </table>
</div>

<h2 class="h5 mt-4">Reporte 2 - INNER JOIN entre solicitud, usuario (cliente), propiedad e inmobiliaria</h2>
<div class="table-responsive">
    <table class="table table-striped table-hover table-sm align-middle">
        <thead>
            <tr>
                <th>ID</th><th>Cliente</th><th>Propiedad</th><th>Inmobiliaria</th>
                <th>Tipo</th><th>Estado</th><th>Fecha solicitud</th>
            </tr>
        </thead>
        <tbody>
            <% if (r2.isEmpty()) { %>
            <tr><td colspan="7" class="text-center text-muted">Sin datos</td></tr>
            <% } else { %>
            <% for (String[] fila : r2) { %>
            <tr>
                <td><%= fila[0] %></td>
                <td><%= escapar(fila[1]) %></td>
                <td><%= escapar(fila[2]) %></td>
                <td><%= escapar(fila[3]) %></td>
                <td><%= escapar(fila[4]) %></td>
                <td><%= escapar(fila[5]) %></td>
                <td><%= fila[6] %></td>
            </tr>
            <% } %>
            <% } %>
        </tbody>
    </table>
</div>

<h2 class="h5 mt-4">Reporte 3 - Relación N:M (usuario <-> rol) vía usuario_rol</h2>
<div class="table-responsive">
    <table class="table table-striped table-hover table-sm align-middle">
        <thead>
            <tr><th>Nombre</th><th>Apellido</th><th>Correo</th><th>Rol</th></tr>
        </thead>
        <tbody>
            <% if (r3.isEmpty()) { %>
            <tr><td colspan="4" class="text-center text-muted">Sin datos</td></tr>
            <% } else { %>
            <% for (String[] fila : r3) { %>
            <tr>
                <td><%= escapar(fila[0]) %></td>
                <td><%= escapar(fila[1]) %></td>
                <td><%= escapar(fila[2]) %></td>
                <td><%= escapar(fila[3]) %></td>
            </tr>
            <% } %>
            <% } %>
        </tbody>
    </table>
</div>

<h2 class="h5 mt-4">Reporte 4 - LEFT JOIN (propiedades disponibles que aún no tienen citas agendadas)</h2>
<div class="table-responsive">
    <table class="table table-striped table-hover table-sm align-middle">
        <thead>
            <tr><th>ID</th><th>Título</th><th>Estado</th></tr>
        </thead>
        <tbody>
            <% if (r4.isEmpty()) { %>
            <tr><td colspan="3" class="text-center text-muted">Sin datos</td></tr>
            <% } else { %>
            <% for (String[] fila : r4) { %>
            <tr>
                <td><%= fila[0] %></td>
                <td><%= escapar(fila[1]) %></td>
                <td><%= escapar(fila[2]) %></td>
            </tr>
            <% } %>
            <% } %>
        </tbody>
    </table>
</div>

<h2 class="h5 mt-4">Reporte 5 - GROUP BY + HAVING (propiedades disponibles por ciudad)</h2>
<div class="table-responsive">
    <table class="table table-striped table-hover table-sm align-middle">
        <thead>
            <tr><th>Ciudad</th><th>Total disponibles</th></tr>
        </thead>
        <tbody>
            <% if (r5.isEmpty()) { %>
            <tr><td colspan="2" class="text-center text-muted">Sin datos</td></tr>
            <% } else { %>
            <% for (String[] fila : r5) { %>
            <tr>
                <td><%= escapar(fila[0]) %></td>
                <td><%= fila[1] %></td>
            </tr>
            <% } %>
            <% } %>
        </tbody>
    </table>
</div>

<h2 class="h5 mt-4">Reporte 6 (extra) - Citas agrupadas por estado (GROUP BY)</h2>
<div class="table-responsive">
    <table class="table table-striped table-hover table-sm align-middle">
        <thead>
            <tr><th>Estado</th><th>Total</th></tr>
        </thead>
        <tbody>
            <% if (r6.isEmpty()) { %>
            <tr><td colspan="2" class="text-center text-muted">Sin datos</td></tr>
            <% } else { %>
            <% for (String[] fila : r6) { %>
            <tr>
                <td><%= escapar(fila[0]) %></td>
                <td><%= fila[1] %></td>
            </tr>
            <% } %>
            <% } %>
        </tbody>
    </table>
</div>

<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>