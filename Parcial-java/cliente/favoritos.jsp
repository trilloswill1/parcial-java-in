<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.text.DecimalFormat, java.text.SimpleDateFormat" %>
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

private String formatoFecha(Timestamp ts) {
    if (ts == null) return "";
    return new SimpleDateFormat("dd/MM/yyyy").format(ts);
}

private String ipCliente(HttpServletRequest request) {
    String ip = request.getRemoteAddr();
    if (ip == null || ip.trim().isEmpty()) return null;
    ip = ip.trim();
    if (ip.length() > 45) ip = ip.substring(0, 45);
    return ip;
}
%>
<%
String[] rolesPermitidos = { "CLIENTE" };
String tituloPagina = "Mis Favoritos";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

// Procesar quitar favorito (POST -> PRG)
if ("POST".equalsIgnoreCase(request.getMethod())) {
    int idPropiedad = 0;
    try { idPropiedad = Integer.parseInt(limpiar(request.getParameter("id_propiedad"))); }
    catch (NumberFormatException ignorada) { idPropiedad = 0; }

    if (idPropiedad > 0 && errorConexion == null) {
        PreparedStatement psSel = null;
        ResultSet rsSel = null;
        int idFavoritoQuitar = -1;
        String tituloQuitar = null;
        try {
            psSel = conexion.prepareStatement(
                "SELECT f.id_favorito, p.titulo " +
                "FROM favorito f JOIN propiedad p ON p.id_propiedad = f.id_propiedad " +
                "WHERE f.id_usuario = ? AND f.id_propiedad = ?");
            psSel.setInt(1, idUsuarioSesion);
            psSel.setInt(2, idPropiedad);
            rsSel = psSel.executeQuery();
            if (rsSel.next()) {
                idFavoritoQuitar = rsSel.getInt(1);
                tituloQuitar = rsSel.getString(2);
            }
        } catch (SQLException ignorada) {
        } finally {
            cerrar(rsSel, psSel);
        }
        if (idFavoritoQuitar > 0) {
            PreparedStatement psDel = null;
            try {
                conexion.setAutoCommit(false);
                psDel = conexion.prepareStatement(
                    "DELETE FROM favorito WHERE id_usuario = ? AND id_propiedad = ?");
                psDel.setInt(1, idUsuarioSesion);
                psDel.setInt(2, idPropiedad);
                int filas = psDel.executeUpdate();
                cerrar(null, psDel);
                if (filas > 0) {
                    // Registro de auditoría (misma transacción)
                    PreparedStatement psAud = conexion.prepareStatement(
                        "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                        "VALUES (?, ?, ?, ?, ?, ?)");
                    psAud.setInt(1, idUsuarioSesion.intValue());
                    psAud.setString(2, "favorito");
                    psAud.setInt(3, idFavoritoQuitar);
                    psAud.setString(4, "DELETE");
                    psAud.setString(5, "Eliminado favorito de propiedad: " + (tituloQuitar == null ? "" : tituloQuitar));
                    String ipQuitar = ipCliente(request);
                    if (ipQuitar == null) {
                        psAud.setNull(6, Types.VARCHAR);
                    } else {
                        psAud.setString(6, ipQuitar);
                    }
                    psAud.executeUpdate();
                    cerrar(null, psAud);
                    conexion.commit();
                    response.sendRedirect(ctx + "/cliente/favoritos.jsp?quitado=1");
                    return;
                }
                deshacer(conexion);
                response.sendRedirect(ctx + "/cliente/favoritos.jsp");
                return;
            } catch (SQLException ex) {
                deshacer(conexion);
                response.sendRedirect(ctx + "/cliente/favoritos.jsp?error=1");
                return;
            } finally {
                cerrar(null, psDel);
            }
        }
        response.sendRedirect(ctx + "/cliente/favoritos.jsp");
        return;
    }

    response.sendRedirect(ctx + "/cliente/favoritos.jsp");
    return;
}

String errorFav = request.getParameter("error") == null ? null : "Ocurrió un error al quitar la propiedad de favoritos. Inténtalo más tarde.";
String errorListado = null;
List<String[]> favoritos = new ArrayList<String[]>();

if (errorConexion != null) {
    errorListado = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT f.id_favorito, f.fecha_agregado, " +
            "p.id_propiedad, p.titulo, p.precio, p.estado, " +
            "p.area_m2, p.num_habitaciones, p.num_banos, p.direccion, " +
            "cd.nombre AS ciudad_nombre, " +
            "tp.nombre AS tipo_nombre, " +
            "i.razon_social, " +
            "(SELECT ip.url_imagen FROM imagen_propiedad ip " +
            " WHERE ip.id_propiedad = p.id_propiedad AND ip.es_principal = 1 " +
            " ORDER BY ip.orden ASC, ip.id_imagen ASC LIMIT 1) AS imagen_principal " +
            "FROM favorito f " +
            "JOIN propiedad p ON p.id_propiedad = f.id_propiedad " +
            "JOIN ciudad cd ON cd.id_ciudad = p.id_ciudad " +
            "JOIN tipo_propiedad tp ON tp.id_tipo = p.id_tipo " +
            "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
            "WHERE f.id_usuario = ? " +
            "ORDER BY f.fecha_agregado DESC");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();

        DecimalFormat df = new DecimalFormat("###,###,##0");
        while (rs.next()) {
            String idFav = String.valueOf(rs.getInt("id_favorito"));
            String fechaFav = formatoFecha(rs.getTimestamp("fecha_agregado"));
            String idProp = String.valueOf(rs.getInt("id_propiedad"));
            String titulo = rs.getString("titulo");
            String precio = df.format(rs.getBigDecimal("precio"));
            String estado = rs.getString("estado");
            BigDecimal area = rs.getBigDecimal("area_m2");
            String areaStr = area == null ? "N/D" : df.format(area);
            String hab = String.valueOf(rs.getInt("num_habitaciones"));
            String ban = String.valueOf(rs.getInt("num_banos"));
            String direccion = rs.getString("direccion");
            String ciudad = rs.getString("ciudad_nombre");
            String tipo = rs.getString("tipo_nombre");
            String inmo = rs.getString("razon_social");
            String imagen = rs.getString("imagen_principal");
            favoritos.add(new String[] {
                idFav, fechaFav, idProp, titulo, precio, estado, areaStr,
                hab, ban, direccion, ciudad, tipo, inmo, imagen
            });
        }
    } catch (SQLException ex) {
        errorListado = "No se pudieron cargar los favoritos. Inténtalo más tarde.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Mis Favoritos</h1>
    <a href="<%= ctx %>/cliente/panel.jsp" class="btn btn-outline-secondary">Volver al panel</a>
</div>

<% if ("1".equals(request.getParameter("quitado"))) { %>
<div class="alert alert-success" role="alert">La propiedad fue quitada de tus favoritos.</div>
<% } %>
<% if (errorFav != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorFav) %></div>
<% } %>
<% if (errorListado != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorListado) %></div>
<% } %>

