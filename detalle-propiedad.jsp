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

private String claseEstado(String estado) {
    if ("RESERVADA".equals(estado)) return "bg-warning text-dark";
    if ("VENDIDA".equals(estado))   return "bg-secondary";
    if ("ALQUILADA".equals(estado)) return "bg-info text-dark";
    return "bg-success";
}
%>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String tituloPagina = "Detalle de Propiedad";
String ctx = request.getContextPath();

int idPropiedad = 0;
try { idPropiedad = Integer.parseInt(limpiar(request.getParameter("id"))); }
catch (NumberFormatException ignorada) { idPropiedad = 0; }
%>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
String errorDetalle = null;
boolean encontrada = false;

String titulo = null, descripcion = null, precio = null, area = null;
String estado = null, direccion = null, matricula = null, fechaPublicacion = null;
String tipoNombre = null, ciudadNombre = null, departamento = null;
String inmoRazonSocial = null, inmoTelefono = null, inmoDireccion = null;
int habitaciones = 0, banos = 0;

List<String[]> imagenes = new ArrayList<String[]>();
List<String[]> caracteristicas = new ArrayList<String[]>();

if (idPropiedad <= 0) {
    errorDetalle = "Propiedad no especificada.";
} else if (errorConexion != null) {
    errorDetalle = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT p.titulo, p.descripcion, p.precio, p.area_m2, p.num_habitaciones, p.num_banos, " +
            "p.estado, p.direccion, p.matricula_inmobiliaria, p.fecha_publicacion, " +
            "t.nombre AS tipo_nombre, c.nombre AS ciudad_nombre, c.departamento, " +
            "i.razon_social, i.telefono AS inmo_telefono, i.direccion AS inmo_direccion " +
            "FROM propiedad p " +
            "JOIN tipo_propiedad t ON t.id_tipo = p.id_tipo " +
            "JOIN ciudad c ON c.id_ciudad = p.id_ciudad " +
            "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
            "WHERE p.id_propiedad = ?");
        ps.setInt(1, idPropiedad);
        rs = ps.executeQuery();
        if (rs.next()) {
            encontrada = true;
            titulo = rs.getString("titulo");
            descripcion = rs.getString("descripcion");
            DecimalFormat df = new DecimalFormat("###,###,##0");
            precio = df.format(rs.getBigDecimal("precio"));
            BigDecimal areaBd = rs.getBigDecimal("area_m2");
            area = areaBd == null ? "N/D" : df.format(areaBd);
            habitaciones = rs.getInt("num_habitaciones");
            banos = rs.getInt("num_banos");
            estado = rs.getString("estado");
            direccion = rs.getString("direccion");
            matricula = rs.getString("matricula_inmobiliaria");
            java.sql.Timestamp fp = rs.getTimestamp("fecha_publicacion");
            fechaPublicacion = fp == null ? "" : fp.toLocalDateTime().toLocalDate().toString();
            tipoNombre = rs.getString("tipo_nombre");
            ciudadNombre = rs.getString("ciudad_nombre");
            departamento = rs.getString("departamento");
            inmoRazonSocial = rs.getString("razon_social");
            inmoTelefono = rs.getString("inmo_telefono");
            inmoDireccion = rs.getString("inmo_direccion");
            tituloPagina = "Detalle: " + titulo;
        }
        cerrar(rs, ps);

        if (encontrada) {
            ps = conexion.prepareStatement(
                "SELECT url_imagen, es_principal, orden FROM imagen_propiedad " +
                "WHERE id_propiedad = ? ORDER BY orden, id_imagen");
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            while (rs.next()) {
                imagenes.add(new String[] {
                    rs.getString("url_imagen"),
                    String.valueOf(rs.getInt("es_principal")),
                    String.valueOf(rs.getInt("orden"))
                });
            }
            cerrar(rs, ps);

            ps = conexion.prepareStatement(
                "SELECT ca.nombre, pc.cantidad FROM propiedad_caracteristica pc " +
                "JOIN caracteristica ca ON ca.id_caracteristica = pc.id_caracteristica " +
                "WHERE pc.id_propiedad = ? ORDER BY ca.nombre");
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            while (rs.next()) {
                caracteristicas.add(new String[] {
                    rs.getString("nombre"),
                    String.valueOf(rs.getInt("cantidad"))
                });
            }
        }
    } catch (SQLException ex) {
        if (!encontrada) errorDetalle = "No se pudo cargar el detalle de la propiedad. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, ps, conexion);
    }
    if (!encontrada && errorDetalle == null) {
        errorDetalle = "La propiedad solicitada no existe.";
    }
}

String imagenPrincipalUrl = null;
if (encontrada) {
    for (String[] img : imagenes) {
        if ("1".equals(img[1])) { imagenPrincipalUrl = img[0]; break; }
    }
    if (imagenPrincipalUrl == null && !imagenes.isEmpty()) {
        imagenPrincipalUrl = imagenes.get(0)[0];
    }
}

