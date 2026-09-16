package clases;

import java.io.IOException;
import java.util.List;
import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

public class FiltroAcceso implements Filter {

    public void init(FilterConfig config) throws ServletException {}

    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;
        HttpSession sesion = req.getSession(false);
        String ctxPath = req.getContextPath();
        String ruta = req.getRequestURI().substring(ctxPath.length());

        if (sesion == null || sesion.getAttribute("idUsuario") == null) {
            res.sendRedirect(ctxPath + "/login.jsp?error=sesion");
            return;
        }

        String rolEsperado = null;
        if (ruta.startsWith("/admin/")) {
            rolEsperado = "ADMINISTRADOR";
        } else if (ruta.startsWith("/cliente/")) {
            rolEsperado = "CLIENTE";
        } else if (ruta.startsWith("/inmobiliaria/")) {
            rolEsperado = "INMOBILIARIA";
        }

        if (rolEsperado != null) {
            String rol = (String) sesion.getAttribute("rol");
            List<String> roles = (List<String>) sesion.getAttribute("roles");
            boolean autorizado = rolEsperado.equals(rol) || (roles != null && roles.contains(rolEsperado));
            if (!autorizado) {
                res.sendRedirect(ctxPath + "/acceso-denegado.jsp");
                return;
            }
        }

        chain.doFilter(request, response);
    }

    public void destroy() {}
}