const REPO = "loSpaccaBit/clipboard-archivio";
const DIRECT_DMG =
  "https://github.com/loSpaccaBit/clipboard-archivio/releases/latest/download/Appunti-Archivio.dmg";

function applyDownloadLinks(url, label) {
  for (const id of ["download-btn", "download-app"]) {
    const el = document.getElementById(id);
    if (!el) continue;
    el.href = url;
    el.setAttribute("download", "Appunti-Archivio.dmg");
    if (label) el.textContent = label;
  }
}

async function loadLatestRelease() {
  const meta = document.getElementById("release-meta");
  applyDownloadLinks(DIRECT_DMG, "Scarica per macOS");

  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`);
    if (!res.ok) throw new Error("no release");

    const data = await res.json();
    const tag = data.tag_name || "latest";
    const assets = data.assets || [];
    const dmg =
      assets.find((a) => a.name === "Appunti-Archivio.dmg") ||
      assets.find((a) => a.name.endsWith(".dmg"));

    meta.textContent = `Ultima versione: ${tag}${data.published_at ? " · " + new Date(data.published_at).toLocaleDateString("it-IT") : ""}`;

    if (dmg) {
      applyDownloadLinks(dmg.browser_download_url, `Scarica ${tag}`);
    }
  } catch {
    meta.textContent =
      "Download diretto disponibile — se la versione non compare, usa il pulsante qui sopra.";
    applyDownloadLinks(DIRECT_DMG, "Scarica per macOS");
  }
}

loadLatestRelease();