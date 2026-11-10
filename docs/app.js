// tristans-addon.myazerothlife.com: quest log, loot, toasts and other small joys.
// Adapted from omaforge.ninepointlabs.com's app.js (Nine Point Labs, MIT).

(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const ICON = (name) => `https://render.worldofwarcraft.com/us/icons/56/${name}.jpg`;
  const ART = (name) => `https://omaforge.ninepointlabs.com/assets/art/${name}`;
  const store = {
    get(key) { try { return localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch { /* private window */ } },
  };

  // --- Achievements ---------------------------------------------------------
  const earned = new Set();
  const toasts = $("#toasts");

  function achieve(id, name, text, icon, points = 10) {
    if (earned.has(id)) return;
    earned.add(id);
    const el = document.createElement("div");
    el.className = "toast";
    el.innerHTML = `<img alt=""><div><small>Achievement Earned</small><strong></strong><span></span></div><div class="points"></div>`;
    el.querySelector("img").src = icon;
    el.querySelector("strong").textContent = name;
    el.querySelector("span").textContent = text;
    el.querySelector(".points").textContent = points;
    toasts.append(el);
    setTimeout(() => el.remove(), 5200);
  }

  window.tristansAchieve = achieve; // used by demo.js

  const zone = $("#zone-text");
  function announce(text) {
    zone.textContent = text;
    zone.classList.remove("show");
    void zone.offsetWidth; // restart the animation
    zone.classList.add("show");
    clearTimeout(announce.timer);
    announce.timer = setTimeout(() => zone.classList.remove("show"), 2700);
  }

  // --- Loading screen tips (all true of the addon) --------------------------
  const tips = [
    "Each press of the Bless next button blesses the next player missing your Blessing, nearest first.",
    "Might for Warriors, Rogues and Hunters, Wisdom for casters and healers. Or Kings for everyone, if you like.",
    "Someone wearing your Blessing of Freedom is skipped until it ends. One Blessing from you per target.",
    "The PvP bar has Freedom, Cleanse, Protection, Stun and Repentance. One press, one cast.",
    "Battle › Cooldowns shows your own cooldowns and Forbearance, so you know if Divine Shield is an option.",
    "The Burst coach only gives advice, and only from your own casts. You still press the buttons.",
    "Battle › Battlegrounds shows which battlegrounds your level can queue for.",
    "The Seal hint counts your Unsealed Wrath echoes and says when to swap. Advice only.",
    "Hover any item: the tooltip compares it for your spec, with PvP weights if you want them.",
    "Talents has validated builds for Holy, Protection and Retribution, PvP builds included.",
    "Learn the Paladin has a PvP basics track for your first battleground.",
    "Every page has a Sources & notes link. Unconfirmed facts are marked, never guessed.",
    "Type /tristan to open the window.",
  ];
  const tip = $("#tip");
  let tipIndex = 0;
  if (!matchMedia("(prefers-reduced-motion: reduce)").matches) {
    setInterval(() => {
      if (document.hidden) return;
      const box = tip.parentElement;
      box.classList.add("fade");
      setTimeout(() => {
        tipIndex = (tipIndex + 1) % tips.length;
        tip.textContent = tips[tipIndex];
        box.classList.remove("fade");
      }, 400);
    }, 6500);
  }

  // --- Faction --------------------------------------------------------------
  const factions = {
    alliance: { cry: "For the Alliance!", icon: ART("alliance-crest.webp") },
    horde: { cry: "For the Horde!", icon: ART("horde-sigil.webp") },
  };
  function setFaction(name, cheer) {
    const pick = factions[name] ? name : "neutral";
    document.documentElement.dataset.faction = pick;
    $$(".faction button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.pick === pick)));
    store.set("tristans-faction", pick);
    if (cheer && factions[pick]) {
      announce(factions[pick].cry);
      achieve(`faction-${pick}`, factions[pick].cry, "Chose a side. The Kirin Tor doesn't mind either way.", factions[pick].icon, 5);
    }
  }
  setFaction(store.get("tristans-faction"), false);
  $$(".faction button").forEach((b) =>
    b.addEventListener("click", () => {
      const current = document.documentElement.dataset.faction;
      setFaction(current === b.dataset.pick ? "neutral" : b.dataset.pick, current !== b.dataset.pick);
    }),
  );

  // --- Quest log ------------------------------------------------------------
  const quests = $$(".quest");
  const list = $("#ql-list");
  const accepted = new Set();
  let current = 0;

  function levelClass(level) {
    if (level >= 45) return "lvl-red";
    if (level >= 30) return "lvl-orange";
    if (level >= 20) return "lvl-yellow";
    return "lvl-green";
  }

  let lastZone = "";
  quests.forEach((q, i) => {
    if (q.dataset.zone !== lastZone) {
      lastZone = q.dataset.zone;
      const z = document.createElement("li");
      z.className = "ql-zone";
      z.textContent = lastZone;
      z.setAttribute("aria-hidden", "true");
      z.setAttribute("role", "none");
      list.append(z);
    }
    const li = document.createElement("li");
    li.setAttribute("role", "none");
    const b = document.createElement("button");
    b.type = "button";
    b.id = `tab-${q.id}`;
    b.className = levelClass(Number(q.dataset.level));
    b.setAttribute("role", "tab");
    b.setAttribute("aria-controls", q.id);
    b.innerHTML = `<span class="lvl">[${q.dataset.level}]</span><span class="qname"></span>`;
    b.querySelector(".qname").textContent = $("h3", q).textContent;
    if (q.hasAttribute("data-new")) b.insertAdjacentHTML("beforeend", `<span class="new-mark">NEW</span>`);
    b.addEventListener("click", () => show(i));
    li.append(b);
    list.append(li);
    q.setAttribute("role", "tabpanel");
    q.setAttribute("aria-labelledby", b.id);
  });
  list.setAttribute("role", "tablist");
  list.setAttribute("aria-orientation", "vertical");
  $(".ql-count").lastChild.textContent = `/${quests.length} accepted`;

  function tabs() { return $$("button[role=tab]", list); }

  function show(i, focus = false) {
    current = (i + quests.length) % quests.length;
    quests.forEach((q, j) => q.classList.toggle("active", j === current));
    tabs().forEach((t, j) => {
      t.setAttribute("aria-selected", String(j === current));
      t.tabIndex = j === current ? 0 : -1;
    });
    if (focus) tabs()[current].focus();
    syncAccept();
  }

  list.addEventListener("keydown", (e) => {
    const step = { ArrowDown: 1, ArrowUp: -1 }[e.key];
    if (step) { e.preventDefault(); show(current + step, true); }
  });

  const acceptBtn = $("#accept");
  function syncAccept() {
    const done = accepted.has(quests[current].id);
    acceptBtn.textContent = done ? "Accepted" : "Accept";
    acceptBtn.disabled = done;
    acceptBtn.style.opacity = done ? 0.6 : 1;
  }

  acceptBtn.addEventListener("click", () => {
    const q = quests[current];
    if (accepted.has(q.id)) return;
    accepted.add(q.id);
    q.classList.add("completed");
    const tab = tabs()[current];
    tab.querySelector(".new-mark")?.remove();
    tab.insertAdjacentHTML("beforeend", `<span class="done-mark" aria-label="accepted">✓</span>`);
    $("#ql-done").textContent = accepted.size;
    announce(`Quest accepted: ${$("h3", q).textContent}`);
    if (accepted.size === quests.length) {
      achieve("loremaster", "Loremaster of the Light", "Accepted every quest in the log.",
        ICON("achievement_quests_completed_08"), 25);
    }
    syncAccept();
  });
  $("#next").addEventListener("click", () => show(current + 1));

  const deep = quests.findIndex((q) => `#${q.id}` === location.hash);
  show(deep >= 0 ? deep : 0);

  // --- Screenshot lightbox ---------------------------------------------------
  const box = $("#lightbox");
  if (box && typeof box.showModal === "function") {
    $$("[data-zoom]").forEach((b) =>
      b.addEventListener("click", () => {
        const img = $("img", b);
        $("img", box).src = img.currentSrc || img.src;
        $("img", box).alt = img.alt;
        box.showModal();
      }),
    );
    box.addEventListener("click", () => box.close());
  }

  // --- Loot -----------------------------------------------------------------
  $$("[data-copy]").forEach((b) =>
    b.addEventListener("click", async () => {
      const text = $("pre", b.closest(".loot-item")).innerText.trim();
      try {
        await navigator.clipboard.writeText(text);
        b.textContent = "Copied";
        setTimeout(() => (b.textContent = "Copy"), 1600);
        achieve("loot", "Loot Acquired", "Copied a command. Now paste it.", ICON("inv_misc_bag_10"));
      } catch {
        b.textContent = "Select it";
      }
    }),
  );

  $(".gossip-bye")?.addEventListener("click", () =>
    achieve("farewell", "Well Met", "Talked to Innkeeper Emberwick.", ICON("inv_drink_06"), 5),
  );

  // The latest release: version and zip link, when GitHub answers.
  fetch("https://api.github.com/repos/ninepointlabs/tristans-addon/releases/latest", { headers: { Accept: "application/vnd.github+json" } })
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((rel) => {
      $$("[data-version]").forEach((el) => (el.textContent = rel.tag_name));
      $$("[data-prerelease]").forEach((el) => (el.hidden = true));
      const zip = (rel.assets || []).find((a) => a.name.endsWith(".zip"));
      if (zip) $$('[data-download="zip"]').forEach((el) => (el.href = zip.browser_download_url));
    })
    .catch(() => { /* keep the built-in version and the releases page link */ });
})();
