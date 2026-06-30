const REPO = "loSpaccaBit/clipboard-archivio";
const DOWNLOAD_URL = "download/Appunti-Archivio.dmg";
const DOWNLOAD_NAME = "Appunti-Archivio.dmg";

function triggerDownload(event) {
  event.preventDefault();
  const link = document.createElement("a");
  link.href = DOWNLOAD_URL;
  link.download = DOWNLOAD_NAME;
  link.rel = "noopener";
  document.body.appendChild(link);
  link.click();
  link.remove();
}

function wireDownloadButtons() {
  document.querySelectorAll(".js-download").forEach((button) => {
    button.href = DOWNLOAD_URL;
    button.setAttribute("download", DOWNLOAD_NAME);
    button.addEventListener("click", triggerDownload);
  });
}

function setButtonLabel(label) {
  document.querySelectorAll(".js-download").forEach((button) => {
    if (button.classList.contains("nav-download")) {
      button.textContent = "Scarica";
      return;
    }
    button.textContent = label;
  });
}

async function loadLatestRelease() {
  const meta = document.getElementById("release-meta");
  wireDownloadButtons();
  setButtonLabel("Scarica per macOS");

  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`);
    if (!res.ok) throw new Error("no release");

    const data = await res.json();
    const tag = data.tag_name || "latest";
    meta.textContent = `Ultima versione: ${tag}${data.published_at ? " · " + new Date(data.published_at).toLocaleDateString("it-IT") : ""}`;
    setButtonLabel(`Scarica ${tag}`);
  } catch {
    meta.textContent = "Download diretto — il file parte subito, senza passare da GitHub.";
    setButtonLabel("Scarica per macOS");
  }
}

loadLatestRelease();