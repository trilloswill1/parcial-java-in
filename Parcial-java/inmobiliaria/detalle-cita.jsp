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
String[] rolesPermitidos = { "INMOBILIARIA" };
String tituloPagina = "Detalle de Cita";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

final String TARGET_INMO =
    "SELECT id_inmobiliaria FROM inmobiliaria WHERE id_usuario = ? LIMIT 1";

int idCita = 0;
try { idCita = Integer.parseInt(limpiar(request.getParameter("id"))); }
catch (NumberFormatException ignorada) { idCita = 0; }

String errorDetalle = null;
boolean encontrada = false;
boolean actualizadaOk = false;

String clienteNombre = null, clienteApellido = null, clienteCorreo = null, clienteTelefono = null;
String fecha = null, hora = null, estadoCita = null, notas = null;
String idPropiedad = "0", titulo = null, direccion = null, ciudadNombre = null;
String inmoRazon = null;
long minutosHastaCita = Long.MAX_VALUE;

if (idCita <= 0) {
    errorDetalle = "Cita no especificada.";
} else if (errorConexion != null) {
    errorDetalle = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    boolean esPost = "POST".equalsIgnoreCase(request.getMethod());
    String accion = esPost ? limpiar(request.getParameter("accion")) : "";

    if (esPost && !accion.isEmpty()) {
        PreparedStatement psSel = null;
        ResultSet rsSel = null;
        String nuevoEstado = null;
        String tituloAud = null;
        try {
            psSel = conexion.prepareStatement(
                "SELECT c.estado, p.titulo " +
                "FROM cita c " +
                "JOIN propiedad p ON p.id_propiedad = c.id_propiedad " +
                "WHERE c.id_cita = ? AND p.id_inmobiliaria = (" + TARGET_INMO + ")");
            psSel.setInt(1, idCita);
            psSel.setInt(2, idUsuarioSesion);
            rsSel = psSel.executeQuery();
            if (rsSel.next()) {
                String estadoActual = rsSel.getString("estado");
                tituloAud = rsSel.getString("titulo");
                if ("PENDIENTE".equals(estadoActual) && "confirmar".equals(accion)) {
                    nuevoEstado = "CONFIRMADA";
                } else if ("PENDIENTE".equals(estadoActual) && "cancelar".equals(accion)) {
                    nuevoEstado = "CANCELADA";
                } else if ("CONFIRMADA".equals(estadoActual) && "realizar".equals(accion)) {
                    nuevoEstado = "REALIZADA";
                } else if ("CONFIRMADA".equals(estadoActual) && "cancelar".equals(accion)) {
                    nuevoEstado = "CANCELADA";
                } else {
                    errorDetalle = "No se puede realizar esa acción sobre una cita en estado " + estadoActual + ".";
                }
            } else {
                errorDetalle = "La cita no existe o pertenece a una propiedad de otra inmobiliaria.";
            }
            cerrar(rsSel, psSel);
        } catch (SQLException ex) {
            errorDetalle = "Ocurrió un error al procesar la acción. Inténtalo más tarde.";
        }

        if (nuevoEstado != null) {
            PreparedStatement psUpd = null;
            try {
                conexion.setAutoCommit(false);
                psUpd = conexion.prepareStatement(
                    "UPDATE cita c " +
                    "JOIN propiedad p ON p.id_propiedad = c.id_propiedad " +
                    "SET c.estado = ? " +
                    "WHERE c.id_cita = ? AND p.id_inmobiliaria = (" + TARGET_INMO + ")");
                psUpd.setString(1, nuevoEstado);
                psUpd.setInt(2, idCita);
                psUpd.setInt(3, idUsuarioSesion);
                int filas = psUpd.executeUpdate();
                if (filas > 0) {
                    // Registro de auditoría (misma transacción)
                    String detalleCita = "";
                    if ("confirmar".equals(accion)) {
                        detalleCita = "Confirmación de cita";
                    } else if ("cancelar".equals(accion)) {
                        detalleCita = "Cancelación de cita por inmobiliaria";
                    } else if ("realizar".equals(accion)) {
                        detalleCita = "Cita marcada como realizada";
                    }
                    if (tituloAud != null && !tituloAud.trim().isEmpty()) {
                        detalleCita += " para propiedad: " + tituloAud;
                    }
                    PreparedStatement psAud = conexion.prepareStatement(
                        "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                        "VALUES (?, ?, ?, ?, ?, ?)");
                    psAud.setInt(1, idUsuarioSesion.intValue());
                    psAud.setString(2, "cita");
                    psAud.setInt(3, idCita);
                    psAud.setString(4, "UPDATE");
                    psAud.setString(5, detalleCita);
                    String ipAccion = ipCliente(request);
                    if (ipAccion == null) {
                        psAud.setNull(6, Types.VARCHAR);
                    } else {
                        psAud.setString(6, ipAccion);
                    }
                    psAud.executeUpdate();
                    cerrar(null, psAud);
                    conexion.commit();
                    actualizadaOk = true;
                } else {
                    deshacer(conexion);
                    errorDetalle = "No se pudo actualizar la cita. Verifica que pertenezca a tu inmobiliaria.";
                }
            } catch (SQLException ex) {
                deshacer(conexion);
                errorDetalle = "Ocurrió un error al actualizar la cita. Inténtalo más tarde.";
            } finally {
                cerrar(null, psUpd);
            }
        }
    }

    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT c.id_cita, c.fecha_hora, c.estado AS cita_estado, c.notas, " +
            "p.id_propiedad, p.titulo, p.direccion, cd.nombre AS ciudad_nombre, " +
            "i.razon_social, " +
            "u.nombre AS cliente_nombre, u.apellido AS cliente_apellido, u.correo, u.telefono " +
            "FROM cita c " +
            "JOIN propiedad p ON p.id_propiedad = c.id_propiedad " +
            "JOIN ciudad cd ON cd.id_ciudad = p.id_ciudad " +
            "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
            "JOIN usuario u ON u.id_usuario = c.id_usuario " +
            "WHERE c.id_cita = ? AND p.id_inmobiliaria = (" + TARGET_INMO + ")");
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
            clienteNombre = rs.getString("cliente_nombre");
            clienteApellido = rs.getString("cliente_apellido");
            clienteCorreo = rs.getString("correo");
            clienteTelefono = rs.getString("telefono");
            java.util.Date ahora = new java.util.Date();
            java.util.Date fhDate = new java.util.Date(fh.getTime());
            if (fhDate.after(ahora)) {
                minutosHastaCita = (fhDate.getTime() - ahora.getTime()) / (1000L * 60L);
            }
        } else {
            errorDetalle = "La cita solicitada no existe o pertenece a la propiedad de otra inmobiliaria.";
        }
    } catch (SQLException ex) {
        errorDetalle = "Ocurrió un error al consultar la cita. Inténtalo más tarde.";
    } finally {
        cerrar(rs, ps);
    }
}
%>
<% if (actualizadaOk) { response.sendRedirect(ctx + "/inmobiliaria/detalle-cita.jsp?id=" + idCita + "&ok=1"); return; } %>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Detalle de Cita</h1>
    <a href="<%= ctx %>/inmobiliaria/citas.jsp" class="btn btn-outline-secondary">Volver a citas</a>
