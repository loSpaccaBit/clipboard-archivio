const REPO = "loSpaccaBit/clipboard-archivio";
const DOWNLOAD_URL = "download/Clipboard-Archive.dmg";

const DOWNLOAD_LABELS = {
  hero: "Download free",
  main: "Download for macOS",
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

  if (hero) hero.textContent = tag ? `Download ${tag}` : DOWNLOAD_LABELS.hero;
  if (main) main.textContent = tag ? `Download ${tag}` : DOWNLOAD_LABELS.main;
}

async function loadLatestRelease() {
  setDownloadLabels(null);
  setReleaseMeta("Direct download from this site");

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
        parts.push(`Version ${tag}`);
        setDownloadLabels(tag);
      }
      if (data.published_at) {
        parts.push(new Date(data.published_at).toLocaleDateString("en-US"));
      }
    }

    if (headRes.ok) {
      const size = formatSize(Number(headRes.headers.get("content-length")));
      if (size) parts.push(size);
    }

    setReleaseMeta(parts.join(" · ") || "Direct download · Clipboard-Archive.dmg");
  } catch {
    setReleaseMeta("Direct download · Clipboard-Archive.dmg");
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