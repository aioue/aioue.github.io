(function () {
  function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    // Fallback for browsers that block navigator.clipboard (e.g. Brave Shields)
    var textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    try {
      document.execCommand('copy');
      document.body.removeChild(textarea);
      return Promise.resolve();
    } catch (e) {
      document.body.removeChild(textarea);
      return Promise.reject(e);
    }
  }

  function addCopyButtons() {
    document.querySelectorAll('div.highlighter-rouge, figure.highlight').forEach(function (block) {
      var wrapper = document.createElement('div');
      wrapper.className = 'code-block-wrapper';
      block.parentNode.insertBefore(wrapper, block);
      wrapper.appendChild(block);

      var btn = document.createElement('button');
      btn.className = 'copy-code-btn';
      btn.textContent = 'copy';
      btn.setAttribute('aria-label', 'Copy code to clipboard');

      btn.addEventListener('click', function () {
        var pre = block.querySelector('pre');
        var code = pre ? pre.innerText : '';
        copyToClipboard(code).then(function () {
          btn.textContent = 'copied!';
          btn.classList.add('copied');
          setTimeout(function () {
            btn.textContent = 'copy';
            btn.classList.remove('copied');
          }, 1500);
        }).catch(function () {
          btn.textContent = 'error';
          setTimeout(function () { btn.textContent = 'copy'; }, 1500);
        });
      });

      wrapper.appendChild(btn);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addCopyButtons);
  } else {
    addCopyButtons();
  }
})();