<% if (errorListado == null && favoritos.isEmpty()) { %>
<div class="alert alert-info" role="alert">
    Todavía no tienes propiedades favoritas. Visita el catálogo y agrega las que más te gusten.
    <a href="<%= ctx %>/cliente/propiedades.jsp" class="btn btn-primary btn-sm ms-2">Ver propiedades</a>
</div>
<% } else if (errorListado == null) { %>

<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
<% for (String[] f : favoritos) { %>
    <div class="col">
        <div class="card h-100 shadow-sm">
            <img class="card-img-top" style="height: 200px; object-fit: cover;"
                 src="<%= f[13] != null ? escapar(f[13]) : PLACEHOLDER_IMG %>"
                 onerror="this.onerror=null; this.src='<%= PLACEHOLDER_IMG %>';"
                 alt="<%= escapar(f[3]) %>">
            <div class="card-body d-flex flex-column">
                <div class="d-flex justify-content-between align-items-start mb-1">
                    <h5 class="card-title mb-0"><%= escapar(f[3]) %></h5>
                    <span class="badge <%= claseEstado(f[5]) %>"><%= escapar(f[5]) %></span>
                </div>
                <p class="text-muted small mb-2">
                    <%= escapar(f[11]) %> &middot; <%= escapar(f[10]) %>
                </p>
                <p class="fs-5 fw-bold text-primary mb-1">$ <%= f[4] %></p>
                <ul class="list-inline small text-muted mb-2">
                    <li class="list-inline-item"><i class="bi bi-arrows-fullscreen"></i> <%= f[6] %> m²</li>
                    <li class="list-inline-item">&#128716; <%= f[7] %> hab</li>
                    <li class="list-inline-item">&#128703; <%= f[8] %> baños</li>
                </ul>
                <p class="small text-muted mb-1"><strong><%= escapar(f[12]) %></strong></p>
                <p class="small text-muted mb-3">
                    Agregado: <%= escapar(f[1]) %> &middot; <%= escapar(f[9]) %>
                </p>
                <div class="mt-auto d-flex flex-column gap-2">
                    <a href="<%= ctx %>/cliente/detalle-propiedad.jsp?id=<%= f[2] %>"
                       class="btn btn-sm btn-outline-primary w-100">Ver detalle</a>
                    <form method="post" action="<%= ctx %>/cliente/favoritos.jsp"
                          onsubmit="return confirm('¿Quitar esta propiedad de tus favoritos?');">
                        <input type="hidden" name="id_propiedad" value="<%= f[2] %>">
                        <button type="submit" class="btn btn-sm btn-danger w-100">
                            <i class="bi bi-heart-fill"></i> Quitar de favoritos
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </div>
<% } %>
</div>

<% } %>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>