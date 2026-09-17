<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.util.HashMap, java.util.Map, java.util.Set, java.util.HashSet" %>
<%!
private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}
%>
<%
String[] rolesPermitidos = { "ADMINISTRADOR" };
String tituloPagina = "Gestión de Usuarios";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String msg = limpiar(request.getParameter("msg"));

// ===========================================================================
// PROCESAMIENTO POST -> PRG (activar/desactivar cuenta, asignar/quitar rol)
// ===========================================================================
if ("POST".equalsIgnoreCase(request.getMethod())) {
    String accion = limpiar(request.getParameter("accion"));
    int idUsuario = 0;
    int idRol = 0;
    try { idUsuario = Integer.parseInt(limpiar(request.getParameter("id_usuario"))); }
    catch (NumberFormatException ignorada) {}
    try { idRol = Integer.parseInt(limpiar(request.getParameter("id_rol"))); }
    catch (NumberFormatException ignorada) {}

    String resultado = "error";

    if (errorConexion != null) {
        resultado = "error";
    } else if (idUsuario <= 0) {
        resultado = "error";
    } else {
        boolean esSelf = idUsuarioSesion != null && idUsuarioSesion.intValue() == idUsuario;

        if ("activar".equals(accion) || "desactivar".equals(accion)) {
            if (esSelf && "desactivar".equals(accion)) {
                // Evitar que el admin se quede sin acceso a mitad de sesión
                resultado = "prohibido_desactivar";
            } else {
                int nuevoActivo = "activar".equals(accion) ? 1 : 0;
                PreparedStatement ps = null;
                try {
                    ps = conexion.prepareStatement("UPDATE usuario SET activo = ? WHERE id_usuario = ?");
                    ps.setInt(1, nuevoActivo);
                    ps.setInt(2, idUsuario);
                    int filas = ps.executeUpdate();
                    resultado = filas > 0 ? ("activar".equals(accion) ? "activado" : "desactivado") : "no_existe";
                } catch (SQLException ex) {
                    resultado = "error";
                } finally {
                    cerrar(null, ps);
                }
            }
        } else if ("asignar_rol".equals(accion)) {
            if (idRol <= 0) {
                resultado = "error";
            } else {
                PreparedStatement ps = null;
                try {
                    ps = conexion.prepareStatement("INSERT INTO usuario_rol (id_usuario, id_rol) VALUES (?, ?)");
                    ps.setInt(1, idUsuario);
                    ps.setInt(2, idRol);
                    ps.executeUpdate();
                    resultado = "rol_asignado";
                } catch (SQLIntegrityConstraintViolationException dup) {
                    resultado = "duplicado";
                } catch (SQLException ex) {
                    resultado = "error";
                } finally {
                    cerrar(null, ps);
                }
            }
        } else if ("quitar_rol".equals(accion)) {
            if (idRol <= 0) {
                resultado = "error";
            } else {
                PreparedStatement ps = null;
                ResultSet rs = null;
                boolean procesar = true;

                // Si el admin se quita su propio rol de ADMINISTRADOR, bloquear
                if (esSelf) {
                    try {
                        ps = conexion.prepareStatement("SELECT nombre FROM rol WHERE id_rol = ?");
                        ps.setInt(1, idRol);
                        rs = ps.executeQuery();
                        String nombreRol = null;
                        if (rs.next()) nombreRol = rs.getString("nombre");
                        cerrar(rs, ps);
                        if ("ADMINISTRADOR".equals(nombreRol)) {
                            resultado = "prohibido_quitar_admin";
                            procesar = false;
                        } else {
                            resultado = "rol_quitado_aviso";
                        }
                    } catch (SQLException ex) {
                        resultado = "error";
                        procesar = false;
                    }
                }

                if (procesar) {
                    // ¿Es el último rol del usuario? (solo advertencia, no bloqueo)
                    boolean esUltimo = false;
                    try {
                        ps = conexion.prepareStatement("SELECT COUNT(*) AS total FROM usuario_rol WHERE id_usuario = ?");
                        ps.setInt(1, idUsuario);
                        rs = ps.executeQuery();
                        int total = 0;
                        if (rs.next()) total = rs.getInt("total");
                        cerrar(rs, ps);
                        esUltimo = total <= 1;
                    } catch (SQLException ex) {
                        resultado = "error";
                        procesar = false;
                    }
                    if (procesar) {
                        try {
                            ps = conexion.prepareStatement("DELETE FROM usuario_rol WHERE id_usuario = ? AND id_rol = ?");
                            ps.setInt(1, idUsuario);
                            ps.setInt(2, idRol);
                            int filas = ps.executeUpdate();
                            if (filas > 0) {
                                resultado = esUltimo && !esSelf ? "rol_quitado_aviso" : "rol_quitado";
                            } else {
                                resultado = "no_tiene_rol";
                            }
                        } catch (SQLException ex) {
                            resultado = "error";
                        } finally {
                            cerrar(rs, ps);
                        }
                    }
                }
            }
        }
    }

    response.sendRedirect(ctx + "/admin/usuarios.jsp?msg=" + resultado);
    return;
}

