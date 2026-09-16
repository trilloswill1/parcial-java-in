<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ include file="/WEB-INF/jspf/utilidades.jspf" %>
<%@ page import="java.sql.*" %>
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
String tituloPagina = "Registro de Usuario";

String correo    = limpiar(request.getParameter("correo"));
String password  = request.getParameter("password");
String password2 = request.getParameter("password2");
String nombres   = limpiar(request.getParameter("nombres"));
String apellidos = limpiar(request.getParameter("apellidos"));
String documento = limpiar(request.getParameter("documento"));
String telefono  = limpiar(request.getParameter("telefono"));
String direccion = limpiar(request.getParameter("direccion"));

String mensajeError = null;
boolean esPost = "POST".equalsIgnoreCase(request.getMethod());

if (esPost) {
    String patronEmail    = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$";
    String patronTelefono = "^[0-9+ ()-]{7,20}$";

    if (correo.isEmpty() || password == null || password.isEmpty()
        || nombres.isEmpty() || apellidos.isEmpty() || documento.isEmpty()
        || telefono.isEmpty() || direccion.isEmpty()) {
        mensajeError = "Todos los campos son obligatorios.";
    } else if (!correo.matches(patronEmail)) {
        mensajeError = "El correo ingresado no tiene un formato válido.";
    } else if (!telefono.matches(patronTelefono)) {
        mensajeError = "El teléfono ingresado no tiene un formato válido.";
    } else if (!password.equals(password2)) {
        mensajeError = "Las contraseñas no coinciden.";
    } else {
%>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
        if (errorConexion != null) {
            mensajeError = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
        } else {
            String salt = generarSalt();
            String hash = claveCifrada(password, salt);
            PreparedStatement psUsuario = null, psPerfil = null, psRol = null, psUR = null;
            ResultSet rsUsuario = null, rsRol = null;
            boolean exito = false;
            try {
                conexion.setAutoCommit(false);

                // a) Usuario con contraseña cifrada (SHA-256 + salt) y activo=1
                psUsuario = conexion.prepareStatement(
                        "INSERT INTO usuario (correo, password_hash, password_salt, nombre, apellido, telefono, activo) " +
                        "VALUES (?, ?, ?, ?, ?, ?, 1)",
                        Statement.RETURN_GENERATED_KEYS);
                psUsuario.setString(1, correo);
                psUsuario.setString(2, hash);
                psUsuario.setString(3, salt);
                psUsuario.setString(4, nombres);
                psUsuario.setString(5, apellidos);
                psUsuario.setString(6, telefono);
                psUsuario.executeUpdate();
                rsUsuario = psUsuario.getGeneratedKeys();
                int idUsuario = 0;
                if (rsUsuario.next()) {
                    idUsuario = rsUsuario.getInt(1);
                }

                // b) Perfil asociado al id_usuario generado
                psPerfil = conexion.prepareStatement(
                        "INSERT INTO perfil (id_usuario, documento_identidad, direccion) " +
                        "VALUES (?, ?, ?)");
                psPerfil.setInt(1, idUsuario);
                psPerfil.setString(2, documento);
                psPerfil.setString(3, direccion);
                psPerfil.executeUpdate();

                // c) Rol CLIENTE por defecto
                int idRolCliente = 0;
                psRol = conexion.prepareStatement("SELECT id_rol FROM rol WHERE nombre = 'CLIENTE'");
                rsRol = psRol.executeQuery();
                if (rsRol.next()) {
                    idRolCliente = rsRol.getInt(1);
                }
                if (idRolCliente == 0) {
                    throw new SQLException("El rol CLIENTE no existe en la base de datos.");
                }

                psUR = conexion.prepareStatement("INSERT INTO usuario_rol (id_usuario, id_rol) VALUES (?, ?)");
                psUR.setInt(1, idUsuario);
                psUR.setInt(2, idRolCliente);
                psUR.executeUpdate();

                conexion.commit();
                exito = true;
            } catch (SQLIntegrityConstraintViolationException ex) {
                deshacer(conexion);
                mensajeError = "El correo ya se encuentra registrado. Prueba con otro.";
            } catch (SQLException ex) {
                deshacer(conexion);
                mensajeError = "No se pudo completar el registro. Inténtalo nuevamente.";
            } finally {
                cerrar(rsRol, rsUsuario, psUR, psRol, psPerfil, psUsuario, conexion);
            }
            if (exito) {
                response.sendRedirect(ctx + "/login.jsp?registro=ok");
                return;
            }
        }
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<h1 class="mb-4">Registro de nuevo usuario</h1>

<% if (mensajeError != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(mensajeError) %></div>
<% } %>

<div class="row">
    <div class="col-md-8 col-lg-6">
        <form method="post" action="<%= ctx %>/registro.jsp" class="row g-3" autocomplete="on">

            <div class="col-12">
                <label for="correo" class="form-label">Correo electrónico *</label>
                <input type="email" class="form-control" id="correo" name="correo" required maxlength="150"
                       value="<%= escapar(correo) %>" placeholder="tucorreo@ejemplo.com"
                       autocomplete="email">
            </div>

            <div class="col-md-6">
                <label for="password" class="form-label">Contraseña *</label>
                <input type="password" class="form-control" id="password" name="password" required minlength="6"
                       autocomplete="new-password" placeholder="Mínimo 6 caracteres">
            </div>

            <div class="col-md-6">
                <label for="password2" class="form-label">Confirmar contraseña *</label>
                <input type="password" class="form-control" id="password2" name="password2" required
                       autocomplete="new-password" placeholder="Repite la contraseña">
            </div>

            <div class="col-md-6">
                <label for="nombres" class="form-label">Nombres *</label>
                <input type="text" class="form-control" id="nombres" name="nombres" required maxlength="100"
                       value="<%= escapar(nombres) %>" autocomplete="given-name">
            </div>

            <div class="col-md-6">
                <label for="apellidos" class="form-label">Apellidos *</label>
                <input type="text" class="form-control" id="apellidos" name="apellidos" required maxlength="100"
                       value="<%= escapar(apellidos) %>" autocomplete="family-name">
            </div>

            <div class="col-md-6">
                <label for="documento" class="form-label">Documento *</label>
                <input type="text" class="form-control" id="documento" name="documento" required maxlength="30"
                       value="<%= escapar(documento) %>" placeholder="N.º de cédula">
            </div>

            <div class="col-md-6">
                <label for="telefono" class="form-label">Teléfono *</label>
                <input type="tel" class="form-control" id="telefono" name="telefono" required maxlength="20"
                       value="<%= escapar(telefono) %>" placeholder="Ej: 3001234567"
                       autocomplete="tel-national">
            </div>

            <div class="col-12">
                <label for="direccion" class="form-label">Dirección *</label>
                <input type="text" class="form-control" id="direccion" name="direccion" required maxlength="255"
                       value="<%= escapar(direccion) %>">
            </div>

            <div class="col-12 d-grid gap-2">
                <button type="submit" class="btn btn-primary">Crear cuenta</button>
            </div>

            <div class="col-12">
                <p class="mb-0">¿Ya tienes una cuenta? <a href="<%= ctx %>/login.jsp" class="link-primary">Inicia sesión aquí</a>.</p>
            </div>
        </form>
    </div>
</div>
<%@ include file="/WEB-INF/jspf/pie.jspf" %>