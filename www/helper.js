    var moxtrahelper = {
        attachTransparentClass: function(div,style) {

          if (div.classList && !div.classList.contains('mepwindow')) {
            div.classList.add('mepwindow');
              div.appendChild(style);
          } else if (div.className && div.className.indexOf('mepwindow') === -1) {
            div.className = div.className + ' mepwindow';
          }

          if (div.shadowRoot) {
            var styleAttr = div.getAttribute('style') || '';
            if (styleAttr && styleAttr.indexOf('--ion-background-color') === -1) {
              styleAttr = styleAttr + ' --ion-background-color: transparent;';
            }
            div.setAttribute('style', styleAttr);
          }
        },
        
        dettachTransparentClass:function(div) {
            if (div.classList && div.classList.contains('mepwindow')) {
              div.classList.remove('mepwindow');
            } else if (div.className && div.className.indexOf('mepwindow') === -1) {
              div.className = div.className.replace('mepwindow', '');
            }
        },
    };
    module.exports = moxtrahelper;
