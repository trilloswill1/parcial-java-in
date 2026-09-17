<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
String tituloPagina = "Acceso denegado";
String ctx = request.getContextPath();
String rolSesion = (session != null) ? (String) session.getAttribute("rol") : null;
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="row justify-content-center">
    <div class="col-md-7">
        <div class="card border-0 shadow-sm text-center p-4 p-md-5 mt-4">
            <div class="mb-3">
                <span style="font-size:3.5rem; line-height:1;">&#128683;</span>
            </div>
            <h1 class="h3 mb-3">Acceso denegado</h1>
            <p class="text-muted mb-4">
                No tienes permiso para ver esta sección. Tu cuenta
                <% if (rolSesion != null) { %>
                    está autenticada con el rol <strong><%= rolSesion %></strong>,
                <% } else { %>
                    no tiene una sesión activa,
                <% } %>
                pero la página que intentaste abrir requiere un rol distinto.
            </p>
            <div class="d-flex justify-content-center gap-2 flex-wrap">
                <a href="<%= ctx %>/index.jsp" class="btn btn-primary">Ir al inicio</a>
                <% if (rolSesion == null) { %>
                    <a href="<%= ctx %>/login.jsp" class="btn btn-outline-secondary">Iniciar sesión</a>
                <% } %>
            </div>
        </div>
    </div>
</div>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>