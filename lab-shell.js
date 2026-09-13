/* ============================================================================
   DietStation Design Lab — shared flow shell
   Drop into any flow page with:
     <script src="../lab-shell.js" data-flow="<flow-id>" defer></script>
   Adds three lab views on top of the prototype:
     Prototype · User flow (auto-laid SVG diagram) · Dev handoff (RN kit + spec)
   Desktop: floating segmented control. Mobile: bottom tab bar that collapses
   to a corner chip while the prototype is in use.
   Data source: ../flows.json — fields used: title, description, status, updated,
   platform, area, handoff{}, downloads[], rn[], flow{nodes[],edges[]}.
   ========================================================================= */
(function () {
  'use strict';

  var FLOW_ID = (document.currentScript && document.currentScript.dataset.flow) ||
    (location.pathname.replace(/\/(index\.html)?$/, '').split('/').pop());

  /* ---------------- styles ---------------- */
  var css = "\
  .lab-tabs { position: fixed; top: 16px; left: 0; right: 0; z-index: 80;\
    display: none; justify-content: center; pointer-events: none; }\
  body.desktop .lab-tabs { display: flex; left: 316px; }\
  .lab-tabs.in-side { position: static; display: flex; margin: 0 0 20px;\
    pointer-events: auto; }\
  body:not(.desktop) .lab-tabs.in-side { display: none; }\
  body.desktop .lab-tabs.in-side { left: auto; }\
  .lab-tabs .seg { pointer-events: auto; display: inline-flex; gap: 2px; padding: 3px;\
    border-radius: 999px; background: #e9e9ec;\
    box-shadow: inset 0 0 0 .5px rgba(0,0,0,.04); }\
  .lab-tabs.in-side .seg { display: flex; width: 100%; }\
  .lab-tabs.in-side .seg button { flex: 1; }\
  .lab-tabs button { border: none; cursor: pointer; padding: 8px 16px; border-radius: 999px;\
    background: transparent; color: #6e6e73;\
    font: 600 12.5px/16px 'Urbane Rounded', -apple-system, sans-serif;\
    transition: background .18s ease, color .18s ease, box-shadow .18s ease; }\
  .lab-tabs button:hover { color: #1d1d1f; }\
  .lab-tabs button.on { background: #fff; color: #1d1d1f;\
    box-shadow: 0 1px 2px rgba(0,0,0,.08), 0 3px 8px rgba(0,0,0,.06); }\
\
  .lab-tabbar { position: fixed; left: 0; right: 0; bottom: 0; z-index: 90;\
    display: none; padding: 8px 10px calc(8px + env(safe-area-inset-bottom, 0px));\
    background: rgba(255,255,255,.92);\
    -webkit-backdrop-filter: blur(18px) saturate(160%); backdrop-filter: blur(18px) saturate(160%);\
    border-top: 0.5px solid rgba(0,0,0,.1);\
    transform: translateY(0); transition: transform .32s cubic-bezier(.3,.8,.3,1); }\
  body.lab-mobile .lab-tabbar { display: flex; }\
  .lab-tabbar.hidden { transform: translateY(110%); }\
  .lab-tabbar button { flex: 1; border: none; cursor: pointer; background: transparent;\
    display: flex; flex-direction: column; align-items: center; gap: 3px; padding: 5px 0 3px;\
    color: #8e8e93; font: 600 10px/12px 'Urbane Rounded', sans-serif;\
    -webkit-tap-highlight-color: transparent; }\
  .lab-tabbar button.on { color: #1d1d1f; }\
  .lab-tabbar button svg { width: 22px; height: 22px; display: block; }\
  .lab-tabbar button.on svg .a { stroke: #ED1C24; }\
\
  .lab-chip { position: fixed; left: 12px; bottom: calc(74px + env(safe-area-inset-bottom, 0px));\
    z-index: 88; width: 42px; height: 42px; border-radius: 50%; border: none; cursor: pointer;\
    display: none; align-items: center; justify-content: center;\
    background: rgba(255,255,255,.85); color: #1d1d1f;\
    -webkit-backdrop-filter: blur(14px) saturate(160%); backdrop-filter: blur(14px) saturate(160%);\
    box-shadow: 0 6px 20px -8px rgba(0,0,0,.25), inset 0 0 0 .5px rgba(0,0,0,.08);\
    -webkit-tap-highlight-color: transparent;\
    opacity: 0; transform: scale(.6); transition: opacity .25s ease, transform .25s cubic-bezier(.3,.8,.3,1); }\
  .lab-chip.show { opacity: 1; transform: scale(1); }\
  body.lab-mobile .lab-chip { display: flex; }\
  .lab-chip svg { width: 20px; height: 20px; }\
\
  .lab-view { position: fixed; inset: 0; z-index: 70; display: none;\
    background: #f5f5f7; overflow-y: auto; overflow-x: hidden;\
    touch-action: pan-y; -webkit-overflow-scrolling: touch; overscroll-behavior: contain; }\
  .lab-view.on { display: block; }\
  body.desktop .lab-view { left: 316px; }\
  .lab-view .lab-col { max-width: 880px; margin: 0 auto; padding: 84px 26px 80px; }\
  body.lab-mobile .lab-view .lab-col { padding: 30px 18px calc(96px + env(safe-area-inset-bottom, 0px)); }\
\
  .lab-kicker { font: 600 10px/14px 'Urbane Rounded', sans-serif; letter-spacing: 2px;\
    text-transform: uppercase; color: #ED1C24; margin-bottom: 10px; }\
  .lab-view h1 { font: 600 26px/32px 'Urbane Rounded', sans-serif; color: #1d1d1f;\
    letter-spacing: -.01em; margin: 0 0 10px; }\
  .lab-meta { display: flex; gap: 8px; flex-wrap: wrap; margin: 0 0 18px; }\
  .lab-meta span { font: 500 10.5px/1 'Urbane Rounded', sans-serif; letter-spacing: .07em;\
    text-transform: uppercase; padding: 6px 10px 5px; border-radius: 999px;\
    background: #e9e9ec; color: #6e6e73; }\
  .lab-meta span.hot { background: #FFF2F2; color: #ED1C24; }\
  .lab-desc { font: 400 14px/22px 'Proxima Nova', sans-serif; color: #6e6e73;\
    max-width: 64ch; margin: 0 0 26px; }\
\
  .lab-h3 { font: 600 11px/14px 'Urbane Rounded', sans-serif; letter-spacing: 1.8px;\
    text-transform: uppercase; color: #1d1d1f; margin: 34px 0 6px; }\
  .lab-note { font: 400 12.5px/18px 'Proxima Nova', sans-serif; color: #8e8e93;\
    max-width: 64ch; margin: 0 0 14px; }\
\
  .lab-diagram-wrap { position: relative; margin-top: 18px; border-radius: 18px;\
    background: #ffffff; box-shadow: 0 1px 3px rgba(0,0,0,.05), 0 12px 30px -20px rgba(0,0,0,.12);\
    overflow: auto; -webkit-overflow-scrolling: touch; touch-action: pan-x pan-y; }\
  .lab-diagram-wrap svg { display: block; margin: 0 auto; }\
  .lab-zoom { position: absolute; top: 12px; right: 12px; z-index: 2; display: inline-flex;\
    gap: 2px; padding: 3px; border-radius: 999px; background: #e9e9ec; }\
  .lab-zoom button { border: none; cursor: pointer; padding: 6px 12px; border-radius: 999px;\
    background: transparent; color: #6e6e73;\
    font: 600 10.5px/14px 'Urbane Rounded', sans-serif; }\
  .lab-zoom button.on { background: #fff; color: #1d1d1f;\
    box-shadow: 0 1px 2px rgba(0,0,0,.08); }\
  .lab-legend { display: flex; gap: 16px; flex-wrap: wrap; margin: 14px 2px 0; }\
  .lab-legend span { display: inline-flex; align-items: center; gap: 7px;\
    font: 400 11.5px/16px 'Proxima Nova', sans-serif; color: #8e8e93; }\
  .lab-legend i { width: 14px; height: 10px; border-radius: 3px; flex: none; }\
\
  .lab-sec { margin-top: 22px; }\
  .lab-sec h4 { font: 600 14.5px/20px 'Urbane Rounded', sans-serif; color: #1d1d1f;\
    letter-spacing: -.005em; margin: 0; }\
  .lab-sec .n { font: 400 12.5px/18px 'Proxima Nova', sans-serif; color: #8e8e93;\
    max-width: 66ch; margin: 4px 0 0; }\
  .lab-codewrap { position: relative; margin-top: 10px; }\
  .lab-codewrap pre { background: #ffffff; color: #1d1d1f; border-radius: 12px;\
    box-shadow: inset 0 0 0 .5px rgba(0,0,0,.1);\
    padding: 14px 16px; overflow-x: auto; -webkit-overflow-scrolling: touch; margin: 0;\
    font: 11.5px/1.6 ui-monospace, 'SF Mono', SFMono-Regular, Menlo, monospace; tab-size: 2;\
    user-select: text; -webkit-user-select: text; }\
  .lab-copy { position: absolute; top: 8px; right: 8px; cursor: pointer;\
    font: 600 10.5px/1 'Urbane Rounded', sans-serif; border: none; border-radius: 999px;\
    padding: 7px 12px; background: #e9e9ec; color: #1d1d1f; }\
  .lab-copy:hover { background: #dfdfe3; }\
  .lab-kithead { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }\
  .lab-kithead .lab-h3 { margin: 34px 0 6px; margin-right: auto; }\
  .lab-kithead .kitcopy { margin-top: 26px; border: none; cursor: pointer; border-radius: 999px;\
    padding: 9px 16px; background: #e9e9ec; color: #1d1d1f;\
    font: 600 11.5px/14px 'Urbane Rounded', sans-serif; }\
  .lab-kithead .kitcopy:hover { background: #dfdfe3; }\
\
  .lab-kv { display: grid; grid-template-columns: 150px 1fr; gap: 8px 18px;\
    font: 400 12.5px/18px 'Proxima Nova', sans-serif; user-select: text; -webkit-user-select: text; }\
  .lab-kv dt { color: #8e8e93; margin: 0; }\
  .lab-kv dd { color: #1d1d1f; margin: 0; overflow-wrap: anywhere; }\
  body.lab-mobile .lab-kv { grid-template-columns: 1fr; gap: 2px 0; }\
  body.lab-mobile .lab-kv dt { margin-top: 10px; }\
  .lab-dl { margin-top: 14px; display: flex; gap: 16px; flex-wrap: wrap; }\
  .lab-dl a { color: #ED1C24; text-decoration: none; font: 400 13px/18px 'Proxima Nova', sans-serif;\
    border-bottom: 1px solid rgba(237,28,36,.25); }\
  .lab-dl a:hover { border-bottom-color: #ED1C24; }\
  .lab-foot { margin-top: 44px; padding-top: 16px; border-top: 1px solid rgba(0,0,0,.08);\
    font: 400 11px/16px 'Proxima Nova', sans-serif; color: #8e8e93; }\
  ";
  var style = document.createElement('style');
  css += "\
/* ---- native TestFlight shell + shared triple-tap lab menu ---- */\
html.ds-native #pill, html.ds-native .lab-chip, html.ds-native .lab-tabs,\
html.ds-native .lab-tabbar { display: none !important; }\
/* in-app the lab views open from the lab menu; the floating back chip is\
   the way out since the tab bar is hidden there */\
.lab-ctrlwrap { overflow-x: auto; -webkit-overflow-scrolling: touch; margin-top: 10px; }\
.lab-ctrlmap { width: 100%; border-collapse: collapse; }\
.lab-ctrlmap th { text-align: left; padding: 0 14px 8px 0; white-space: nowrap;\
  font: 600 10.5px/1 'Urbane Rounded', sans-serif; letter-spacing: .09em;\
  text-transform: uppercase; color: #6e6e73; }\
.lab-ctrlmap td { padding: 9px 14px 9px 0; vertical-align: top;\
  border-top: 0.5px solid rgba(0,0,0,.09);\
  font: 400 13px/1.45 -apple-system, sans-serif; color: #1d1d1f; }\
.lab-ctrlmap code { font: 500 11.5px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;\
  background: #f5f5f7; color: #1d1d1f; padding: 2px 7px; border-radius: 6px; white-space: nowrap; }\
.lab-ctrlmap tr.stub td { opacity: .45; }\
.lab-ctrlmap .c-intent { display: block; margin-top: 4px; color: #ED1C24;\
  font: 500 11.5px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace; }\
@media (max-width: 600px) {\
  .lab-ctrlmap, .lab-ctrlmap tbody, .lab-ctrlmap tr, .lab-ctrlmap td { display: block; width: auto; }\
  .lab-ctrlmap thead { display: none; }\
  .lab-ctrlmap tr { border-top: 0.5px solid rgba(0,0,0,.09); padding: 11px 0; }\
  .lab-ctrlmap td { border: 0; padding: 0; }\
  .lab-ctrlmap td:not(:first-child):not(:empty) { margin-top: 5px; }\
  .lab-ctrlmap code { white-space: normal; word-break: break-word; }\
}\
.lab-back { display: none; position: fixed; top: calc(14px + env(safe-area-inset-top, 0px));\
  right: 14px; z-index: 80; width: 40px; height: 40px; border: 0.5px solid rgba(0,0,0,.1);\
  border-radius: 50%; align-items: center; justify-content: center;\
  background: rgba(255,255,255,.55); color: #1d1d1f; cursor: pointer;\
  -webkit-backdrop-filter: blur(14px) saturate(170%);\
  backdrop-filter: blur(14px) saturate(170%);\
  box-shadow: inset 0 0 0 0.5px rgba(255,255,255,.6), 0 4px 12px -6px rgba(0,0,0,.25); }\
.lab-back svg { width: 15px; height: 15px; }\
html.ds-native .lab-back.show { display: flex; }\
.labshell-veil { position: fixed; inset: 0; z-index: 128; background: rgba(0,0,0,.45);\
  opacity: 0; pointer-events: none; transition: opacity .25s ease; }\
body.labshell-open .labshell-veil { opacity: 1; pointer-events: auto; }\
/* OVERLAY RULE: the veil dissolves in place; the sheet travels on the\
   house spring (labshell-menu mounts it offscreen, labshell-open rides) */\
body.labshell-menu:not(.desktop) #side { display: block !important; left: 0; right: 0;\
  top: auto; bottom: 0; width: auto; max-height: 76vh; overflow-y: auto;\
  border-radius: 24px 24px 0 0; z-index: 129; background: #fbfbfc;\
  box-shadow: 0 -18px 60px rgba(0,0,0,.28);\
  transform: translateY(103%);\
  transition: transform .55s cubic-bezier(.32,.72,0,1);\
  padding: 22px 22px calc(30px + env(safe-area-inset-bottom, 0px)); }\
body.labshell-open:not(.desktop) #side { transform: translateY(0); }\
.labshell-topbar { display: none; gap: 10px; margin: 0 0 12px; }\
body.labshell-menu:not(.desktop) .labshell-topbar { display: flex; }\
.labshell-topbar button { flex: 1; display: flex; align-items: center;\
  justify-content: center; gap: 7px; padding: 13px;\
  border: 1px solid rgba(0,0,0,.12); border-radius: 14px; background: #fff;\
  color: #1d1d1f; font: 600 13px/1 -apple-system, sans-serif; }\
.labshell-topbar button svg { width: 13px; height: 13px; flex: none; }\
.labshell-topbar .lx-exit { color: #ED1C24; border-color: rgba(237,28,36,.28); }\
.labshell-links { display: none; gap: 10px; margin: 0 0 18px; }\
body.labshell-menu:not(.desktop) .labshell-links { display: flex; }\
.labshell-links button { flex: 1; padding: 13px; border: 1px solid rgba(0,0,0,.12);\
  border-radius: 14px; background: #fff; color: #1d1d1f;\
  font: 600 13px/1 -apple-system, sans-serif; }\
.labshell-done { display: none; margin: 20px 0 0; width: 100%; padding: 14px; border: 0;\
  border-radius: 999px; background: #1d1d1f; color: #fff;\
  font: 600 15px/1 -apple-system, sans-serif; }\
body.labshell-menu:not(.desktop) .labshell-done { display: block; }\
";
  style.textContent = css;
  document.head.appendChild(style);

  /* ---------------- icons ---------------- */
  var IC = {
    proto: '<svg viewBox="0 0 24 24" fill="none"><rect class="a" x="7" y="3" width="10" height="18" rx="2.5" stroke="currentColor" stroke-width="1.6"/><path class="a" d="M10.5 5h3" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>',
    flow: '<svg viewBox="0 0 24 24" fill="none"><rect class="a" x="9" y="3" width="6" height="4.6" rx="1.6" stroke="currentColor" stroke-width="1.6"/><rect class="a" x="3.5" y="16.4" width="6" height="4.6" rx="1.6" stroke="currentColor" stroke-width="1.6"/><rect class="a" x="14.5" y="16.4" width="6" height="4.6" rx="1.6" stroke="currentColor" stroke-width="1.6"/><path class="a" d="M12 7.6v3.4m0 0-5.5 2.6m5.5-2.6 5.5 2.6" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>',
    code: '<svg viewBox="0 0 24 24" fill="none"><path class="a" d="m8.5 8-4 4 4 4M15.5 8l4 4-4 4M13 5.5l-2 13" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    chip: '<svg viewBox="0 0 24 24" fill="none"><path d="m8.5 8-4 4 4 4M15.5 8l4 4-4 4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
  };

  /* ---------------- DOM scaffold ---------------- */
  var TABS = [
    { id: 'proto', label: 'Prototype', icon: IC.proto },
    { id: 'userflow', label: 'User flow', icon: IC.flow },
    { id: 'handoff', label: 'Dev handoff', icon: IC.code }
  ];

  var tabsEl = document.createElement('div');
  tabsEl.className = 'lab-tabs';
  tabsEl.innerHTML = '<div class="seg">' + TABS.map(function (t) {
    return '<button data-lab-tab="' + t.id + '">' + t.label + '</button>';
  }).join('') + '</div>';

  var barEl = document.createElement('nav');
  barEl.className = 'lab-tabbar hidden';
  barEl.innerHTML = TABS.map(function (t) {
    return '<button data-lab-tab="' + t.id + '">' + t.icon + '<span>' + t.label + '</span></button>';
  }).join('');

  var chipEl = document.createElement('button');
  chipEl.className = 'lab-chip';
  chipEl.setAttribute('aria-label', 'Lab views');
  chipEl.innerHTML = IC.chip;

  var flowView = document.createElement('section');
  flowView.className = 'lab-view';
  flowView.id = 'labUserflow';

  var handView = document.createElement('section');
  handView.className = 'lab-view';
  handView.id = 'labHandoff';

  var backEl = document.createElement('button');
  backEl.className = 'lab-back';
  backEl.setAttribute('aria-label', 'Back to prototype');
  backEl.innerHTML = '<svg viewBox="0 0 16 16" fill="none"><path d="M3.5 3.5l9 9M12.5 3.5l-9 9" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>';
  backEl.addEventListener('click', function () { setTab('proto'); });

  /* ---------------- tab state ---------------- */
  var current = 'proto';
  var collapseTimer = null;

  function isMobile() { return document.body.classList.contains('lab-mobile'); }

  function syncMobileClass() {
    var mobile = matchMedia('(max-width: 500px)').matches ||
      (matchMedia('(pointer: coarse)').matches && Math.min(innerWidth, innerHeight) < 900);
    document.body.classList.toggle('lab-mobile', mobile);
  }

  function collapseBar(delay) {
    clearTimeout(collapseTimer);
    collapseTimer = setTimeout(function () {
      if (current === 'proto') {
        barEl.classList.add('hidden');
        chipEl.classList.add('show');
      }
    }, delay);
  }

  function expandBar() {
    clearTimeout(collapseTimer);
    barEl.classList.remove('hidden');
    chipEl.classList.remove('show');
  }

  function setTab(name, fromHash) {
    current = name;
    tabsEl.querySelectorAll('button').forEach(function (b) {
      b.classList.toggle('on', b.dataset.labTab === name);
    });
    barEl.querySelectorAll('button').forEach(function (b) {
      b.classList.toggle('on', b.dataset.labTab === name);
    });
    flowView.classList.toggle('on', name === 'userflow');
    handView.classList.toggle('on', name === 'handoff');
    backEl.classList.toggle('show', name !== 'proto');
    if (!fromHash) {
      var h = name === 'userflow' ? '#userflow' : name === 'handoff' ? '#handoff' : ' ';
      try { history.replaceState(null, '', h === ' ' ? location.pathname + location.search : h); } catch (_) {}
    }
    if (isMobile()) {
      if (name === 'proto') collapseBar(400); else expandBar();
    }
  }

  tabsEl.addEventListener('click', function (e) {
    var b = e.target.closest('button[data-lab-tab]');
    if (b) setTab(b.dataset.labTab);
  });
  barEl.addEventListener('click', function (e) {
    var b = e.target.closest('button[data-lab-tab]');
    if (b) setTab(b.dataset.labTab);
  });
  chipEl.addEventListener('click', function () {
    expandBar();
    collapseBar(3500); // auto-tuck again if untouched
  });

  addEventListener('resize', function () {
    syncMobileClass();
    if (!isMobile()) { barEl.classList.add('hidden'); chipEl.classList.remove('show'); }
    else if (current !== 'proto') expandBar();
    else if (!chipEl.classList.contains('show')) collapseBar(0);
  });

  /* ---------------- helpers ---------------- */
  function esc(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
  }

  function copyFeedback(btn, text, label) {
    (navigator.clipboard ? navigator.clipboard.writeText(text) : Promise.reject())
      .then(function () {
        btn.textContent = 'Copied ✓';
        setTimeout(function () { btn.textContent = label; }, 1400);
      }).catch(function () {});
  }

  /* =========================================================================
     USER FLOW DIAGRAM — layered DAG auto-layout onto SVG
     nodes: [{id, t, kind: screen|decision|module|end, note?}]
     edges: [[from, to, label?]]
     ====================================================================== */
  function wrap(text, max) {
    var words = String(text).split(/\s+/), lines = [], cur = '';
    words.forEach(function (w) {
      if ((cur + ' ' + w).trim().length > max && cur) { lines.push(cur); cur = w; }
      else cur = (cur + ' ' + w).trim();
    });
    if (cur) lines.push(cur);
    return lines;
  }

  function buildDiagram(flow) {
    var NW = 182, GX = 34, GY = 60, PAD = 36;
    var nodes = {}, order = [];
    flow.nodes.forEach(function (n) {
      var tl = wrap(n.t, 20), nl = n.note ? wrap(n.note, 30) : [];
      nodes[n.id] = { d: n, tl: tl, nl: nl,
        h: 15 + tl.length * 18 + (nl.length ? 5 + nl.length * 14 : 0) + 13,
        parents: [], children: [], layer: 0 };
      order.push(n.id);
    });
    // classify back-edges (retry loops) so cycles never distort the layering;
    // they are still drawn, just ignored for layer assignment
    var state = {}, backSet = {};
    function dfs(id) {
      state[id] = 1;
      nodes[id].children.forEach(function (c) {
        if (state[c] === 1) backSet[id + '>' + c] = true;
        else if (!state[c]) dfs(c);
      });
      state[id] = 2;
    }
    flow.edges.forEach(function (e) {
      var a = nodes[e[0]], b = nodes[e[1]];
      if (!a || !b) return;
      a.children.push(e[1]);
    });
    order.forEach(function (id) { if (!state[id]) dfs(id); });
    flow.edges.forEach(function (e) {
      if (!nodes[e[0]] || !nodes[e[1]]) return;
      if (!backSet[e[0] + '>' + e[1]]) nodes[e[1]].parents.push(e[0]);
    });
    // longest-path layering over forward edges only
    for (var pass = 0; pass < order.length; pass++) {
      var moved = false;
      order.forEach(function (id) {
        var n = nodes[id];
        n.parents.forEach(function (p) {
          if (nodes[p].layer + 1 > n.layer) { n.layer = nodes[p].layer + 1; moved = true; }
        });
      });
      if (!moved) break;
    }
    var layers = [];
    order.forEach(function (id) {
      var L = nodes[id].layer;
      (layers[L] = layers[L] || []).push(id);
    });
    // barycenter ordering (few sweeps)
    for (var s = 0; s < 3; s++) {
      layers.forEach(function (row, li) {
        if (li === 0) return;
        row.sort(function (a, b) {
          var ba = bary(a), bb = bary(b);
          return ba - bb;
        });
        function bary(id) {
          var ps = nodes[id].parents.filter(function (p) { return nodes[p].layer === li - 1; });
          if (!ps.length) return row.indexOf(id);
          var sum = 0;
          ps.forEach(function (p) { sum += layers[li - 1].indexOf(p); });
          return sum / ps.length;
        }
      });
    }
    // x positions: spread each layer, center on widest
    var maxW = 0;
    layers.forEach(function (row) {
      maxW = Math.max(maxW, row.length * NW + (row.length - 1) * GX);
    });
    var W = maxW + PAD * 2;
    var y = PAD;
    layers.forEach(function (row) {
      var total = row.length * NW + (row.length - 1) * GX;
      var x0 = (W - total) / 2, maxH = 0;
      row.forEach(function (id, i) {
        var n = nodes[id];
        n.x = x0 + i * (NW + GX); n.y = y; n.w = NW;
        maxH = Math.max(maxH, n.h);
      });
      y += maxH + GY;
    });
    var H = y - GY + PAD;

    // gentle x-alignment: single-parent/single-child chains follow the parent
    order.forEach(function (id) {
      var n = nodes[id];
      if (n.parents.length === 1) {
        var p = nodes[n.parents[0]];
        var siblings = p.children.filter(function (c) { return nodes[c].layer === n.layer; });
        if (siblings.length === 1 && layers[n.layer].length === 1) n.x = p.x;
      }
    });

    var KIND = {
      screen:   { fill: '#ffffff', stroke: 'rgba(0,0,0,.16)', dash: '', text: '#1d1d1f' },
      decision: { fill: '#FFF2F2', stroke: '#ED1C24', dash: '', text: '#1d1d1f' },
      module:   { fill: '#f5f5f7', stroke: 'rgba(0,0,0,.3)', dash: '5 4', text: '#3a3a3c' },
      end:      { fill: '#ED1C24', stroke: 'rgba(0,0,0,.08)', dash: '', text: '#ffffff' }
    };

    var svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + W + ' ' + H +
      '" width="' + W + '" height="' + H + '" font-family="\'Urbane Rounded\',-apple-system,sans-serif">'];
    svg.push('<defs><marker id="labArr" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse">' +
      '<path d="M0.5,0.8 L7,4 L0.5,7.2" fill="none" stroke="rgba(0,0,0,.38)" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></marker></defs>');

    // edges under nodes
    flow.edges.forEach(function (e) {
      var a = nodes[e[0]], b = nodes[e[1]];
      if (!a || !b) return;
      var back = b.y <= a.y;
      var x1 = a.x + a.w / 2, y1 = back ? a.y : a.y + a.h;
      var x2 = b.x + b.w / 2, y2 = back ? b.y + b.h + 3 : b.y - 3;
      var same = Math.abs(x1 - x2) < 2;
      var midY = (y1 + y2) / 2;
      // edges that skip layers bow sideways so they don't run through nodes
      var skip = !back && (b.layer - a.layer) > 1;
      var bow = skip ? ((x1 + x2) / 2 >= W / 2 ? 1 : -1) * Math.min(150, W / 2 - PAD) * 0.9 : 0;
      if (skip && same) bow = -Math.min(150, (x1 - PAD)) * 0.9;
      var d;
      if (skip) {
        var cx = (x1 + x2) / 2 + bow;
        d = 'M' + x1 + ',' + y1 + ' C' + cx + ',' + (y1 + 50) + ' ' + cx + ',' + (y2 - 50) + ' ' + x2 + ',' + y2;
      } else if (same) {
        d = 'M' + x1 + ',' + y1 + ' L' + x2 + ',' + y2;
      } else {
        d = 'M' + x1 + ',' + y1 + ' C' + x1 + ',' + midY + ' ' + x2 + ',' + midY + ' ' + x2 + ',' + y2;
      }
      svg.push('<path d="' + d + '" fill="none" stroke="rgba(0,0,0,.25)" stroke-width="1.4"' +
        (back ? ' stroke-dasharray="3 4"' : '') + ' marker-end="url(#labArr)"/>');
      if (e[2]) {
        var lx = Math.max(40, (x1 + x2) / 2 + bow * 0.75), ly = midY;
        var tw = e[2].length * 5.6 + 12;
        svg.push('<rect x="' + (lx - tw / 2) + '" y="' + (ly - 9) + '" width="' + tw +
          '" height="17" rx="8.5" fill="#ffffff" stroke="rgba(0,0,0,.12)"/>');
        svg.push('<text x="' + lx + '" y="' + (ly + 3.5) + '" text-anchor="middle" font-size="9.5" ' +
          'font-family="\'Proxima Nova\',sans-serif" fill="#6e6e73">' + esc(e[2]) + '</text>');
      }
    });

    // nodes
    order.forEach(function (id) {
      var n = nodes[id], k = KIND[n.d.kind] || KIND.screen;
      svg.push('<g>');
      svg.push('<rect x="' + n.x + '" y="' + n.y + '" width="' + n.w + '" height="' + n.h +
        '" rx="13" fill="' + k.fill + '" stroke="' + k.stroke + '" stroke-width="1.2"' +
        (k.dash ? ' stroke-dasharray="' + k.dash + '"' : '') + '/>');
      var ty = n.y + 15 + 12;
      n.tl.forEach(function (line) {
        svg.push('<text x="' + (n.x + n.w / 2) + '" y="' + ty + '" text-anchor="middle" font-size="12.5" ' +
          'font-weight="600" fill="' + k.text + '">' + esc(line) + '</text>');
        ty += 18;
      });
      if (n.nl.length) {
        ty += 1;
        n.nl.forEach(function (line) {
          svg.push('<text x="' + (n.x + n.w / 2) + '" y="' + ty + '" text-anchor="middle" font-size="10" ' +
            'font-family="\'Proxima Nova\',sans-serif" fill="' +
            (n.d.kind === 'end' ? 'rgba(255,255,255,.85)' : '#8e8e93') + '">' + esc(line) + '</text>');
          ty += 14;
        });
      }
      svg.push('</g>');
    });
    svg.push('</svg>');
    return { svg: svg.join(''), w: W, h: H };
  }

  /* ---------------- view renderers ---------------- */
  function metaPills(f) {
    var out = [];
    if (f.platform) out.push('<span>' + esc(f.platform) + '</span>');
    if (f.area) out.push('<span>' + esc(f.area) + '</span>');
    out.push('<span class="hot">' + (f.status === 'ready' ? 'Ready' : 'In progress') + '</span>');
    if (f.updated) out.push('<span>Updated ' + esc(f.updated) + '</span>');
    return '<div class="lab-meta">' + out.join('') + '</div>';
  }

  function renderUserflow(f) {
    var col = document.createElement('div');
    col.className = 'lab-col';
    col.innerHTML = '<div class="lab-kicker">DietStation · Design Lab</div>' +
      '<h1>' + esc(f.title) + '</h1>' + metaPills(f) +
      '<p class="lab-desc">Every screen and decision in this flow, in order — dashed modules ' +
      'only exist when their condition is met. The prototype tab walks the same map live.</p>';
    if (f.flow && f.flow.nodes && f.flow.nodes.length) {
      var dg = buildDiagram(f.flow);
      var wrapEl = document.createElement('div');
      wrapEl.className = 'lab-diagram-wrap';
      wrapEl.innerHTML = '<div class="lab-zoom"><button data-z="fit" class="on">Fit</button>' +
        '<button data-z="full">100%</button></div>' + dg.svg;
      var svgEl = wrapEl.querySelector('svg');
      function applyZoom(mode) {
        wrapEl.querySelectorAll('.lab-zoom button').forEach(function (b) {
          b.classList.toggle('on', b.dataset.z === mode);
        });
        if (mode === 'fit') { svgEl.style.width = '100%'; svgEl.style.height = 'auto'; svgEl.style.maxWidth = dg.w + 'px'; }
        else { svgEl.style.width = dg.w + 'px'; svgEl.style.height = dg.h + 'px'; svgEl.style.maxWidth = 'none'; }
      }
      wrapEl.querySelector('.lab-zoom').addEventListener('click', function (e) {
        var b = e.target.closest('button'); if (b) applyZoom(b.dataset.z);
      });
      applyZoom('fit');
      col.appendChild(wrapEl);
      var legend = document.createElement('div');
      legend.className = 'lab-legend';
      legend.innerHTML =
        '<span><i style="background:#fff;box-shadow:inset 0 0 0 1px rgba(0,0,0,.2)"></i>Screen</span>' +
        '<span><i style="background:#FFF2F2;box-shadow:inset 0 0 0 1px #ED1C24"></i>Decision</span>' +
        '<span><i style="background:#f5f5f7;border:0;outline:1px dashed rgba(0,0,0,.35);outline-offset:-1px"></i>Conditional module</span>' +
        '<span><i style="background:#ED1C24"></i>End state</span>';
      col.appendChild(legend);
    } else {
      col.innerHTML += '<p class="lab-note">No flow map published for this prototype yet.</p>';
    }
    var foot = document.createElement('div');
    foot.className = 'lab-foot';
    foot.textContent = 'Drawn live from flows.json · maintained by Rashid × Claude';
    col.appendChild(foot);
    flowView.appendChild(col);
  }

  function renderHandoff(f) {
    var col = document.createElement('div');
    col.className = 'lab-col';
    col.innerHTML = '<div class="lab-kicker">DietStation · Design Lab</div>' +
      '<h1>' + esc(f.title) + '</h1>' + metaPills(f) +
      '<p class="lab-desc">' + esc(f.description || '') + '</p>';

    /* dev kits: SwiftUI spec first (native-first, handoff template v2),
       the RN kit stays as the fallback for every other platform */
    function renderKit(title, noteTxt, secs) {
      var head = document.createElement('div');
      head.className = 'lab-kithead';
      head.innerHTML = '<div class="lab-h3">' + title + '</div>' +
        '<button class="kitcopy">Copy full kit</button>';
      col.appendChild(head);
      var kitNote = document.createElement('p');
      kitNote.className = 'lab-note';
      kitNote.textContent = noteTxt;
      col.appendChild(kitNote);
      secs.forEach(function (s) {
        var sec = document.createElement('div');
        sec.className = 'lab-sec';
        sec.innerHTML = '<h4>' + esc(s.t) + '</h4><p class="n">' + esc(s.note) + '</p>';
        if (s.code) {
          var w = document.createElement('div');
          w.className = 'lab-codewrap';
          var pre = document.createElement('pre');
          pre.textContent = s.code;
          var c = document.createElement('button');
          c.className = 'lab-copy'; c.textContent = 'Copy';
          c.onclick = function () { copyFeedback(c, s.code, 'Copy'); };
          w.append(pre, c);
          sec.appendChild(w);
        }
        col.appendChild(sec);
      });
      head.querySelector('.kitcopy').onclick = function (e) {
        var md = '# ' + f.title + ' — ' + title + '\n\n' + secs.map(function (s) {
          return '## ' + s.t + '\n\n' + s.note + (s.code ? '\n\n```\n' + s.code + '\n```' : '');
        }).join('\n\n');
        copyFeedback(e.target, md, 'Copy full kit');
      };
    }
    if (f.swift && f.swift.length)
      renderKit('SwiftUI spec', 'The native iOS build sheet — stack, ' +
        '.glassEffect materials, motion springs and DS tokens, ready to paste.', f.swift);
    if (f.rn && f.rn.length)
      renderKit('React fallback kit', 'For every non-iOS platform — stack, ' +
        'Figma-exact tokens, and the interaction math, ready to paste into your own workflow.', f.rn);

    if (f.controls && f.controls.length) {
      var h3c = document.createElement('div');
      h3c.className = 'lab-h3'; h3c.textContent = 'Semantic control map';
      col.appendChild(h3c);
      var noteC = document.createElement('p');
      noteC.className = 'lab-note';
      noteC.textContent = 'Every control this flow exposes, in authoring ' +
        'order — drive a regression run by [data-act], never by visible ' +
        'text (labels split across weight spans and move in Arabic).';
      col.appendChild(noteC);
      var wrap = document.createElement('div');
      wrap.className = 'lab-ctrlwrap';
      var rows = f.controls.map(function (c) {
        var intent = c.intent
          ? '<span class="c-intent">&rarr; ' + esc(c.intent.to) +
            ' &middot; ' + esc(c.intent.present) + '</span>' : '';
        return '<tr' + (c.status === 'stub' ? ' class="stub"' : '') + '>' +
          '<td><code>[data-act="' + esc(c.act) + '"]</code></td>' +
          '<td>' + esc(c.does) + intent + '</td>' +
          '<td>' + (c.payload ? '<code>' + esc(c.payload) + '</code>' : '') +
          '</td></tr>';
      }).join('');
      wrap.innerHTML = '<table class="lab-ctrlmap"><thead><tr><th>Act</th>' +
        '<th>What it does</th><th>Payload</th></tr></thead><tbody>' +
        rows + '</tbody></table>';
      col.appendChild(wrap);
    }

    if ((f.entries && f.entries.length) || (f.exits && f.exits.length)) {
      var h3i = document.createElement('div');
      h3i.className = 'lab-h3'; h3i.textContent = 'Integration points';
      col.appendChild(h3i);
      var noteI = document.createElement('p');
      noteI.className = 'lab-note';
      noteI.textContent = 'Cross-flow contract: deep links this flow accepts ' +
        '(entries) and ds-nav intents it emits (exits), routed by the hub.';
      col.appendChild(noteI);
      var dli = document.createElement('dl');
      dli.className = 'lab-kv';
      (f.entries || []).forEach(function (en) {
        var dt = document.createElement('dt'); dt.textContent = 'entry · ' + en.id;
        var dd = document.createElement('dd');
        dd.textContent = (en.note || '') + (en.params
          ? ' · params: ' + Object.keys(en.params).join(', ') : '');
        dli.append(dt, dd);
      });
      (f.exits || []).forEach(function (ex) {
        var dt = document.createElement('dt'); dt.textContent = 'exit · ' + ex.intent;
        var dd = document.createElement('dd');
        dd.textContent = '→ ' + ex.to + ' (' + ex.present + ')' +
          (ex.note ? ' — ' + ex.note : '');
        dli.append(dt, dd);
      });
      col.appendChild(dli);
    }

    if (f.handoff && Object.keys(f.handoff).length) {
      var h3 = document.createElement('div');
      h3.className = 'lab-h3'; h3.textContent = 'Spec sheet';
      col.appendChild(h3);
      var note = document.createElement('p');
      note.className = 'lab-note';
      note.textContent = 'The design decisions and exact values behind this build — same spec the hub card carries.';
      col.appendChild(note);
      var dl = document.createElement('dl');
      dl.className = 'lab-kv';
      Object.keys(f.handoff).forEach(function (k) {
        var dt = document.createElement('dt'); dt.textContent = k;
        var dd = document.createElement('dd'); dd.textContent = f.handoff[k];
        dl.append(dt, dd);
      });
      col.appendChild(dl);
    }

    if (f.downloads && f.downloads.length) {
      var h3d = document.createElement('div');
      h3d.className = 'lab-h3'; h3d.textContent = 'Downloads';
      col.appendChild(h3d);
      var dld = document.createElement('div');
      dld.className = 'lab-dl';
      f.downloads.forEach(function (d) {
        var a = document.createElement('a');
        // hrefs in flows.json are hub-relative ("rewards/file") — we're inside the folder
        a.href = '../' + d.href; a.download = ''; a.textContent = d.label;
        dld.appendChild(a);
      });
      col.appendChild(dld);
    }

    var foot = document.createElement('div');
    foot.className = 'lab-foot';
    foot.textContent = 'Served live from flows.json · maintained by Rashid × Claude';
    col.appendChild(foot);
    handView.appendChild(col);
  }

  /* ---------------- boot ---------------- */
  function boot() {
    document.body.append(tabsEl, barEl, chipEl, flowView, handView, backEl);
    var side = document.getElementById('side');
    if (side) {
      tabsEl.classList.add('in-side');
      side.insertBefore(tabsEl, side.firstChild);
    }
    syncMobileClass();
    setupLabMenu();
    setupSideResize();
    fetch('../flows.json?v=' + Date.now())
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var f = (data.flows || []).find(function (x) { return x.id === FLOW_ID; });
        if (!f) return;
        renderUserflow(f);
        renderHandoff(f);
        var initial = location.hash === '#userflow' ? 'userflow'
          : location.hash === '#handoff' ? 'handoff' : 'proto';
        setTab(initial, true);
        if (isMobile() && initial === 'proto') {
          // brief hello so the tab bar is discoverable, then tuck away
          barEl.classList.remove('hidden');
          collapseBar(2200);
        }
      })
      .catch(function () { /* offline / file:// — shell stays dormant */ });
  }

  /* Desktop: resizable sidebar (drag the divider), default half the screen */
  function setupSideResize() {
    if (!document.body.classList.contains('desktop')) return;
    if (!document.getElementById('side')) return;
    var saved = null;
    try { saved = localStorage.getItem('ds-sidew'); } catch (e) {}
    var setW = function (px) {
      document.documentElement.style.setProperty('--sidew', px + 'px');
      try { localStorage.setItem('ds-sidew', String(px)); } catch (e) {}
    };
    var st = document.createElement('style');
    st.textContent = '\
body.desktop #side { width: var(--sidew, 50vw) !important; }\
body.desktop #stage { left: var(--sidew, 50vw) !important; }\
body.desktop .lab-tabs:not(.in-side) { left: var(--sidew, 50vw) !important; }\
body.desktop .lab-view { left: var(--sidew, 50vw) !important; }\
.side-resizer { position: fixed; top: 0; bottom: 0;\
  left: calc(var(--sidew, 50vw) - 3px); width: 7px; cursor: col-resize;\
  z-index: 300; }\
.side-resizer:hover, .side-resizer.dragging { background: rgba(237,28,36,.18); }';
    document.head.appendChild(st);
    setW(saved ? parseFloat(saved) : Math.round(innerWidth / 2));
    var rz = document.createElement('div');
    rz.className = 'side-resizer';
    document.body.appendChild(rz);
    var dragging = false;
    rz.addEventListener('mousedown', function (e) {
      dragging = true;
      rz.classList.add('dragging');
      e.preventDefault();
    });
    addEventListener('mousemove', function (e) {
      if (!dragging) return;
      var w = Math.max(260, Math.min(innerWidth - 320, e.clientX));
      setW(w);
      dispatchEvent(new Event('resize'));
    });
    addEventListener('mouseup', function () {
      if (!dragging) return;
      dragging = false;
      rz.classList.remove('dragging');
      dispatchEvent(new Event('resize'));
    });
  }

  /* Native TestFlight shell (DietStationLab UA token): chrome-free prototypes */
  if (/DietStationLab/.test(navigator.userAgent))
    document.documentElement.classList.add('ds-native');

  /* Standard mobile lab menu: triple-tap & hold anywhere. Flows with their own
     implementation (meal-select) set window.dsOwnLabMenu before this runs. */
  /* Gesture tuned for real fingers on device: taps are counted in the
     CAPTURE phase on the window, so prototype surfaces that stopPropagation
     in their own touch handlers can't swallow them (the old bubble-phase
     listener only fired on "dead" spots), and the hold tolerates up to
     16px of finger jitter instead of dying on the first touchmove. */
  function tripleTapHold(openFn) {
    /* Timing reads e.timeStamp (hardware event time), NOT performance.now()
       at processing time: on flows with heavy main-thread work (liquid-glass
       html2canvas snapshots, Rive canvases) handlers run late, and wall-clock
       deltas made real triple-taps look too slow to ever count.
       Delivery is belt-and-suspenders: WKWebView proved on-device that
       window-level TOUCH listeners can silently never fire while
       element-level ones work, so the primary source is POINTER events
       (dispatched ahead of touch events, immune to touch-layer games),
       attached at BOTH window (capture) and document (bubble) with a
       same-event dedupe so whichever path survives delivers exactly once.
       Touch events remain as the no-PointerEvent fallback. */
    var TAP_MS = 550, HOLD_MS = 380, SLOP = 16;
    var taps = 0, last = 0, hold = null, holdAt = 0, x0 = 0, y0 = 0;
    function cancel() { if (hold) { clearTimeout(hold); hold = null; } }
    function fire() { cancel(); taps = 0; holdAt = 0; openFn(); }
    function down(x, y, ts, multi) {
      if (multi) { taps = 0; cancel(); return; }
      taps = (ts - last < TAP_MS) ? taps + 1 : 1;
      last = ts;
      x0 = x; y0 = y;
      cancel();
      if (taps >= 3) { holdAt = ts; hold = setTimeout(fire, HOLD_MS); }
    }
    function move(x, y) {
      if (hold && (Math.abs(x - x0) > SLOP || Math.abs(y - y0) > SLOP)) cancel();
    }
    function up(ts) {
      /* jank can starve the hold timer past the queued release — honor a
         hold that was physically long enough by its event timestamps */
      if (hold && holdAt && ts - holdAt >= HOLD_MS) { fire(); return; }
      cancel();
    }
    var seen = '';
    function once(fn) {
      return function (e) {
        var k = e.type + '|' + e.timeStamp + '|' +
          (e.pointerId !== undefined ? e.pointerId
            : (e.changedTouches && e.changedTouches[0]
                ? e.changedTouches[0].identifier : 0));
        if (k === seen) return;
        seen = k;
        fn(e);
      };
    }
    function on(type, fn) {
      var h = once(fn);
      addEventListener(type, h, { passive: true, capture: true });
      document.addEventListener(type, h, { passive: true });
    }
    function ts(e) { return e.timeStamp || performance.now(); }
    if (window.PointerEvent) {
      on('pointerdown', function (e) {
        if (e.pointerType === 'mouse') return;
        down(e.clientX, e.clientY, ts(e), !e.isPrimary);
      });
      on('pointermove', function (e) {
        if (e.pointerType === 'mouse' || !e.isPrimary) return;
        move(e.clientX, e.clientY);
      });
      on('pointerup', function (e) {
        if (e.pointerType === 'mouse') return;
        up(ts(e));
      });
      on('pointercancel', function () { cancel(); });
    } else {
      on('touchstart', function (e) {
        var t = e.touches[0];
        down(t ? t.clientX : 0, t ? t.clientY : 0, ts(e), e.touches.length > 1);
      });
      on('touchmove', function (e) {
        var t = e.touches[0];
        if (t) move(t.clientX, t.clientY);
      });
      on('touchend', function (e) { up(ts(e)); });
      on('touchcancel', function () { cancel(); });
    }
  }
  /* Canonical lab gesture (Rashid, spec corrected 2026-09-09): a
     THREE-FINGER single tap-and-hold — three simultaneous touches held
     ~0.4s. The single-finger triple-tap-and-hold above stays as the
     pointer/desktop fallback (mice and simulators can't make 3 touches).
     Same delivery belt-and-suspenders as tripleTapHold: pointer tracking
     AND document-level touch counting behind one latch, hardware
     timestamps, and a hold the release can honor when jank starves the
     timer. */
  function threeFingerHold(openFn) {
    var HOLD_MS = 400, SLOP = 24;
    var lastFire = 0;
    function latchFire() {
      var now = performance.now();
      if (now - lastFire < 600) return;
      lastFire = now;
      openFn();
    }
    /* ---- pointer source ---- */
    if (window.PointerEvent) {
      var active = {}, pAt = 0, pHold = null;
      var pCount = function () { var n = 0; for (var k in active) n++; return n; };
      var pCancel = function () {
        if (pHold) clearTimeout(pHold);
        pHold = null; pAt = 0;
      };
      addEventListener('pointerdown', function (e) {
        if (e.pointerType === 'mouse') return;
        active[e.pointerId] = { x: e.clientX, y: e.clientY };
        var n = pCount();
        if (n === 3) {
          pAt = e.timeStamp || performance.now();
          pHold = setTimeout(function () { pHold = null; pAt = 0; latchFire(); }, HOLD_MS);
        } else if (n > 3) pCancel();
      }, { passive: true, capture: true });
      addEventListener('pointermove', function (e) {
        var a = active[e.pointerId];
        if (!a || !pAt) return;
        if (Math.abs(e.clientX - a.x) > SLOP ||
            Math.abs(e.clientY - a.y) > SLOP) pCancel();
      }, { passive: true, capture: true });
      var pLift = function (e) {
        delete active[e.pointerId];
        if (pAt) {
          var held = (e.timeStamp || performance.now()) - pAt;
          pCancel();
          if (held >= HOLD_MS) latchFire();
        }
      };
      addEventListener('pointerup', pLift, { passive: true, capture: true });
      addEventListener('pointercancel', function (e) {
        delete active[e.pointerId]; pCancel();
      }, { passive: true, capture: true });
    }
    /* ---- document-level touch source ---- */
    var tAt = 0, tHold = null, tPts = null;
    function tCancel() {
      if (tHold) clearTimeout(tHold);
      tHold = null; tAt = 0; tPts = null;
    }
    document.addEventListener('touchstart', function (e) {
      if (!e.touches) return;
      if (e.touches.length === 3 && !tAt) {
        tAt = e.timeStamp || performance.now();
        tPts = [];
        for (var i = 0; i < 3; i++)
          tPts.push({ id: e.touches[i].identifier,
            x: e.touches[i].clientX, y: e.touches[i].clientY });
        tHold = setTimeout(function () { tHold = null; tAt = 0; latchFire(); }, HOLD_MS);
      } else if (e.touches.length > 3) tCancel();
    }, { passive: true });
    document.addEventListener('touchmove', function (e) {
      if (!tAt || !e.changedTouches) return;
      for (var i = 0; i < e.changedTouches.length; i++) {
        var c = e.changedTouches[i];
        for (var j = 0; j < tPts.length; j++) {
          if (tPts[j].id === c.identifier &&
              (Math.abs(c.clientX - tPts[j].x) > SLOP ||
               Math.abs(c.clientY - tPts[j].y) > SLOP)) { tCancel(); return; }
        }
      }
    }, { passive: true });
    document.addEventListener('touchend', function (e) {
      if (!tAt) return;
      var held = (e.timeStamp || performance.now()) - tAt;
      tCancel();
      if (held >= HOLD_MS) latchFire();
    }, { passive: true });
    document.addEventListener('touchcancel', function () { tCancel(); }, { passive: true });
  }
  function setupLabMenu() {
    if (window.dsOwnLabMenu) {
      /* flows with their own sheet still get the reliable window-level
         gestures, routed to their opener when they expose one */
      if (typeof window.openLabMenu === 'function') {
        var routed = function () {
          if (!document.body.classList.contains('desktop')) window.openLabMenu();
        };
        threeFingerHold(routed);   /* primary */
        tripleTapHold(routed);     /* pointer/desktop fallback */
      }
      return;
    }
    var side = document.getElementById('side');
    if (!side) return;
    var veil = document.createElement('div');
    veil.className = 'labshell-veil';
    document.body.appendChild(veil);
    var links = document.createElement('div');
    links.className = 'labshell-links';
    links.innerHTML = '<button data-t="userflow">User flow</button>' +
      '<button data-t="handoff">Dev handoff</button>';
    side.insertBefore(links, side.firstChild);
    /* top action bar: restart the prototype fresh, or exit back to the hub */
    var bar = document.createElement('div');
    bar.className = 'labshell-topbar';
    bar.innerHTML =
      '<button class="lx-restart"><svg viewBox="0 0 16 16" fill="none">' +
      '<path d="M13.7 8a5.7 5.7 0 1 1-1.67-4.03" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>' +
      '<path d="M12.4 1.5v2.7H9.7" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>' +
      '</svg>Restart</button>' +
      '<button class="lx-exit"><svg viewBox="0 0 16 16" fill="none">' +
      '<path d="M3.2 3.2l9.6 9.6M12.8 3.2l-9.6 9.6" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>' +
      '</svg>Exit prototype</button>';
    side.insertBefore(bar, links);
    bar.querySelector('.lx-restart').addEventListener('click', function () {
      /* fresh reload with a cache-bust, keeping flags like embed=1 */
      var q = location.search.replace(/^\?/, '').split('&')
        .filter(function (p) { return p && p.indexOf('v=') !== 0; });
      q.push('v=' + Date.now());
      location.replace(location.pathname + '?' + q.join('&'));
    });
    bar.querySelector('.lx-exit').addEventListener('click', function () {
      /* inside the hub's flow sheet the hub closes us; standalone, go home.
         NATIVE SHEET HOST (composition.html#spec-sheethost): a page hosted
         in its own native web view has parent === window, so a window
         comparison alone would skip the close and load the hub INSIDE the
         sheet. The guard reads `embedded` and sends through the spec's rule.
         One clause beyond the spec's predicate: hosted also requires
         parent === window. A truly hosted page always satisfies it, so the
         hosted case is unchanged — but the app injects its bridge scripts
         into iframes too (forMainFrameOnly: false), and every hub flow
         frame carries embed=1, so without it a cap visible in an iframe
         would route every flow's Exit to native instead of the hub.
         No cap present: identical to the old behaviour. */
      var hosted = !!(window.DSNativeCaps && window.DSNativeCaps.sheetHost >= 1) &&
        /[?&]embed=1/.test(location.search) &&
        !/[?&]sheethost=0/.test(location.search) &&
        window.parent === window;
      var embedded = window.parent !== window || hosted;
      if (embedded) {
        try {
          if (hosted) {
            window.webkit.messageHandlers.ds.postMessage({ t: 'ds-relay', msg: { t: 'ds-close' } });
          } else {
            window.parent.postMessage({ t: 'ds-close' }, '*');
          }
          return;
        } catch (_) {}
      }
      location.href = '../?v=' + Date.now();
    });
    var done = document.createElement('button');
    done.className = 'labshell-done';
    done.textContent = 'Done';
    side.appendChild(done);
    var closeT = null;
    function open() {
      if (document.body.classList.contains('desktop')) return;
      clearTimeout(closeT); closeT = null;
      document.body.classList.add('labshell-menu');
      /* two-phase so the sheet mounts offscreen, then rides the spring
         (setTimeout, not rAF — rAF starves in hidden tabs) */
      setTimeout(function () {
        document.body.classList.add('labshell-open');
      }, 20);
      try { navigator.vibrate && navigator.vibrate(12); } catch (_) {}
    }
    function close() {
      document.body.classList.remove('labshell-open');
      clearTimeout(closeT);
      closeT = setTimeout(function () {
        closeT = null;
        document.body.classList.remove('labshell-menu');
      }, 560);
    }
    /* legacy openers (flow-page backup detectors) add labshell-menu
       directly — lift them onto the two-phase spring automatically,
       but never while a close is mid-travel */
    new MutationObserver(function () {
      if (closeT === null &&
          document.body.classList.contains('labshell-menu') &&
          !document.body.classList.contains('labshell-open'))
        setTimeout(function () {
          if (closeT === null &&
              document.body.classList.contains('labshell-menu'))
            document.body.classList.add('labshell-open');
        }, 20);
    }).observe(document.body, { attributes: true, attributeFilter: ['class'] });
    veil.addEventListener('click', close);
    done.addEventListener('click', close);
    links.querySelectorAll('button').forEach(function (b) {
      b.addEventListener('click', function () { close(); setTab(b.dataset.t); });
    });
    threeFingerHold(open);   /* primary */
    tripleTapHold(open);     /* pointer/desktop fallback */
    /* hub Settings button lands here with #labmenu: open the sheet on arrival */
    if (location.hash === '#labmenu') {
      history.replaceState(null, '', location.pathname);
      setTimeout(open, 350);
    }
  }

  if (document.readyState === 'loading') addEventListener('DOMContentLoaded', boot);
  else boot();
})();
