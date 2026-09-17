<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.text.DecimalFormat" %>
<%!
private static final String[] TIPOS_SOLICITUD = { "COMPRA", "ALQUILER" };

private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private boolean tipoValido(String tipo) {
    if (tipo == null) return false;
    for (String t : TIPOS_SOLICITUD) {
        if (t.equals(tipo)) return true;
    }
    return false;
}
%>
<%
String[] rolesPermitidos = { "CLIENTE" };
String tituloPagina = "Crear Solicitud";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

int idPropiedad = 0;
try { idPropiedad = Integer.parseInt(limpiar(request.getParameter("id_propiedad"))); }
catch (NumberFormatException ignorada) { idPropiedad = 0; }

String errorFormulario = null;
String mensajeInfo = null;

boolean propiedadEncontrada = false;
String titulo = null, precio = null, ciudadNombre = null, departamento = null;
String tipoNombre = null, estadoPropiedad = null, razonSocial = null;

String tipoSeleccionado = "COMPRA";
String notasPrevia = "";

if (idPropiedad <= 0) {
    errorFormulario = "Propiedad no especificada.";
} else if (errorConexion != null) {
    errorFormulario = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    DecimalFormat df = new DecimalFormat("###,###,##0");
    try {
        ps = conexion.prepareStatement(
            "SELECT p.titulo, p.precio, p.estado, p.id_ciudad, " +
            "c.nombre AS ciudad_nombre, c.departamento, " +
            "t.nombre AS tipo_nombre, i.razon_social " +
            "FROM propiedad p " +
            "JOIN tipo_propiedad t ON t.id_tipo = p.id_tipo " +
            "JOIN ciudad c ON c.id_ciudad = p.id_ciudad " +
            "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
            "WHERE p.id_propiedad = ?");
        ps.setInt(1, idPropiedad);
        rs = ps.executeQuery();
        if (rs.next()) {
            propiedadEncontrada = true;
            titulo = rs.getString("titulo");
            precio = df.format(rs.getBigDecimal("precio"));
            estadoPropiedad = rs.getString("estado");
            ciudadNombre = rs.getString("ciudad_nombre");
            departamento = rs.getString("departamento");
            tipoNombre = rs.getString("tipo_nombre");
            razonSocial = rs.getString("razon_social");
            tituloPagina = "Solicitar: " + titulo;
        }
        cerrar(rs, ps);
    } catch (SQLException ex) {
        errorFormulario = "No se pudo cargar la información de la propiedad. Inténtalo más tarde.";
    } finally {
        cerrar(rs, ps);
    }
    if (!propiedadEncontrada && errorFormulario == null) {
        errorFormulario = "La propiedad solicitada no existe.";
    }
}

