<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.ArrayList, java.util.List" %>
<%@ page import="java.text.DecimalFormat" %>
<%@ page import="java.math.BigDecimal" %>
<%!
private static class FilaPropiedad {
    int id;
    String titulo;
    String precio;
    String area;
    int habitaciones;
    int banos;
    String estado;
    String tipo;
    String ciudad;
    String departamento;
    String inmobiliaria;
    String urlPrincipal;
    String direccion;
    String matricula;
    boolean esFavorito;
}

private static final String PLACEHOLDER_IMG =
    "data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%22400%22%20height%3D%22200%22%3E%3Crect%20width%3D%22400%22%20height%3D%22200%22%20fill%3D%22%23e9ecef%22%2F%3E%3Ctext%20x%3D%22200%22%20y%3D%22100%22%20fill%3D%22%236c757d%22%20font-family%3D%22Arial%22%20font-size%3D%2218%22%20text-anchor%3D%22middle%22%3ESin%20imagen%3C%2Ftext%3E%3C%2Fsvg%3E";

private String limpiar(String valor) { return valor == null ? "" : valor.trim(); }

private String enc(String valor) {
    try {
        return java.net.URLEncoder.encode(valor == null ? "" : valor, "UTF-8");
    } catch (Exception ignorada) {
        return "";
    }
}

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

private String ipCliente(HttpServletRequest request) {
    String ip = request.getRemoteAddr();
    if (ip == null || ip.trim().isEmpty()) return null;
    ip = ip.trim();
    if (ip.length() > 45) ip = ip.substring(0, 45);
    return ip;
}
%>
<%
String[] rolesPermitidos = { "CLIENTE" };
String tituloPagina = "Propiedades Disponibles";
%>
<%@ include file="/WEB-INF/jspf/seguridad.jspf" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<%
try { request.setCharacterEncoding("UTF-8"); } catch (Exception ignorada) {}

// Filtros recibidos por GET (todos opcionales)
String fTipo   = limpiar(request.getParameter("tipo"));
String fCiudad = limpiar(request.getParameter("ciudad"));
String fEstado = limpiar(request.getParameter("estado"));
String fPrecioMin = limpiar(request.getParameter("precio_min"));
String fPrecioMax = limpiar(request.getParameter("precio_max"));

