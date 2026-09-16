<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%!
private static final String[] TIPOS_DOCUMENTO =
    { "CEDULA", "CARTA_CREDITO", "CERTIFICADO_INGRESOS", "AVALUO", "CONTRATO" };
private static final String TARGET_INMO =
    "SELECT id_inmobiliaria FROM inmobiliaria WHERE id_usuario = ? LIMIT 1";

private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}

private String claseEstado(String estado) {
    if ("EN_REVISION".equals(estado)) return "bg-warning text-dark";
    if ("APROBADA".equals(estado))    return "bg-info text-dark";
    if ("RECHAZADA".equals(estado))   return "bg-danger";
    return "bg-success";
}

private String formatoFecha(Timestamp ts) {
    if (ts == null) return "";
    return new SimpleDateFormat("dd/MM/yyyy HH:mm").format(ts);
}

private boolean tipoDocumentoValido(String tipo) {
    if (tipo == null) return false;
    for (String t : TIPOS_DOCUMENTO) {
        if (t.equals(tipo)) return true;
    }
    return false;
}

private String estadoDestino(String accion) {
    if ("aprobar".equals(accion))   return "APROBADA";
    if ("rechazar".equals(accion))  return "RECHAZADA";
    if ("completar".equals(accion)) return "COMPLETADA";
    return null;
}
%>
<%
String[] rolesPermitidos = { "INMOBILIARIA" };
String tituloPagina = "Detalle de Solicitud";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

int idSolicitud = 0;
try { idSolicitud = Integer.parseInt(limpiar(request.getParameter("id"))); }
catch (NumberFormatException ignorada) { idSolicitud = 0; }

String errorDetalle = null;
String errorDocumento = null;
boolean encontrada = false;
boolean estadoActualizado = false;
boolean documentoRegistrado = false;

String tipo = null, estado = null, fecha = null, notas = null;
String clienteNombre = null, clienteApellido = null, clienteCorreo = null, clienteTelefono = null;
String idPropiedad = "0", titulo = null, direccion = null, ciudadNombre = null;
String inmoRazon = null;
List<String[]> documentos = new ArrayList<String[]>();

