# Layout and component styles. Colors and fonts come from the variables in
# R/app_theme.R, which tools/build_theme.R generates from _brand.yml.
app_css <- function() {
  "
html, body { font-family: var(--font-body); color: var(--ink); background: var(--paper); }
h1, h2, h3, h4 {
  font-family: var(--font-display); font-weight: var(--headings-weight);
  line-height: var(--headings-line-height); color: var(--ink);
}
a { color: var(--primary); text-decoration-thickness: 1px; text-underline-offset: 0.15em; }
a:hover { color: var(--primary-deep); }
:focus-visible { outline: 2px solid var(--primary); outline-offset: 2px; }

/* Header band with the layered radial gradient */
.bslib-page-sidebar > .navbar {
  position: relative; overflow: hidden; background: var(--paper);
  border-bottom: 1px solid var(--hairline); padding: 1.1rem 1.5rem; min-height: 0;
}
.bslib-page-sidebar > .navbar > .container-fluid { padding: 0; }
.bslib-page-sidebar > .navbar .navbar-brand { margin: 0; padding: 0; white-space: normal; width: 100%; }
.header-art { position: absolute; inset: 0; z-index: 0; pointer-events: none; }
.header-art svg { display: block; width: 100%; height: 100%; }
/* Ink scrim over the art, so white text keeps a contrast of at least 4.5:1 on
   the lightest gradient color (Cerulean) */
.header-art::after { content: ''; position: absolute; inset: 0; background: rgba(33, 37, 41, 0.3); }
.app-title {
  position: relative; z-index: 1; display: flex; flex-wrap: wrap; align-items: baseline;
  justify-content: space-between; gap: 0.25rem 2rem; line-height: 1.2; color: #ffffff;
}
.app-title-text { display: flex; flex-direction: column; gap: 0.2rem; }
.app-title-main { font-size: 1.5rem; font-weight: 600; letter-spacing: -0.01em; }
.app-title-sub { font-size: 0.9rem; color: #ffffff; }
.app-title-meta { font-size: 0.8rem; color: #ffffff; max-width: 24rem; text-align: right; }
@media (max-width: 767.98px) { .app-title-meta { display: none; } }

/* Sidebar inputs */
.bslib-sidebar-layout > .sidebar { background: var(--paper); border-color: var(--hairline); }
.sidebar-heading { margin-bottom: 0.25rem; }
.sidebar-heading h2 { font-size: 1.1rem; margin: 0 0 0.25rem; }
.sidebar-actions { display: flex; gap: 1rem; font-size: 0.85rem; white-space: nowrap; }
fieldset.input-block { border: 0; padding: 0; margin: 0.6rem 0 0; min-width: 0; }
fieldset.input-block legend {
  font-size: 0.72rem; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase;
  color: var(--ink-muted); margin-bottom: 0.6rem; border-bottom: 1px solid var(--hairline);
  padding-bottom: 0.3rem; width: 100%;
}
.field { margin-bottom: 0.9rem; }
.field .shiny-input-container { width: 100%; margin-bottom: 0; }
.field .control-label { font-size: 0.875rem; font-weight: 600; margin-bottom: 0.3rem; color: var(--ink); }
.help-button {
  display: inline-flex; align-items: center; justify-content: center; flex: none;
  vertical-align: text-bottom; margin-left: 0.35rem;
  width: 1.05rem; height: 1.05rem; padding: 0; border-radius: 50%;
  border: 1px solid var(--ink-muted); background: transparent; color: var(--ink-muted);
  font: italic 700 0.72rem Georgia, 'Times New Roman', serif; line-height: 1; cursor: pointer;
}
.help-button:hover, .help-button:focus-visible { border-color: var(--primary); color: var(--primary); }
.popover {
  font-family: var(--font-body); font-size: 0.85rem; max-width: 320px;
  border: 1px solid var(--hairline); border-radius: 4px; background: var(--surface);
  box-shadow: 0 4px 14px rgba(33, 37, 41, 0.08);
}
.popover-header {
  font-size: 0.9rem; font-weight: 600;
  background: var(--surface-muted); border-bottom: 1px solid var(--hairline);
}
.form-control {
  background: var(--surface); border: 1px solid var(--hairline); border-radius: 3px;
  color: var(--ink); font-variant-numeric: tabular-nums;
}
.form-control:focus {
  border-color: var(--primary); box-shadow: 0 0 0 0.2rem rgba(var(--bs-primary-rgb), 0.15); background: var(--surface);
}
.field-row { display: flex; gap: 0.5rem; align-items: flex-end; }
.field-row > .shiny-input-container { flex: 1 1 auto; min-width: 5.5rem; }
.field-row .unit-switch { flex: 0 0 auto; }
.field-row .unit-switch .shiny-input-container { width: auto; }
.field-feedback .feedback { font-size: 0.8rem; line-height: 1.35; margin-top: 0.3rem; }
.feedback.error { color: var(--error-ink); }
.feedback.warning { color: var(--warning-ink); }
.feedback.note { color: var(--ink-secondary); }

/* Segmented controls built on Shiny radio buttons */
.segmented .shiny-options-group {
  display: flex; flex-wrap: nowrap !important; gap: 0 !important;
  border: 1px solid var(--ink-muted); border-radius: 3px;
  overflow: hidden; background: var(--surface);
}
.segmented .shiny-options-group > label.radio-inline {
  flex: 1 1 0; min-width: 0; position: relative; margin: 0 !important; padding: 0 !important;
  border-left: 1px solid var(--ink-muted);
}
.segmented .shiny-options-group > label.radio-inline:first-child { border-left: 0; }
.segmented .control-label:has(.visually-hidden) { margin: 0; }
.segmented .radio-inline input { position: absolute; opacity: 0; pointer-events: none; }
.segmented .radio-inline span {
  display: block; padding: 0.42rem 0.4rem; text-align: center; font-size: 0.875rem;
  cursor: pointer; user-select: none; white-space: nowrap; color: var(--ink);
}
.segmented .radio-inline:hover span { background: rgba(var(--bs-primary-rgb), 0.08); }
.segmented .radio-inline:has(input:checked) span {
  background: var(--primary); color: #ffffff; font-weight: 600;
}
.segmented .radio-inline:has(input:focus-visible) {
  outline: 2px solid var(--primary); outline-offset: -2px; z-index: 1;
}
.unit-switch .shiny-options-group > label.radio-inline { flex: 0 0 auto; }
.unit-switch .radio-inline span { padding-left: 0.45rem; padding-right: 0.45rem; font-size: 0.82rem; }
.scale-switch .shiny-input-container { margin-bottom: 0; width: auto; }
.scale-switch .shiny-options-group > label.radio-inline { flex: 0 0 auto; }
.scale-switch .radio-inline span { font-size: 0.8rem; padding: 0.3rem 0.6rem; }

/* On phones, show the inputs before the results. */
@media (max-width: 575.98px) {
  .bslib-page-sidebar .bslib-sidebar-layout[data-collapsible-mobile='false'] {
    display: flex !important; flex-direction: column; height: auto !important;
  }
  .bslib-page-sidebar .bslib-sidebar-layout[data-collapsible-mobile='false'] > .main {
    flex: none; overflow: visible !important;
  }
  .bslib-page-sidebar .bslib-sidebar-layout[data-collapsible-mobile='false'] > .sidebar {
    order: -1; flex: none; max-height: none !important; overflow: visible !important;
    border-bottom: 1px solid var(--hairline);
  }
  .value-boxes { grid-template-columns: 1fr !important; }
  .bslib-page-sidebar .bslib-sidebar-layout[data-collapsible-mobile='false'] > .sidebar > .sidebar-content {
    max-height: none !important; overflow: visible !important;
  }
}

/* Buttons */
.btn { border-radius: 3px; font-weight: 500; }
.btn-outline-secondary { color: var(--ink); border-color: var(--ink-muted); background: var(--surface); }
.btn-outline-secondary:hover, .btn-outline-secondary:focus-visible {
  color: #ffffff; background: var(--ink); border-color: var(--ink);
}
.btn-outline-primary { color: var(--primary); border-color: var(--primary); background: var(--surface); }
.btn-outline-primary:hover, .btn-outline-primary:focus-visible {
  color: #ffffff; background: var(--primary); border-color: var(--primary);
}

/* Cards, value boxes, accordions */
.card {
  border: 1px solid var(--hairline); border-radius: 4px; box-shadow: none !important;
  background: var(--surface);
}
.card-header {
  font-size: 1rem; font-weight: 600;
  background: transparent; border-bottom: 1px solid var(--hairline); padding: 0.75rem 1.1rem;
}
.empty-state h2 { font-size: 1.2rem; }
.empty-state p { color: var(--ink-secondary); max-width: 46rem; }
.input-progress p { margin-bottom: 0.35rem; }
.results-header {
  display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center;
  gap: 0.5rem 1rem; margin-bottom: 0.75rem;
}
.comparison-note { color: var(--ink-secondary); font-size: 0.9rem; margin: 0; }
.value-boxes { margin-bottom: 1rem; grid-template-columns: 1fr !important; row-gap: 0.75rem; }
@media (min-width: 640px) {
  .value-boxes { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; }
}
/* From 1140px: the 2 risks share the first row, the 3 treatment effects the second. */
@media (min-width: 1140px) {
  .value-boxes { grid-template-columns: repeat(6, minmax(0, 1fr)) !important; }
  .value-boxes > * { grid-column: span 2; }
  .value-boxes > :nth-child(-n + 2) { grid-column: span 3; }
}
.bslib-value-box {
  border: 0 !important; border-top: 2px solid var(--ink) !important; border-radius: 0 !important;
  background: transparent !important; box-shadow: none !important;
}
.bslib-value-box > .card-body { padding: 0; }
.bslib-value-box .value-box-area { padding: 0.6rem 0.2rem 0.5rem; justify-content: flex-start; }
.bslib-value-box .value-box-title { font-size: 0.85rem; color: var(--ink-secondary); margin-bottom: 0.35rem; }
.bslib-value-box .value-box-value {
  font-size: 2.1rem; font-weight: 600; line-height: 1.05;
  margin-bottom: 0.3rem; color: var(--ink); font-variant-numeric: tabular-nums;
}
.bslib-value-box .value-unit {
  font-size: 0.95rem; font-weight: 500; color: var(--ink-secondary); margin-left: 0.3rem;
}
.bslib-value-box .value-box-detail { font-size: 0.85rem; color: var(--ink-secondary); margin: 0; }
.result-notes {
  border-left: 3px solid var(--warning-rule); background: var(--warning-wash);
  border-radius: 3px; padding: 0.75rem 1rem; margin-bottom: 1rem; font-size: 0.875rem;
}
.result-notes ul { margin: 0.35rem 0 0; padding-left: 1.1rem; }
.chart-header {
  display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 0.5rem;
}
/* The readout keeps a fixed height. Its text changes length as the pointer moves
   over the chart; if the height followed the text, the page would shift the
   chart under the pointer and the readout would flicker between states.
   The longest text (about 100 characters) needs 2 lines when the card is at
   least 400px wide, 3 lines down to 270px, and 4 below that. */
/* The effect plot is inline SVG drawn at the output's width; it scales with
   the card, and the pointer reads values from it (app_js()). */
.effect-plot { cursor: crosshair; touch-action: manipulation; }
.effect-plot svg { display: block; width: 100%; height: auto; }
.readout-frame { container-type: inline-size; margin: 0.25rem 0 0.35rem; }
#effect_readout { display: block; height: 5.3rem; overflow: hidden; }
@container (min-width: 270px) { #effect_readout { height: 4rem; } }
@container (min-width: 400px) { #effect_readout { height: 2.7rem; } }
#effect_readout.recalculating { opacity: 1; }
.effect-readout { font-size: 0.875rem; line-height: 1.5; margin: 0; }
.chart-caption, .table-note { font-size: 0.8rem; color: var(--ink-muted); margin-bottom: 0; }
.accordion { --bs-accordion-bg: transparent; --bs-accordion-border-color: var(--hairline); }
.accordion-item {
  border: 0; border-top: 1px solid var(--hairline); border-radius: 0 !important; background: transparent;
}
.accordion-item:last-child { border-bottom: 1px solid var(--hairline); }
.accordion-button {
  font-size: 1rem; font-weight: 600; color: var(--ink);
  background: transparent; padding: 0.85rem 0.25rem; box-shadow: none !important;
}
.accordion-button:not(.collapsed) { color: var(--ink); background: transparent; }
.accordion-body { padding: 0.25rem 0.25rem 1.1rem; }

/* Icon array */
.icon-summary { font-size: 0.9rem; }
.icon-array {
  display: grid; grid-template-columns: repeat(10, 1fr); gap: 4px;
  max-width: 250px; margin: 0.25rem 0 1rem;
}
.icon-array .icon { aspect-ratio: 1; border-radius: 50%; }
.icon.alive, .swatch.alive { background: var(--series-1); }
.icon.additional, .swatch.additional { background: var(--series-2); }
.icon.died, .swatch.died { background: var(--neutral-mark); }
.icon-legend { list-style: none; padding: 0; margin: 0; font-size: 0.875rem; }
.icon-legend li { display: flex; gap: 0.5rem; align-items: baseline; margin-bottom: 0.4rem; }
.icon-legend .swatch { flex: none; width: 0.7rem; height: 0.7rem; border-radius: 50%; transform: translateY(1px); }
.icon-legend .count { font-weight: 650; }
.icon-legend .legend-extra { color: var(--ink-secondary); }

/* Tables and about */
.data-table {
  font-size: 0.85rem; margin-bottom: 0.4rem; --bs-table-bg: transparent; --bs-table-border-color: var(--hairline);
}
.data-table th, .data-table td { font-variant-numeric: tabular-nums; }
.data-table thead th { color: var(--ink-secondary); font-weight: 600; border-bottom: 1px solid var(--ink-muted); }
.data-table tbody th { font-weight: 500; }
.about { margin-top: 1rem; }
.about h3 { font-size: 0.95rem; font-weight: 600; margin: 0.9rem 0 0.3rem; }
.about h3:first-child { margin-top: 0; }
.about p, .about li { font-size: 0.9rem; max-width: 52rem; }
.app-footer {
  display: flex; flex-wrap: wrap; gap: 0.35rem 1.25rem; margin-top: 1.25rem; padding-top: 0.75rem;
  border-top: 1px solid var(--hairline); font-size: 0.78rem; color: var(--ink-muted);
}

/* Printing from the browser: results only, without controls. */
@media print {
  body { background: #ffffff; }
  .header-art { display: none !important; }
  .bslib-page-sidebar > .navbar { background: #ffffff; padding: 0 0 0.6rem; }
  .app-title, .app-title-sub, .app-title-meta { color: var(--ink); }
  .bslib-page-sidebar .bslib-sidebar-layout { display: block !important; height: auto !important; }
  .bslib-sidebar-layout > .sidebar, .bslib-sidebar-layout > .collapse-toggle,
  .sidebar-actions, .scale-switch, .empty-state, .about, .readout-frame { display: none !important; }
  .bslib-sidebar-layout > .main { overflow: visible !important; padding: 0 !important; }
  .value-boxes { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; }
  .accordion-button::after { display: none !important; }
  .card, .bslib-value-box, .accordion-item { break-inside: avoid; box-shadow: none !important; }
  .icon-array .icon { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
  .icon-legend .swatch { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
  a[href]::after { content: none !important; }
}
"
}

# Sends the page address to the server (Shinylive runs the app in an iframe,
# so the server cannot see the page's query string), reports hover and tap on
# the effect plot, closes help notes on an outside click, and picks the header
# gradient at random.
app_js <- function() {
  "
document.addEventListener('DOMContentLoaded', function () {
  var art = document.querySelector('.header-art');
  var source = document.getElementById('header-gradients');
  if (!art || !source) { return; }
  var gradients = JSON.parse(source.textContent);
  art.innerHTML = gradients[Math.floor(Math.random() * gradients.length)];
});
$(document).on('shiny:connected', function () {
  var location = window.location;
  try { location = window.top.location; } catch (error) {}
  Shiny.setInputValue(
    'page_location',
    { search: location.search },
    { priority: 'event' }
  );
});
// Hover and tap on the effect plot report the baseline risk under the pointer,
// as plotOutput() did: { x } in percent, or null outside the plotting region.
(function () {
  function riskAt(plot, event) {
    var rect = plot.getBoundingClientRect();
    var user = plot.dataset.xUser.split(' ').map(Number);
    var ndc = plot.dataset.xNdc.split(' ').map(Number);
    var position = ((event.clientX - rect.left) / rect.width - ndc[0]) / (ndc[1] - ndc[0]);
    if (!(position >= 0 && position <= 1)) { return null; }
    return { x: user[0] + position * (user[1] - user[0]) };
  }
  function plotOf(target) {
    return target && target.closest ? target.closest('.effect-plot') : null;
  }
  var lastHover = 0;
  document.addEventListener('mousemove', function (event) {
    var plot = plotOf(event.target);
    if (!plot || Date.now() - lastHover < 80) { return; }
    lastHover = Date.now();
    Shiny.setInputValue('effect_hover', riskAt(plot, event));
  });
  document.addEventListener('mouseout', function (event) {
    if (plotOf(event.target) && !plotOf(event.relatedTarget)) {
      Shiny.setInputValue('effect_hover', null);
    }
  });
  document.addEventListener('click', function (event) {
    var plot = plotOf(event.target);
    var point = plot ? riskAt(plot, event) : null;
    if (point) { Shiny.setInputValue('effect_click', point, { priority: 'event' }); }
  });
})();
// Close open help notes when the user clicks or taps outside them.
document.addEventListener('click', function (event) {
  document.querySelectorAll('bslib-popover').forEach(function (popover) {
    if (!popover.visible || !popover.bsPopover) { return; }
    var tip = popover.bsPopover.tip;
    var inside = popover.triggerElement.contains(event.target) || (tip && tip.contains(event.target));
    if (!inside) { popover.bsPopover.hide(); }
  });
});
"
}
