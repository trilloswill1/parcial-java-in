<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%!
private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

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
String tituloPagina = "Eliminar Propiedad";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
int idPropiedad = 0;
try { idPropiedad = Integer.parseInt(limpiar(request.getParameter("id"))); }
catch (NumberFormatException ignorada) { idPropiedad = 0; }

boolean esPost = "POST".equalsIgnoreCase(request.getMethod());
String mensajeError = null;

boolean encontrada = false;
String titulo = null, estado = null, precio = null, tipoNombre = null, ciudadNombre = null;

if (errorConexion != null) {
    mensajeError = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Integer idInmobiliaria = null;
        ps = conexion.prepareStatement(
            "SELECT id_inmobiliaria FROM inmobiliaria WHERE id_usuario = ? LIMIT 1");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            idInmobiliaria = Integer.valueOf(rs.getInt("id_inmobiliaria"));
        }
        cerrar(rs, ps);

        if (idPropiedad <= 0) {
            mensajeError = "Propiedad no especificada.";
        } else if (idInmobiliaria == null) {
            mensajeError = "No tienes una inmobiliaria asociada en el sistema.";
        } else if (esPost) {
            // Eliminación: solo si la propiedad pertenece a la inmobiliaria autenticada.
            // Los registros relacionados (imagen_propiedad, propiedad_caracteristica)
            // se eliminan en cascada por las FKs ON DELETE CASCADE.
            boolean eliminada = false;
            try {
                conexion.setAutoCommit(false);

                String tituloEliminada = null;
                ps = conexion.prepareStatement(
                    "SELECT titulo FROM propiedad WHERE id_propiedad = ? AND id_inmobiliaria = ?");
                ps.setInt(1, idPropiedad);
                ps.setInt(2, idInmobiliaria.intValue());
                rs = ps.executeQuery();
                if (rs.next()) {
                    tituloEliminada = rs.getString("titulo");
                }
                cerrar(rs, ps);

                ps = conexion.prepareStatement(
                    "DELETE FROM propiedad WHERE id_propiedad = ? AND id_inmobiliaria = ?");
                ps.setInt(1, idPropiedad);
                ps.setInt(2, idInmobiliaria.intValue());
                int eliminadas = ps.executeUpdate();
                if (eliminadas == 0) {
                    deshacer(conexion);
                    mensajeError = "La propiedad no existe o no pertenece a tu inmobiliaria.";
                } else {
                    if (tituloEliminada == null) tituloEliminada = "Sin título";
                    ps = conexion.prepareStatement(
                        "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                        "VALUES (?, ?, ?, ?, ?, ?)");
                    ps.setInt(1, idUsuarioSesion.intValue());
                    ps.setString(2, "propiedad");
                    ps.setInt(3, idPropiedad);
                    ps.setString(4, "DELETE");
                    ps.setString(5, "Eliminación de propiedad: " + tituloEliminada);
                    String ipDel = ipCliente(request);
                    if (ipDel == null) {
                        ps.setNull(6, Types.VARCHAR);
                    } else {
                        ps.setString(6, ipDel);
                    }
                    ps.executeUpdate();
                    cerrar(rs, ps);
                    conexion.commit();
                    eliminada = true;
                }
            } catch (SQLException ex) {
                deshacer(conexion);
                mensajeError = "Ocurrió un error al procesar la solicitud. Inténtalo nuevamente.";
            }
            if (eliminada) {
                response.sendRedirect(ctx + "/inmobiliaria/propiedades.jsp?eliminada=1");
                return;
            }
        } else {
            // Carga la propiedad para mostrar la confirmación (verificando la pertenencia)
            ps = conexion.prepareStatement(
                "SELECT p.titulo, p.estado, p.precio, t.nombre AS tipo_nombre, c.nombre AS ciudad_nombre " +
                "FROM propiedad p " +
                "JOIN tipo_propiedad t ON t.id_tipo = p.id_tipo " +
                "JOIN ciudad c ON c.id_ciudad = p.id_ciudad " +
                "WHERE p.id_propiedad = ? AND p.id_inmobiliaria = ?");
            ps.setInt(1, idPropiedad);
            ps.setInt(2, idInmobiliaria.intValue());
            rs = ps.executeQuery();
            if (rs.next()) {
                encontrada = true;
                titulo = rs.getString("titulo");
                estado = rs.getString("estado");
                java.text.DecimalFormat df = new java.text.DecimalFormat("###,###,##0");
                precio = df.format(rs.getBigDecimal("precio"));
                tipoNombre = rs.getString("tipo_nombre");
                ciudadNombre = rs.getString("ciudad_nombre");
            } else {
                mensajeError = "La propiedad no existe o no pertenece a tu inmobiliaria.";
            }
        }
    } catch (SQLException ex) {
        mensajeError = "Ocurrió un error al procesar la solicitud. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-3">
    <h1 class="mb-0">Eliminar propiedad</h1>
    <a href="<%= ctx %>/inmobiliaria/propiedades.jsp" class="btn btn-outline-secondary">Volver al listado</a>
</div>

<% if (mensajeError != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(mensajeError) %></div>
<% } else if (encontrada) { %>

<div class="alert alert-warning" role="alert">
    <strong>¿Estás seguro de eliminar la siguiente propiedad?</strong>
    Esta acción no se puede deshacer. Las imágenes y características asociadas se eliminarán automáticamente.
</div>

<div class="card shadow-sm mb-4">
    <div class="card-body">
        <h5 class="card-title"><%= escapar(titulo) %></h5>
        <p class="mb-1"><%= escapar(tipoNombre) %> &middot; <%= escapar(ciudadNombre) %></p>
        <p class="mb-0">Precio: <strong>$ <%= precio %></strong> &middot; Estado:
            <span class="badge bg-secondary"><%= escapar(estado) %></span>
        </p>
    </div>
</div>

<form method="post" action="<%= ctx %>/inmobiliaria/eliminar-propiedad.jsp" class="d-flex gap-2">
    <input type="hidden" name="id" value="<%= idPropiedad %>">
    <button type="submit" class="btn btn-danger">Sí, eliminar propiedad</button>
    <a href="<%= ctx %>/inmobiliaria/propiedades.jsp" class="btn btn-outline-secondary">Cancelar</a>
</form>

<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>