// ===========================================================================
// CONSULTA DE DATOS PARA EL LISTADO
// ===========================================================================
String errorListado = null;
List<String[]> usuarios = new ArrayList<String[]>();
List<String[]> rolesCatalogo = new ArrayList<String[]>();
Map<Integer, List<String[]>> rolesPorUsuario = new HashMap<Integer, List<String[]>>();
Set<Integer> idsUsuarios = new HashSet<Integer>();

if (errorConexion != null) {
    errorListado = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT id_usuario, correo, nombre, apellido, activo " +
            "FROM usuario ORDER BY activo DESC, nombre, apellido");
        rs = ps.executeQuery();
        while (rs.next()) {
            int id = rs.getInt("id_usuario");
            usuarios.add(new String[] {
                String.valueOf(id),
                rs.getString("correo"),
                rs.getString("nombre"),
                rs.getString("apellido"),
                rs.getInt("activo") == 1 ? "Sí" : "No"
            });
            idsUsuarios.add(Integer.valueOf(id));
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement("SELECT id_rol, nombre FROM rol ORDER BY id_rol");
        rs = ps.executeQuery();
        while (rs.next()) {
            rolesCatalogo.add(new String[] { String.valueOf(rs.getInt("id_rol")), rs.getString("nombre") });
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement(
            "SELECT ur.id_usuario, ur.id_rol, r.nombre AS rol " +
            "FROM usuario_rol ur INNER JOIN rol r ON r.id_rol = ur.id_rol " +
            "ORDER BY ur.id_usuario, r.id_rol");
        rs = ps.executeQuery();
        while (rs.next()) {
            int idUsuario = rs.getInt("id_usuario");
            List<String[]> lst = rolesPorUsuario.get(Integer.valueOf(idUsuario));
            if (lst == null) {
                lst = new ArrayList<String[]>();
                rolesPorUsuario.put(Integer.valueOf(idUsuario), lst);
            }
            lst.add(new String[] { String.valueOf(rs.getInt("id_rol")), rs.getString("rol") });
        }
    } catch (SQLException ex) {
        errorListado = "No se pudieron cargar los usuarios. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-4">
    <h1 class="mb-0">Gestión de usuarios</h1>
    <a href="<%= ctx %>/admin/panel.jsp" class="btn btn-outline-secondary btn-sm">Volver al panel</a>
</div>

<% if (errorListado != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorListado) %></div>
<% } %>

<% if ("activado".equals(msg)) { %>
<div class="alert alert-success" role="alert">La cuenta fue activada correctamente.</div>
<% } %>
<% if ("desactivado".equals(msg)) { %>
<div class="alert alert-info" role="alert">La cuenta fue desactivada. El usuario ya no podrá iniciar sesión.</div>
<% } %>
<% if ("rol_asignado".equals(msg)) { %>
<div class="alert alert-success" role="alert">El rol fue asignado correctamente.</div>
<% } %>
<% if ("rol_quitado".equals(msg)) { %>
<div class="alert alert-info" role="alert">El rol fue quitado correctamente.</div>
<% } %>
<% if ("rol_quitado_aviso".equals(msg)) { %>
<div class="alert alert-warning" role="alert">
    Advertencia: este usuario quedó sin roles asignados y no podrá iniciar sesión hasta que se le asigne uno.
</div>
<% } %>
<% if ("duplicado".equals(msg)) { %>
<div class="alert alert-warning" role="alert">El usuario ya tenía ese rol asignado.</div>
<% } %>
<% if ("prohibido_desactivar".equals(msg)) { %>
<div class="alert alert-danger" role="alert">
    No puedes desactivar tu propia cuenta: te quedarías sin acceso al sistema.
</div>
<% } %>
<% if ("prohibido_quitar_admin".equals(msg)) { %>
<div class="alert alert-danger" role="alert">
    No puedes quitarte tu propio rol de ADMINISTRADOR: te quedarías sin acceso a este panel.
</div>
<% } %>
<% if ("no_existe".equals(msg)) { %>
<div class="alert alert-danger" role="alert">El usuario indicado no existe.</div>
<% } %>
<% if ("no_tiene_rol".equals(msg)) { %>
<div class="alert alert-warning" role="alert">El usuario no tenía ese rol asignado.</div>
<% } %>
<% if ("error".equals(msg)) { %>
<div class="alert alert-danger" role="alert">No se pudo procesar la acción. Inténtalo nuevamente.</div>
<% } %>

<% if (errorListado == null) { %>

<div class="table-responsive">
    <table class="table table-striped table-hover align-middle">
        <thead>
            <tr>
                <th>Usuario</th>
                <th>Roles</th>
                <th>Estado</th>
                <th>Acciones</th>
            </tr>
        </thead>
        <tbody>
        <% for (String[] usr : usuarios) {
            int idUsuario = Integer.parseInt(usr[0]);
            List<String[]> rolesU = rolesPorUsuario.get(Integer.valueOf(idUsuario));
            boolean sinRoles = rolesU == null || rolesU.isEmpty();
        %>
            <tr>
                <td>
                    <strong><%= escapar(usr[2]) %> <%= escapar(usr[3]) %></strong><br>
                    <span class="text-muted small"><%= escapar(usr[1]) %></span>
                </td>
                <td>
                    <% if (sinRoles) { %>
                    <span class="text-muted small">Sin roles</span>
                    <% } else {
                        boolean ultimoRol = rolesU.size() == 1;
                        for (String[] rolUsr : rolesU) { %>
                        <span class="badge bg-primary me-1"><%= escapar(rolUsr[1]) %></span>
                        <form method="post" action="<%= ctx %>/admin/usuarios.jsp" class="d-inline">
                            <input type="hidden" name="accion" value="quitar_rol">
                            <input type="hidden" name="id_usuario" value="<%= usr[0] %>">
                            <input type="hidden" name="id_rol" value="<%= rolUsr[0] %>">
                            <button type="submit" class="btn btn-outline-danger btn-sm p-0 px-1 me-2"
                                    title="Quitar este rol"
                                    <% if (ultimoRol) { %>
                                    onclick="return confirm('Advertencia: este es el último rol del usuario. Si continúa no podrá iniciar sesión hasta que se le asigne otro. ¿Desea continuar?');"
                                    <% } %>>
                                &times;
                            </button>
                        </form>
                    <% }
                    } %>
                </td>
                <td>
                    <% if ("Sí".equals(usr[4])) { %>
                    <span class="badge bg-success">Activo</span>
                    <% } else { %>
                    <span class="badge bg-danger">Inactivo</span>
                    <% } %>
                </td>
                <td>
                    <form method="post" action="<%= ctx %>/admin/usuarios.jsp" class="d-inline">
                        <input type="hidden" name="accion" value="<%= "Sí".equals(usr[4]) ? "desactivar" : "activar" %>">
                        <input type="hidden" name="id_usuario" value="<%= usr[0] %>">
                        <button type="submit" class="btn btn-sm <%= "Sí".equals(usr[4]) ? "btn-outline-warning" : "btn-outline-success" %>">
                            <%= "Sí".equals(usr[4]) ? "Desactivar" : "Activar" %>
                        </button>
                    </form>

                    <% if (!sinRoles) { %>
                    <form method="post" action="<%= ctx %>/admin/usuarios.jsp"
                          class="d-inline-flex align-items-center gap-1">
                        <input type="hidden" name="accion" value="asignar_rol">
                        <input type="hidden" name="id_usuario" value="<%= usr[0] %>">
                        <select name="id_rol" class="form-select form-select-sm w-auto">
                            <option value="">Asignar rol...</option>
                            <%
                            Set<String> asignados = new HashSet<String>();
                            for (String[] r : rolesU) asignados.add(r[0]);
                            for (String[] rc : rolesCatalogo) {
                                if (!asignados.contains(rc[0])) {
                            %>
                            <option value="<%= rc[0] %>"><%= escapar(rc[1]) %></option>
                            <%  }
                            } %>
                        </select>
                        <button type="submit" class="btn btn-sm btn-outline-primary">Asignar</button>
                    </form>
                    <% } %>
                </td>
            </tr>
        <% } %>
        </tbody>
    </table>
</div>

<% } %>

<% cerrar(conexion); %>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>