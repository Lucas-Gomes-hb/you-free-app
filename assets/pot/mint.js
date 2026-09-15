// Runs inside the headless WebView, on the https://www.youtube.com origin.
//
// Ports the flow the bgutil PO Token provider uses on the server: pull the
// BotGuard challenge, run its interpreter, exchange the snapshot for an
// integrity token, and mint a token bound to an identifier (visitorData).
// Same-origin here, so the /api/jnn/v1 calls need no CORS handling.
(function () {
  var BGUtils = window.BGUtils;
  var BG = BGUtils.BG;
  var REQUEST_KEY = 'O43z0dpjhgX20SCx4KAo';

  var minter = null;
  var minterExpiry = 0;

  function innertubeContext() {
    return {
      client: { clientName: 'WEB', clientVersion: '2.20260227.01.00' },
    };
  }

  async function descrambleChallenge() {
    // Network goes through Dart: the WebView page this runs in has a real
    // YouTube origin but no network of its own.
    var attestation = await window.__youfreeFetchJson(
      'https://www.youtube.com/youtubei/v1/att/get?prettyPrint=false',
      {
        method: 'POST',
        // Only JSON here: getHeaders() is shaped for the protobuf JNN
        // endpoints and its api-key makes /att/get reject the request.
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          context: innertubeContext(),
          engagementType: 'ENGAGEMENT_TYPE_UNBOUND',
        }),
      },
    );
    var challenge = attestation && attestation.bgChallenge;
    if (!challenge) throw new Error('sem bgChallenge em /att/get');

    var interpreterUrl =
      challenge.interpreterUrl
        .privateDoNotAccessOrElseTrustedResourceUrlWrappedValue;
    var interpreterJs = await window.__youfreeFetchText('https:' + interpreterUrl);
    if (!interpreterJs) throw new Error('interpretador vazio');

    return {
      program: challenge.program,
      globalName: challenge.globalName,
      interpreterJs: interpreterJs,
    };
  }

  async function buildMinter() {
    var challenge = await descrambleChallenge();

    // Defines the BotGuard VM on the global object. In a browser `window` and
    // `globalThis` are the same object; under a DOM shim they are not, so take
    // whichever one the interpreter actually wrote to.
    new Function(challenge.interpreterJs)();
    var globalObj =
      typeof window[challenge.globalName] !== 'undefined' ? window : globalThis;

    var client = await BG.BotGuardClient.create({
      program: challenge.program,
      globalName: challenge.globalName,
      globalObj: globalObj,
    });

    var webPoSignalOutput = [];
    var snapshot = await client.snapshot({ webPoSignalOutput: webPoSignalOutput });

    var parsed = await window.__youfreeFetchJson(BGUtils.buildURL('GenerateIT'), {
      method: 'POST',
      headers: BGUtils.getHeaders(),
      body: JSON.stringify([REQUEST_KEY, snapshot]),
    });
    var integrityToken = parsed[0];
    var ttlSeconds = parsed[1];
    if (!integrityToken) throw new Error('integrity token vazio');

    minterExpiry = Date.now() + (ttlSeconds || 3600) * 1000;
    minter = await BG.WebPoMinter.create(
      {
        integrityToken: integrityToken,
        estimatedTtlSecs: ttlSeconds,
        mintRefreshThreshold: parsed[2],
        websafeFallbackToken: parsed[3],
      },
      webPoSignalOutput,
    );
    return ttlSeconds;
  }

  // Called from Dart. Returns JSON so the bridge stays string-only.
  window.__youfreeMintPoToken = async function (identifier) {
    try {
      var ttl = null;
      if (!minter || Date.now() > minterExpiry - 60000) {
        ttl = await buildMinter();
      }
      var token = await minter.mintAsWebsafeString(identifier);
      return JSON.stringify({
        ok: true,
        poToken: token,
        expiresAt: minterExpiry,
        refreshed: ttl !== null,
      });
    } catch (e) {
      return JSON.stringify({ ok: false, error: String((e && e.message) || e) });
    }
  };

  window.__youfreePotReady = true;
})();
