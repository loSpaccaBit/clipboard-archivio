const REPO = "loSpaccaBit/clipboard-archivio";
const DOWNLOAD_URL = "download/Appunti-Archivio.dmg";

function formatSize(bytes) {
  if (!bytes) return "";
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function setLabelWithIcon(button, label) {
  if (!button) return;
  const svg = button.querySelector("svg");
  button.textContent = "";
  if (svg) button.appendChild(svg);
  button.append(document.createTextNode(` ${label}`));
}

function setReleaseMeta(text) {
  const meta = document.getElementById("release-meta");
  if (meta) meta.textContent = text;
}

async function loadLatestRelease() {
  setLabelWithIcon(document.getElementById("download-btn"), "Scarica per macOS");
  setLabelWithIcon(document.getElementById("download-app"), "Scarica Appunti Archivio");
  setReleaseMeta("Download diretto dal sito");

  try {
    const [releaseRes, headRes] = await Promise.all([
      fetch(`https://api.github.com/repos/${REPO}/releases/latest`),
      fetch(DOWNLOAD_URL, { method: "HEAD" }),
    ]);

    const metaParts = [];

    if (releaseRes.ok) {
      const data = await releaseRes.json();
      const tag = data.tag_name || "latest";
      metaParts.push(`Versione ${tag}`);
      if (data.published_at) {
        metaParts.push(new Date(data.published_at).toLocaleDateString("it-IT"));
      }
      setLabelWithIcon(document.getElementById("download-btn"), `Scarica ${tag}`);
      setLabelWithIcon(document.getElementById("download-app"), `Scarica ${tag}`);
    }

    if (headRes.ok) {
      const sizeLabel = formatSize(Number(headRes.headers.get("content-length")));
      if (sizeLabel) metaParts.push(sizeLabel);
    }

    setReleaseMeta(metaParts.join(" · ") || "Download diretto dal sito");
  } catch {
    setReleaseMeta("Download diretto · Appunti-Archivio.dmg");
  }
}

function initReveal() {
  const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const items = document.querySelectorAll(".reveal");

  if (prefersReduced) {
    items.forEach((el) => el.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
  );

  items.forEach((el) => observer.observe(el));
}

loadLatestRelease();
initReveal();