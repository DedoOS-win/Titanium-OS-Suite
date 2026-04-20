const SCRIPTS = {
  home:   "https://raw.githubusercontent.com/DedoOS-win/Titanium-OS-Suite/main/win11_HOME.ps1",
  pro:    "https://raw.githubusercontent.com/DedoOS-win/Titanium-OS-Suite/main/win11_PRO.ps1",
  ltsc:   "https://raw.githubusercontent.com/DedoOS-win/Titanium-OS-Suite/main/win11_LTSC.ps1",
  adobe:  "https://raw.githubusercontent.com/DedoOS-win/Titanium-OS-Suite/main/win11_ADOBE.ps1",
  launch: "https://raw.githubusercontent.com/DedoOS-win/Titanium-OS-Suite/main/launch.ps1"
};

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname.replace("/", "").toLowerCase() || "launch";

    const target = SCRIPTS[path] ?? SCRIPTS["launch"];

    const upstream = await fetch(target, {
      headers: { "User-Agent": "TitaniumOS-Worker/1.0" }
    });

    if (!upstream.ok) {
      return new Response(`Script non trovato: ${path}`, { status: 404 });
    }

    const content = await upstream.text();

    return new Response(content, {
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-store"
      }
    });
  }
};
