<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.math.BigDecimal" %>
<%!
private static class FilaPropiedad {
    int id;
    String titulo;
    String tipo;
    String ciudad;
    String precio;
    String area;
    int habitaciones;
    int banos;
    String estado;
    String matricula;
    String urlPrincipal;
}

private static final String PLACEHOLDER_IMG =
    "data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%22400%22%20height%3D%22200%22%3E%3Crect%20width%3D%22400%22%20height%3D%22200%22%20fill%3D%22%23e9ecef%22%2F%3E%3Ctext%20x%3D%22200%22%20y%3D%22100%22%20fill%3D%22%236c757d%22%20font-family%3D%22Arial%22%20font-size%3D%2218%22%20text-anchor%3D%22middle%22%3ESin%20imagen%3C%2Ftext%3E%3C%2Fsvg%3E";

private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private String claseEstado(String estado) {
    if ("RESERVADA".equals(estado)) return "bg-warning text-dark";
    if ("VENDIDA".equals(estado))   return "bg-secondary";
    if ("ALQUILADA".equals(estado)) return "bg-info text-dark";
    return "bg-success";
}
%>
<%
String[] rolesPermitidos = { "INMOBILIARIA" };
String tituloPagina = "Mis Propiedades";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
String mensajeOk = null;
if ("1".equals(request.getParameter("creada"))) {
    mensajeOk = "La propiedad se registró correctamente.";
} else if ("1".equals(request.getParameter("editada"))) {
    mensajeOk = "La propiedad se actualizó correctamente.";
} else if ("1".equals(request.getParameter("eliminada"))) {
    mensajeOk = "La propiedad se eliminó correctamente.";
}

String errorListado = null;
List<FilaPropiedad> filas = new ArrayList<FilaPropiedad>();
Integer idInmobiliaria = null;
int total = 0;

if (errorConexion != null) {
    errorListado = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
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

        if (idInmobiliaria != null) {
            ps = conexion.prepareStatement(
                "SELECT p.id_propiedad, p.titulo, p.precio, p.area_m2, p.num_habitaciones, p.num_banos, " +
                "p.estado, p.matricula_inmobiliaria, " +
                "t.nombre AS tipo_nombre, c.nombre AS ciudad_nombre, " +
                "(SELECT ip.url_imagen FROM imagen_propiedad ip " +
                " WHERE ip.id_propiedad = p.id_propiedad AND ip.es_principal = 1 " +
                " ORDER BY ip.orden LIMIT 1) AS url_principal " +
                "FROM propiedad p " +
                "JOIN tipo_propiedad t ON t.id_tipo = p.id_tipo " +
                "JOIN ciudad c ON c.id_ciudad = p.id_ciudad " +
                "WHERE p.id_inmobiliaria = ? " +
                "ORDER BY p.fecha_publicacion DESC, p.id_propiedad DESC");
            ps.setInt(1, idInmobiliaria);
            rs = ps.executeQuery();
            java.text.DecimalFormat df = new java.text.DecimalFormat("###,###,##0");
            while (rs.next()) {
                FilaPropiedad f = new FilaPropiedad();
                f.id = rs.getInt("id_propiedad");
                f.titulo = rs.getString("titulo");
                f.tipo = rs.getString("tipo_nombre");
                f.ciudad = rs.getString("ciudad_nombre");
                f.precio = df.format(rs.getBigDecimal("precio"));
                BigDecimal area = rs.getBigDecimal("area_m2");
                f.area = area == null ? "N/D" : df.format(area);
                f.habitaciones = rs.getInt("num_habitaciones");
                f.banos = rs.getInt("num_banos");
                f.estado = rs.getString("estado");
                f.matricula = rs.getString("matricula_inmobiliaria");
                f.urlPrincipal = rs.getString("url_principal");
                filas.add(f);
            }
            cerrar(rs, ps);

            ps = conexion.prepareStatement(
                "SELECT COUNT(*) AS total FROM propiedad WHERE id_inmobiliaria = ?");
            ps.setInt(1, idInmobiliaria);
            rs = ps.executeQuery();
            if (rs.next()) {
                total = rs.getInt("total");
            }
        }
    } catch (SQLException ex) {
        errorListado = "No se pudieron cargar las propiedades. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-3">
    <h1 class="mb-0">Mis propiedades</h1>
    <div class="d-flex gap-2">
        <a href="<%= ctx %>/inmobiliaria/crear-propiedad.jsp" class="btn btn-success">Nueva propiedad</a>
        <a href="<%= ctx %>/inmobiliaria/panel.jsp" class="btn btn-outline-secondary">Volver al panel</a>
    </div>
</div>

<% if (mensajeOk != null) { %>
<div class="alert alert-success" role="alert"><%= escapar(mensajeOk) %></div>
<% } %>
<% if (errorListado != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorListado) %></div>
<% } else if (idInmobiliaria == null) { %>
<div class="alert alert-warning" role="alert">
    Tu usuario aún no tiene una inmobiliaria asociada en el sistema. Contacta al administrador.
</div>
<% } %>

<% if (idInmobiliaria != null && errorListado == null) { %>
<p class="text-muted">Total de propiedades registradas: <strong><%= total %></strong></p>

<% if (filas.isEmpty()) { %>
<div class="alert alert-info" role="alert">Aún no has registrado propiedades. Usa el botón "Nueva propiedad".</div>
<% } else { %>
<div class="table-responsive">
    <table class="table table-hover align-middle">
        <thead class="table-light">
            <tr>
                <th>ID</th>
                <th>Imagen</th>
                <th>Título</th>
                <th>Tipo</th>
                <th>Ciudad</th>
                <th>Precio</th>
                <th>Área</th>
                <th>Hab.</th>
                <th>Baños</th>
                <th>Estado</th>
                <th>Acciones</th>
            </tr>
        </thead>
        <tbody>
        <% for (FilaPropiedad f : filas) { %>
            <tr>
                <td><%= f.id %></td>
                <td>
                    <img style="width: 64px; height: 48px; object-fit: cover;"
                         src="<%= f.urlPrincipal != null ? escapar(f.urlPrincipal) : PLACEHOLDER_IMG %>"
                         onerror="this.onerror=null; this.src='<%= PLACEHOLDER_IMG %>';"
                         alt="<%= escapar(f.titulo) %>" class="img-thumbnail">
                </td>
                <td><%= escapar(f.titulo) %></td>
                <td><%= escapar(f.tipo) %></td>
                <td><%= escapar(f.ciudad) %></td>
                <td class="text-nowrap">$ <%= f.precio %></td>
                <td class="text-nowrap"><%= f.area %> m²</td>
                <td><%= f.habitaciones %></td>
                <td><%= f.banos %></td>
                <td><span class="badge <%= claseEstado(f.estado) %>"><%= escapar(f.estado) %></span></td>
                <td class="text-nowrap">
                    <a href="<%= ctx %>/inmobiliaria/ver-propiedad.jsp?id=<%= f.id %>" class="btn btn-sm btn-outline-primary">Ver</a>
                    <a href="<%= ctx %>/inmobiliaria/editar-propiedad.jsp?id=<%= f.id %>" class="btn btn-sm btn-outline-secondary">Editar</a>
                    <a href="<%= ctx %>/inmobiliaria/eliminar-propiedad.jsp?id=<%= f.id %>" class="btn btn-sm btn-outline-danger">Eliminar</a>
                </td>
            </tr>
        <% } %>
        </tbody>
    </table>
</div>
<% } %>
<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>