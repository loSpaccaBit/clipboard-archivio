const REPO = "loSpaccaBit/clipboard-archivio";

async function loadLatestRelease() {
  const meta = document.getElementById("release-meta");
  const zipBtn = document.getElementById("download-zip");
  const heroBtn = document.getElementById("download-btn");

  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`);
    if (!res.ok) throw new Error("no release");

    const data = await res.json();
    const tag = data.tag_name || "latest";
    const asset = (data.assets || []).find((a) => a.name.endsWith(".zip"));

    meta.textContent = `Ultima versione: ${tag}${data.published_at ? " · " + new Date(data.published_at).toLocaleDateString("it-IT") : ""}`;

    if (asset) {
      zipBtn.href = asset.browser_download_url;
      zipBtn.textContent = `Scarica ${tag}`;
      heroBtn.href = asset.browser_download_url;
      heroBtn.textContent = `Scarica ${tag}`;
    } else {
      zipBtn.href = data.html_url;
      zipBtn.textContent = `Vai alla release ${tag}`;
      heroBtn.href = data.html_url;
    }
  } catch {
    meta.textContent = "Nessuna release pubblicata ancora — compila con make install o controlla GitHub Releases.";
    const fallback = `https://github.com/${REPO}/releases`;
    zipBtn.href = fallback;
    heroBtn.href = "#download";
  }
}

loadLatestRelease();