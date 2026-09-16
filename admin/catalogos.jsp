<%@ page contentType="text/html;charset=UTF-8" language="java" %>
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
String[] rolesPermitidos = { "ADMINISTRADOR" };
String tituloPagina = "Gestión de Catálogos";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

String msg = limpiar(request.getParameter("msg"));

// ===========================================================================
// PROCESAMIENTO POST -> PRG (agregar / eliminar registros de catálogo)
// ===========================================================================
if ("POST".equalsIgnoreCase(request.getMethod())) {
    String accion = limpiar(request.getParameter("accion"));
    String resultado = "error";
    String ancla = "ciudad";

    if (errorConexion == null) {

        // ------------------------------- CIUDAD -------------------------------
        if ("agregar_ciudad".equals(accion)) {
            ancla = "ciudad";
            String nombre = limpiar(request.getParameter("nombre"));
            String departamento = limpiar(request.getParameter("departamento"));
            if (nombre.isEmpty()) {
                resultado = "ciudad_nombre_vacio";
            } else if (departamento.isEmpty()) {
                resultado = "ciudad_departamento_vacio";
            } else {
                PreparedStatement ps = null;
                try {
                    ps = conexion.prepareStatement("INSERT INTO ciudad (nombre, departamento) VALUES (?, ?)");
                    ps.setString(1, nombre);
                    ps.setString(2, departamento);
                    ps.executeUpdate();
                    resultado = "ciudad_agregada";
                } catch (SQLIntegrityConstraintViolationException dup) {
                    resultado = "ciudad_duplicada";
                } catch (SQLException ex) {
                    resultado = "ciudad_error";
                } finally {
                    cerrar(null, ps);
                }
            }
        } else if ("eliminar_ciudad".equals(accion)) {
            ancla = "ciudad";
            int idCiudad = 0;
            try { idCiudad = Integer.parseInt(limpiar(request.getParameter("id_ciudad"))); }
            catch (NumberFormatException ignorada) {}
            if (idCiudad <= 0) {
                resultado = "ciudad_no_existe";
            } else {
                PreparedStatement ps = null;
                ResultSet rs = null;
                try {
                    ps = conexion.prepareStatement("SELECT COUNT(*) AS total FROM propiedad WHERE id_ciudad = ?");
                    ps.setInt(1, idCiudad);
                    rs = ps.executeQuery();
                    int total = 0;
                    if (rs.next()) total = rs.getInt("total");
                    cerrar(rs, ps);
                    if (total > 0) {
                        resultado = "ciudad_en_uso";
                    } else {
                        ps = conexion.prepareStatement("DELETE FROM ciudad WHERE id_ciudad = ?");
                        ps.setInt(1, idCiudad);
                        int filas = ps.executeUpdate();
                        resultado = filas > 0 ? "ciudad_eliminada" : "ciudad_no_existe";
                    }
                } catch (SQLException ex) {
                    resultado = "ciudad_error";
                } finally {
                    cerrar(rs, ps);
                }
            }
        }
        // --------------------------- TIPO_PROPIEDAD -----------------------------
        else if ("agregar_tipo".equals(accion)) {
            ancla = "tipo";
            String nombre = limpiar(request.getParameter("nombre"));
            if (nombre.isEmpty()) {
                resultado = "tipo_nombre_vacio";
            } else {
                PreparedStatement ps = null;
                try {
                    ps = conexion.prepareStatement("INSERT INTO tipo_propiedad (nombre) VALUES (?)");
                    ps.setString(1, nombre);
                    ps.executeUpdate();
                    resultado = "tipo_agregado";
                } catch (SQLIntegrityConstraintViolationException dup) {
                    resultado = "tipo_duplicado";
                } catch (SQLException ex) {
                    resultado = "tipo_error";
                } finally {
                    cerrar(null, ps);
                }
            }
        } else if ("eliminar_tipo".equals(accion)) {
            ancla = "tipo";
            int idTipo = 0;
            try { idTipo = Integer.parseInt(limpiar(request.getParameter("id_tipo"))); }
            catch (NumberFormatException ignorada) {}
            if (idTipo <= 0) {
                resultado = "tipo_no_existe";
            } else {
                PreparedStatement ps = null;
                ResultSet rs = null;
                try {
                    ps = conexion.prepareStatement("SELECT COUNT(*) AS total FROM propiedad WHERE id_tipo = ?");
                    ps.setInt(1, idTipo);
                    rs = ps.executeQuery();
                    int total = 0;
                    if (rs.next()) total = rs.getInt("total");
                    cerrar(rs, ps);
                    if (total > 0) {
                        resultado = "tipo_en_uso";
                    } else {
                        ps = conexion.prepareStatement("DELETE FROM tipo_propiedad WHERE id_tipo = ?");
                        ps.setInt(1, idTipo);
                        int filas = ps.executeUpdate();
                        resultado = filas > 0 ? "tipo_eliminado" : "tipo_no_existe";
                    }
                } catch (SQLException ex) {
                    resultado = "tipo_error";
                } finally {
                    cerrar(rs, ps);
                }
            }
        }
        // ---------------------------- CARACTERISTICA ----------------------------
        else if ("agregar_caracteristica".equals(accion)) {
            ancla = "caracteristica";
            String nombre = limpiar(request.getParameter("nombre"));
            if (nombre.isEmpty()) {
                resultado = "carac_nombre_vacio";
            } else {
                PreparedStatement ps = null;
                try {
                    ps = conexion.prepareStatement("INSERT INTO caracteristica (nombre) VALUES (?)");
                    ps.setString(1, nombre);
                    ps.executeUpdate();
                    resultado = "carac_agregada";
                } catch (SQLIntegrityConstraintViolationException dup) {
                    resultado = "carac_duplicada";
                } catch (SQLException ex) {
                    resultado = "carac_error";
                } finally {
                    cerrar(null, ps);
                }
            }
        } else if ("eliminar_caracteristica".equals(accion)) {
            ancla = "caracteristica";
            int idCarac = 0;
            try { idCarac = Integer.parseInt(limpiar(request.getParameter("id_caracteristica"))); }
            catch (NumberFormatException ignorada) {}
            if (idCarac <= 0) {
                resultado = "carac_no_existe";
            } else {
                PreparedStatement ps = null;
                ResultSet rs = null;
                try {
                    ps = conexion.prepareStatement("SELECT COUNT(*) AS total FROM propiedad_caracteristica WHERE id_caracteristica = ?");
                    ps.setInt(1, idCarac);
                    rs = ps.executeQuery();
                    int total = 0;
                    if (rs.next()) total = rs.getInt("total");
                    cerrar(rs, ps);
                    if (total > 0) {
                        resultado = "carac_en_uso";
                    } else {
                        ps = conexion.prepareStatement("DELETE FROM caracteristica WHERE id_caracteristica = ?");
                        ps.setInt(1, idCarac);
                        int filas = ps.executeUpdate();
                        resultado = filas > 0 ? "carac_eliminada" : "carac_no_existe";
                    }
                } catch (SQLException ex) {
                    resultado = "carac_error";
                } finally {
                    cerrar(rs, ps);
                }
            }
        }
    }

    response.sendRedirect(ctx + "/admin/catalogos.jsp?msg=" + resultado + "#" + ancla);
    return;
}

