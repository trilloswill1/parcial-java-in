<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%!
private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private String claseEstado(String estado) {
    if ("PENDIENTE".equals(estado))  return "bg-warning text-dark";
    if ("CONFIRMADA".equals(estado)) return "bg-info text-dark";
    if ("CANCELADA".equals(estado))  return "bg-secondary";
    return "bg-success";
}

private String formatoFecha(Timestamp ts) {
    if (ts == null) return "";
    return new SimpleDateFormat("dd/MM/yyyy").format(ts);
}

private String formatoHora(Timestamp ts) {
    if (ts == null) return "";
    return new SimpleDateFormat("HH:mm").format(ts);
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
String[] rolesPermitidos = { "CLIENTE" };
String tituloPagina = "Detalle de Cita";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

int idCita = 0;
try { idCita = Integer.parseInt(limpiar(request.getParameter("id"))); }
catch (NumberFormatException ignorada) { idCita = 0; }

String errorDetalle = null;
String infoDetalle = null;
boolean encontrada = false;
boolean cancelable = false;
boolean canceladaOk = false;

String fecha = null, hora = null, estadoCita = null, notas = null;
String idPropiedad = "0", titulo = null, direccion = null, ciudadNombre = null;
String inmoRazon = null, inmoTelefono = null, inmoDireccion = null;

if (idCita <= 0) {
    errorDetalle = "Cita no especificada.";
} else if (errorConexion != null) {
    errorDetalle = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    boolean accionCancelacion = "POST".equalsIgnoreCase(request.getMethod())
            && "1".equals(limpiar(request.getParameter("cancelar")));

    if (accionCancelacion) {
        PreparedStatement psUpd = null;
        try {
            conexion.setAutoCommit(false);
            psUpd = conexion.prepareStatement(
                "UPDATE cita SET estado = 'CANCELADA' " +
                "WHERE id_cita = ? AND id_usuario = ? AND estado IN ('PENDIENTE', 'CONFIRMADA')");
            psUpd.setInt(1, idCita);
            psUpd.setInt(2, idUsuarioSesion);
            int filas = psUpd.executeUpdate();
            if (filas > 0) {
                // Registro de auditoría (misma transacción)
                PreparedStatement psAud = conexion.prepareStatement(
                    "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                    "VALUES (?, ?, ?, ?, ?, ?)");
                psAud.setInt(1, idUsuarioSesion.intValue());
                psAud.setString(2, "cita");
                psAud.setInt(3, idCita);
                psAud.setString(4, "UPDATE");
                psAud.setString(5, "Cancelación de cita");
                String ipCancelar = ipCliente(request);
                if (ipCancelar == null) {
                    psAud.setNull(6, Types.VARCHAR);
                } else {
                    psAud.setString(6, ipCancelar);
                }
                psAud.executeUpdate();
                cerrar(null, psAud);
                conexion.commit();
                canceladaOk = true;
            } else {
                deshacer(conexion);
                errorDetalle = "No se pudo cancelar esta cita. Verifica que te pertenezca y que su estado lo permita.";
            }
        } catch (SQLException ex) {
            deshacer(conexion);
            errorDetalle = "Ocurrió un error al cancelar la cita. Inténtalo más tarde.";
        } finally {
            cerrar(null, psUpd);
        }
    }

    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT c.id_cita, c.fecha_hora, c.estado AS cita_estado, c.notas, " +
            "p.id_propiedad, p.titulo, p.direccion, cd.nombre AS ciudad_nombre, " +
            "i.razon_social, i.telefono AS inmo_telefono, i.direccion AS inmo_direccion " +
            "FROM cita c " +
            "JOIN propiedad p ON p.id_propiedad = c.id_propiedad " +
            "JOIN ciudad cd ON cd.id_ciudad = p.id_ciudad " +
            "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
            "WHERE c.id_cita = ? AND c.id_usuario = ?");
        ps.setInt(1, idCita);
        ps.setInt(2, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            encontrada = true;
            Timestamp fh = rs.getTimestamp("fecha_hora");
            fecha = formatoFecha(fh);
            hora = formatoHora(fh);
            estadoCita = rs.getString("cita_estado");
            notas = rs.getString("notas");
            idPropiedad = String.valueOf(rs.getInt("id_propiedad"));
            titulo = rs.getString("titulo");
            direccion = rs.getString("direccion");
            ciudadNombre = rs.getString("ciudad_nombre");
            inmoRazon = rs.getString("razon_social");
            inmoTelefono = rs.getString("inmo_telefono");
            inmoDireccion = rs.getString("inmo_direccion");
            cancelable = "PENDIENTE".equals(estadoCita) || "CONFIRMADA".equals(estadoCita);
        } else {
            errorDetalle = "La cita solicitada no existe o no te pertenece.";
        }
    } catch (SQLException ex) {
        errorDetalle = "Ocurrió un error al consultar la cita. Inténtalo más tarde.";
    } finally {
        cerrar(rs, ps);
    }
}
%>
<% if (canceladaOk) { response.sendRedirect(ctx + "/cliente/detalle-cita.jsp?id=" + idCita + "&cancelada=1"); return; } %>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Detalle de Cita</h1>
    <a href="<%= ctx %>/cliente/citas.jsp" class="btn btn-outline-secondary">Volver a mis citas</a>