// Toggle de favoritos (POST -> PRG conservando filtros)
String mensajeFavorito = null;
if ("POST".equalsIgnoreCase(request.getMethod())) {
    int idPropiedad = 0;
    try { idPropiedad = Integer.parseInt(limpiar(request.getParameter("id_propiedad"))); }
    catch (NumberFormatException ignorada) { idPropiedad = 0; }
    String accion = limpiar(request.getParameter("accion"));

    if (idPropiedad > 0 && errorConexion == null) {
        if ("agregar".equals(accion)) {
            PreparedStatement psChk = null;
            ResultSet rsChk = null;
            boolean existe = false;
            String tituloAgregar = null;
            try {
                psChk = conexion.prepareStatement("SELECT titulo FROM propiedad WHERE id_propiedad = ?");
                psChk.setInt(1, idPropiedad);
                rsChk = psChk.executeQuery();
                existe = rsChk.next();
                if (existe) tituloAgregar = rsChk.getString(1);
            } catch (SQLException ignorada) {
            } finally {
                cerrar(rsChk, psChk);
            }
            if (existe) {
                PreparedStatement psIns = null;
                ResultSet rsClave = null;
                try {
                    conexion.setAutoCommit(false);
                    psIns = conexion.prepareStatement(
                        "INSERT INTO favorito (id_usuario, id_propiedad) VALUES (?, ?)",
                        Statement.RETURN_GENERATED_KEYS);
                    psIns.setInt(1, idUsuarioSesion);
                    psIns.setInt(2, idPropiedad);
                    psIns.executeUpdate();
                    int idFavorito = -1;
                    rsClave = psIns.getGeneratedKeys();
                    if (rsClave.next()) idFavorito = rsClave.getInt(1);
                    cerrar(rsClave, psIns);
                    if (idFavorito > 0) {
                        // Registro de auditoría (misma transacción)
                        PreparedStatement psAud = conexion.prepareStatement(
                            "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                            "VALUES (?, ?, ?, ?, ?, ?)");
                        psAud.setInt(1, idUsuarioSesion.intValue());
                        psAud.setString(2, "favorito");
                        psAud.setInt(3, idFavorito);
                        psAud.setString(4, "INSERT");
                        psAud.setString(5, "Agregado favorito de propiedad: " + (tituloAgregar == null ? "" : tituloAgregar));
                        String ipAgregar = ipCliente(request);
                        if (ipAgregar == null) {
                            psAud.setNull(6, Types.VARCHAR);
                        } else {
                            psAud.setString(6, ipAgregar);
                        }
                        psAud.executeUpdate();
                        cerrar(null, psAud);
                        conexion.commit();
                        mensajeFavorito = "agregado";
                    } else {
                        deshacer(conexion);
                        mensajeFavorito = "error";
                    }
                } catch (SQLIntegrityConstraintViolationException dup) {
                    deshacer(conexion);
                    mensajeFavorito = "duplicado";
                } catch (SQLException ex) {
                    deshacer(conexion);
                    mensajeFavorito = "error";
                } finally {
                    cerrar(rsClave, psIns);
                }
            } else {
                mensajeFavorito = "error";
            }
        } else if ("quitar".equals(accion)) {
            PreparedStatement psSel = null;
            ResultSet rsSel = null;
            int idFavoritoQuitar = -1;
            String tituloQuitar = null;
            try {
                psSel = conexion.prepareStatement(
                    "SELECT f.id_favorito, p.titulo " +
                    "FROM favorito f JOIN propiedad p ON p.id_propiedad = f.id_propiedad " +
                    "WHERE f.id_usuario = ? AND f.id_propiedad = ?");
                psSel.setInt(1, idUsuarioSesion);
                psSel.setInt(2, idPropiedad);
                rsSel = psSel.executeQuery();
                if (rsSel.next()) {
                    idFavoritoQuitar = rsSel.getInt(1);
                    tituloQuitar = rsSel.getString(2);
                }
            } catch (SQLException ignorada) {
            } finally {
                cerrar(rsSel, psSel);
            }
            if (idFavoritoQuitar > 0) {
                PreparedStatement psDel = null;
                try {
                    conexion.setAutoCommit(false);
                    psDel = conexion.prepareStatement(
                        "DELETE FROM favorito WHERE id_usuario = ? AND id_propiedad = ?");
                    psDel.setInt(1, idUsuarioSesion);
                    psDel.setInt(2, idPropiedad);
                    int filasDel = psDel.executeUpdate();
                    cerrar(null, psDel);
                    if (filasDel > 0) {
                        // Registro de auditoría (misma transacción)
                        PreparedStatement psAud = conexion.prepareStatement(
                            "INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, detalles, ip_address) " +
                            "VALUES (?, ?, ?, ?, ?, ?)");
                        psAud.setInt(1, idUsuarioSesion.intValue());
                        psAud.setString(2, "favorito");
                        psAud.setInt(3, idFavoritoQuitar);
                        psAud.setString(4, "DELETE");
                        psAud.setString(5, "Eliminado favorito de propiedad: " + (tituloQuitar == null ? "" : tituloQuitar));
                        String ipEliminar = ipCliente(request);
                        if (ipEliminar == null) {
                            psAud.setNull(6, Types.VARCHAR);
                        } else {
                            psAud.setString(6, ipEliminar);
                        }
                        psAud.executeUpdate();
                        cerrar(null, psAud);
                        conexion.commit();
                        mensajeFavorito = "quitado";
                    } else {
                        deshacer(conexion);
                        mensajeFavorito = "quitado";
                    }
                } catch (SQLException ex) {
                    deshacer(conexion);
                    mensajeFavorito = "error";
                } finally {
                    cerrar(null, psDel);
                }
            } else {
                mensajeFavorito = "quitado";
            }
        }
    } else if (idPropiedad <= 0) {
        mensajeFavorito = "error";
    }

    StringBuilder q = new StringBuilder();
    if (!fTipo.isEmpty())   q.append("&tipo=").append(enc(fTipo));
    if (!fCiudad.isEmpty()) q.append("&ciudad=").append(enc(fCiudad));
    if (!fEstado.isEmpty()) q.append("&estado=").append(enc(fEstado));
    if (!fPrecioMin.isEmpty()) q.append("&precio_min=").append(enc(fPrecioMin));
    if (!fPrecioMax.isEmpty()) q.append("&precio_max=").append(enc(fPrecioMax));
    if (mensajeFavorito != null) q.append("&favorito=").append(mensajeFavorito);
    String qs = q.length() > 0 ? "?" + q.substring(1) : "";
    response.sendRedirect(ctx + "/cliente/propiedades.jsp" + qs);
    return;
}
String favDespuesPrg = limpiar(request.getParameter("favorito"));

String errorListado = null;
List<FilaPropiedad> filas = new ArrayList<FilaPropiedad>();
List<String[]> tiposCatalogo = new ArrayList<String[]>();
List<String[]> ciudadesCatalogo = new ArrayList<String[]>();
String[] estadosCatalogo = { "DISPONIBLE", "RESERVADA", "VENDIDA", "ALQUILADA" };

if (errorConexion != null) {
    errorListado = "No se pudo conectar con la base de datos. Inténtalo más tarde.";
} else {
    StringBuilder sql = new StringBuilder(
        "SELECT p.id_propiedad, p.titulo, p.precio, p.area_m2, p.num_habitaciones, p.num_banos, " +
        "p.estado, p.direccion, p.matricula_inmobiliaria, " +
        "t.nombre AS tipo_nombre, c.nombre AS ciudad_nombre, c.departamento, i.razon_social, " +
        "(SELECT ip.url_imagen FROM imagen_propiedad ip " +
        " WHERE ip.id_propiedad = p.id_propiedad AND ip.es_principal = 1 " +
        " ORDER BY ip.orden LIMIT 1) AS url_principal, " +
        "(ff.id_favorito IS NOT NULL) AS es_favorito " +
        "FROM propiedad p " +
        "JOIN tipo_propiedad t ON t.id_tipo = p.id_tipo " +
        "JOIN ciudad c ON c.id_ciudad = p.id_ciudad " +
        "JOIN inmobiliaria i ON i.id_inmobiliaria = p.id_inmobiliaria " +
        "LEFT JOIN favorito ff ON ff.id_propiedad = p.id_propiedad AND ff.id_usuario = ? " +
        "WHERE 1=1");
    List<Object> params = new ArrayList<Object>();

    if (!fTipo.isEmpty()) {
        try { int v = Integer.parseInt(fTipo); if (v > 0) { sql.append(" AND p.id_tipo = ?"); params.add(Integer.valueOf(v)); } } catch (NumberFormatException ignorada) {}
    }
    if (!fCiudad.isEmpty()) {
        try { int v = Integer.parseInt(fCiudad); if (v > 0) { sql.append(" AND p.id_ciudad = ?"); params.add(Integer.valueOf(v)); } } catch (NumberFormatException ignorada) {}
    }
    if (!fEstado.isEmpty()) {
        sql.append(" AND p.estado = ?"); params.add(fEstado);
    }
    if (!fPrecioMin.isEmpty()) {
        try { BigDecimal v = new BigDecimal(fPrecioMin); sql.append(" AND p.precio >= ?"); params.add(v); } catch (NumberFormatException ignorada) {}
    }
    if (!fPrecioMax.isEmpty()) {
        try { BigDecimal v = new BigDecimal(fPrecioMax); sql.append(" AND p.precio <= ?"); params.add(v); } catch (NumberFormatException ignorada) {}
    }
    sql.append(" ORDER BY p.fecha_publicacion DESC, p.id_propiedad DESC");

    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        // Catálogos para el formulario de filtros
        ps = conexion.prepareStatement("SELECT id_tipo, nombre FROM tipo_propiedad ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            tiposCatalogo.add(new String[] { String.valueOf(rs.getInt("id_tipo")), rs.getString("nombre") });
        }
        cerrar(rs, ps);

        ps = conexion.prepareStatement("SELECT id_ciudad, nombre, departamento FROM ciudad ORDER BY nombre");
        rs = ps.executeQuery();
        while (rs.next()) {
            ciudadesCatalogo.add(new String[] {
                String.valueOf(rs.getInt("id_ciudad")),
                rs.getString("nombre") + " (" + rs.getString("departamento") + ")"
            });
        }
        cerrar(rs, ps);

        // Consulta principal de propiedades con filtros dinámicos
        ps = conexion.prepareStatement(sql.toString());
        ps.setInt(1, idUsuarioSesion);
        int i = 2;
        for (Object p : params) {
            ps.setObject(i++, p);
        }
        rs = ps.executeQuery();

        DecimalFormat df = new DecimalFormat("###,###,##0");
        while (rs.next()) {
            FilaPropiedad f = new FilaPropiedad();
            f.id = rs.getInt("id_propiedad");
            f.titulo = rs.getString("titulo");
            f.precio = df.format(rs.getBigDecimal("precio"));
            BigDecimal area = rs.getBigDecimal("area_m2");
            f.area = area == null ? "N/D" : df.format(area);
            f.habitaciones = rs.getInt("num_habitaciones");
            f.banos = rs.getInt("num_banos");
            f.estado = rs.getString("estado");
            f.tipo = rs.getString("tipo_nombre");
            f.ciudad = rs.getString("ciudad_nombre");
            f.departamento = rs.getString("departamento");
            f.inmobiliaria = rs.getString("razon_social");
            f.urlPrincipal = rs.getString("url_principal");
            f.direccion = rs.getString("direccion");
            f.matricula = rs.getString("matricula_inmobiliaria");
            f.esFavorito = rs.getBoolean("es_favorito");
            filas.add(f);
        }
    } catch (SQLException ex) {
        errorListado = "No se pudieron cargar las propiedades. Inténtalo nuevamente.";
    } finally {
        cerrar(rs, ps, conexion);
    }
}
%>
<%@ include file="/WEB-INF/jspf/cabecera.jspf" %>

