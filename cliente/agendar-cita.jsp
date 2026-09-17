<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.text.DecimalFormat" %>
<%@ page import="java.time.LocalDate, java.time.LocalTime, java.time.LocalDateTime" %>
<%!
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
String tituloPagina = "Agendar Cita";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}
DecimalFormat df = new DecimalFormat("###,###,##0");

int idPropiedad = 0;
try { idPropiedad = Integer.parseInt(limpiar(request.getParameter("id_propiedad"))); }
catch (NumberFormatException ignorada) { idPropiedad = 0; }

String errorAgendar = null;
String infoAgendar = null;
boolean propiedadEncontrada = false;
boolean agendable = false;
boolean procesadoOk = false;

String titulo = null, descripcion = null, precio = null, direccion = null;
String estadoProp = null, ciudadNombre = null, inmoRazon = null;

if (idPropiedad <= 0) {
    errorAgendar = "Propiedad no especificada.";
} else if (errorConexion != null) {
    errorAgendar = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT p.titulo, p.descripcion, p.precio, p.estado, p.direccion, " +
            "cd.nombre AS ciudad_nombre, i.razon_social " +
            "FROM propiedad p " +
            "JOIN ciudad cd ON cd.id_ciudad = p.id_ciudad " +
            "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
            "WHERE p.id_propiedad = ?");
        ps.setInt(1, idPropiedad);
        rs = ps.executeQuery();
        if (rs.next()) {
            propiedadEncontrada = true;
            titulo = rs.getString("titulo");
            descripcion = rs.getString("descripcion");
            precio = df.format(rs.getBigDecimal("precio"));
            estadoProp = rs.getString("estado");
            direccion = rs.getString("direccion");
            ciudadNombre = rs.getString("ciudad_nombre");
            inmoRazon = rs.getString("razon_social");
            agendable = "DISPONIBLE".equals(estadoProp) || "RESERVADA".equals(estadoProp);
        } else {
            errorAgendar = "La propiedad solicitada no existe.";
        }
    } catch (SQLException ex) {
        errorAgendar = "Ocurrió un error al consultar la propiedad. Inténtalo más tarde.";
    } finally {
        cerrar(rs, ps);
    }

    if (propiedadEncontrada && "POST".equalsIgnoreCase(request.getMethod())) {
        if (!agendable) {
            infoAgendar = "Esta propiedad no está disponible para agendar citas (estado: " + estadoProp + ").";
        } else {
            String fFecha = limpiar(request.getParameter("fecha"));
            String fHora = limpiar(request.getParameter("hora"));
            String fNotas = limpiar(request.getParameter("notas"));

            LocalDate fecha = null;
            LocalTime hora = null;
            boolean datosValidos = true;

            try {
                fecha = LocalDate.parse(fFecha);
            } catch (Exception e) {
                datosValidos = false;
                errorAgendar = "La fecha es obligatoria y debe tener un formato válido.";
            }
            try {
                hora = LocalTime.parse(fHora);
            } catch (Exception e) {
                datosValidos = false;
                if (errorAgendar == null) {
                    errorAgendar = "La hora es obligatoria y debe tener un formato válido.";
                }
            }

            if (datosValidos) {
                LocalDateTime fechaHora = LocalDateTime.of(fecha, hora);
                if (fechaHora.isBefore(LocalDateTime.now())) {
                    datosValidos = false;
                    errorAgendar = "La fecha y la hora de la cita no pueden estar en el pasado.";
                }
            }

            if (datosValidos) {
                PreparedStatement ps2 = null;
                ResultSet rsClave = null;
                try {
                    conexion.setAutoCommit(false);
                    Timestamp ts = Timestamp.valueOf(LocalDateTime.of(fecha, hora));
                    ps2 = conexion.prepareStatement(
                        "INSERT INTO cita (id_usuario, id_propiedad, fecha_hora, estado, notas) VALUES (?, ?, ?, 'PENDIENTE', ?)",
                        Statement.RETURN_GENERATED_KEYS);
                    ps2.setInt(1, idUsuarioSesion);
                    ps2.setInt(2, idPropiedad);
                    ps2.setTimestamp(3, ts);
                    if (fNotas.isEmpty()) {
                        ps2.setNull(4, Types.VARCHAR);
                    } else {
                        ps2.setString(4, fNotas);
                    }
                    int filas = ps2.executeUpdate();
                    int idCita = -1;
                    if (filas > 0) {
                        rsClave = ps2.getGeneratedKeys();
                        if (rsClave.next()) {
                            idCita = rsClave.getInt(1);
                        }
                    }
                    cerrar(rsClave, ps2);
                    if (idCita > 0) {
                        // Registro de auditoría (misma transacción)
                        PreparedStatement psAud = conexion.prepareStatement(
                            "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                            "VALUES (?, ?, ?, ?, ?, ?)");
                        psAud.setInt(1, idUsuarioSesion.intValue());
                        psAud.setString(2, "cita");
                        psAud.setInt(3, idCita);
                        psAud.setString(4, "INSERT");
                        psAud.setString(5, "Creación de cita para propiedad: " + titulo + ", fecha: " + fFecha + " " + fHora);
                        String ipAgendar = ipCliente(request);
                        if (ipAgendar == null) {
                            psAud.setNull(6, Types.VARCHAR);
                        } else {
                            psAud.setString(6, ipAgendar);
                        }
                        psAud.executeUpdate();
                        cerrar(null, psAud);
                        conexion.commit();
                        procesadoOk = true;
                    }
                } catch (SQLIntegrityConstraintViolationException dup) {
                    deshacer(conexion);
                    errorAgendar = "Ese horario ya está reservado para esta propiedad. Por favor elige otra fecha u hora.";
                } catch (SQLException ex) {
                    deshacer(conexion);
                    errorAgendar = "No se pudo agendar la cita. Inténtalo más tarde.";
                } finally {
                    cerrar(rsClave, ps2);
                }
            }
        }
    }
}
%>
<% if (procesadoOk) { response.sendRedirect(ctx + "/cliente/citas.jsp?creada=1"); return; } %>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Agendar cita</h1>
    <a href="<%= ctx %>/cliente/propiedades.jsp" class="btn btn-outline-secondary">Volver a propiedades</a>
