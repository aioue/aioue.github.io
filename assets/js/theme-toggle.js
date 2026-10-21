(function () {
  var OVERRIDE = "aioue-theme-override";
  var SESSION = "aioue-theme-session";

  function systemTheme() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }

  function overrideTheme() {
    try {
      var t = localStorage.getItem(OVERRIDE);
      if (t === "light" || t === "dark") {
        return t;
      }
    } catch (e) {
      /* private mode */
    }
    return null;
  }

  function sessionTheme() {
    try {
      var t = sessionStorage.getItem(SESSION);
      if (t === "light" || t === "dark") {
        return t;
      }
    } catch (e) {
      /* private mode */
    }
    return null;
  }

  function effectiveTheme() {
    var attr = document.documentElement.getAttribute("data-theme");
    if (attr === "light" || attr === "dark") {
      return attr;
    }
    return systemTheme();
  }

  function applyTheme(theme, persist) {
    document.documentElement.setAttribute("data-theme", theme);
    try {
      if (persist) {
        localStorage.setItem(OVERRIDE, theme);
        sessionStorage.removeItem(SESSION);
      }
    } catch (e) {
      /* private mode */
    }
    updateToggle();
  }

  function updateToggle() {
    var btn = document.getElementById("theme-toggle");
    if (!btn) {
      return;
    }
    btn.hidden = false;
    var theme = effectiveTheme();
    var isDark = theme === "dark";
    btn.setAttribute(
      "aria-label",
      isDark ? "Switch to light mode" : "Switch to dark mode"
    );
    btn.setAttribute("aria-pressed", isDark ? "true" : "false");
    btn.classList.toggle("theme-toggle--is-dark", isDark);
    btn.classList.toggle("theme-toggle--is-light", !isDark);
  }

  document.addEventListener("DOMContentLoaded", function () {
    var btn = document.getElementById("theme-toggle");
    if (!btn) {
      return;
    }
    if (typeof window.__aioueResolveTheme === "function") {
      window.__aioueResolveTheme();
    }
    updateToggle();
    btn.addEventListener("click", function () {
      applyTheme(effectiveTheme() === "dark" ? "light" : "dark", true);
    });
    window
      .matchMedia("(prefers-color-scheme: dark)")
      .addEventListener("change", function () {
        if (!overrideTheme() && !sessionTheme()) {
          if (typeof window.__aioueResolveTheme === "function") {
            window.__aioueResolveTheme();
          }
          updateToggle();
        }
      });
  });
})();