<div class="d-flex justify-content-between align-items-start mb-3">
    <h1 class="mb-0">Propiedades disponibles</h1>
    <a href="<%= ctx %>/cliente/panel.jsp" class="btn btn-outline-secondary btn-sm">Volver al panel</a>
</div>

<% if (errorListado != null) { %>
<div class="alert alert-danger" role="alert"><%= escapar(errorListado) %></div>
<% } %>

<% if ("agregado".equals(favDespuesPrg)) { %>
<div class="alert alert-success" role="alert">La propiedad fue agregada a tus favoritos. <i class="bi bi-heart-fill"></i></div>
<% } %>
<% if ("quitado".equals(favDespuesPrg)) { %>
<div class="alert alert-info" role="alert">La propiedad fue quitada de tus favoritos.</div>
<% } %>
<% if ("duplicado".equals(favDespuesPrg)) { %>
<div class="alert alert-warning" role="alert">Esta propiedad ya estaba en tus favoritos.</div>
<% } %>
<% if ("error".equals(favDespuesPrg)) { %>
<div class="alert alert-danger" role="alert">No se pudo actualizar el favorito. Inténtalo más tarde.</div>
<% } %>

<form method="get" action="<%= ctx %>/cliente/propiedades.jsp" class="row g-2 mb-4">
    <div class="col-12 col-md-3">
        <select name="tipo" class="form-select">
            <option value="">Tipo (todos)</option>
            <% for (String[] tp : tiposCatalogo) { %>
            <option value="<%= tp[0] %>" <%= fTipo.equals(tp[0]) ? "selected" : "" %>><%= escapar(tp[1]) %></option>
            <% } %>
        </select>
    </div>
    <div class="col-12 col-md-3">
        <select name="ciudad" class="form-select">
            <option value="">Ciudad (todas)</option>
            <% for (String[] cd : ciudadesCatalogo) { %>
            <option value="<%= cd[0] %>" <%= fCiudad.equals(cd[0]) ? "selected" : "" %>><%= escapar(cd[1]) %></option>
            <% } %>
        </select>
    </div>
    <div class="col-12 col-md-2">
        <select name="estado" class="form-select">
            <option value="">Estado (todos)</option>
            <% for (String es : estadosCatalogo) { %>
            <option value="<%= es %>" <%= fEstado.equals(es) ? "selected" : "" %>><%= es %></option>
            <% } %>
        </select>
    </div>
    <div class="col-6 col-md-2">
        <input type="number" min="0" step="1000000" name="precio_min" value="<%= escapar(fPrecioMin) %>"
               class="form-control" placeholder="Precio mín.">
    </div>
    <div class="col-6 col-md-2">
        <input type="number" min="0" step="1000000" name="precio_max" value="<%= escapar(fPrecioMax) %>"
               class="form-control" placeholder="Precio máx.">
    </div>
    <div class="col-12 col-md-4 col-lg-2 d-flex gap-2">
        <button type="submit" class="btn btn-primary flex-fill">Filtrar</button>
        <a href="<%= ctx %>/cliente/propiedades.jsp" class="btn btn-outline-secondary">Limpiar</a>
    </div>
