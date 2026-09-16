<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
String[] rolesPermitidos = { "ADMINISTRADOR" };
String tituloPagina = "Panel Administrador";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-4">
    <h1 class="mb-0">Panel de Administrador</h1>
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
                <h5 class="card-title">Auditoría</h5>
                <p class="card-text text-muted">Consulta el registro de acciones del sistema.</p>
                <a href="<%= ctx %>/admin/auditoria.jsp" class="btn btn-primary mt-auto">Ver auditoría</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-4">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h5 class="card-title">Reportes</h5>
                <p class="card-text text-muted">Consulta consultas con INNER JOIN, LEFT JOIN, N:M, GROUP BY y HAVING.</p>
                <a href="<%= ctx %>/admin/reportes.jsp" class="btn btn-primary mt-auto">Ver reportes</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-4">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h5 class="card-title">Gestión de usuarios</h5>
                <p class="card-text text-muted">Activa o desactiva cuentas y asigna/retira roles de acceso.</p>
                <a href="<%= ctx %>/admin/usuarios.jsp" class="btn btn-primary mt-auto">Ver usuarios</a>
            </div>
        </div>
    </div>
    <div class="col-12 col-md-6 col-lg-4">
        <div class="card shadow-sm h-100">
            <div class="card-body d-flex flex-column">
                <h5 class="card-title">Gestión de catálogos</h5>
                <p class="card-text text-muted">Administra ciudades, tipos de propiedad y características del catálogo.</p>
                <a href="<%= ctx %>/admin/catalogos.jsp" class="btn btn-primary mt-auto">Ver catálogos</a>
            </div>
        </div>
    </div>
</div>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>