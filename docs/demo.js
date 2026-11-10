// The Blessing button demo: the same picking rules as the addon's
// UI/BlessingButton.lua. Each press blesses the next player missing your
// Blessing, nearest first, class-smart (Might for Warriors, Rogues and Hunters,
// Wisdom for casters and healers, or Kings for everyone). Out-of-range players
// are skipped; in combat the button keeps its target and the demo disarms it.
// One press, one cast.
(() => {
  const root = document.querySelector("#bless-demo");
  if (!root) return;
  const ICON = (name) => `https://render.worldofwarcraft.com/us/icons/56/${name}.jpg`;

  const BLESSINGS = {
    Might: { spell: "Blessing of Might", icon: ICON("spell_holy_fistofjustice") },
    Wisdom: { spell: "Blessing of Wisdom", icon: ICON("spell_holy_sealofwisdom") },
    Kings: { spell: "Blessing of Kings", icon: ICON("spell_magic_greaterblessingofkings") },
  };
  // Class defaults from the addon (Settings > Paladin bar can override them).
  const CLASS_DEFAULT = { Warrior: "Might", Rogue: "Might", Hunter: "Might", Priest: "Wisdom", Mage: "Wisdom" };

  // Pretend party, already sorted nearest first. Distances are demo values.
  const PARTY = [
    { name: "You", cls: "Paladin (Retribution)", self: true, where: "right here" },
    { name: "Brannoc", cls: "Warrior", where: "5 yd" },
    { name: "Elowen", cls: "Priest", where: "12 yd" },
    { name: "Corvin", cls: "Mage", where: "18 yd" },
    { name: "Wren", cls: "Rogue", where: "24 yd" },
    { name: "Hollis", cls: "Hunter", where: "out of range", far: true },
  ];

  let blessed = new Set();
  let combat = false;
  let kings = false;
  let flash = null;
  const list = root.querySelector(".party");
  const btn = root.querySelector(".bless-btn");
  const status = root.querySelector(".demo-status");
  const combatRow = root.querySelector(".demo-combat");
  const combatBtn = root.querySelector(".combat-toggle");
  const kingsBox = root.querySelector(".kings-toggle");

  function want(m) {
    if (kings) return "Kings";
    if (m.self) return "Might"; // your own follows your spec: Might for Ret/Prot, Wisdom for Holy
    return CLASS_DEFAULT[m.cls] || "Wisdom";
  }

  function next() {
    return PARTY.find((m) => !m.far && !blessed.has(m.name)) || null;
  }

  function render() {
    const pick = combat ? null : next();
    list.innerHTML = "";
    for (const m of PARTY) {
      const has = blessed.has(m.name);
      const b = BLESSINGS[want(m)];
      const li = document.createElement("li");
      li.className = "member" + (has ? " buffed" : "") + (m.far ? " far" : "") + (pick === m ? " next" : "") + (flash === m.name ? " flash" : "");
      li.innerHTML = `<div class="who"><b></b><span class="cls"></span></div><div class="state"><span class="tag"></span><img alt=""></div>`;
      li.querySelector("b").textContent = m.name;
      li.querySelector(".cls").textContent = `${m.cls} · ${m.where}`;
      const tag = li.querySelector(".tag");
      if (has) { tag.textContent = "blessed"; tag.className = "tag ok"; }
      else if (m.far) { tag.textContent = "out of range"; tag.className = "tag skip"; }
      else if (pick === m) { tag.textContent = "next"; tag.className = "tag"; }
      else { tag.textContent = "missing"; tag.className = "tag"; }
      const img = li.querySelector("img");
      img.src = b.icon;
      img.alt = b.spell;
      if (flash === m.name) {
        const f = document.createElement("span");
        f.className = "cast-float";
        f.textContent = `+ ${b.spell}`;
        li.append(f);
      }
      list.append(li);
    }
    flash = null;

    btn.disabled = !pick;
    btn.style.setProperty("--icon", `url("${BLESSINGS[pick ? want(pick) : "Might"].icon}")`);
    btn.setAttribute("aria-label", pick ? `Cast ${BLESSINGS[want(pick)].spell} on ${pick.name}` : "Nobody to bless");
    combatRow.classList.toggle("on", combat);
    combatRow.querySelector("span").textContent = combat ? "In combat: the button is disarmed." : "Out of combat.";
    combatBtn.textContent = combat ? "Leave combat" : "Pull a mob";

    if (combat) {
      status.innerHTML = `<b>In combat</b><span>The button can't change its target until the fight ends (Blizzard rule). Bless between pulls.</span>`;
    } else if (pick) {
      status.innerHTML = `<b></b><span>press the button or <kbd>B</kbd></span>`;
      status.querySelector("b").textContent = `Next: ${BLESSINGS[want(pick)].spell} on ${pick.name}`;
    } else {
      status.innerHTML = `<b>Everyone nearby is blessed</b><span>Hollis is out of range: the button skips him until he's closer.</span><br><button type="button" class="wow-btn small ghost reset">Reset the demo</button>`;
      status.querySelector(".reset").addEventListener("click", reset);
    }
  }

  function cast() {
    if (combat) return;
    const pick = next();
    if (!pick) return;
    blessed.add(pick.name);
    flash = pick.name;
    render();
    if (!next() && window.tristansAchieve) {
      window.tristansAchieve("bless", "Blessings All Around", "Blessed everyone in range, one press at a time.", BLESSINGS[want(pick)].icon, 10);
    }
  }

  function reset() {
    blessed = new Set();
    combat = false;
    render();
  }

  btn.addEventListener("click", cast);
  combatBtn.addEventListener("click", () => { combat = !combat; render(); });
  kingsBox.addEventListener("change", () => { kings = kingsBox.checked; blessed = new Set(); render(); });
  root.addEventListener("keydown", (e) => {
    if (e.target === kingsBox) return;
    if (e.key === "b" || e.key === "B") { e.preventDefault(); cast(); }
  });
  reset();
})();