</form>

<% if (filas.isEmpty() && errorListado == null) { %>
<div class="alert alert-info" role="alert">No se encontraron propiedades con los filtros seleccionados.</div>
<% } %>

<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
<% for (FilaPropiedad f : filas) { %>
    <div class="col">
        <div class="card h-100 shadow-sm">
            <img class="card-img-top" style="height: 200px; object-fit: cover;"
                 src="<%= f.urlPrincipal != null ? escapar(f.urlPrincipal) : PLACEHOLDER_IMG %>"
                 onerror="this.onerror=null; this.src='<%= PLACEHOLDER_IMG %>';"
                 alt="<%= escapar(f.titulo) %>">
            <div class="card-body d-flex flex-column">
                <div class="d-flex justify-content-between align-items-start mb-1">
                    <h5 class="card-title mb-0"><%= escapar(f.titulo) %></h5>
                    <span class="badge <%= claseEstado(f.estado) %>"><%= escapar(f.estado) %></span>
                </div>
                <p class="text-muted small mb-2">
                    <%= escapar(f.tipo) %> &middot; <%= escapar(f.ciudad) %>, <%= escapar(f.departamento) %>
                </p>
                <p class="fs-5 fw-bold text-primary mb-1">$ <%= f.precio %></p>
                <ul class="list-inline small text-muted mb-2">
                    <li class="list-inline-item"><i class="bi bi-arrows-fullscreen"></i> <%= f.area %> m²</li>
                    <li class="list-inline-item">&#128716; <%= f.habitaciones %> hab</li>
                    <li class="list-inline-item">&#128703; <%= f.banos %> baños</li>
                </ul>
                <p class="small mb-1"><strong>Matrícula:</strong> <%= escapar(f.matricula) %></p>
                <p class="small text-muted mb-3"><strong><%= escapar(f.inmobiliaria) %></strong></p>
                <div class="mt-auto d-flex flex-column gap-2">
                    <a href="<%= ctx %>/cliente/detalle-propiedad.jsp?id=<%= f.id %>"
                       class="btn btn-sm btn-outline-primary w-100">Ver detalle</a>
                    <form method="post" action="<%= ctx %>/cliente/propiedades.jsp">
                        <input type="hidden" name="id_propiedad" value="<%= f.id %>">
                        <input type="hidden" name="accion" value="<%= f.esFavorito ? "quitar" : "agregar" %>">
                        <input type="hidden" name="tipo" value="<%= escapar(fTipo) %>">
                        <input type="hidden" name="ciudad" value="<%= escapar(fCiudad) %>">
                        <input type="hidden" name="estado" value="<%= escapar(fEstado) %>">
                        <input type="hidden" name="precio_min" value="<%= escapar(fPrecioMin) %>">
                        <input type="hidden" name="precio_max" value="<%= escapar(fPrecioMax) %>">
                        <button type="submit" class="btn btn-sm w-100 <%= f.esFavorito ? "btn-danger" : "btn-outline-danger" %>">
                            <i class="bi bi-heart<%= f.esFavorito ? "-fill" : "" %>"></i>
                            <%= f.esFavorito ? "Quitar de favoritos" : "Agregar a favoritos" %>
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </div>
<% } %>
</div>

<%@ include file="/WEB-INF/jspf/pie.jspf" %>