</div>

<% if (!propiedadEncontrada) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorAgendar) %></div>
<% } else { %>

<div class="row g-4">
    <div class="col-12 col-lg-6">
        <div class="card shadow-sm h-100">
            <div class="card-header">Propiedad</div>
            <div class="card-body">
                <h2 class="h5 card-title"><%= escapar(titulo) %></h2>
                <p class="text-muted mb-1">
                    Ciudad: <strong><%= escapar(ciudadNombre) %></strong><br>
                    Dirección: <strong><%= escapar(direccion) %></strong><br>
                    Precio: <strong>$ <%= precio %></strong><br>
                    Inmobiliaria: <strong><%= escapar(inmoRazon) %></strong><br>
                </p>
                <span class="badge <%= claseEstado(estadoProp) %>"><%= escapar(estadoProp) %></span>
                <p class="text-muted small mt-2 mb-0"><%= escapar(descripcion) %></p>
            </div>
        </div>
    </div>

    <div class="col-12 col-lg-6">
        <div class="card shadow-sm">
            <div class="card-header">Fecha y hora de la visita</div>
            <div class="card-body">
                <% if (!agendable) { %>
                <div class="alert alert-warning mb-0" role="alert">
                    Esta propiedad no está disponible para agendar citas por su estado actual
                    (<strong><%= escapar(estadoProp) %></strong>).
                    <a href="<%= ctx %>/cliente/detalle-propiedad.jsp?id=<%= idPropiedad %>" class="alert-link">Ver detalle de la propiedad</a>
                </div>
                <% } else { %>

                <% if (errorAgendar != null) { %>
                <div class="alert alert-danger" role="alert"><%= escapar(errorAgendar) %></div>
                <% } else { %>
                <div class="alert alert-light border" role="alert">
                    Tu cita quedará en estado <span class="badge bg-warning text-dark">PENDIENTE</span> y la inmobiliaria
                    <strong><%= escapar(inmoRazon) %></strong> deberá confirmarla.
                </div>
                <% } %>

                <form method="post" action="<%= ctx %>/cliente/agendar-cita.jsp?id_propiedad=<%= idPropiedad %>">
                    <div class="mb-3">
                        <label for="fecha" class="form-label">Fecha</label>
                        <input type="date" class="form-control" id="fecha" name="fecha"
                               value="<%= escapar(request.getParameter("fecha")) %>" required>
                    </div>
                    <div class="mb-3">
                        <label for="hora" class="form-label">Hora</label>
                        <input type="time" class="form-control" id="hora" name="hora"
                               value="<%= escapar(request.getParameter("hora")) %>" required>
                    </div>
                    <div class="mb-3">
                        <label for="notas" class="form-label">Notas / observaciones (opcional)</label>
                        <textarea class="form-control" id="notas" name="notas" rows="3"
                                  placeholder="Cuéntanos cualquier detalle sobre la visita"><%= escapar(request.getParameter("notas")) %></textarea>
                    </div>
                    <button type="submit" class="btn btn-success">Confirmar cita</button>
                    <a href="<%= ctx %>/cliente/detalle-propiedad.jsp?id=<%= idPropiedad %>" class="btn btn-outline-secondary">Cancelar</a>
                </form>
                <% } %>
            </div>
        </div>
    </div>
</div>

<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>