if (idSolicitud <= 0) {
    errorDetalle = "Solicitud no especificada.";
} else if (errorConexion != null) {
    errorDetalle = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    boolean esPostEstado = "POST".equalsIgnoreCase(request.getMethod())
            && "1".equals(limpiar(request.getParameter("cambiar_estado")));
    boolean esPostDoc = "POST".equalsIgnoreCase(request.getMethod())
            && "1".equals(limpiar(request.getParameter("registrar_doc")));

    if (esPostEstado) {
        String accion = limpiar(request.getParameter("accion"));
        String destino = estadoDestino(accion);
        if (destino == null) {
            errorDetalle = "La acción de cambio de estado no es válida.";
        } else {
            String estadoActual = null;
            PreparedStatement psSel = null;
            ResultSet rsSel = null;
            try {
                psSel = conexion.prepareStatement(
                    "SELECT s.estado " +
                    "FROM solicitud s " +
                    "JOIN propiedad p ON p.id_propiedad = s.id_propiedad " +
                    "WHERE s.id_solicitud = ? AND p.id_inmobiliaria = (" + TARGET_INMO + ")");
                psSel.setInt(1, idSolicitud);
                psSel.setInt(2, idUsuarioSesion);
                rsSel = psSel.executeQuery();
                if (rsSel.next()) {
                    estadoActual = rsSel.getString("estado");
                } else {
                    errorDetalle = "La solicitud no existe o pertenece a una propiedad de otra inmobiliaria.";
                }
                cerrar(rsSel, psSel);
            } catch (SQLException ex) {
                errorDetalle = "Ocurrió un error al procesar la acción. Inténtalo más tarde.";
            }

            if (errorDetalle == null) {
                boolean transicionPermitida =
                    ("EN_REVISION".equals(estadoActual) && "APROBADA".equals(destino))
                    || ("EN_REVISION".equals(estadoActual) && "RECHAZADA".equals(destino))
                    || ("APROBADA".equals(estadoActual) && "COMPLETADA".equals(destino));
                if (!transicionPermitida) {
                    errorDetalle = "No se puede pasar una solicitud de estado " + estadoActual
                            + " a " + destino + ". Solo se permiten las transiciones: EN_REVISION → APROBADA, EN_REVISION → RECHAZADA y APROBADA → COMPLETADA.";
                }
            }

            if (errorDetalle == null) {
                PreparedStatement psUpd = null;
                try {
                    psUpd = conexion.prepareStatement(
                        "UPDATE solicitud s " +
                        "JOIN propiedad p ON p.id_propiedad = s.id_propiedad " +
                        "SET s.estado = ? " +
                        "WHERE s.id_solicitud = ? AND p.id_inmobiliaria = (" + TARGET_INMO + ")");
                    psUpd.setString(1, destino);
                    psUpd.setInt(2, idSolicitud);
                    psUpd.setInt(3, idUsuarioSesion);
                    int filas = psUpd.executeUpdate();
                    if (filas > 0) {
                        estadoActualizado = true;
                    } else {
                        errorDetalle = "No se pudo actualizar la solicitud. Verifica que pertenezca a tu inmobiliaria.";
                    }
                } catch (SQLException ex) {
                    errorDetalle = "Ocurrió un error al actualizar la solicitud. Inténtalo más tarde.";
                } finally {
                    cerrar(null, psUpd);
                }
            }
        }
    }

    if (esPostDoc && errorDetalle == null) {
        String nombre = limpiar(request.getParameter("nombre_archivo"));
        String url = limpiar(request.getParameter("url_archivo"));
        String tipodoc = limpiar(request.getParameter("tipo_documento"));

        if (nombre.isEmpty()) {
            errorDocumento = "Debes indicar el nombre del archivo.";
        } else if (nombre.length() > 255) {
            errorDocumento = "El nombre del archivo no puede superar los 255 caracteres.";
        } else if (url.isEmpty()) {
            errorDocumento = "Debes indicar la URL o ruta del archivo.";
        } else if (url.length() > 500) {
            errorDocumento = "La URL o ruta no puede superar los 500 caracteres.";
        } else if (!tipoDocumentoValido(tipodoc)) {
            errorDocumento = "El tipo de documento no es válido.";
        } else {
            PreparedStatement psVer = null;
            ResultSet rsVer = null;
            boolean propia = false;
            try {
                psVer = conexion.prepareStatement(
                    "SELECT s.id_solicitud " +
                    "FROM solicitud s " +
                    "JOIN propiedad p ON p.id_propiedad = s.id_propiedad " +
                    "WHERE s.id_solicitud = ? AND p.id_inmobiliaria = (" + TARGET_INMO + ")");
                psVer.setInt(1, idSolicitud);
                psVer.setInt(2, idUsuarioSesion);
                rsVer = psVer.executeQuery();
                propia = rsVer.next();
                cerrar(rsVer, psVer);
            } catch (SQLException ex) {
                errorDocumento = "Ocurrió un error al verificar la solicitud. Inténtalo más tarde.";
            }
            if (errorDocumento == null && !propia) {
                errorDocumento = "No puedes registrar documentos en una solicitud que no pertenece a tu inmobiliaria.";
            }
            if (errorDocumento == null) {
                PreparedStatement psIns = null;
                try {
                    psIns = conexion.prepareStatement(
                        "INSERT INTO documento_solicitud (id_solicitud, nombre_archivo, url_archivo, tipo_documento) VALUES (?, ?, ?, ?)");
                    psIns.setInt(1, idSolicitud);
                    psIns.setString(2, nombre);
                    psIns.setString(3, url);
                    psIns.setString(4, tipodoc);
                    psIns.executeUpdate();
                    documentoRegistrado = true;
                } catch (SQLException ex) {
                    errorDocumento = "Ocurrió un error al registrar el documento. Inténtalo más tarde.";
                } finally {
                    cerrar(null, psIns);
                }
            }
        }
    }

    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT s.id_solicitud, s.tipo, s.estado, s.fecha_solicitud, s.notas, " +
            "p.id_propiedad, p.titulo, p.direccion, cd.nombre AS ciudad_nombre, " +
            "i.razon_social, " +
            "u.nombre AS cliente_nombre, u.apellido AS cliente_apellido, u.correo, u.telefono " +
            "FROM solicitud s " +
            "JOIN propiedad p ON p.id_propiedad = s.id_propiedad " +
            "JOIN ciudad cd ON cd.id_ciudad = p.id_ciudad " +
            "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
            "JOIN usuario u ON u.id_usuario = s.id_usuario " +
            "WHERE s.id_solicitud = ? AND p.id_inmobiliaria = (" + TARGET_INMO + ")");
        ps.setInt(1, idSolicitud);
        ps.setInt(2, idUsuarioSesion);
        rs = ps.executeQuery();
        if (rs.next()) {
            encontrada = true;
            tipo = rs.getString("tipo");
            estado = rs.getString("estado");
            fecha = formatoFecha(rs.getTimestamp("fecha_solicitud"));
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
        } else {
            errorDetalle = "La solicitud solicitada no existe o pertenece a una propiedad de otra inmobiliaria.";
        }
        cerrar(rs, ps);

        if (encontrada) {
            ps = conexion.prepareStatement(
                "SELECT id_documento, nombre_archivo, url_archivo, tipo_documento, fecha_subida " +
                "FROM documento_solicitud WHERE id_solicitud = ? ORDER BY fecha_subida DESC, id_documento DESC");
            ps.setInt(1, idSolicitud);
            rs = ps.executeQuery();
            while (rs.next()) {
                documentos.add(new String[] {
                    String.valueOf(rs.getInt("id_documento")),
                    rs.getString("nombre_archivo"),
                    rs.getString("url_archivo"),
                    rs.getString("tipo_documento"),
                    formatoFecha(rs.getTimestamp("fecha_subida"))
                });
            }
        }
    } catch (SQLException ex) {
        if (!encontrada) errorDetalle = "Ocurrió un error al consultar la solicitud. Inténtalo más tarde.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<% if (estadoActualizado) { response.sendRedirect(ctx + "/inmobiliaria/detalle-solicitud.jsp?id=" + idSolicitud + "&ok=1"); return; } %>
<% if (documentoRegistrado) { response.sendRedirect(ctx + "/inmobiliaria/detalle-solicitud.jsp?id=" + idSolicitud + "&docok=1"); return; } %>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex flex-wrap align-items-center justify-content-between mb-3">
    <h1 class="mb-0">Detalle de Solicitud</h1>
    <a href="<%= ctx %>/inmobiliaria/solicitudes.jsp" class="btn btn-outline-secondary">Volver a solicitudes</a>
</div>

<% if ("1".equals(request.getParameter("ok"))) { %>
<div class="alert alert-success" role="alert">La solicitud fue actualizada correctamente.</div>
<% } %>
<% if ("1".equals(request.getParameter("docok"))) { %>
<div class="alert alert-success" role="alert">El documento fue registrado correctamente.</div>
<% } %>

<% if (errorDetalle != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorDetalle) %></div>
<% } %>
<% if (errorDocumento != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorDocumento) %></div>
<% } %>

