const REPO = "loSpaccaBit/clipboard-archivio";

async function loadLatestRelease() {
  const meta = document.getElementById("release-meta");
  const downloadBtn = document.getElementById("download-app");
  const heroBtn = document.getElementById("download-btn");

  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`);
    if (!res.ok) throw new Error("no release");

    const data = await res.json();
    const tag = data.tag_name || "latest";
    const assets = data.assets || [];
    const asset =
      assets.find((a) => a.name.endsWith(".dmg")) ||
      assets.find((a) => a.name.includes(".app") && a.name.endsWith(".zip"));

    meta.textContent = `Ultima versione: ${tag}${data.published_at ? " · " + new Date(data.published_at).toLocaleDateString("it-IT") : ""}`;

    if (asset) {
      downloadBtn.href = asset.browser_download_url;
      downloadBtn.textContent = `Scarica ${tag}`;
      heroBtn.href = asset.browser_download_url;
      heroBtn.textContent = `Scarica ${tag}`;
    } else {
      downloadBtn.href = data.html_url;
      downloadBtn.textContent = `Vai alla release ${tag}`;
      heroBtn.href = data.html_url;
    }
  } catch {
    meta.textContent = "Nessuna release pubblicata ancora — compila con make install o controlla GitHub Releases.";
    const fallback = `https://github.com/${REPO}/releases`;
    downloadBtn.href = fallback;
    heroBtn.href = "#download";
  }
}

loadLatestRelease();