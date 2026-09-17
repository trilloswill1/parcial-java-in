<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.text.DecimalFormat" %>
<%@ page import="java.math.BigDecimal" %>
<%!
private static final String PLACEHOLDER_IMG =
    "data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%22400%22%20height%3D%22200%22%3E%3Crect%20width%3D%22400%22%20height%3D%22200%22%20fill%3D%22%23e9ecef%22%2F%3E%3Ctext%20x%3D%22200%22%20y%3D%22100%22%20fill%3D%22%236c757d%22%20font-family%3D%22Arial%22%20font-size%3D%2218%22%20text-anchor%3D%22middle%22%3ESin%20imagen%3C%2Ftext%3E%3C%2Fsvg%3E";

private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private static class FilaPropiedad {
    int id;
    String titulo;
    String precio;
    String area;
    int habitaciones;
    int banos;
    String tipo;
    String ciudad;
    String departamento;
    String urlPrincipal;
}
%>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String tituloPagina = "Catálogo de Propiedades";
String ctx = request.getContextPath();

String fCiudad    = limpiar(request.getParameter("ciudad"));
String fTipo      = limpiar(request.getParameter("tipo"));
String fOperacion = limpiar(request.getParameter("operacion"));
String fPrecioMax = limpiar(request.getParameter("precio_max"));
%>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
String errorListado = null;
List<FilaPropiedad> filas = new ArrayList<FilaPropiedad>();
List<String[]> tiposCatalogo = new ArrayList<String[]>();
List<String[]> ciudadesCatalogo = new ArrayList<String[]>();
String[] operaciones = { "VENTA", "ARRIENDO" };

if (errorConexion != null) {
    errorListado = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    StringBuilder sql = new StringBuilder(
        "SELECT p.id_propiedad, p.titulo, p.precio, p.area_m2, p.num_habitaciones, p.num_banos, " +
        "t.nombre AS tipo_nombre, c.nombre AS ciudad_nombre, c.departamento, " +
        "(SELECT ip.url_imagen FROM imagen_propiedad ip " +
        " WHERE ip.id_propiedad = p.id_propiedad AND ip.es_principal = 1 " +
        " ORDER BY ip.orden LIMIT 1) AS url_principal " +
        "FROM propiedad p " +
        "JOIN tipo_propiedad t ON t.id_tipo = p.id_tipo " +
        "JOIN ciudad c ON c.id_ciudad = p.id_ciudad " +
        "WHERE p.estado = 'DISPONIBLE'");
    List<Object> params = new ArrayList<Object>();

    if (!fCiudad.isEmpty()) {
        try { int v = Integer.parseInt(fCiudad); if (v > 0) { sql.append(" AND p.id_ciudad = ?"); params.add(Integer.valueOf(v)); } } catch (NumberFormatException ignorada) {}
    }
    if (!fTipo.isEmpty()) {
        try { int v = Integer.parseInt(fTipo); if (v > 0) { sql.append(" AND p.id_tipo = ?"); params.add(Integer.valueOf(v)); } } catch (NumberFormatException ignorada) {}
    }
    if (!fPrecioMax.isEmpty()) {
        try { BigDecimal v = new BigDecimal(fPrecioMax); sql.append(" AND p.precio <= ?"); params.add(v); } catch (NumberFormatException ignorada) {}
    }
    // operacion: no existe columna en la BD (solo VENTA). Se conserva en la URL, no filtra.

    sql.append(" ORDER BY p.fecha_publicacion DESC, p.id_propiedad DESC");

    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement("SELECT id_tipo, nombre FROM tipo_propiedad ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            tiposCatalogo.add(new String[] { String.valueOf(rs.getInt("id_tipo")), rs.getString("nombre") });
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement("SELECT id_ciudad, nombre, departamento FROM ciudad ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            ciudadesCatalogo.add(new String[] {
                String.valueOf(rs.getInt("id_ciudad")),
                rs.getString("nombre") + " (" + rs.getString("departamento") + ")"
            });
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement(sql.toString());
        int i = 1;
        for (Object p : params) {
            ps.setObject(i++, p);
        }
        rs = ps.executeQuery();

        DecimalFormat df = new DecimalFormat("###,###,##0");
        while (rs.next()) {
            FilaPropiedad f = new FilaPropiedad();
            f.id = rs.getInt("id_propiedad");
            f.titulo = rs.getString("titulo");
            f.precio = df.format(rs.getBigDecimal("precio"));
            BigDecimal area = rs.getBigDecimal("area_m2");
            f.area = area == null ? "N/D" : df.format(area);
            f.habitaciones = rs.getInt("num_habitaciones");
            f.banos = rs.getInt("num_banos");
            f.tipo = rs.getString("tipo_nombre");
            f.ciudad = rs.getString("ciudad_nombre");
            f.departamento = rs.getString("departamento");
            f.urlPrincipal = rs.getString("url_principal");
            filas.add(f);
        }
    } catch (SQLException ex) {
        errorListado = "No se pudieron cargar las propiedades. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<h1 class="h3 mb-4">Catálogo de propiedades</h1>

<% if (errorListado != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorListado) %></div>
<% } %>

