const REPO = "loSpaccaBit/clipboard-archivio";
const DOWNLOAD_URL = "download/Appunti-Archivio.dmg";

const DOWNLOAD_LABELS = {
  hero: "Scarica gratis",
  main: "Scarica per macOS",
  footer: "Scarica Appunti Archivio",
};

function formatSize(bytes) {
  if (!bytes) return "";
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function setReleaseMeta(text) {
  const el = document.getElementById("release-meta");
  if (el) el.textContent = text;
}

function setDownloadLabels(tag) {
  const hero = document.getElementById("download-hero");
  const main = document.getElementById("download-btn");
  const footer = document.getElementById("download-footer");

  if (hero) hero.textContent = tag ? `Scarica ${tag}` : DOWNLOAD_LABELS.hero;
  if (main) main.textContent = tag ? `Scarica ${tag}` : DOWNLOAD_LABELS.main;
  if (footer) footer.textContent = tag ? `Scarica ${tag}` : DOWNLOAD_LABELS.footer;
}

async function loadLatestRelease() {
  setDownloadLabels(null);
  setReleaseMeta("Download diretto dal sito");

  try {
    const [releaseRes, headRes] = await Promise.all([
      fetch(`https://api.github.com/repos/${REPO}/releases/latest`),
      fetch(DOWNLOAD_URL, { method: "HEAD" }),
    ]);

    const parts = [];

    if (releaseRes.ok) {
      const data = await releaseRes.json();
      const tag = data.tag_name || null;
      if (tag) {
        parts.push(`Versione ${tag}`);
        setDownloadLabels(tag);
      }
      if (data.published_at) {
        parts.push(new Date(data.published_at).toLocaleDateString("it-IT"));
      }
    }

    if (headRes.ok) {
      const size = formatSize(Number(headRes.headers.get("content-length")));
      if (size) parts.push(size);
    }

    setReleaseMeta(parts.join(" · ") || "Download diretto · Appunti-Archivio.dmg");
  } catch {
    setReleaseMeta("Download diretto · Appunti-Archivio.dmg");
  }
}

function initReveal() {
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const items = document.querySelectorAll(".reveal");

  if (reduced) {
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
    { threshold: 0.1, rootMargin: "0px 0px -32px 0px" }
  );

  items.forEach((el) => observer.observe(el));
}

loadLatestRelease();
initReveal();