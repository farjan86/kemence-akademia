// =====================================================================
//  ADMIN — Beállítások fül: általános + azonosító-formátum + e-mail sablonok
// =====================================================================
function mentesVisszajelzes(form, error){
  if(error){ dialog.uzen("Nem sikerült menteni: " + error.message, { cim:"Hiba" }); return; }
  const jel = form.querySelector(".mentve");
  if(jel){ jel.hidden = false; setTimeout(() => { jel.hidden = true; }, 2000); }
}

const fZ = document.getElementById("formAzonosito");
function azonPreview(){
  const elotag = fZ.azonosito_elotag.value || "";
  const kezdo  = parseInt(fZ.azonosito_kezdo.value, 10);
  document.getElementById("azonPreview").textContent = elotag + (Number.isFinite(kezdo) ? kezdo : "");
}
fZ.azonosito_elotag.addEventListener("input", azonPreview);
fZ.azonosito_kezdo.addEventListener("input", azonPreview);

async function betoltBeallitasokUrlap(){
  const { data } = await db.from("settings").select("*").eq("id", 1).maybeSingle();
  if(!data) return;
  const fA = document.getElementById("formAltalanos");
  fA.levelezesi_email.value = data.levelezesi_email ?? "";
  fA.foglalas_infosav.value = data.foglalas_infosav ?? "";
  fA.naptar_nezet.value     = data.naptar_nezet ?? "lista";
  fZ.azonosito_elotag.value = data.azonosito_elotag ?? "F-";
  fZ.azonosito_kezdo.value  = data.azonosito_kezdo ?? 100;
  azonPreview();
}

document.getElementById("formAltalanos").addEventListener("submit", async e => {
  e.preventDefault();
  const f = e.target;
  const { error } = await db.from("settings").update({
    levelezesi_email: f.levelezesi_email.value.trim() || null,
    foglalas_infosav: f.foglalas_infosav.value.trim() || null,
    naptar_nezet: f.naptar_nezet.value,
    updated_at: new Date().toISOString(),
  }).eq("id", 1);
  if(!error){ naptarNezet = f.naptar_nezet.value; if(naptarEv !== null) renderNaptar(); }  // naptarNezet: core, naptarEv/renderNaptar: naptar.js
  mentesVisszajelzes(f, error);
});

fZ.addEventListener("submit", async e => {
  e.preventDefault();
  const elotag = fZ.azonosito_elotag.value;
  const kezdo  = parseInt(fZ.azonosito_kezdo.value, 10);
  if(elotag.length > 2) return dialog.uzen("Az előtag legfeljebb 2 karakter lehet.", { cim:"Hiba" });
  if(!(kezdo >= 1 && kezdo <= 999)) return dialog.uzen("A kezdő sorszám 1 és 999 között legyen.", { cim:"Hiba" });
  const { error } = await db.from("settings").update({
    azonosito_elotag: elotag, azonosito_kezdo: kezdo, updated_at: new Date().toISOString(),
  }).eq("id", 1);
  if(!error){
    beall.azonosito_elotag = elotag;   // beall: core
    beall.azonosito_kezdo  = kezdo;
    megjelenit();                       // foglalasok.js — az azonosítók frissüljenek
  }
  mentesVisszajelzes(fZ, error);
});

const SABLON_SORREND = ["visszaigazolas","csapat_ertesito","jovahagyas","elutasitas","lemondas","program_elmarad","emlekezteto"];
const SABLON_CIMKE = {
  visszaigazolas:  "Visszaigazolás (foglaláskor, a vendégnek)",
  csapat_ertesito: "Csapat-értesítő (foglaláskor, nektek)",
  jovahagyas:      "Jóváhagyás",
  elutasitas:      "Elutasítás",
  lemondas:        "Lemondás",
  program_elmarad: "Program/időpont elmarad (a vendégeknek)",
  emlekezteto:     "Emlékeztető (a program előtti napon, a vendégnek)",
};
async function betoltSablonok(){
  const cel = document.getElementById("sablonok");
  const { data, error } = await db.from("email_sablonok").select("*").in("tipus", SABLON_SORREND);
  if(error){ cel.innerHTML = `<p class="status">Hiba: ${error.message}</p>`; return; }
  const rendezett = SABLON_SORREND.map(t => (data || []).find(s => s.tipus === t)).filter(Boolean);
  cel.innerHTML = rendezett.map(s => `
    <form class="sablon-form" data-tipus="${s.tipus}">
      <h4>${SABLON_CIMKE[s.tipus] || s.tipus}</h4>
      <label>Tárgy <input name="targy" value="${escapeHtml(s.targy)}"></label>
      <label>Törzsszöveg <textarea name="torzs" rows="6">${escapeHtml(s.torzs)}</textarea></label>
      <div class="beall-foot"><button class="btn" type="submit">Mentés</button><span class="mentve" hidden>Mentve ✓</span></div>
    </form>`).join("");
  cel.querySelectorAll(".sablon-form").forEach(f => f.addEventListener("submit", mentSablon));
}
async function mentSablon(e){
  e.preventDefault();
  const f = e.target;
  const { error } = await db.from("email_sablonok").update({
    targy: f.targy.value, torzs: f.torzs.value, updated_at: new Date().toISOString(),
  }).eq("tipus", f.dataset.tipus);
  mentesVisszajelzes(f, error);
}