<form method="get" action="<%= ctx %>/catalogo.jsp" class="row g-2 mb-4">
    <div class="col-12 col-md-3">
        <select name="ciudad" class="form-select">
            <option value="">Ciudad (todas)</option>
            <% for (String[] cd : ciudadesCatalogo) { %>
            <option value="<%= cd[0] %>" <%= fCiudad.equals(cd[0]) ? "selected" : "" %>><%= escapar(cd[1]) %></option>
            <% } %>
        </select>
    </div>
    <div class="col-12 col-md-3">
        <select name="tipo" class="form-select">
            <option value="">Tipo (todos)</option>
            <% for (String[] tp : tiposCatalogo) { %>
            <option value="<%= tp[0] %>" <%= fTipo.equals(tp[0]) ? "selected" : "" %>><%= escapar(tp[1]) %></option>
            <% } %>
        </select>
    </div>
    <div class="col-6 col-md-2 d-none">
        <select name="operacion" class="form-select">
            <option value="">Operación (toda)</option>
            <% for (String op : operaciones) { %>
            <option value="<%= op %>" <%= fOperacion.equals(op) ? "selected" : "" %>><%= op %></option>
            <% } %>
        </select>
    </div>
    <div class="col-6 col-md-2">
        <input type="number" min="0" step="1000000" name="precio_max" value="<%= escapar(fPrecioMax) %>"
               class="form-control" placeholder="Precio máx.">
    </div>
    <div class="col-12 col-md-2 d-flex gap-2">
        <button type="submit" class="btn btn-primary flex-fill">Filtrar</button>
        <a href="<%= ctx %>/catalogo.jsp" class="btn btn-outline-secondary">Limpiar</a>
    </div>
</form>

<% if (filas.isEmpty() && errorListado == null) { %>
<div class="alert alert-info" role="alert">No se encontraron propiedades con los filtros seleccionados.</div>
<% } %>

<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
<% for (FilaPropiedad f : filas) { %>
    <div class="col">
        <div class="card h-100 shadow-sm">
            <img class="card-img-top" style="height: 200px; object-fit: cover;"
                 src="<%= f.urlPrincipal != null ? escapar(f.urlPrincipal) : PLACEHOLDER_IMG %>"
                 onerror="this.onerror=null; this.src='<%= PLACEHOLDER_IMG %>';"
                 alt="<%= escapar(f.titulo) %>">
            <div class="card-body d-flex flex-column">
                <h5 class="card-title"><%= escapar(f.titulo) %></h5>
                <p class="text-muted small mb-2">
                    <%= escapar(f.tipo) %> &middot; <%= escapar(f.ciudad) %>, <%= escapar(f.departamento) %>
                </p>
                <p class="fs-5 fw-bold text-primary mb-1">$ <%= f.precio %></p>
                <ul class="list-inline small text-muted mb-3">
                    <li class="list-inline-item"><%= f.area %> m²</li>
                    <li class="list-inline-item"><%= f.habitaciones %> hab</li>
                    <li class="list-inline-item"><%= f.banos %> baños</li>
                </ul>
                <a href="<%= ctx %>/detalle-propiedad.jsp?id=<%= f.id %>"
                   class="mt-auto btn btn-sm btn-outline-primary w-100">Ver detalle</a>
            </div>
        </div>
    </div>
<% } %>
</div>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>