<% if (encontrada) { %>

<div class="row g-4">
    <div class="col-12 col-lg-8">
        <div class="card shadow-sm">
            <div class="card-header d-flex justify-content-between align-items-center">
                <span>Solicitud #<%= idSolicitud %></span>
                <span>
                    <span class="badge bg-primary me-1"><%= escapar(tipo) %></span>
                    <span class="badge <%= claseEstado(estado) %>"><%= escapar(estado) %></span>
                </span>
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
                            <th scope="row">Dirección</th>
                            <td><%= escapar(direccion) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Ciudad</th>
                            <td><%= escapar(ciudadNombre) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Tipo</th>
                            <td><%= escapar(tipo) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Estado</th>
                            <td><span class="badge <%= claseEstado(estado) %>"><%= escapar(estado) %></span></td>
                        </tr>
                        <tr>
                            <th scope="row">Fecha de solicitud</th>
                            <td><%= escapar(fecha) %></td>
                        </tr>
                        <tr>
                            <th scope="row">Notas</th>
                            <td><%= notas == null || notas.isEmpty() ? "<span class='text-muted'>Sin notas</span>" : escapar(notas) %></td>
                        </tr>
                    </tbody>
                </table>
                <p class="text-muted small mb-0">Inmobiliaria responsable: <strong><%= escapar(inmoRazon) %></strong></p>
            </div>
        </div>
    </div>

    <div class="col-12 col-lg-4">
        <div class="card shadow-sm">
            <div class="card-header">Gestionar solicitud</div>
            <div class="card-body">
                <% if ("EN_REVISION".equals(estado)) { %>
                <form method="post" action="<%= ctx %>/inmobiliaria/detalle-solicitud.jsp?id=<%= idSolicitud %>">
                    <input type="hidden" name="cambiar_estado" value="1">
                    <input type="hidden" name="accion" value="aprobar">
                    <button type="submit" class="btn btn-success w-100 mb-2">Aprobar solicitud</button>
                </form>
                <form method="post" action="<%= ctx %>/inmobiliaria/detalle-solicitud.jsp?id=<%= idSolicitud %>"
                      onsubmit="return confirm('¿Seguro que deseas rechazar esta solicitud?');">
                    <input type="hidden" name="cambiar_estado" value="1">
                    <input type="hidden" name="accion" value="rechazar">
                    <button type="submit" class="btn btn-outline-danger w-100">Rechazar solicitud</button>
                </form>
                <% } else if ("APROBADA".equals(estado)) { %>
                <form method="post" action="<%= ctx %>/inmobiliaria/detalle-solicitud.jsp?id=<%= idSolicitud %>">
                    <input type="hidden" name="cambiar_estado" value="1">
                    <input type="hidden" name="accion" value="completar">
                    <button type="submit" class="btn btn-primary w-100 mb-2" onclick="return confirm('¿Confirmas que la solicitud se completó (contrato firmado / compra cerrada)?');">Marcar como completada</button>
                </form>
                <% } else { %>
                <p class="text-muted small mb-0">
                    Esta solicitud está en estado <strong><%= escapar(estado) %></strong>; no hay
                    transiciones disponibles hacia adelante desde este estado.
                </p>
                <% } %>
            </div>
        </div>
    </div>
</div>

<div class="row g-4 mt-1">
    <div class="col-12 col-lg-8">
        <div class="card shadow-sm">
            <div class="card-header">Documentos de la solicitud</div>
            <div class="card-body">
                <% if (documentos.isEmpty()) { %>
                <p class="text-muted mb-0">Aún no hay documentos registrados para esta solicitud.</p>
                <% } else { %>
                <div class="table-responsive">
                    <table class="table table-striped align-middle">
                        <thead class="table-light">
                            <tr>
                                <th>Nombre</th>
                                <th>Tipo</th>
                                <th>Fecha</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            <% for (String[] d : documentos) { %>
                            <tr>
                                <td><%= escapar(d[1]) %></td>
                                <td><span class="badge bg-secondary"><%= escapar(d[3]) %></span></td>
                                <td><%= escapar(d[4]) %></td>
                                <td>
                                    <a href="<%= escapar(d[2]) %>" target="_blank" class="btn btn-sm btn-outline-primary">Ver documento</a>
                                </td>
                            </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
                <% } %>
            </div>
        </div>
    </div>
    <div class="col-12 col-lg-4">
        <div class="card shadow-sm">
            <div class="card-header">Registrar documento</div>
            <div class="card-body">
                <p class="text-muted small">
                    Registra la referencia de un documento adjunto a esta solicitud.
                </p>
                <form method="post" action="<%= ctx %>/inmobiliaria/detalle-solicitud.jsp?id=<%= idSolicitud %>">
                    <input type="hidden" name="registrar_doc" value="1">
                    <div class="mb-2">
                        <label for="nombre_archivo" class="form-label">Nombre del archivo</label>
                        <input type="text" id="nombre_archivo" name="nombre_archivo" class="form-control"
                               maxlength="255" placeholder="Ej.: contrato_firmado.pdf">
                    </div>
                    <div class="mb-2">
                        <label for="tipo_documento" class="form-label">Tipo de documento</label>
                        <select id="tipo_documento" name="tipo_documento" class="form-select">
                            <% for (String t : TIPOS_DOCUMENTO) { %>
                            <option value="<%= t %>"><%= t %></option>
                            <% } %>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label for="url_archivo" class="form-label">URL / ruta del archivo</label>
                        <input type="text" id="url_archivo" name="url_archivo" class="form-control"
                               maxlength="500" placeholder="Ej.: /docs/sol6/contrato.pdf">
                    </div>
                    <button type="submit" class="btn btn-primary w-100">Guardar documento</button>
                </form>
            </div>
        </div>
    </div>
</div>

<% } %>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>