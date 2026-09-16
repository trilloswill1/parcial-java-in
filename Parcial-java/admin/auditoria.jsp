<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%!
private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private String formatoFecha(Timestamp ts) {
    if (ts == null) return "";
    return new SimpleDateFormat("dd/MM/yyyy HH:mm").format(ts);
}

private String claseAccion(String accion) {
    if ("INSERT".equals(accion)) return "bg-success";
    if ("UPDATE".equals(accion)) return "bg-warning text-dark";
    if ("DELETE".equals(accion)) return "bg-danger";
    if ("LOGIN".equals(accion))  return "bg-info text-dark";
    return "bg-secondary";
}

private java.sql.Date parsearFecha(String texto) {
    if (texto == null || texto.trim().isEmpty()) return null;
    SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
    sdf.setLenient(false);
    try {
        java.util.Date fecha = sdf.parse(texto.trim());
        if (!sdf.format(fecha).equals(texto.trim())) return null;
        return new java.sql.Date(fecha.getTime());
    } catch (java.text.ParseException ex) {
        return null;
    }
}
%>
<%
String[] rolesPermitidos = { "ADMINISTRADOR" };
String tituloPagina = "Auditoría del sistema";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String filtroTabla = limpiar(request.getParameter("tabla"));
String filtroAccion = limpiar(request.getParameter("accion"));
String paramUsuario = limpiar(request.getParameter("id_usuario"));
String paramFechaDesde = limpiar(request.getParameter("fecha_desde"));
String paramFechaHasta = limpiar(request.getParameter("fecha_hasta"));

Integer filtroUsuario = null;
boolean usuarioInvalido = false;
if (!paramUsuario.isEmpty()) {
    try {
        filtroUsuario = Integer.valueOf(paramUsuario);
    } catch (NumberFormatException ex) {
        usuarioInvalido = true;
    }
}

java.sql.Date fechaDesde = parsearFecha(paramFechaDesde);
java.sql.Date fechaHasta = parsearFecha(paramFechaHasta);
boolean fechaDesdeInvalida = !paramFechaDesde.isEmpty() && fechaDesde == null;
boolean fechaHastaInvalida = !paramFechaHasta.isEmpty() && fechaHasta == null;
if (fechaDesdeInvalida) fechaDesde = null;
if (fechaHastaInvalida) fechaHasta = null;

List<String> erroresFiltros = new ArrayList<String>();
if (usuarioInvalido) {
    erroresFiltros.add("El filtro de usuario debe ser un número entero (id_usuario).");
}
if (fechaDesdeInvalida) {
    erroresFiltros.add("La fecha 'desde' no tiene el formato válido (YYYY-MM-DD).");
}
if (fechaHastaInvalida) {
    erroresFiltros.add("La fecha 'hasta' no tiene el formato válido (YYYY-MM-DD).");
}

String errorAuditoria = null;
List<String[]> registros = new ArrayList<String[]>();
List<String> tablas = new ArrayList<String>();
List<String> acciones = new ArrayList<String>();

if (errorConexion != null) {
    errorAuditoria = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement psDist = null;
    ResultSet rsDist = null;
    try {
        psDist = conexion.prepareStatement("SELECT DISTINCT tabla_afectada FROM auditoria ORDER BY tabla_afectada");
        rsDist = psDist.executeQuery();
        while (rsDist.next()) {
            tablas.add(rsDist.getString(1));
        }
    } catch (SQLException ex) {
        errorAuditoria = "Ocurrió un error al consultar los filtros disponibles. Inténtalo más tarde.";
    } finally {
        cerrar(rsDist, psDist);
    }

    PreparedStatement psAcc = null;
    ResultSet rsAcc = null;
    if (errorAuditoria == null) {
        try {
            psAcc = conexion.prepareStatement("SELECT DISTINCT accion FROM auditoria ORDER BY accion");
            rsAcc = psAcc.executeQuery();
            while (rsAcc.next()) {
                acciones.add(rsAcc.getString(1));
            }
        } catch (SQLException ex) {
            errorAuditoria = "Ocurrió un error al consultar los filtros disponibles. Inténtalo más tarde.";
        } finally {
            cerrar(rsAcc, psAcc);
        }
    }
}