</div>

<% if ("1".equals(request.getParameter("cancelada"))) { %>
<div class="alert alert-success" role="alert">Tu cita fue cancelada correctamente.</div>
<% } %>

<% if (errorDetalle != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorDetalle) %></div>
<% } %>

<% if (encontrada) { %>

<div class="row g-4">
    <div class="col-12 col-lg-8">
        <div class="card shadow-sm">
            <div class="card-header d-flex justify-content-between align-items-center">
                <span>Cita #<%= idCita %></span>
                <span class="badge <%= claseEstado(estadoCita) %>"><%= escapar(estadoCita) %></span>
            </div>
            <div class="card-body">
                <table class="table table-sm table-borderless mb-3">
                    <tbody>
                        <tr>
                            <th scope="row" style="width: 180px;">Propiedad</th>
                            <td>
                                <a href="<%= ctx %>/cliente/detalle-propiedad.jsp?id=<%= idPropiedad %>"><%= escapar(titulo) %></a>
                            </td>
                        </tr>
                        <tr>
                            <th scope="row">Ciudad</th>
                            <td><%= escapar(ciudadNombre) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Dirección</th>
                            <td><%= escapar(direccion) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Fecha</th>
                            <td><%= escapar(fecha) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Hora</th>
                            <td><%= escapar(hora) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Estado</th>
                            <td><span class="badge <%= claseEstado(estadoCita) %>"><%= escapar(estadoCita) %></span></td>
                        </tr>
                        <tr>
                            <th scope="row">Notas</th>
                            <td><%= notas == null || notas.isEmpty() ? "<span class='text-muted'>Sin notas</span>" : escapar(notas) %></td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="col-12 col-lg-4">
        <div class="card shadow-sm">
            <div class="card-header">Inmobiliaria</div>
            <div class="card-body">
                <p class="mb-1"><strong><%= escapar(inmoRazon) %></strong></p>
                <p class="mb-1 text-muted small">Dirección: <%= escapar(inmoDireccion) %></p>
                <p class="mb-0 text-muted small">Teléfono: <%= escapar(inmoTelefono) %></p>
            </div>
        </div>

        <div class="card shadow-sm mt-3">
            <div class="card-header">Acciones</div>
            <div class="card-body">
                <% if (cancelable) { %>
                <form method="post"
                      action="<%= ctx %>/cliente/detalle-cita.jsp?id=<%= idCita %>"
                      onsubmit="return confirm('¿Seguro que deseas cancelar esta cita?');">
                    <input type="hidden" name="cancelar" value="1">
                    <button type="submit" class="btn btn-outline-danger w-100">Cancelar cita</button>
                </form>
                <p class="text-muted small mt-2 mb-0">Puedes cancelar citas en estado PENDIENTE o CONFIRMADA.</p>
                <% } else if ("REALIZADA".equals(estadoCita)) { %>
                <p class="text-muted small mb-0">Esta cita ya fue realizada; no puedes cancelarla.</p>
                <% } else if ("CANCELADA".equals(estadoCita)) { %>
                <p class="text-muted small mb-0">Esta cita ya está cancelada.</p>
                <% } %>
            </div>
        </div>
    </div>
</div>

<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>