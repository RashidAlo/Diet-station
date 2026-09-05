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
  .lab-tabs .seg { pointer-events: auto; display: inline-flex; gap: 2px; padding: 4px;\
    border-radius: 999px; background: rgba(22,22,26,.86);\
    -webkit-backdrop-filter: blur(14px) saturate(160%); backdrop-filter: blur(14px) saturate(160%);\
    box-shadow: 0 10px 30px -12px rgba(0,0,0,.55), inset 0 1px 0 rgba(255,255,255,.07),\
      0 0 0 1px rgba(255,255,255,.06); }\
  .lab-tabs button { border: none; cursor: pointer; padding: 9px 18px; border-radius: 999px;\
    background: transparent; color: rgba(255,255,255,.6);\
    font: 600 12.5px/16px 'Urbane Rounded', -apple-system, sans-serif;\
    transition: background .18s ease, color .18s ease; }\
  .lab-tabs button:hover { color: rgba(255,255,255,.85); }\
  .lab-tabs button.on { background: rgba(255,255,255,.14); color: #fff; }\
\
  .lab-tabbar { position: fixed; left: 0; right: 0; bottom: 0; z-index: 90;\
    display: none; padding: 8px 10px calc(8px + env(safe-area-inset-bottom, 0px));\
    background: rgba(15,15,18,.88);\
    -webkit-backdrop-filter: blur(18px) saturate(160%); backdrop-filter: blur(18px) saturate(160%);\
    border-top: 0.5px solid rgba(255,255,255,.1);\
    transform: translateY(0); transition: transform .32s cubic-bezier(.3,.8,.3,1); }\
  body.lab-mobile .lab-tabbar { display: flex; }\
  .lab-tabbar.hidden { transform: translateY(110%); }\
  .lab-tabbar button { flex: 1; border: none; cursor: pointer; background: transparent;\
    display: flex; flex-direction: column; align-items: center; gap: 3px; padding: 5px 0 3px;\
    color: rgba(255,255,255,.5); font: 600 10px/12px 'Urbane Rounded', sans-serif;\
    -webkit-tap-highlight-color: transparent; }\
  .lab-tabbar button.on { color: #fff; }\
  .lab-tabbar button svg { width: 22px; height: 22px; display: block; }\
  .lab-tabbar button.on svg .a { stroke: #ff5a5f; }\
\
  .lab-chip { position: fixed; left: 12px; bottom: calc(74px + env(safe-area-inset-bottom, 0px));\
    z-index: 88; width: 42px; height: 42px; border-radius: 50%; border: none; cursor: pointer;\
    display: none; align-items: center; justify-content: center;\
    background: rgba(20,20,24,.72); color: rgba(255,255,255,.85);\
    -webkit-backdrop-filter: blur(14px) saturate(160%); backdrop-filter: blur(14px) saturate(160%);\
    box-shadow: 0 10px 26px -10px rgba(0,0,0,.5), inset 0 1px 0 rgba(255,255,255,.1);\
    -webkit-tap-highlight-color: transparent;\
    opacity: 0; transform: scale(.6); transition: opacity .25s ease, transform .25s cubic-bezier(.3,.8,.3,1); }\
  .lab-chip.show { opacity: 1; transform: scale(1); }\
  body.lab-mobile .lab-chip { display: flex; }\
  .lab-chip svg { width: 20px; height: 20px; }\
\
  .lab-view { position: fixed; inset: 0; z-index: 70; display: none;\
    background: #0f0f12; overflow-y: auto; overflow-x: hidden;\
    touch-action: pan-y; -webkit-overflow-scrolling: touch; overscroll-behavior: contain; }\
  .lab-view.on { display: block; }\
  .lab-view .lab-col { max-width: 880px; margin: 0 auto; padding: 84px 26px 80px; }\
  body.lab-mobile .lab-view .lab-col { padding: 30px 18px calc(96px + env(safe-area-inset-bottom, 0px)); }\
\
  .lab-kicker { font: 600 10px/14px 'Urbane Rounded', sans-serif; letter-spacing: 2px;\
    text-transform: uppercase; color: #ff5a5f; margin-bottom: 10px; }\
  .lab-view h1 { font: 600 26px/32px 'Urbane Rounded', sans-serif; color: #fff;\
    letter-spacing: -.01em; margin: 0 0 10px; }\
  .lab-meta { display: flex; gap: 8px; flex-wrap: wrap; margin: 0 0 18px; }\
  .lab-meta span { font: 500 10.5px/1 'Urbane Rounded', sans-serif; letter-spacing: .07em;\
    text-transform: uppercase; padding: 6px 10px 5px; border-radius: 999px;\
    background: rgba(255,255,255,.07); color: rgba(255,255,255,.6); }\
  .lab-meta span.hot { background: rgba(237,28,36,.16); color: #ff5a5f; }\
  .lab-desc { font: 400 14px/22px 'Proxima Nova', sans-serif; color: rgba(255,255,255,.55);\
    max-width: 64ch; margin: 0 0 26px; }\
\
  .lab-h3 { font: 600 11px/14px 'Urbane Rounded', sans-serif; letter-spacing: 1.8px;\
    text-transform: uppercase; color: rgba(255,255,255,.8); margin: 34px 0 6px; }\
  .lab-note { font: 400 12.5px/18px 'Proxima Nova', sans-serif; color: rgba(255,255,255,.4);\
    max-width: 64ch; margin: 0 0 14px; }\
\
  .lab-diagram-wrap { position: relative; margin-top: 18px; border-radius: 18px;\
    background: #131318; box-shadow: inset 0 0 0 1px rgba(255,255,255,.06);\
    overflow: auto; -webkit-overflow-scrolling: touch; touch-action: pan-x pan-y; }\
  .lab-diagram-wrap svg { display: block; margin: 0 auto; }\
  .lab-zoom { position: absolute; top: 12px; right: 12px; z-index: 2; display: inline-flex;\
    gap: 2px; padding: 3px; border-radius: 999px; background: rgba(22,22,26,.9);\
    box-shadow: 0 0 0 1px rgba(255,255,255,.08); }\
  .lab-zoom button { border: none; cursor: pointer; padding: 6px 12px; border-radius: 999px;\
    background: transparent; color: rgba(255,255,255,.55);\
    font: 600 10.5px/14px 'Urbane Rounded', sans-serif; }\
  .lab-zoom button.on { background: rgba(255,255,255,.14); color: #fff; }\
  .lab-legend { display: flex; gap: 16px; flex-wrap: wrap; margin: 14px 2px 0; }\
  .lab-legend span { display: inline-flex; align-items: center; gap: 7px;\
    font: 400 11.5px/16px 'Proxima Nova', sans-serif; color: rgba(255,255,255,.45); }\
  .lab-legend i { width: 14px; height: 10px; border-radius: 3px; flex: none; }\
\
  .lab-sec { margin-top: 22px; }\
  .lab-sec h4 { font: 600 14.5px/20px 'Urbane Rounded', sans-serif; color: #fff;\
    letter-spacing: -.005em; margin: 0; }\
  .lab-sec .n { font: 400 12.5px/18px 'Proxima Nova', sans-serif; color: rgba(255,255,255,.45);\
    max-width: 66ch; margin: 4px 0 0; }\
  .lab-codewrap { position: relative; margin-top: 10px; }\
  .lab-codewrap pre { background: #1a1a20; color: #e8e8ed; border-radius: 12px;\
    box-shadow: inset 0 0 0 1px rgba(255,255,255,.06);\
    padding: 14px 16px; overflow-x: auto; -webkit-overflow-scrolling: touch; margin: 0;\
    font: 11.5px/1.6 ui-monospace, 'SF Mono', SFMono-Regular, Menlo, monospace; tab-size: 2;\
    user-select: text; -webkit-user-select: text; }\
  .lab-copy { position: absolute; top: 8px; right: 8px; cursor: pointer;\
    font: 600 10.5px/1 'Urbane Rounded', sans-serif; border: none; border-radius: 999px;\
    padding: 7px 12px; background: rgba(255,255,255,.1); color: #f5f5f7;\
    -webkit-backdrop-filter: blur(6px); backdrop-filter: blur(6px); }\
  .lab-copy:hover { background: rgba(255,255,255,.2); }\
  .lab-kithead { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }\
  .lab-kithead .lab-h3 { margin: 34px 0 6px; margin-right: auto; }\
  .lab-kithead .kitcopy { margin-top: 26px; border: none; cursor: pointer; border-radius: 999px;\
    padding: 9px 16px; background: rgba(255,255,255,.09); color: rgba(255,255,255,.85);\
    font: 600 11.5px/14px 'Urbane Rounded', sans-serif; }\
  .lab-kithead .kitcopy:hover { background: rgba(255,255,255,.16); }\
\
  .lab-kv { display: grid; grid-template-columns: 150px 1fr; gap: 8px 18px;\
    font: 400 12.5px/18px 'Proxima Nova', sans-serif; user-select: text; -webkit-user-select: text; }\
  .lab-kv dt { color: rgba(255,255,255,.4); margin: 0; }\
  .lab-kv dd { color: rgba(255,255,255,.78); margin: 0; overflow-wrap: anywhere; }\
  body.lab-mobile .lab-kv { grid-template-columns: 1fr; gap: 2px 0; }\
  body.lab-mobile .lab-kv dt { margin-top: 10px; }\
  .lab-dl { margin-top: 14px; display: flex; gap: 16px; flex-wrap: wrap; }\
  .lab-dl a { color: #ff5a5f; text-decoration: none; font: 400 13px/18px 'Proxima Nova', sans-serif;\
    border-bottom: 1px solid rgba(237,28,36,.3); }\
  .lab-dl a:hover { border-bottom-color: #ff5a5f; }\
  .lab-foot { margin-top: 44px; padding-top: 16px; border-top: 1px solid rgba(255,255,255,.07);\
    font: 400 11px/16px 'Proxima Nova', sans-serif; color: rgba(255,255,255,.3); }\
  ";

  var style = document.createElement('style');
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
      screen:   { fill: '#1b1b21', stroke: 'rgba(255,255,255,.16)', dash: '', text: '#ffffff' },
      decision: { fill: 'rgba(237,28,36,.10)', stroke: '#ff5a5f', dash: '', text: '#ffffff' },
      module:   { fill: '#17171c', stroke: 'rgba(255,255,255,.34)', dash: '5 4', text: 'rgba(255,255,255,.88)' },
      end:      { fill: '#ED1C24', stroke: 'rgba(255,255,255,.25)', dash: '', text: '#ffffff' }
    };

    var svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + W + ' ' + H +
      '" width="' + W + '" height="' + H + '" font-family="\'Urbane Rounded\',-apple-system,sans-serif">'];
    svg.push('<defs><marker id="labArr" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse">' +
      '<path d="M0.5,0.8 L7,4 L0.5,7.2" fill="none" stroke="rgba(255,255,255,.42)" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></marker></defs>');

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
      svg.push('<path d="' + d + '" fill="none" stroke="rgba(255,255,255,.28)" stroke-width="1.4"' +
        (back ? ' stroke-dasharray="3 4"' : '') + ' marker-end="url(#labArr)"/>');
      if (e[2]) {
        var lx = Math.max(40, (x1 + x2) / 2 + bow * 0.75), ly = midY;
        var tw = e[2].length * 5.6 + 12;
        svg.push('<rect x="' + (lx - tw / 2) + '" y="' + (ly - 9) + '" width="' + tw +
          '" height="17" rx="8.5" fill="#0f0f12" stroke="rgba(255,255,255,.1)"/>');
        svg.push('<text x="' + lx + '" y="' + (ly + 3.5) + '" text-anchor="middle" font-size="9.5" ' +
          'font-family="\'Proxima Nova\',sans-serif" fill="rgba(255,255,255,.55)">' + esc(e[2]) + '</text>');
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
            (n.d.kind === 'end' ? 'rgba(255,255,255,.8)' : 'rgba(255,255,255,.45)') + '">' + esc(line) + '</text>');
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
        '<span><i style="background:#1b1b21;box-shadow:inset 0 0 0 1px rgba(255,255,255,.2)"></i>Screen</span>' +
        '<span><i style="background:rgba(237,28,36,.15);box-shadow:inset 0 0 0 1px #ff5a5f"></i>Decision</span>' +
        '<span><i style="background:#17171c;box-shadow:inset 0 0 0 1px rgba(255,255,255,.4);border:0;outline:1px dashed rgba(255,255,255,.4);outline-offset:-1px"></i>Conditional module</span>' +
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

    if (f.rn && f.rn.length) {
      var head = document.createElement('div');
      head.className = 'lab-kithead';
      head.innerHTML = '<div class="lab-h3">React Native kit</div>' +
        '<button class="kitcopy">Copy full kit</button>';
      col.appendChild(head);
      var kitNote = document.createElement('p');
      kitNote.className = 'lab-note';
      kitNote.textContent = 'Everything a React Native dev needs to recreate this flow — ' +
        'stack, Figma-exact tokens, and the interaction math, ready to paste into your own workflow.';
      col.appendChild(kitNote);
      f.rn.forEach(function (s) {
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
        var md = '# ' + f.title + ' — React Native kit\n\n' + f.rn.map(function (s) {
          return '## ' + s.t + '\n\n' + s.note + (s.code ? '\n\n```\n' + s.code + '\n```' : '');
        }).join('\n\n');
        copyFeedback(e.target, md, 'Copy full kit');
      };
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
    document.body.append(tabsEl, barEl, chipEl, flowView, handView);
    syncMobileClass();
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

  if (document.readyState === 'loading') addEventListener('DOMContentLoaded', boot);
  else boot();
})();
