<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%!
private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}
%>
<%
String[] rolesPermitidos = { "INMOBILIARIA" };
String tituloPagina = "Panel Inmobiliaria";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
String razonSocial = null, nit = null, telefono = null, direccionInmo = null;
boolean activa = false;
int numPropiedades = 0;
int numSolicitudes = 0;
String errorDatos = null;

if (errorConexion != null) {
    errorDatos = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT id_inmobiliaria, razon_social, nit, telefono, direccion, activa " +
            "FROM inmobiliaria WHERE id_usuario = ? LIMIT 1");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            razonSocial = rs.getString("razon_social");
            nit = rs.getString("nit");
            telefono = rs.getString("telefono");
            direccionInmo = rs.getString("direccion");
            activa = rs.getInt("activa") == 1;
            int idInmobiliaria = rs.getInt("id_inmobiliaria");
            cerrar(rs, ps);

            ps = conexion.prepareStatement(
                "SELECT COUNT(*) AS total FROM propiedad WHERE id_inmobiliaria = ?");
            ps.setInt(1, idInmobiliaria);
            rs = ps.executeQuery();
            if (rs.next()) {
                numPropiedades = rs.getInt("total");
            }
            cerrar(rs, ps);

            ps = conexion.prepareStatement(
                "SELECT COUNT(*) AS total FROM solicitud s " +
                "JOIN propiedad p ON p.id_propiedad = s.id_propiedad " +
                "WHERE p.id_inmobiliaria = ?");
            ps.setInt(1, idInmobiliaria);
            rs = ps.executeQuery();
            if (rs.next()) {
                numSolicitudes = rs.getInt("total");
            }
        }
    } catch (SQLException ex) {
        errorDatos = "Ocurrió un error al consultar la información de tu inmobiliaria.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-4">
    <h1 class="mb-0">Panel de Inmobiliaria</h1>
    <a href="<%= ctx %>/mi-perfil.jsp" class="btn btn-outline-primary btn-sm">Mi perfil</a>
</div>

<div class="alert alert-info">
    <strong>Sesión iniciada como:</strong>
    <%= escapar((String) session.getAttribute("nombre")) %> <%= escapar((String) session.getAttribute("apellido")) %>
    (<%= escapar((String) session.getAttribute("correo")) %>).
</div>

<% if (errorDatos != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorDatos) %></div>
<% } else if (razonSocial == null) { %>
<div class="alert alert-warning" role="alert">
    Tu usuario aún no tiene una inmobiliaria asociada en el sistema. Contacta al administrador.
</div>
<% } else { %>

<div class="row g-3 mb-4">
    <div class="col-12 col-lg-7">
        <div class="card shadow-sm h-100">
            <div class="card-body">
                <h5 class="card-title"><%= escapar(razonSocial) %></h5>
                <p class="card-text text-muted mb-1">
                    NIT: <strong><%= escapar(nit) %></strong><br>
                    Teléfono: <strong><%= escapar(telefono) %></strong><br>
                    Dirección: <strong><%= escapar(direccionInmo) %></strong><br>
                    Estado:
                    <% if (activa) { %>
                    <span class="badge bg-success">Activa</span>
                    <% } else { %>
                    <span class="badge bg-danger">Inactiva</span>
                    <% } %>
                </p>
            </div>
        </div>
    </div>
    <div class="col-12 col-lg-5">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column justify-content-center text-center">
                <p class="display-5 fw-bold mb-0"><%= numPropiedades %></p>
                <p class="text-muted mb-0">propiedades registradas</p>
            </div>
        </div>
    </div>
</div>

<div class="row g-3">
    <div class="col-12 col-md-6 col-lg-3">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h6 class="card-title">Mis propiedades</h6>
                <p class="card-text text-muted small">Consulta, edita o elimina las propiedades de tu inmobiliaria.</p>
                <a href="<%= ctx %>/inmobiliaria/propiedades.jsp" class="btn btn-primary mt-auto">Ver listado</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-3">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h6 class="card-title">Registrar propiedad</h6>
                <p class="card-text text-muted small">Crea una nueva propiedad con sus características e imágenes.</p>
                <a href="<%= ctx %>/inmobiliaria/crear-propiedad.jsp" class="btn btn-success mt-auto">Nueva propiedad</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-3">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h6 class="card-title">Citas</h6>
                <p class="card-text text-muted small">Consulta y gestiona las citas de visita a las propiedades de tu inmobiliaria.</p>
                <a href="<%= ctx %>/inmobiliaria/citas.jsp" class="btn btn-primary mt-auto">Ver citas</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-3">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h6 class="card-title">Solicitudes</h6>
                <p class="card-text text-muted small">Revisa y gestiona las solicitudes de compra o alquiler de tus propiedades. Tienes <strong><%= numSolicitudes %></strong> solicitud(es).</p>
                <a href="<%= ctx %>/inmobiliaria/solicitudes.jsp" class="btn btn-primary mt-auto">Ver solicitudes</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-3">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h6 class="card-title">Salir</h6>
                <p class="card-text text-muted small">Cierra tu sesión de forma segura.</p>
                <a href="<%= ctx %>/cerrar-sesion.jsp" class="btn btn-outline-danger mt-auto">Cerrar sesión</a>
            </div>
        </div>
    </div>
</div>

<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>