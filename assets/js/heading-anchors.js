(function () {
  function addHeadingAnchors() {
    document.querySelectorAll('main h2[id], main h3[id], main h4[id], main h5[id], main h6[id]').forEach(function (heading) {
      if (heading.querySelector('.heading-anchor')) return;

      var link = document.createElement('a');
      link.className = 'heading-anchor';
      link.href = '#' + heading.id;
      link.setAttribute('aria-label', 'Link to this section');
      link.textContent = '#';
      heading.appendChild(link);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addHeadingAnchors);
  } else {
    addHeadingAnchors();
  }
})();
