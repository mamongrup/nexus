(() => {
  const header = document.querySelector('.site-header');
  const nav = header?.querySelector('.site-nav');
  if (header && nav) {
    nav.id = 'site-navigation';
    const toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'site-menu-toggle';
    toggle.setAttribute('aria-controls', nav.id);
    toggle.setAttribute('aria-expanded', 'false');
    toggle.setAttribute('aria-label', 'Menüyü aç');
    const glyph = document.createElement('span');
    glyph.className = 'hamburger-glyph';
    glyph.setAttribute('aria-hidden', 'true');
    for (let i = 0; i < 3; i++) glyph.append(document.createElement('span'));
    toggle.append(glyph);
    header.insertBefore(toggle, nav);
    header.classList.add('mobile-menu-ready');
    const close = () => {
      header.classList.remove('mobile-menu-open');
      toggle.setAttribute('aria-expanded', 'false');
      toggle.setAttribute('aria-label', 'Menüyü aç');
    };
    toggle.addEventListener('click', () => {
      const open = header.classList.toggle('mobile-menu-open');
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Menüyü kapat' : 'Menüyü aç');
    });
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape' && header.classList.contains('mobile-menu-open')) { close(); toggle.focus(); }
    });
    document.addEventListener('click', event => { if (!header.contains(event.target)) close(); });
    header.querySelectorAll('a').forEach(link => link.addEventListener('click', close));
    matchMedia('(min-width: 1101px)').addEventListener('change', close);
  }
  // 1. Language switcher & persistence
  const langDropdown = document.querySelector('.lang-dropdown');
  const pillLabel = document.querySelector('.pill-lang-label');
  const langOptions = document.querySelectorAll('.lang-option-btn');
  const localeStatus = document.getElementById('locale-status');

  const langMap = {
    tr: { label: 'TR', name: 'Türkçe' },
    en: { label: 'EN', name: 'English' },
    de: { label: 'DE', name: 'Deutsch' },
    ru: { label: 'RU', name: 'Русский' },
    ar: { label: 'AR', name: 'العربية' },
    fr: { label: 'FR', name: 'Français' }
  };

  try {
    const saved = localStorage.getItem('nexus.language') || 'tr';
    if (pillLabel && langMap[saved]) {
      pillLabel.textContent = langMap[saved].label;
    }
    if (localeStatus) {
      localeStatus.textContent = saved === 'tr' ? '' : 'Dil tercihiniz (' + langMap[saved].name + ') kaydedildi. Yayınlanmış çevirisi bulunmayan içerikler Türkçe gösterilir.';
    }
    langOptions.forEach(btn => {
      if (btn.getAttribute('data-lang') === saved) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });
  } catch (_) {}

  langOptions.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const code = btn.getAttribute('data-lang');
      if (!code || !langMap[code]) return;
      try {
        localStorage.setItem('nexus.language', code);
      } catch (_) {}
      if (pillLabel) {
        pillLabel.textContent = langMap[code].label;
      }
      langOptions.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      if (localeStatus) {
        localeStatus.textContent = code === 'tr' ? '' : 'Dil tercihiniz (' + langMap[code].name + ') kaydedildi. Yayınlanmış çevirisi bulunmayan içerikler Türkçe gösterilir.';
      }
      if (langDropdown) {
        langDropdown.removeAttribute('open');
      }
    });
  });

  // 2. Prevent dropdown overlapping: opening one details element closes all others
  const allNavDropdowns = document.querySelectorAll('details.nav-dropdown');
  allNavDropdowns.forEach(dropdown => {
    dropdown.addEventListener('toggle', () => {
      if (dropdown.open) {
        allNavDropdowns.forEach(other => {
          if (other !== dropdown && other.open) {
            other.removeAttribute('open');
          }
        });
      }
    });
  });

  // 3. Close open dropdowns when clicking outside
  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    allNavDropdowns.forEach(dropdown => {
      if (dropdown.open) {
        dropdown.open = false;
        if (dropdown.contains(document.activeElement)) dropdown.querySelector('summary')?.focus();
      }
    });
  });
  document.addEventListener('click', (e) => {
    allNavDropdowns.forEach(dropdown => {
      if (dropdown.open && !dropdown.contains(e.target)) {
        dropdown.removeAttribute('open');
      }
    });
  });
})();
