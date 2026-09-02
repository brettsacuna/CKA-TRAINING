
(function(){
  "use strict";
  // copy buttons for markdown code blocks
  document.querySelectorAll('.md pre, .md .hl, .md .codehilite').forEach(function(pre){
    if(pre.querySelector('.copybtn-float')) return;
    var b=document.createElement('button');
    b.className='copybtn-float';
    b.type='button';
    b.innerHTML='<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="12" height="12" rx="2"></rect><path d="M5 15V5a2 2 0 0 1 2-2h10"></path></svg> Copiar';
    b.addEventListener('click',function(){
      var code=pre.querySelector('code')||pre.querySelector('pre')||pre;
      navigator.clipboard.writeText(code.innerText.replace(/\n$/,'')).then(function(){
        b.textContent='Copiado'; setTimeout(function(){b.innerHTML='<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="12" height="12" rx="2"></rect><path d="M5 15V5a2 2 0 0 1 2-2h10"></path></svg> Copiar';},1400);
      });
    });
    pre.appendChild(b);
  });

  // resource viewer
  var stack=document.querySelector('.viewer-stack');
  if(stack){
    var items=[].slice.call(document.querySelectorAll('.rl-item'));
    var viewers=[].slice.call(document.querySelectorAll('.viewer'));
    function show(name){
      viewers.forEach(function(v){ v.hidden = v.dataset.file!==name; });
      items.forEach(function(a){ a.classList.toggle('on', a.dataset.file===name); });
    }
    items.forEach(function(a){
      a.addEventListener('click',function(e){ e.preventDefault();
        history.replaceState(null,'','#'+a.dataset.file); show(a.dataset.file); });
    });
    var initial=(location.hash||'').replace('#','');
    if(!initial || !viewers.some(function(v){return v.dataset.file===initial;}))
      initial = items[0] && items[0].dataset.file;
    if(initial) show(initial);

    document.querySelectorAll('.copybtn').forEach(function(btn){
      btn.addEventListener('click',function(){
        var v=document.querySelector('.viewer[data-file="'+btn.dataset.target+'"] .viewer-code');
        if(!v) return;
        navigator.clipboard.writeText(v.innerText.replace(/\n$/,'')).then(function(){
          var t=btn.innerHTML; btn.textContent='Copiado';
          setTimeout(function(){btn.innerHTML=t;},1400);
        });
      });
    });
  }
})();
