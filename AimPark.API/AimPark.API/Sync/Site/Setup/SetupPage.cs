namespace AimPark.API.Sync.Site.Setup
{
    /// <summary>
    /// The setup page's HTML. Self-contained (no fonts or scripts from the
    /// internet), because the PC may be offline when someone first opens it.
    /// </summary>
    internal static class SetupPage
    {
        public const string Html = """
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AimPark Setup</title>
<style>
  :root {
    --bg: #f4f5f7; --card: #ffffff; --text: #1b1f24; --muted: #5d6673;
    --line: #d9dde3; --accent: #1f6feb; --ok: #1a7f37; --bad: #cf222e;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0f1216; --card: #171b21; --text: #e6e8eb; --muted: #9aa3ad;
      --line: #2c323a; --accent: #4c8dff; --ok: #3fb950; --bad: #ff6b6b;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--text);
    font: 15px/1.5 "Segoe UI", system-ui, sans-serif;
  }
  main { max-width: 620px; margin: 40px auto; padding: 0 16px; }
  h1 { font-size: 24px; margin: 0 0 4px; }
  .lead { color: var(--muted); margin: 0 0 24px; }
  section {
    background: var(--card); border: 1px solid var(--line); border-radius: 10px;
    padding: 20px; margin-bottom: 16px;
  }
  h2 { font-size: 16px; margin: 0 0 4px; display: flex; gap: 8px; align-items: center; }
  .step {
    width: 24px; height: 24px; border-radius: 50%; background: var(--accent); color: #fff;
    display: inline-grid; place-items: center; font-size: 13px; flex: none;
  }
  .hint { color: var(--muted); margin: 0 0 12px; font-size: 14px; }
  label { display: block; font-weight: 600; font-size: 14px; margin: 12px 0 4px; }
  input {
    width: 100%; padding: 9px 11px; border: 1px solid var(--line); border-radius: 6px;
    background: var(--bg); color: var(--text); font: inherit;
  }
  input:focus { outline: 2px solid var(--accent); outline-offset: -1px; }
  details { margin-top: 12px; }
  summary { cursor: pointer; color: var(--muted); font-size: 14px; }
  .row { display: grid; grid-template-columns: 1fr 1fr; gap: 0 12px; }
  @media (max-width: 480px) { .row { grid-template-columns: 1fr; } }
  .result { margin-top: 12px; font-size: 14px; min-height: 1em; }
  .result.ok { color: var(--ok); }
  .result.bad { color: var(--bad); }
  button {
    width: 100%; padding: 12px; border: 0; border-radius: 8px; background: var(--accent);
    color: #fff; font: 600 16px/1 inherit; font-family: inherit; cursor: pointer;
  }
  button:disabled { opacity: .6; cursor: progress; }
  #done { text-align: center; }
  #done[hidden] { display: none; }
</style>
</head>
<body>
<main>
  <form id="form">
    <h1>Set up this guard post</h1>
    <p class="lead">Three things, once. Each one is checked before anything is saved.</p>

    <section>
      <h2><span class="step">1</span> Local database</h2>
      <p class="hint">The password chosen when PostgreSQL was installed on this PC. The database is created for you.</p>
      <p class="hint" id="dbPresetNote" style="color: var(--ok)" hidden>✓ Already set up by the installer. Nothing to do here.</p>
      <div id="dbPasswordBox">
        <label for="dbPassword">PostgreSQL password</label>
        <input id="dbPassword" type="password" autocomplete="off" required>
      </div>
      <details>
        <summary>Advanced</summary>
        <div class="row">
          <div><label for="dbHost">Host</label><input id="dbHost"></div>
          <div><label for="dbPort">Port</label><input id="dbPort" type="number"></div>
        </div>
        <div class="row">
          <div><label for="dbName">Database</label><input id="dbName"></div>
          <div><label for="dbUser">User</label><input id="dbUser"></div>
        </div>
      </details>
      <div class="result" id="r-Database"></div>
    </section>

    <section>
      <h2><span class="step">2</span> Site key</h2>
      <p class="hint">From the online admin panel: <b>Gate Devices → Register a device</b>, type <b>Site Server</b>. It is shown only once.</p>
      <label for="cloudApiKey">Site Server key</label>
      <input id="cloudApiKey" autocomplete="off" spellcheck="false" required>
      <details>
        <summary>Advanced</summary>
        <label for="cloudBaseUrl">Cloud address</label>
        <input id="cloudBaseUrl" spellcheck="false">
      </details>
      <div class="result" id="r-Site key"></div>
    </section>

    <section>
      <h2><span class="step">3</span> Sign-in key</h2>
      <p class="hint">The value of <b>Jwt__Key</b> in Render → Environment. It lets staff accounts from the cloud sign in here.</p>
      <label for="jwtKey">Sign-in key</label>
      <input id="jwtKey" type="password" autocomplete="off" spellcheck="false" required>
      <details>
        <summary>Advanced</summary>
        <div class="row">
          <div><label for="jwtIssuer">Issuer</label><input id="jwtIssuer"></div>
          <div><label for="jwtAudience">Audience</label><input id="jwtAudience"></div>
        </div>
      </details>
      <div class="result" id="r-Sign-in key"></div>
    </section>

    <button id="save" type="submit">Check and save</button>
  </form>

  <section id="done" hidden>
    <h2 style="justify-content:center">✅ Setup saved</h2>
    <p class="hint" id="doneText">Starting AimPark…</p>
  </section>
</main>
<script>
  const $ = id => document.getElementById(id);
  const fields = ["dbHost", "dbPort", "dbName", "dbUser", "dbPassword",
                  "cloudBaseUrl", "cloudApiKey", "jwtKey", "jwtIssuer", "jwtAudience"];

  fetch("/setup/api/defaults").then(r => r.json()).then(d => {
    for (const k of Object.keys(d)) if ($(k) && !$(k).value) $(k).value = d[k];
    if (d.dbPreset) {
      $("dbPasswordBox").hidden = true;
      $("dbPassword").required = false;
      $("dbPresetNote").hidden = false;
    }
  });

  $("form").addEventListener("submit", async e => {
    e.preventDefault();
    const body = {};
    for (const f of fields) body[f] = f === "dbPort" ? Number($(f).value) : $(f).value;

    $("save").disabled = true;
    $("save").textContent = "Checking… (the cloud can take a minute to wake up)";
    for (const el of document.querySelectorAll(".result")) { el.textContent = ""; el.className = "result"; }

    try {
      const res = await fetch("/setup/api/save", {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body)
      });
      const data = await res.json();
      for (const c of data.checks) {
        const el = $("r-" + c.name);
        if (!el) continue;
        el.textContent = (c.ok ? "✓ " : "✗ ") + c.message;
        el.className = "result " + (c.ok ? "ok" : "bad");
      }
      if (data.ok) return finished(data.restarting);
    } catch {
      alert("The server stopped answering. Is it still running?");
    }
    $("save").disabled = false;
    $("save").textContent = "Check and save";
  });

  async function finished(restarting) {
    $("form").hidden = true;
    $("done").hidden = false;
    if (!restarting) {
      $("doneText").textContent = "Start the server again, then open http://localhost:5041/ to sign in.";
      return;
    }
    // Wait for the real server to come back, then open the guard panel.
    for (;;) {
      await new Promise(r => setTimeout(r, 2000));
      try {
        const s = await (await fetch("/api/site/status", { cache: "no-store" })).json();
        if (s.mode === "Site") { location.href = "/"; return; }
      } catch { /* still restarting */ }
    }
  }
</script>
</body>
</html>
""";
    }
}