</div>

<% if ("1".equals(request.getParameter("ok"))) { %>
<div class="alert alert-success" role="alert">La cita fue actualizada correctamente.</div>
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
                            <th scope="row" style="width: 180px;">Cliente</th>
                            <td>
                                <strong><%= escapar(clienteNombre) %> <%= escapar(clienteApellido) %></strong>
                            </td>
                        </tr>
                        <tr>
                            <th scope="row">Correo</th>
                            <td><%= escapar(clienteCorreo) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Teléfono</th>
                            <td><%= clienteTelefono == null || clienteTelefono.isEmpty() ? "<span class='text-muted'>N/D</span>" : escapar(clienteTelefono) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Propiedad</th>
                            <td>
                                <a href="<%= ctx %>/inmobiliaria/ver-propiedad.jsp?id=<%= idPropiedad %>"><%= escapar(titulo) %></a>
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
                <p class="text-muted small mb-0">Inmobiliaria responsable: <strong><%= escapar(inmoRazon) %></strong>
                    <% if (minutosHastaCita != Long.MAX_VALUE) { %> · La cita es en aproximadamente <strong><%= minutosHastaCita %></strong> minuto(s)<% } %>.</p>
            </div>
        </div>
    </div>

    <div class="col-12 col-lg-4">
        <div class="card shadow-sm">
            <div class="card-header">Gestionar cita</div>
            <div class="card-body">
                <% if ("PENDIENTE".equals(estadoCita)) { %>
                <form method="post" action="<%= ctx %>/inmobiliaria/detalle-cita.jsp?id=<%= idCita %>">
                    <input type="hidden" name="accion" value="confirmar">
                    <button type="submit" class="btn btn-success w-100 mb-2">Confirmar cita</button>
                </form>
                <form method="post" action="<%= ctx %>/inmobiliaria/detalle-cita.jsp?id=<%= idCita %>"
                      onsubmit="return confirm('¿Seguro que deseas cancelar esta cita?');">
                    <input type="hidden" name="accion" value="cancelar">
                    <button type="submit" class="btn btn-outline-danger w-100">Cancelar cita</button>
                </form>
                <% } else if ("CONFIRMADA".equals(estadoCita)) { %>
                <form method="post" action="<%= ctx %>/inmobiliaria/detalle-cita.jsp?id=<%= idCita %>">
                    <input type="hidden" name="accion" value="realizar">
                    <button type="submit" class="btn btn-primary w-100 mb-2" onclick="return confirm('¿Confirmas que la visita se realizó?');">Marcar como realizada</button>
                </form>
                <form method="post" action="<%= ctx %>/inmobiliaria/detalle-cita.jsp?id=<%= idCita %>"
                      onsubmit="return confirm('¿Seguro que deseas cancelar esta cita?');">
                    <input type="hidden" name="accion" value="cancelar">
                    <button type="submit" class="btn btn-outline-danger w-100">Cancelar cita</button>
                </form>
                <% } else if ("CANCELADA".equals(estadoCita)) { %>
                <p class="text-muted small mb-0">Esta cita fue cancelada; no hay acciones de gestión disponibles.</p>
                <% } else if ("REALIZADA".equals(estadoCita)) { %>
                <p class="text-muted small mb-0">Esta cita ya fue realizada; no hay acciones de gestión disponibles.</p>
                <% } %>
            </div>
        </div>
    </div>
</div>

<% } %>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>