Integer idUsuarioSesion = (Integer) session.getAttribute("idUsuario");
String rolSesion = (String) session.getAttribute("rol");
boolean haySesion = idUsuarioSesion != null;
boolean esCliente = haySesion && "CLIENTE".equals(rolSesion);
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<% if (errorDetalle != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorDetalle) %></div>
<a href="<%= ctx %>/catalogo.jsp" class="btn btn-outline-secondary">Volver al catálogo</a>
<% } else if (encontrada) { %>

<div class="mb-3">
    <a href="<%= ctx %>/catalogo.jsp" class="btn btn-outline-secondary btn-sm">&larr; Volver al catálogo</a>
</div>

<div class="row g-4">
    <div class="col-12 col-lg-6">
        <div class="card shadow-sm">
            <img class="card-img-top" style="height: 340px; object-fit: cover;"
                 src="<%= imagenPrincipalUrl != null ? escapar(imagenPrincipalUrl) : PLACEHOLDER_IMG %>"
                 onerror="this.onerror=null; this.src='<%= PLACEHOLDER_IMG %>';"
                 alt="<%= escapar(titulo) %>">
            <% if (imagenes.size() > 1) { %>
            <div class="card-body">
                <div class="row row-cols-3 g-2">
                    <% for (String[] img : imagenes) { %>
                    <div class="col">
                        <img class="img-thumbnail w-100" style="height: 80px; object-fit: cover;"
                             src="<%= escapar(img[0]) %>"
                             onerror="this.onerror=null; this.src='<%= PLACEHOLDER_IMG %>';"
                             alt="Imagen">
                    </div>
                    <% } %>
                </div>
            </div>
            <% } %>
        </div>
    </div>

    <div class="col-12 col-lg-6">
        <div class="d-flex justify-content-between align-items-start">
            <h1 class="h3 mb-0"><%= escapar(titulo) %></h1>
            <span class="badge fs-6 <%= claseEstado(estado) %>"><%= escapar(estado) %></span>
        </div>
        <p class="text-muted mb-3"><%= escapar(tipoNombre) %> &middot; <%= escapar(ciudadNombre) %>, <%= escapar(departamento) %></p>

        <p class="fs-3 fw-bold text-primary">$ <%= precio %></p>

        <ul class="list-inline mb-3">
            <li class="list-inline-item me-3"><strong><%= area %></strong> m²</li>
            <li class="list-inline-item me-3"><strong><%= habitaciones %></strong> habitaciones</li>
            <li class="list-inline-item"><strong><%= banos %></strong> baños</li>
        </ul>

        <h2 class="h5 mt-4 mb-2">Descripción</h2>
        <p><%= descripcion != null && !descripcion.isBlank() ? escapar(descripcion) : "Sin descripción registrada." %></p>

        <table class="table table-sm table-borderless w-auto">
            <tbody>
                <tr><td class="text-muted">Dirección</td><td><%= escapar(direccion) %></td></tr>
                <tr><td class="text-muted">Matrícula</td><td><%= escapar(matricula) %></td></tr>
                <tr><td class="text-muted">Publicada</td><td><%= escapar(fechaPublicacion) %></td></tr>
            </tbody>
        </table>
    </div>
</div>

<div class="row g-4 mt-1">
    <div class="col-12 col-lg-6">
        <h2 class="h5">Características</h2>
        <% if (caracteristicas.isEmpty()) { %>
        <p class="text-muted">No se registraron características.</p>
        <% } else { %>
        <ul class="list-group list-group-flush">
            <% for (String[] car : caracteristicas) { %>
            <li class="list-group-item d-flex justify-content-between">
                <span><%= escapar(car[0]) %></span>
                <span class="badge bg-primary rounded-pill"><%= escapar(car[1]) %></span>
            </li>
            <% } %>
        </ul>
        <% } %>
    </div>

    <div class="col-12 col-lg-6">
        <h2 class="h5">Inmobiliaria</h2>
        <div class="card">
            <div class="card-body">
                <p class="mb-1"><strong><%= escapar(inmoRazonSocial) %></strong></p>
                <p class="mb-1 text-muted small">Dirección: <%= escapar(inmoDireccion) %></p>
                <p class="mb-0 text-muted small">Teléfono: <%= escapar(inmoTelefono) %></p>
            </div>
        </div>

        <% if (!haySesion) { %>
        <div class="alert alert-warning mt-3 mb-0">
            Inicia sesión para agendar una cita o solicitar este inmueble.
            <a href="<%= ctx %>/login.jsp" class="alert-link">Inicia sesión aquí</a>.
        </div>
        <% } else if (esCliente) {
            boolean propAgendable = "DISPONIBLE".equals(estado) || "RESERVADA".equals(estado);
            if (propAgendable) { %>
        <a href="<%= ctx %>/cliente/agendar-cita.jsp?id_propiedad=<%= idPropiedad %>" class="btn btn-success mt-3">
            Agendar visita
        </a>
        <% } else { %>
        <button type="button" class="btn btn-secondary mt-3" disabled
                title="Esta propiedad no está disponible para agendar citas por su estado actual">
            Agendar visita
        </button>
        <div class="alert alert-warning mt-2 mb-0">
            Esta propiedad no está disponible para agendar citas por su estado actual
            (<strong><%= escapar(estado) %></strong>).
        </div>
        <% } %>
        <a href="<%= ctx %>/cliente/crear-solicitud.jsp?id_propiedad=<%= idPropiedad %>"
           class="btn btn-outline-primary mt-3 w-100">
            Solicitar compra/alquiler
        </a>
        <% } %>
    </div>
</div>
<% } %>
<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>