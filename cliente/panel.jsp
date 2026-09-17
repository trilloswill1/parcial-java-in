<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%
String[] rolesPermitidos = { "CLIENTE" };
String tituloPagina = "Panel Cliente";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
int numCitasActivas = 0;
int numFavoritos = 0;
int numSolicitudesActivas = 0;
if (errorConexion == null) {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT COUNT(*) AS total FROM cita WHERE id_usuario = ? AND estado IN ('PENDIENTE', 'CONFIRMADA')");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            numCitasActivas = rs.getInt("total");
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement(
            "SELECT COUNT(*) AS total FROM favorito WHERE id_usuario = ?");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            numFavoritos = rs.getInt("total");
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement(
            "SELECT COUNT(*) AS total FROM solicitud WHERE id_usuario = ? AND estado IN ('EN_REVISION', 'APROBADA')");
        ps.setInt(1, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            numSolicitudesActivas = rs.getInt("total");
        }
    } catch (SQLException ignorada) {
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-4">
    <h1 class="mb-0">Panel de Cliente</h1>
    <a href="<%= ctx %>/mi-perfil.jsp" class="btn btn-outline-primary btn-sm">Mi perfil</a>
</div>

<div class="alert alert-success">
    <strong>Autenticación correcta.</strong> Sesión iniciada como
    <strong><%= session.getAttribute("nombre") %> <%= session.getAttribute("apellido") %></strong>
    (<%= session.getAttribute("correo") %>).
</div>

<p>Rol principal: <strong><%= session.getAttribute("rol") %></strong></p>

<div class="row g-3 mt-1">
    <div class="col-12 col-md-6 col-lg-4">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h5 class="card-title">Propiedades</h5>
                <p class="card-text text-muted">Consulta las propiedades disponibles, filtra por tipo, ciudad, estado y precio, y revisa el detalle de cada una.</p>
                <a href="<%= ctx %>/cliente/propiedades.jsp" class="btn btn-primary mt-auto">Ver propiedades</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-4">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h5 class="card-title">Citas</h5>
                <p class="card-text text-muted">
                    Consulta y gestiona tus citas de visita a propiedades.
                    Ahora tienes <strong><%= numCitasActivas %></strong> cita(s) en estado
                    PENDIENTE o CONFIRMADA.
                </p>
                <a href="<%= ctx %>/cliente/citas.jsp" class="btn btn-primary mt-auto">Ver mis citas</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-4">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h5 class="card-title">Mis favoritos <i class="bi bi-heart-fill text-danger"></i></h5>
                <p class="card-text text-muted">
                    Tienes <strong><%= numFavoritos %></strong> propiedad(es) guardada(s) como favorita(s).
                    Accede rápido a las que más te interesan.
                </p>
                <a href="<%= ctx %>/cliente/favoritos.jsp" class="btn btn-primary mt-auto">Ver favoritos</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-4">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h5 class="card-title">Solicitudes</h5>
                <p class="card-text text-muted">
                    Consulta y crea solicitudes de compra o alquiler de propiedades.
                    Ahora tienes <strong><%= numSolicitudesActivas %></strong> solicitud(es) en estado
                    EN_REVISION o APROBADA.
                </p>
                <a href="<%= ctx %>/cliente/solicitudes.jsp" class="btn btn-primary mt-auto">Ver solicitudes</a>
            </div>
        </div>
    </div>
</div>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>