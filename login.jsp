<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ include file="/WEB-INF/jspf/utilidades.jspf" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%!
private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }
private String escapar(String valor) {
    if (valor == null) return "";
    return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
}
%>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String ctx = request.getContextPath();
String tituloPagina = "Iniciar Sesión";

String correo   = limpiar(request.getParameter("correo"));
String password = request.getParameter("password");

String mensajeError = null;
String mensajeOk    = null;
if ("ok".equals(request.getParameter("registro"))) {
    mensajeOk = "Registro exitoso. Ya puedes iniciar sesión.";
} else if ("ok".equals(request.getParameter("logout"))) {
    mensajeOk = "Sesión cerrada correctamente.";
}

boolean esPost = "POST".equalsIgnoreCase(request.getMethod());

if (esPost) {
    if (correo.isEmpty() || password == null || password.isEmpty()) {
        mensajeError = "Ingresa tu correo y tu contraseña.";
    } else {
%>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
        if (errorConexion != null) {
            mensajeError = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
        } else {
            PreparedStatement ps = null, psRol = null;
            ResultSet rs = null, rsRol = null;
            String destino = null;
            try {
                ps = conexion.prepareStatement(
                        "SELECT id_usuario, correo, password_hash, password_salt, activo, nombre, apellido " +
                        "FROM usuario WHERE correo = ?");
                ps.setString(1, correo);
                rs = ps.executeQuery();

                if (!rs.next()) {
                    mensajeError = "Credenciales inválidas";
                } else {
                    String hashBD   = rs.getString("password_hash");
                    String saltBD   = rs.getString("password_salt");
                    boolean activo  = rs.getInt("activo") == 1;
                    String hashCalc = claveCifrada(password, saltBD);

                    if (!hashCalc.equalsIgnoreCase(hashBD)) {
                        mensajeError = "Credenciales inválidas";
                    } else if (!activo) {
                        mensajeError = "Tu cuenta está inactiva. Contacta al administrador del sistema.";
                    } else {
                        int idUsuario = rs.getInt("id_usuario");

                        // Cargar todos los roles del usuario (N:M usuario_rol JOIN rol)
                        List<String> roles = new ArrayList<String>();
                        psRol = conexion.prepareStatement(
                                "SELECT r.nombre FROM rol r " +
                                "INNER JOIN usuario_rol ur ON r.id_rol = ur.id_rol " +
                                "WHERE ur.id_usuario = ? ORDER BY r.id_rol");
                        psRol.setInt(1, idUsuario);
                        rsRol = psRol.executeQuery();
                        while (rsRol.next()) {
                            roles.add(rsRol.getString("nombre"));
                        }
                        cerrar(rsRol, psRol);

                        if (roles.isEmpty()) {
                            mensajeError = "Credenciales inválidas";
                        } else {
                            // Evitar fijación de sesión: crear una sesión nueva
                            session.invalidate();
                            HttpSession sesionNueva = request.getSession(true);

                            sesionNueva.setAttribute("idUsuario", Integer.valueOf(idUsuario));
                            sesionNueva.setAttribute("correo", rs.getString("correo"));
                            sesionNueva.setAttribute("nombre", rs.getString("nombre"));
                            sesionNueva.setAttribute("apellido", rs.getString("apellido"));
                            sesionNueva.setAttribute("roles", roles);
                            sesionNueva.setAttribute("rol", roles.get(0)); // rol principal

                            if (roles.get(0).equals("ADMINISTRADOR")) {
                                destino = "/admin/panel.jsp";
                            } else if (roles.get(0).equals("INMOBILIARIA")) {
                                destino = "/inmobiliaria/panel.jsp";
                            } else {
                                destino = "/cliente/panel.jsp";
                            }
                        }
                    }
                }
            } catch (SQLException ex) {
                mensajeError = "Ocurrió un error al iniciar sesión. Inténtalo nuevamente.";
            } finally {
                cerrar(rsRol, rs, psRol, ps, conexion);
            }
            cerrar(conexion);
            if (destino != null) {
                response.sendRedirect(ctx + destino);
                return;
            }
        }
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<h1 class="mb-4">Iniciar Sesión</h1>

<% if (mensajeOk != null) { %>
<div class="alert alert-success" role="alert"><%= escapar(mensajeOk) %></div>
<% } %>
<% if (mensajeError != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(mensajeError) %></div>
<% } %>

<div class="row">
    <div class="col-md-6 col-lg-4">
        <form method="post" action="<%= ctx %>/login.jsp" class="row g-3">

            <div class="col-12">
                <label for="correo" class="form-label">Correo electrónico</label>
                <input type="email" class="form-control" id="correo" name="correo" required maxlength="150"
                       value="<%= escapar(correo) %>" placeholder="tucorreo@ejemplo.com" autocomplete="email">
            </div>

            <div class="col-12">
                <label for="password" class="form-label">Contraseña</label>
                <input type="password" class="form-control" id="password" name="password" required
                       placeholder="Tu contraseña" autocomplete="current-password">
            </div>

            <div class="col-12 d-grid gap-2">
                <button type="submit" class="btn btn-primary">Ingresar</button>
            </div>

            <div class="col-12">
                <p class="mb-0">¿No tienes una cuenta? <a href="<%= ctx %>/registro.jsp" class="link-primary">Regístrate aquí</a>.</p>
            </div>
        </form>
    </div>
</div>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>