if (errorFormulario == null && propiedadEncontrada
        && "POST".equalsIgnoreCase(request.getMethod())) {
    tipoSeleccionado = limpiar(request.getParameter("tipo"));
    notasPrevia = limpiar(request.getParameter("notas"));

    if (!tipoValido(tipoSeleccionado)) {
        errorFormulario = "Debes elegir un tipo válido: COMPRA o ALQUILER.";
    } else {
        PreparedStatement psChk = null;
        ResultSet rsChk = null;
        boolean yaExiste = false;
        try {
            psChk = conexion.prepareStatement(
                "SELECT COUNT(*) AS total FROM solicitud WHERE id_usuario = ? AND id_propiedad = ?");
            psChk.setInt(1, idUsuarioSesion);
            psChk.setInt(2, idPropiedad);
            rsChk = psChk.executeQuery();
            if (rsChk.next()) {
                yaExiste = rsChk.getInt("total") > 0;
            }
            cerrar(rsChk, psChk);
        } catch (SQLException ex) {
            errorFormulario = "Ocurrió un error al verificar la solicitud. Inténtalo más tarde.";
        }

        if (errorFormulario == null && yaExiste) {
            errorFormulario = "Ya tienes una solicitud registrada para esta propiedad.";
        }

        if (errorFormulario == null) {
            PreparedStatement psIns = null;
            ResultSet rsGen = null;
            int idNueva = 0;
            try {
                psIns = conexion.prepareStatement(
                    "INSERT INTO solicitud (id_usuario, id_propiedad, tipo, notas) VALUES (?, ?, ?, ?)",
                    Statement.RETURN_GENERATED_KEYS);
                psIns.setInt(1, idUsuarioSesion);
                psIns.setInt(2, idPropiedad);
                psIns.setString(3, tipoSeleccionado);
                if (notasPrevia.isEmpty()) {
                    psIns.setString(4, null);
                } else {
                    psIns.setString(4, notasPrevia);
                }
                psIns.executeUpdate();
                rsGen = psIns.getGeneratedKeys();
                if (rsGen.next()) {
                    idNueva = rsGen.getInt(1);
                }
                cerrar(rsGen, psIns);
            } catch (SQLException ex) {
                cerrar(rsGen, psIns);
                errorFormulario = "Ocurrió un error al crear la solicitud. Inténtalo más tarde.";
            }
            if (errorFormulario == null && idNueva > 0) {
                response.sendRedirect(ctx + "/cliente/detalle-solicitud.jsp?id=" + idNueva + "&ok=1");
                return;
            }
            if (errorFormulario == null) {
                errorFormulario = "No se pudo crear la solicitud. Inténtalo más tarde.";
            }
        }
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Solicitar <span class="text-primary">compra / alquiler</span></h1>
    <a href="<%= ctx %>/cliente/propiedades.jsp" class="btn btn-outline-secondary">Volver a propiedades</a>
</div>

<% if (mensajeInfo != null) { %>
<div class="alert alert-info" role="alert"><%= escapar(mensajeInfo) %></div>
<% } %>

<% if (errorFormulario != null) { %>
<div class="alert alert-<%= "Ya tienes una solicitud registrada para esta propiedad.".equals(errorFormulario) ? "warning" : "danger" %>" role="alert">
    <%= escapar(errorFormulario) %>
</div>
<% } %>

<% if (propiedadEncontrada) { %>
<div class="row g-4">
    <div class="col-12 col-lg-5">
        <div class="card shadow-sm">
            <div class="card-body">
                <h5 class="card-title"><%= escapar(titulo) %></h5>
                <p class="text-muted mb-2"><%= escapar(tipoNombre) %> &middot; <%= escapar(ciudadNombre) %>, <%= escapar(departamento) %></p>
                <p class="fs-4 fw-bold text-primary mb-2">$ <%= precio %></p>
                <p class="mb-1"><strong>Estado:</strong> <%= escapar(estadoPropiedad) %></p>
                <p class="mb-0"><strong>Inmobiliaria:</strong> <%= escapar(razonSocial) %></p>
            </div>
        </div>
    </div>
    <div class="col-12 col-lg-7">
        <div class="card shadow-sm">
            <div class="card-header">Datos de la solicitud</div>
            <div class="card-body">
                <form method="post" action="<%= ctx %>/cliente/crear-solicitud.jsp?id_propiedad=<%= idPropiedad %>">
                    <div class="mb-3">
                        <label for="tipo" class="form-label">Tipo de solicitud</label>
                        <select id="tipo" name="tipo" class="form-select">
                            <% for (String t : TIPOS_SOLICITUD) { %>
                            <option value="<%= t %>" <%= t.equals(tipoSeleccionado) ? "selected" : "" %>><%= t %></option>
                            <% } %>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label for="notas" class="form-label">Notas <span class="text-muted">(opcional)</span></label>
                        <textarea id="notas" name="notas" class="form-control" rows="4"
                                  maxlength="2000" placeholder="Ej.: ofrecimiento inicial, condiciones, observaciones..."><%= escapar(notasPrevia) %></textarea>
                    </div>
                    <p class="text-muted small">
                        Al crear la solicitud, se registrará automáticamente en estado
                        <strong>EN_REVISION</strong>. La inmobiliaria evaluará tu solicitud.
                    </p>
                    <button type="submit" class="btn btn-primary">Crear solicitud</button>
                    <a href="<%= ctx %>/cliente/detalle-propiedad.jsp?id=<%= idPropiedad %>" class="btn btn-outline-secondary">Cancelar</a>
                </form>
            </div>
        </div>
    </div>
</div>
<% } else if (errorFormulario != null) { %>
<a href="<%= ctx %>/cliente/propiedades.jsp" class="btn btn-outline-secondary">Volver a propiedades</a>
<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>