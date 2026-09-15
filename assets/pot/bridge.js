// Bridge between Dart and the JavaScript YouTube needs us to run.
//
// Lives on the https://www.youtube.com origin, so fetching the player script
// and talking to the BotGuard endpoints is same-origin. InnerTube calls stay
// in Dart — music.youtube.com would be cross-origin from here, and Dart has no
// CORS to fight.
(function () {
  var preprocessedPlayer = null;
  var signatureTimestamp = null;

  function fail(e) {
    return JSON.stringify({ ok: false, error: String((e && e.message) || e) });
  }

  // Dart hands over the already-downloaded player script; the solver turns it
  // into a much smaller preprocessed form that every later call reuses.
  window.__youfreePreparePlayer = async function (playerJs) {
    try {
      if (preprocessedPlayer) {
        return JSON.stringify({
          ok: true,
          signatureTimestamp: signatureTimestamp,
          cached: true,
        });
      }

      var result = window.jsc({
        type: 'player',
        player: playerJs,
        requests: [],
        output_preprocessed: true,
      });
      if (!result || !result.preprocessed_player) {
        throw new Error('solver nao devolveu o player pre-processado');
      }
      preprocessedPlayer = result.preprocessed_player;

      signatureTimestamp =
        preprocessedPlayer.signature_timestamp ||
        Number((playerJs.match(/signatureTimestamp[:=](\d+)/) || [])[1]) ||
        null;
      if (!signatureTimestamp) throw new Error('sem signatureTimestamp');

      return JSON.stringify({
        ok: true,
        signatureTimestamp: signatureTimestamp,
        cached: false,
      });
    } catch (e) {
      return fail(e);
    }
  };

  // type is 'sig' (signature cipher) or 'n' (throttling parameter).
  window.__youfreeSolve = async function (type, challenge) {
    try {
      if (!preprocessedPlayer) throw new Error('player nao preparado');
      var result = window.jsc({
        type: 'preprocessed',
        preprocessed_player: preprocessedPlayer,
        requests: [{ type: type, challenges: [challenge] }],
      });
      var response = result && result.responses && result.responses[0];
      if (!response || response.type === 'error') {
        throw new Error((response && response.error) || 'solver falhou');
      }
      var data = response.data;
      var solved = data && (data.results ? data.results[0] : data[challenge]);
      if (!solved) throw new Error('solver devolveu vazio');
      return JSON.stringify({ ok: true, value: solved });
    } catch (e) {
      return fail(e);
    }
  };

  window.__youfreeBridgeReady = true;
})();
