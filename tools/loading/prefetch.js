// Downloads the files R needs at startup while reporting progress, so the
// loading screen can show a real progress bar. Shinylive then starts R, which
// reads these files from the browser cache. `startupFiles` ([path, bytes]
// pairs) is inserted by tools/build_shinylive.R. A failed download is skipped;
// Shinylive retries it and reports its own error.
//
// Shinylive needs a service worker. On a first visit it installs one and
// reloads the page, so the downloads wait until the worker controls the page;
// otherwise the reload would cut them off and they would start again.
window.mhspcPrefetch = (function () {
  var startupFiles = __STARTUP_FILES__;
  var loading = document.getElementById("loading");
  var progress = document.getElementById("loading-progress");
  var fill = document.getElementById("loading-fill");
  var text = document.getElementById("loading-text");
  var total = startupFiles.reduce(function (sum, file) { return sum + file[1]; }, 0);
  var received = 0;

  function show(percent) {
    fill.style.width = percent + "%";
    progress.setAttribute("aria-valuenow", String(percent));
    text.textContent = "Downloading, " + percent + "%";
  }

  // A failed download is retried once, as requests occasionally fail while the
  // service worker updates.
  function download(file) {
    var counted = 0;
    function attempt(retries) {
      received -= counted;
      counted = 0;
      return fetch(file[0])
        .then(function (response) {
          if (!response.ok || !response.body) {
            throw new Error("HTTP " + response.status);
          }
          var reader = response.body.getReader();
          function read() {
            return reader.read().then(function (chunk) {
              if (chunk.done) {
                return;
              }
              counted += chunk.value.length;
              received += chunk.value.length;
              show(Math.min(99, Math.floor((100 * received) / total)));
              return read();
            });
          }
          return read();
        })
        .catch(function (error) {
          if (retries > 0) {
            return new Promise(function (resolve) { setTimeout(resolve, 500); }).then(function () {
              return attempt(retries - 1);
            });
          }
          console.warn("Could not prefetch " + file[0] + ": " + error);
        });
    }
    return attempt(1).then(function () {
      // Count the expected size of a file that could not be measured.
      received += Math.max(0, file[1] - counted);
      show(Math.min(99, Math.floor((100 * received) / total)));
    });
  }

  function downloadAll() {
    setTimeout(function () { loading.classList.add("is-slow"); }, 90000);
    show(0);
    return Promise.all(startupFiles.map(download)).then(function () {
      show(100);
      loading.classList.add("is-starting");
      progress.removeAttribute("aria-valuenow");
      text.textContent = "Starting R";
    });
  }

  if (!("serviceWorker" in navigator)) {
    progress.hidden = true;
    text.textContent = "This browser does not allow the calculator to run. Open it in another browser or on a computer.";
    return new Promise(function () {});
  }
  if (navigator.serviceWorker.controller) {
    return downloadAll();
  }
  // Same test as Shinylive's loader: once the worker is ready, Shinylive reloads
  // the page if the worker does not control it, and otherwise carries on.
  return navigator.serviceWorker.ready.then(function () {
    if (navigator.serviceWorker.controller) {
      return downloadAll();
    }
    return new Promise(function () {});
  });
})();