if (errorAuditoria == null) {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        StringBuilder sql = new StringBuilder(
            "SELECT a.id_auditoria, a.id_usuario, a.tabla_afectada, a.id_registro, a.accion, a.detalles, " +
            "a.fecha_accion, a.ip_address, u.nombre, u.apellido, u.correo " +
            "FROM auditoria a " +
            "LEFT JOIN usuario u ON a.id_usuario = u.id_usuario " +
            "WHERE 1=1");
        int numParams = 0;
        if (!filtroTabla.isEmpty()) {
            sql.append(" AND a.tabla_afectada = ?");
            numParams++;
        }
        if (!filtroAccion.isEmpty()) {
            sql.append(" AND a.accion = ?");
            numParams++;
        }
        if (filtroUsuario != null) {
            sql.append(" AND a.id_usuario = ?");
            numParams++;
        }
        if (fechaDesde != null) {
            sql.append(" AND a.fecha_accion >= ?");
            numParams++;
        }
        if (fechaHasta != null) {
            sql.append(" AND a.fecha_accion < DATE_ADD(?, INTERVAL 1 DAY)");
            numParams++;
        }
        sql.append(" ORDER BY a.fecha_accion DESC, a.id_auditoria DESC");

        ps = conexion.prepareStatement(sql.toString());
        int idx = 1;
        if (!filtroTabla.isEmpty()) {
            ps.setString(idx++, filtroTabla);
        }
        if (!filtroAccion.isEmpty()) {
            ps.setString(idx++, filtroAccion);
        }
        if (filtroUsuario != null) {
            ps.setInt(idx++, filtroUsuario);
        }
        if (fechaDesde != null) {
            ps.setDate(idx++, fechaDesde);
        }
        if (fechaHasta != null) {
            ps.setDate(idx, fechaHasta);
        }
        rs = ps.executeQuery();
        while (rs.next()) {
            String idAud = String.valueOf(rs.getInt("id_auditoria"));
            boolean usuarioNull = rs.getObject("id_usuario") == null;
            String usuarioMostrado;
            String correoUsuario = "";
            if (usuarioNull) {
                usuarioMostrado = "Usuario eliminado";
            } else {
                String nombre = rs.getString("nombre");
                String apellido = rs.getString("apellido");
                String correo = rs.getString("correo");
                StringBuilder nombreCompleto = new StringBuilder();
                if (nombre != null && !nombre.trim().isEmpty()) {
                    nombreCompleto.append(nombre.trim());
                }
                if (apellido != null && !apellido.trim().isEmpty()) {
                    if (nombreCompleto.length() > 0) nombreCompleto.append(" ");
                    nombreCompleto.append(apellido.trim());
                }
                if (nombreCompleto.length() == 0) {
                    nombreCompleto.append("Usuario ").append(rs.getInt("id_usuario"));
                }
                usuarioMostrado = nombreCompleto.toString();
                correoUsuario = correo == null ? "" : correo;
            }
            String idRegistro = rs.getObject("id_registro") == null ? "" : String.valueOf(rs.getInt("id_registro"));
            String detalles = rs.getString("detalles");
            String ip = rs.getString("ip_address");
            registros.add(new String[] {
                idAud,
                usuarioMostrado,
                correoUsuario,
                rs.getString("tabla_afectada"),
                idRegistro,
                rs.getString("accion"),
                detalles == null ? "" : detalles,
                formatoFecha(rs.getTimestamp("fecha_accion")),
                ip == null ? "" : ip
            });
        }
    } catch (SQLException ex) {
        errorAuditoria = "Ocurrió un error al consultar la auditoría. Inténtalo más tarde.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Auditoría del sistema</h1>
    <div class="mt-2 mt-md-0">
        <a href="<%= ctx %>/admin/auditoria.jsp" class="btn btn-outline-secondary">Limpiar filtros</a>
        <a href="<%= ctx %>/admin/panel.jsp" class="btn btn-outline-secondary">Volver al panel</a>
    </div>
</div>

<form method="get" action="<%= ctx %>/admin/auditoria.jsp" class="row g-2 align-items-end mb-3">
    <div class="col-auto">
        <label for="tabla" class="form-label mb-1">Tabla afectada:</label>
        <select id="tabla" name="tabla" class="form-select">
            <option value="">Todas las tablas</option>
            <% for (String t : tablas) { %>
            <option value="<%= escapar(t) %>" <%= t.equals(filtroTabla) ? "selected" : "" %>><%= escapar(t) %></option>
            <% } %>
        </select>
    </div>
    <div class="col-auto">
        <label for="accion" class="form-label mb-1">Acción:</label>
        <select id="accion" name="accion" class="form-select">
            <option value="">Todas las acciones</option>
            <% for (String a : acciones) { %>
            <option value="<%= escapar(a) %>" <%= a.equals(filtroAccion) ? "selected" : "" %>><%= escapar(a) %></option>
            <% } %>
        </select>
    </div>
    <div class="col-auto">
        <label for="id_usuario" class="form-label mb-1">ID usuario:</label>
        <input type="number" id="id_usuario" name="id_usuario" class="form-control"
               value="<%= escapar(paramUsuario) %>" min="1">
    </div>
    <div class="col-auto">
        <label for="fecha_desde" class="form-label mb-1">Desde:</label>
        <input type="date" id="fecha_desde" name="fecha_desde" class="form-control"
               value="<%= escapar(paramFechaDesde) %>">
    </div>
    <div class="col-auto">
        <label for="fecha_hasta" class="form-label mb-1">Hasta:</label>
        <input type="date" id="fecha_hasta" name="fecha_hasta" class="form-control"
               value="<%= escapar(paramFechaHasta) %>">
    </div>
    <div class="col-auto">
        <button type="submit" class="btn btn-primary">Filtrar</button>
    </div>
</form>

<% if (!erroresFiltros.isEmpty()) { %>
<div class="alert alert-warning" role="alert">
    <ul class="mb-0">
        <% for (String e : erroresFiltros) { %>
        <li><%= escapar(e) %></li>
        <% } %>
    </ul>
</div>
<% } %>

<% if (errorAuditoria != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorAuditoria) %></div>
<% } else { %>
<p class="text-muted">Registros encontrados: <strong><%= registros.size() %></strong></p>

<% if (registros.isEmpty()) { %>
<div class="alert alert-info" role="alert">
    No hay registros de auditoría que coincidan con los criterios indicados.
</div>
<% } else { %>
<div class="table-responsive">
    <table class="table table-striped table-hover align-middle">
        <thead class="table-light">
            <tr>
                <th>ID</th>
                <th>Usuario</th>
                <th>Tabla afectada</th>
                <th>ID registro</th>
                <th>Acción</th>
                <th>Detalles</th>
                <th>Fecha</th>
                <th>IP</th>
            </tr>
        </thead>
        <tbody>
            <% for (String[] a : registros) { %>
            <tr>
                <td><strong>#<%= escapar(a[0]) %></strong></td>
                <td>
                    <strong><%= escapar(a[1]) %></strong>
                    <% if (!a[2].isEmpty()) { %>
                    <br><small class="text-muted"><%= escapar(a[2]) %></small>
                    <% } %>
                </td>
                <td><span class="badge bg-secondary"><%= escapar(a[3]) %></span></td>
                <td><%= a[4].isEmpty() ? "<span class='text-muted'>N/D</span>" : escapar(a[4]) %></td>
                <td><span class="badge <%= claseAccion(a[5]) %>"><%= escapar(a[5]) %></span></td>
                <td><%= escapar(a[6]) %></td>
                <td><%= escapar(a[7]) %></td>
                <td><%= a[8].isEmpty() ? "<span class='text-muted'>No registrada</span>" : escapar(a[8]) %></td>
            </tr>
            <% } %>
        </tbody>
    </table>
</div>
<% } %>
<% } %>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>