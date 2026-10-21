(function () {
  var KEY = "aioue-color-scheme";

  function systemTheme() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }

  function storedTheme() {
    try {
      var t = localStorage.getItem(KEY);
      if (t === "light" || t === "dark") {
        return t;
      }
    } catch (e) {
      /* private mode */
    }
    return null;
  }

  function effectiveTheme() {
    return storedTheme() || systemTheme();
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme);
    try {
      localStorage.setItem(KEY, theme);
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
    if (!document.documentElement.getAttribute("data-theme")) {
      var stored = storedTheme();
      if (stored) {
        document.documentElement.setAttribute("data-theme", stored);
      }
    }
    updateToggle();
    btn.addEventListener("click", function () {
      applyTheme(effectiveTheme() === "dark" ? "light" : "dark");
    });
    window
      .matchMedia("(prefers-color-scheme: dark)")
      .addEventListener("change", function () {
        if (!storedTheme()) {
          updateToggle();
        }
      });
  });
})();
