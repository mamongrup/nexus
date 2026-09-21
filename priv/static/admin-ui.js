(() => {
  const path = location.pathname.replace(/\/$/, "") || "/";
  const links = [...document.querySelectorAll(".navigation a")];
  const navigation = document.querySelector(".navigation");
  if (navigation && links.length > 8) {
    const search = document.createElement("input");
    search.type = "search";
    search.className = "navigation-search";
    search.placeholder = "Menüde ara…";
    search.setAttribute("aria-label", "Menüde sayfa ara");
    navigation.prepend(search);
    const empty = document.createElement("p");
    empty.textContent = "Eşleşen sayfa yok.";
    empty.hidden = true;
    empty.setAttribute("role", "status");
    navigation.append(empty);
    search.addEventListener("input", () => {
      const query = search.value.toLocaleLowerCase("tr").trim();
      links.forEach(link => { link.hidden = !link.textContent.toLocaleLowerCase("tr").includes(query); });
      empty.hidden = links.some(link => !link.hidden);
    });
  }
  const main = document.querySelector("main");
  if (main) {
    main.id ||= "main-content";
    main.tabIndex = -1;
    const skip = document.createElement("a");
    skip.href = "#" + main.id;
    skip.className = "skip-content";
    skip.textContent = "İçeriğe geç";
    document.body.prepend(skip);
  }
  const icons = {
    "/admin": "⌂", "/admin/ai": "✦", "/admin/finance": "₺",
    "/admin/pricing": "%", "/admin/digital-twin": "◇", "/admin/site": "▤",
    "/admin/messages": "✉", "/admin/partners": "◎", "/admin/applications": "✓",
    "/admin/application": "✓", "/admin/modules": "▦", "/admin/category-fields": "⌘",
    "/admin/listings": "▣", "/admin/calendar": "□", "/admin/requests": "↔",
    "/admin/options": "◷", "/admin/departments": "⌁", "/admin/settings": "⚙",
    "/admin/users": "♙", "/admin/profile": "●", "/admin/reservations": "◆", "/": "↗"
  };
  links.forEach(link => {
    const href = new URL(link.href, location.origin).pathname.replace(/\/$/, "") || "/";
    const key = Object.keys(icons).filter(item => href === item || href.startsWith(item + "/")).sort((a, b) => b.length - a.length)[0];
    if (!key || link.querySelector(".nav-icon")) return;
    const icon = document.createElement("span");
    icon.className = "nav-icon";
    icon.setAttribute("aria-hidden", "true");
    icon.textContent = icons[key];
    link.prepend(icon);
  });
  const candidates = links.filter(link => {
    const href = new URL(link.href, location.origin).pathname.replace(/\/$/, "") || "/";
    return path === href || (href !== "/admin" && path.startsWith(href + "/"));
  });
  candidates.sort((a, b) => b.pathname.length - a.pathname.length);
  if (candidates[0]) {
    candidates[0].classList.add("active");
    candidates[0].setAttribute("aria-current", "page");
  }

  const workspace = document.querySelector(".workspace");
  const topbar = document.querySelector(".topbar");
  if (workspace && topbar) {
    const toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "mobile-nav-toggle";
    toggle.setAttribute("aria-label", "Menüyü aç veya kapat");
    toggle.setAttribute("aria-expanded", "false");
    toggle.textContent = "☰";
    topbar.prepend(toggle);
    toggle.addEventListener("click", () => {
      const open = workspace.classList.toggle("nav-open");
      toggle.setAttribute("aria-expanded", String(open));
      toggle.textContent = open ? "×" : "☰";
    });
    const closeMenu = () => {
      workspace.classList.remove("nav-open");
      toggle.setAttribute("aria-expanded", "false");
      toggle.textContent = "☰";
    };
    document.querySelectorAll(".navigation a").forEach(link => link.addEventListener("click", closeMenu));
    document.addEventListener("keydown", event => {
      if (event.key === "Escape" && workspace.classList.contains("nav-open")) { closeMenu(); toggle.focus(); }
    });
  }

  const searchablePanels = [...document.querySelectorAll("main.content > div > details.panel")];
  if (searchablePanels.length >= 6) {
    const filter = document.createElement("div");
    filter.className = "panel-filter";
    const input = document.createElement("input");
    input.type = "search";
    input.placeholder = "Bölüm, ayar veya içerik ara…";
    input.setAttribute("aria-label", "Panel bölümlerinde ara");
    const count = document.createElement("small");
    count.textContent = searchablePanels.length + " bölüm";
    filter.append(input, count);
    searchablePanels[0].parentNode.insertBefore(filter, searchablePanels[0]);
    input.addEventListener("input", () => {
      const query = input.value.toLocaleLowerCase("tr").trim();
      let visible = 0;
      searchablePanels.forEach(panel => {
        const match = !query || panel.textContent.toLocaleLowerCase("tr").includes(query);
        panel.hidden = !match;
        if (match) visible++;
        if (query && match) panel.open = true;
      });
      count.textContent = visible + " bölüm gösteriliyor";
    });
  }

  document.querySelectorAll(".table-scroll table, .panel > table").forEach((table, index) => {
    const body = table.tBodies[0];
    if (!body || body.rows.length < 6 || table.dataset.searchReady) return;
    table.dataset.searchReady = "true";
    const tools = document.createElement("div");
    tools.className = "table-tools";
    const search = document.createElement("input");
    search.type = "search";
    search.className = "table-search";
    search.placeholder = "Listede ara…";
    search.setAttribute("aria-label", "Tabloda ara");
    tools.append(search);
    const host = table.closest(".table-scroll") || table;
    host.parentNode.insertBefore(tools, host);
    search.addEventListener("input", () => {
      const query = search.value.toLocaleLowerCase("tr").trim();
      [...body.rows].forEach(row => {
        row.hidden = query !== "" && !row.textContent.toLocaleLowerCase("tr").includes(query);
      });
    });
  });

  document.querySelectorAll("form").forEach(form => {
    form.addEventListener("submit", () => {
      const button = form.querySelector("button[type=submit], button:not([type])");
      if (!button || !form.checkValidity()) return;
      button.classList.add("form-submit-busy");
      button.setAttribute("aria-busy", "true");
    });
  });

  document.querySelectorAll(".file-drop-field input[type=file]").forEach(input => {
    input.addEventListener("change", () => {
      const field = input.closest(".file-drop-field");
      const name = field?.querySelector(".file-drop-copy strong");
      const help = field?.querySelector(".file-drop-copy small");
      if (!input.files?.[0] || !name || !help) return;
      name.textContent = input.files[0].name;
      help.textContent = "Yüklemeye hazır · " + Math.max(1, Math.ceil(input.files[0].size / 1024)) + " KB";
      field.classList.add("has-file");
    });
  });
})();
