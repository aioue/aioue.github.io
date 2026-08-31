(function () {
  function sliceLines(text, startAttr, endAttr) {
    var lines = text.replace(/\n$/, '').split('\n');
    var start = startAttr ? parseInt(startAttr, 10) : 1;
    var end = endAttr ? parseInt(endAttr, 10) : lines.length;
    if (!start || start < 1) start = 1;
    if (!end || end > lines.length) end = lines.length;
    if (end < start) return text.replace(/\n$/, '');
    return lines.slice(start - 1, end).join('\n');
  }

  function loadEmbed(el) {
    var repo = el.getAttribute('data-repo');
    var ref = el.getAttribute('data-ref') || 'main';
    var file = el.getAttribute('data-file');
    var code = el.querySelector('code');
    if (!repo || !file || !code) return;

    var url = 'https://raw.githubusercontent.com/' + repo + '/' + ref + '/' + file;
    fetch(url).then(function (response) {
      if (!response.ok) {
        throw new Error('HTTP ' + response.status);
      }
      return response.text();
    }).then(function (text) {
      code.textContent = sliceLines(
        text,
        el.getAttribute('data-start'),
        el.getAttribute('data-end')
      );
    }).catch(function () {
      code.textContent = 'Could not load ' + file + '. Open the GitHub link above.';
    });
  }

  function init() {
    document.querySelectorAll('.github-embed').forEach(loadEmbed);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