// ===========================================================================
// CONSULTA DE DATOS PARA EL LISTADO
// ===========================================================================
String errorListado = null;
List<String[]> ciudades = new ArrayList<String[]>();
List<String[]> tipos = new ArrayList<String[]>();
List<String[]> caracteristicas = new ArrayList<String[]>();

if (errorConexion != null) {
    errorListado = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement(
            "SELECT id_ciudad, nombre, departamento FROM ciudad ORDER BY nombre, departamento");
        rs = ps.executeQuery();
        while (rs.next()) {
            ciudades.add(new String[] {
                String.valueOf(rs.getInt("id_ciudad")),
                rs.getString("nombre"),
                rs.getString("departamento")
            });
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement(
            "SELECT id_tipo, nombre FROM tipo_propiedad ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            tipos.add(new String[] { String.valueOf(rs.getInt("id_tipo")), rs.getString("nombre") });
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement(
            "SELECT id_caracteristica, nombre FROM caracteristica ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            caracteristicas.add(new String[] { String.valueOf(rs.getInt("id_caracteristica")), rs.getString("nombre") });
        }
    } catch (SQLException ex) {
        errorListado = "No se pudieron cargar los catálogos. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-4">
    <h1 class="mb-0">Gestión de catálogos</h1>
    <a href="<%= ctx %>/admin/panel.jsp" class="btn btn-outline-secondary btn-sm">Volver al panel</a>
</div>

<% if (errorListado != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorListado) %></div>
<% } %>

<%
String[][] mensajes = {
    { "ciudad_agregada",              "success", "La ciudad se agregó correctamente." },
    { "ciudad_eliminada",             "success", "La ciudad se eliminó correctamente." },
    { "ciudad_duplicada",             "warning", "Ya existe una ciudad con ese nombre y departamento." },
    { "ciudad_nombre_vacio",          "danger",  "El nombre de la ciudad no puede estar vacío." },
    { "ciudad_departamento_vacio",    "danger",  "El departamento no puede estar vacío." },
    { "ciudad_en_uso",                "danger",  "No se puede eliminar: hay propiedades asociadas a esta ciudad." },
    { "ciudad_no_existe",             "warning", "La ciudad indicada ya no existe." },
    { "ciudad_error",                 "danger",  "No se pudo procesar la ciudad. Inténtalo nuevamente." },
    { "tipo_agregado",                "success", "El tipo de propiedad se agregó correctamente." },
    { "tipo_eliminado",               "success", "El tipo de propiedad se eliminó correctamente." },
    { "tipo_duplicado",               "warning", "Ya existe un tipo de propiedad con ese nombre." },
    { "tipo_nombre_vacio",            "danger",  "El nombre del tipo de propiedad no puede estar vacío." },
    { "tipo_en_uso",                  "danger",  "No se puede eliminar: hay propiedades asociadas a este tipo." },
    { "tipo_no_existe",               "warning", "El tipo de propiedad indicado ya no existe." },
    { "tipo_error",                   "danger",  "No se pudo procesar el tipo de propiedad. Inténtalo nuevamente." },
    { "carac_agregada",               "success", "La característica se agregó correctamente." },
    { "carac_eliminada",              "success", "La característica se eliminó correctamente." },
    { "carac_duplicada",              "warning", "Ya existe una característica con ese nombre." },
    { "carac_nombre_vacio",           "danger",  "El nombre de la característica no puede estar vacío." },
    { "carac_en_uso",                 "danger",  "No se puede eliminar: hay propiedades que usan esta característica." },
    { "carac_no_existe",              "warning", "La característica indicada ya no existe." },
    { "carac_error",                  "danger",  "No se pudo procesar la característica. Inténtalo nuevamente." },
    { "error",                        "danger",  "No se pudo procesar la acción. Inténtalo nuevamente." }
};
for (String[] m : mensajes) {
    if (m[0].equals(msg)) {
%>
<div class="alert alert-<%= m[1] %>" role="alert"><%= m[2] %></div>
<%
    }
}
%>

<% if (errorListado == null) { %>

<!-- ============================ CIUDAD ============================ -->
<section id="ciudad" class="card shadow-sm mb-4">
    <div class="card-body">
        <h2 class="h5 mb-3">Ciudades</h2>
        <form method="post" action="<%= ctx %>/admin/catalogos.jsp" class="row g-2 align-items-end mb-3">
            <input type="hidden" name="accion" value="agregar_ciudad">
            <div class="col-12 col-md-4">
                <label class="form-label" for="ciudad-nombre">Nombre</label>
                <input type="text" name="nombre" id="ciudad-nombre" class="form-control"
                       placeholder="Ej. Bucaramanga" maxlength="100">
            </div>
            <div class="col-12 col-md-4">
                <label class="form-label" for="ciudad-departamento">Departamento</label>
                <input type="text" name="departamento" id="ciudad-departamento" class="form-control"
                       placeholder="Ej. Santander" maxlength="100">
            </div>
            <div class="col-12 col-md-2 d-grid">
                <button type="submit" class="btn btn-primary">Agregar</button>
            </div>
        </form>

        <div class="table-responsive">
            <table class="table table-striped table-hover align-middle">
                <thead>
                    <tr><th>ID</th><th>Ciudad</th><th>Departamento</th><th>Acciones</th></tr>
                </thead>
                <tbody>
                <% for (String[] cd : ciudades) { %>
                    <tr>
                        <td><%= cd[0] %></td>
                        <td><%= escapar(cd[1]) %></td>
                        <td><%= escapar(cd[2]) %></td>
                        <td>
                            <form method="post" action="<%= ctx %>/admin/catalogos.jsp" class="d-inline">
                                <input type="hidden" name="accion" value="eliminar_ciudad">
                                <input type="hidden" name="id_ciudad" value="<%= cd[0] %>">
                                <button type="submit" class="btn btn-outline-danger btn-sm"
                                        onclick="return confirm('¿Eliminar esta ciudad? No se podrá borrar si tiene propiedades asociadas.');">
                                    Eliminar
                                </button>
                            </form>
                        </td>
                    </tr>
                <% } %>
                <% if (ciudades.isEmpty()) { %>
                    <tr><td colspan="4" class="text-muted text-center">No hay ciudades registradas.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </div>
</section>

<!-- ======================= TIPO_PROPIEDAD ======================= -->
<section id="tipo" class="card shadow-sm mb-4">
    <div class="card-body">
        <h2 class="h5 mb-3">Tipos de propiedad</h2>
        <form method="post" action="<%= ctx %>/admin/catalogos.jsp" class="row g-2 align-items-end mb-3">
            <input type="hidden" name="accion" value="agregar_tipo">
            <div class="col-12 col-md-8">
                <label class="form-label" for="tipo-nombre">Nombre</label>
                <input type="text" name="nombre" id="tipo-nombre" class="form-control"
                       placeholder="Ej. Casa" maxlength="80">
            </div>
            <div class="col-12 col-md-2 d-grid">
                <button type="submit" class="btn btn-primary">Agregar</button>
            </div>
        </form>

        <div class="table-responsive">
            <table class="table table-striped table-hover align-middle">
                <thead>
                    <tr><th>ID</th><th>Nombre</th><th>Acciones</th></tr>
                </thead>
                <tbody>
                <% for (String[] tp : tipos) { %>
                    <tr>
                        <td><%= tp[0] %></td>
                        <td><%= escapar(tp[1]) %></td>
                        <td>
                            <form method="post" action="<%= ctx %>/admin/catalogos.jsp" class="d-inline">
                                <input type="hidden" name="accion" value="eliminar_tipo">
                                <input type="hidden" name="id_tipo" value="<%= tp[0] %>">
                                <button type="submit" class="btn btn-outline-danger btn-sm"
                                        onclick="return confirm('¿Eliminar este tipo de propiedad? No se podrá borrar si tiene propiedades asociadas.');">
                                    Eliminar
                                </button>
                            </form>
                        </td>
                    </tr>
                <% } %>
                <% if (tipos.isEmpty()) { %>
                    <tr><td colspan="3" class="text-muted text-center">No hay tipos de propiedad registrados.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </div>
</section>

<!-- ======================= CARACTERISTICA ======================= -->
<section id="caracteristica" class="card shadow-sm mb-4">
    <div class="card-body">
        <h2 class="h5 mb-3">Características</h2>
        <form method="post" action="<%= ctx %>/admin/catalogos.jsp" class="row g-2 align-items-end mb-3">
            <input type="hidden" name="accion" value="agregar_caracteristica">
            <div class="col-12 col-md-8">
                <label class="form-label" for="carac-nombre">Nombre</label>
                <input type="text" name="nombre" id="carac-nombre" class="form-control"
                       placeholder="Ej. Parqueadero" maxlength="100">
            </div>
            <div class="col-12 col-md-2 d-grid">
                <button type="submit" class="btn btn-primary">Agregar</button>
            </div>
        </form>

        <div class="table-responsive">
            <table class="table table-striped table-hover align-middle">
                <thead>
                    <tr><th>ID</th><th>Nombre</th><th>Acciones</th></tr>
                </thead>
                <tbody>
                <% for (String[] ca : caracteristicas) { %>
                    <tr>
                        <td><%= ca[0] %></td>
                        <td><%= escapar(ca[1]) %></td>
                        <td>
                            <form method="post" action="<%= ctx %>/admin/catalogos.jsp" class="d-inline">
                                <input type="hidden" name="accion" value="eliminar_caracteristica">
                                <input type="hidden" name="id_caracteristica" value="<%= ca[0] %>">
                                <button type="submit" class="btn btn-outline-danger btn-sm"
                                        onclick="return confirm('¿Eliminar esta característica? No se podrá borrar si alguna propiedad la usa.');">
                                    Eliminar
                                </button>
                            </form>
                        </td>
                    </tr>
                <% } %>
                <% if (caracteristicas.isEmpty()) { %>
                    <tr><td colspan="3" class="text-muted text-center">No hay características registradas.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </div>
</section>

<% } %>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>