/* NEXUS TravelTech — Rich Markdown Editor & AI Generation Assistant */
(function () {
  function initEditor() {
    var editorWrap = document.querySelector('.rich-editor-container');
    var textarea = document.querySelector('textarea[name="description"]');
    var preview = document.querySelector('.editor-preview');
    var previewToggle = document.querySelector('[data-edit-action="toggle-preview"]');
    var descCounter = document.querySelector('.char-counter-desc');

    function normalizeCategory(value) {
      var slug = String(value || '').trim().toLowerCase();
      if (slug === 'villa') return 'holiday_home';
      return slug;
    }

    function loadManagedFilterSelects() {
      var form = document.querySelector('.editor-form');
      var selects = Array.prototype.slice.call(document.querySelectorAll('select[data-managed-filter-category][data-managed-filter-key]'));
      if (!selects.length) return;
      var activeCategory = normalizeCategory(((form || document).querySelector('input[name="category_code"]') || {}).value || '');
      fetch('/admin/category-filters/data', { credentials: 'same-origin', cache: 'no-store' })
        .then(function (res) {
          if (!res.ok) throw new Error('Kategori filtreleri okunamadı');
          return res.json();
        })
        .then(function (groups) {
          if (!Array.isArray(groups)) return;
          selects.forEach(function (select) {
            var category = normalizeCategory(select.getAttribute('data-managed-filter-category') || activeCategory);
            var key = select.getAttribute('data-managed-filter-key') || select.name || '';
            if (key.indexOf('attr_') === 0) key = key.slice(5);
            var current = select.value;
            var group = groups.find(function (item) {
              return normalizeCategory(item.category) === category && item.key === key;
            });
            if (!group || !Array.isArray(group.items) || !group.items.length) return;
            select.textContent = '';
            group.items.forEach(function (item) {
              var option = document.createElement('option');
              option.value = item.contractValue || item.title || item.key;
              option.textContent = item.title || item.key;
              select.appendChild(option);
            });
            var keep = Array.prototype.some.call(select.options, function (option) {
              return option.value === current;
            });
            if (keep) select.value = current;
            select.dispatchEvent(new Event('change', { bubbles: true }));
          });
        })
        .catch(function () {
          // Merkezi sözleşme olmadan bağımsız kullanımda mevcut seçenekler kalır.
        });
    }

    function loadCategoryFilterAdmin() {
      var host = document.querySelector('[data-category-filter-admin]');
      var table = document.getElementById('nexus-category-filter-table');
      var groupSelect = document.getElementById('nexus-filter-item-group');
      if (!host || (!table && !groupSelect)) return;
      var selectedCategory = normalizeCategory(host.getAttribute('data-category-filter-admin'));
      fetch('/admin/category-filters/data', { credentials: 'same-origin', cache: 'no-store' })
        .then(function (res) {
          if (!res.ok) throw new Error('Kategori filtreleri okunamadı');
          return res.json();
        })
        .then(function (groups) {
          groups = Array.isArray(groups) ? groups.filter(function (group) {
            return normalizeCategory(group.category) === selectedCategory;
          }) : [];

          if (groupSelect) {
            groupSelect.textContent = '';
            var empty = document.createElement('option');
            empty.value = '';
            empty.textContent = groups.length ? 'Filtre grubu seçin' : 'Önce filtre grubu oluşturun';
            groupSelect.appendChild(empty);
            groups.forEach(function (group) {
              var option = document.createElement('option');
              option.value = group.id;
              option.textContent = (group.title || group.key) + ' · ' + group.key;
              groupSelect.appendChild(option);
            });
          }

          if (!table) return;
          if (!groups.length) {
            table.innerHTML = '<p class="muted text-sm">Bu kategori için henüz admin yönetimli filtre grubu yok.</p>';
            return;
          }
          table.innerHTML = '';
          groups.forEach(function (group) {
            var card = document.createElement('div');
            card.className = 'category-filter-admin-card';
            var items = Array.isArray(group.items) ? group.items : [];
            card.innerHTML =
              '<div class="flex-between align-center gap-2">' +
                '<div><strong>' + escapeHtml(group.title || group.key) + '</strong>' +
                '<div class="muted text-xs">' + escapeHtml(group.key) + ' · ' + escapeHtml(group.displayType || 'chip') + (group.multiple ? ' · çoklu' : '') + '</div></div>' +
                '<span class="badge neutral">Sıra: ' + escapeHtml(String(group.sortOrder || '')) + '</span>' +
              '</div>' +
              '<div class="category-filter-admin-items">' +
                (items.length ? items.map(function (item) {
                  return '<span class="badge light">' + escapeHtml(item.title || item.key) + '<small> ' + escapeHtml(item.contractValue || item.key || '') + '</small></span>';
                }).join('') : '<span class="muted text-sm">Henüz madde yok.</span>') +
              '</div>';
            var actions = document.createElement('div');
            actions.className = 'category-filter-admin-actions';
            actions.appendChild(postFilterAction('/admin/category-filters/groups/deactivate', 'group_id', group.id, selectedCategory, 'Grubu pasifleştir'));
            items.forEach(function (item) {
              actions.appendChild(postFilterAction('/admin/category-filters/items/deactivate', 'item_id', item.id, selectedCategory, 'Madde: ' + (item.title || item.key)));
            });
            card.appendChild(actions);
            table.appendChild(card);
          });
        })
        .catch(function () {
          if (table) {
            table.innerHTML = '<p class="muted text-sm">Filtreler okunamadı. Veritabanı bağlantısını kontrol edin.</p>';
          }
        });
    }

    function postFilterAction(action, fieldName, fieldValue, category, label) {
      var form = document.createElement('form');
      form.method = 'post';
      form.action = action;
      form.className = 'inline-action-form';
      form.innerHTML =
        '<input type="hidden" name="csrf" value="' + escapeHtml(csrfToken()) + '">' +
        '<input type="hidden" name="category" value="' + escapeHtml(category || '') + '">' +
        '<input type="hidden" name="' + escapeHtml(fieldName) + '" value="' + escapeHtml(fieldValue || '') + '">' +
        '<button type="submit" class="button danger small" data-filter-confirm="Bu filtreyi pasifleştirmek istediğinize emin misiniz?">' + escapeHtml(label) + '</button>';
      return form;
    }

    function csrfToken() {
      var match = document.cookie.match(/(?:^|;\s*)nexus_csrf=([^;]*)/);
      return match ? decodeURIComponent(match[1]) : '';
    }

    function escapeHtml(value) {
      return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    loadManagedFilterSelects();
    loadCategoryFilterAdmin();

    document.addEventListener('submit', function (event) {
      var button = event.submitter;
      var message = button && button.getAttribute('data-filter-confirm');
      if (message && !confirm(message)) event.preventDefault();
    });

    if (textarea) {
      function updateDescCount() {
        if (descCounter) {
          var len = textarea.value.length;
          descCounter.textContent = len + ' / 5000 karakter';
        }
      }
      textarea.addEventListener('input', updateDescCount);
      updateDescCount();
    }

    // Toolbar actions
    document.querySelectorAll('[data-edit-action]').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        if (!textarea) return;
        var action = btn.getAttribute('data-edit-action');
        var start = textarea.selectionStart;
        var end = textarea.selectionEnd;
        var val = textarea.value;
        var selected = val.substring(start, end);
        var replace = '';

        switch (action) {
          case 'bold':
            replace = '**' + (selected || 'kalın metin') + '**';
            break;
          case 'italic':
            replace = '*' + (selected || 'italik metin') + '*';
            break;
          case 'h2':
            replace = '\n## ' + (selected || 'Bölüm Başlığı') + '\n';
            break;
          case 'h3':
            replace = '\n### ' + (selected || 'Alt Başlık') + '\n';
            break;
          case 'bullet':
            replace = '\n- ' + (selected || 'Madde başlığı');
            break;
          case 'number':
            replace = '\n1. ' + (selected || 'Numaralı adım');
            break;
          case 'quote':
            replace = '\n> ' + (selected || 'Önemli bilgilendirme veya alıntı') + '\n';
            break;
          case 'link':
            var url = prompt('Bağlantı URL adresini girin (örn: https://...):', 'https://');
            if (url) {
              replace = '[' + (selected || 'Bağlantı Metni') + '](' + url + ')';
            } else {
              return;
            }
            break;
          case 'template':
            var cat = (document.querySelector('input[name="category_code"]') || {}).value || 'villa';
            replace = '\n## Genel Bakış & Ayrıcalıklar\n' +
              'Tesisimiz misafirlerine eşsiz bir konaklama ve tatil deneyimi sunmaktadır.\n\n' +
              '## Konaklama & Donanım Özellikleri\n' +
              '- ✨ Yüksek kaliteli mobilyalar ve ferah yaşam alanları\n' +
              '- 📶 Ücretsiz yüksek hızlı Wi-Fi ve otopark\n' +
              '- 🛡️ Resmi mevzuata ve emniyet bildirimine tam uyumlu\n\n' +
              '## Konum & Çevre\n' +
              'Bölgenin cazibe merkezlerine ve ana ulaşım hatlarına yakın mesafededir.\n\n' +
              '## Giriş & Rezervasyon Kuralları\n' +
              '- Giriş: 14:00 | Çıkış: 11:00\n';
            break;
          case 'toggle-preview':
            if (preview && editorWrap) {
              var isPreview = editorWrap.classList.toggle('preview-active');
              btn.classList.toggle('active', isPreview);
              btn.textContent = isPreview ? '✏️ Düzenlemeye Dön' : '👁️ Önizleme';
              if (isPreview) {
                preview.innerHTML = renderMarkdown(textarea.value);
              }
            }
            return;
        }

        textarea.focus();
        textarea.setRangeText(replace, start, end, 'end');
        textarea.dispatchEvent(new Event('input', { bubbles: true }));
      });
    });

    // Simple, safe Markdown parser for live preview
    function renderMarkdown(md) {
      if (!md) return '<p class="muted">Henüz açıklama metni girilmedi.</p>';
      var esc = md
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
      
      // Headings
      esc = esc.replace(/^### (.*$)/gim, '<h3>$1</h3>');
      esc = esc.replace(/^## (.*$)/gim, '<h2>$1</h2>');
      esc = esc.replace(/^# (.*$)/gim, '<h1>$1</h1>');
      // Bold & Italic
      esc = esc.replace(/\*\*(.*?)\*\*/gim, '<strong>$1</strong>');
      esc = esc.replace(/\*(.*?)\*/gim, '<em>$1</em>');
      // Blockquote
      esc = esc.replace(/^\> (.*$)/gim, '<blockquote>$1</blockquote>');
      // Links
      esc = esc.replace(/\[([^\]]+)\]\(([^)]+)\)/gim, '<a href="$2" target="_blank" rel="noopener">$1</a>');
      // Unordered List
      esc = esc.replace(/^\- (.*$)/gim, '<li>$1</li>');
      esc = esc.replace(/(<li>.*<\/li>)/gim, '<ul>$1</ul>');
      // Paragraphs
      esc = esc.replace(/\n\n+/g, '</p><p>');
      return '<p>' + esc.replace(/\n/g, '<br>') + '</p>';
    }

    // SEO Character Counters
    var seoTitleInput = document.querySelector('input[name="seo_title"]');
    var seoTitleCounter = document.querySelector('.char-counter-seo-title');
    if (seoTitleInput && seoTitleCounter) {
      function updateSeoTitle() {
        var len = seoTitleInput.value.length;
        var badge = '';
        if (len === 0) badge = ' (Önerilen: 50-70)';
        else if (len >= 45 && len <= 75) badge = ' (✓ İdeal Google uzunluğu)';
        else if (len > 160) badge = ' (⚠️ Sınır aşıldı)';
        else badge = ' (Kısa)';
        seoTitleCounter.textContent = len + ' / 160 karakter' + badge;
        seoTitleCounter.className = 'char-counter-seo-title ' + (len >= 45 && len <= 75 ? 'counter-optimal' : len > 160 ? 'counter-danger' : 'counter-muted');
      }
      seoTitleInput.addEventListener('input', updateSeoTitle);
      updateSeoTitle();
    }

    var seoDescInput = document.querySelector('input[name="seo_description"]');
    var seoDescCounter = document.querySelector('.char-counter-seo-desc');
    if (seoDescInput && seoDescCounter) {
      function updateSeoDesc() {
        var len = seoDescInput.value.length;
        var badge = '';
        if (len === 0) badge = ' (Önerilen: 120-160)';
        else if (len >= 110 && len <= 165) badge = ' (✓ İdeal SERP özeti)';
        else if (len > 320) badge = ' (⚠️ Sınır aşıldı)';
        else badge = ' (Detaylandırılabilir)';
        seoDescCounter.textContent = len + ' / 320 karakter' + badge;
        seoDescCounter.className = 'char-counter-seo-desc ' + (len >= 110 && len <= 165 ? 'counter-optimal' : len > 320 ? 'counter-danger' : 'counter-muted');
      }
      seoDescInput.addEventListener('input', updateSeoDesc);
      updateSeoDesc();
    }

    // AI Generation Triggers
    document.querySelectorAll('[data-ai-trigger]').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        var triggerType = btn.getAttribute('data-ai-trigger');
        var form = btn.closest('form') || document.querySelector('.editor-form');
        if (!form) return;

        var csrfInput = form.querySelector('input[name="csrf"]');
        var categoryInput = form.querySelector('input[name="category_code"]');
        var localityInput = form.querySelector('input[name="locality"]');
        var titleInput = form.querySelector('input[name="title"]');
        var capacityInput = form.querySelector('input[name="capacity"]');
        var descInput = form.querySelector('textarea[name="description"]');
        var seoTitleInput = form.querySelector('input[name="seo_title"]');
        var seoDescInput = form.querySelector('input[name="seo_description"]');

        var csrf = csrfInput ? csrfInput.value : '';
        var category = categoryInput ? categoryInput.value : 'villa';
        var locality = localityInput ? localityInput.value : '';
        var title = titleInput ? titleInput.value : '';
        var capacity = capacityInput ? capacityInput.value : '';

        var origHtml = btn.innerHTML;
        btn.disabled = true;
        btn.classList.add('ai-loading');
        btn.innerHTML = '<span class="ai-spinner">✨</span> Yapay zeka üretiyor...';

        var bodyData = new URLSearchParams();
        bodyData.append('csrf', csrf);
        bodyData.append('category_code', category);
        bodyData.append('locality', locality);
        bodyData.append('title', title);
        bodyData.append('capacity', capacity);
        bodyData.append('field', triggerType);
        bodyData.append('ajax', '1');

        fetch('/admin/ai/generate', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: bodyData.toString()
        })
          .then(function (res) {
            if (!res.ok) throw new Error('AI isteği başarısız oldu (' + res.status + ')');
            return res.json();
          })
          .then(function (data) {
            btn.disabled = false;
            btn.classList.remove('ai-loading');
            btn.innerHTML = '✓ Üretildi!';
            setTimeout(function () {
              btn.innerHTML = origHtml;
            }, 2500);

            if (triggerType === 'title' || triggerType === 'all') {
              if (titleInput && data.title) {
                titleInput.value = data.title;
                flashAiEffect(titleInput);
                titleInput.dispatchEvent(new Event('input', { bubbles: true }));
              }
            }

            if (triggerType === 'description' || triggerType === 'all') {
              if (descInput && data.description) {
                descInput.value = data.description;
                flashAiEffect(descInput);
                descInput.dispatchEvent(new Event('input', { bubbles: true }));
              }
            }

            if (triggerType === 'seo' || triggerType === 'all') {
              if (seoTitleInput && data.seo_title) {
                seoTitleInput.value = data.seo_title;
                flashAiEffect(seoTitleInput);
                seoTitleInput.dispatchEvent(new Event('input', { bubbles: true }));
              }
              if (seoDescInput && data.seo_description) {
                seoDescInput.value = data.seo_description;
                flashAiEffect(seoDescInput);
                seoDescInput.dispatchEvent(new Event('input', { bubbles: true }));
              }
            }

            showAiToast('✨ ' + (triggerType === 'title' ? 'İlan başlığı' : triggerType === 'description' ? 'Detaylı açıklama' : 'SEO ve meta verileri') + ' başarıyla üretildi!');
          })
          .catch(function (err) {
            console.error('AI error:', err);
            btn.disabled = false;
            btn.classList.remove('ai-loading');
            btn.innerHTML = '⚠️ Tekrar Dene';
            setTimeout(function () {
              btn.innerHTML = origHtml;
            }, 3000);
            showAiToast('Hata: ' + err.message, true);
          });
      });
    });

    function flashAiEffect(el) {
      el.classList.add('ai-highlight-flash');
      setTimeout(function () {
        el.classList.remove('ai-highlight-flash');
      }, 2000);
    }

    function showAiToast(msg, isError) {
      var toast = document.createElement('div');
      toast.className = 'ai-toast' + (isError ? ' error' : '');
      toast.textContent = msg;
      document.body.appendChild(toast);
      setTimeout(function () {
        toast.classList.add('show');
      }, 20);
      setTimeout(function () {
        toast.classList.remove('show');
        setTimeout(function () {
          if (toast.parentNode) toast.parentNode.removeChild(toast);
        }, 300);
      }, 3500);
    }

    // ==========================================================================
    // Media Uploader, AVIF Conversion & Video Preview
    // ==========================================================================
    function initMediaUploader() {
      var heroFileInput = document.getElementById('hero_file_input');
      var heroImageInput = document.getElementById('hero_image_input');
      var heroPreviewContainer = document.querySelector('.hero-preview-container');
      var heroPreviewImg = document.getElementById('hero_preview_img');

      var galleryFileInput = document.getElementById('gallery_file_input');
      var galleryImagesInput = document.getElementById('gallery_images_input');
      var galleryGrid = document.querySelector('.gallery-grid-items');

      var videoUrlInput = document.getElementById('video_url_input');
      var videoPreviewBox = document.querySelector('.video-preview-box');
      var videoPreviewFrame = document.querySelector('.video-preview-frame');
      var btnPreset = document.getElementById('btn-preset-photos');
      var btnAiSort = document.getElementById('btn-ai-sort-photos');
      var chkAutoSort = document.getElementById('chk-auto-ai-sort');
      var aiSortBanner = document.querySelector('.ai-sort-banner');

      // Cache of AI Metadata by URL: { rank, tag, score, reason, is_hero }
      var aiMetadataMap = {};

      function formatBytes(bytes) {
        if (!bytes) return '0 B';
        var k = 1024;
        var sizes = ['B', 'KB', 'MB', 'GB'];
        var i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
      }

      // Convert any image file to AVIF using Canvas API
      function convertToAvif(file) {
        return new Promise(function (resolve, reject) {
          var reader = new FileReader();
          reader.onload = function (e) {
            var img = new Image();
            img.onload = function () {
              var canvas = document.createElement('canvas');
              var width = img.width;
              var height = img.height;
              var maxDim = 1920;
              if (width > maxDim || height > maxDim) {
                if (width > height) {
                  height = Math.round((height * maxDim) / width);
                  width = maxDim;
                } else {
                  width = Math.round((width * maxDim) / height);
                  height = maxDim;
                }
              }
              canvas.width = width;
              canvas.height = height;
              var ctx = canvas.getContext('2d');
              ctx.drawImage(img, 0, 0, width, height);

              // Check for AVIF canvas support
              var supportsAvif = false;
              try {
                supportsAvif = canvas.toDataURL('image/avif').indexOf('data:image/avif') === 0;
              } catch (e) {
                supportsAvif = false;
              }

              if (supportsAvif) {
                canvas.toBlob(function (blob) {
                  if (blob && blob.size > 0) {
                    var r = new FileReader();
                    r.onloadend = function () {
                      resolve({
                        dataUrl: r.result,
                        width: width,
                        height: height,
                        format: 'avif',
                        origSize: file.size,
                        newSize: blob.size
                      });
                    };
                    r.readAsDataURL(blob);
                  } else {
                    fallbackWebp();
                  }
                }, 'image/avif', 0.85);
              } else {
                fallbackWebp();
              }

              function fallbackWebp() {
                canvas.toBlob(function (blob) {
                  var r = new FileReader();
                  r.onloadend = function () {
                    resolve({
                      dataUrl: r.result,
                      width: width,
                      height: height,
                      format: 'webp',
                      origSize: file.size,
                      newSize: blob ? blob.size : file.size
                    });
                  };
                  r.readAsDataURL(blob || file);
                }, 'image/webp', 0.85);
              }
            };
            img.onerror = reject;
            img.src = e.target.result;
          };
          reader.onerror = reject;
          reader.readAsDataURL(file);
        });
      }

      function uploadImageData(base64Data, csrf) {
        var body = new URLSearchParams();
        body.append('csrf', csrf);
        body.append('data', base64Data);
        return fetch('/admin/media/upload', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: body.toString()
        }).then(function (res) {
          if (!res.ok) throw new Error('Yükleme başarısız (' + res.status + ')');
          return res.json();
        });
      }

      // AI Smart Image Sorting Engine
      function aiSortPhotos(isAuto) {
        var heroVal = (heroImageInput ? heroImageInput.value : '').trim();
        var galleryVal = (galleryImagesInput ? galleryImagesInput.value : '').trim();

        if (!heroVal && !galleryVal) {
          if (!isAuto) showAiToast('Sıralanacak görsel bulunamadı. Lütfen önce fotoğraf ekleyin.', true);
          return Promise.resolve();
        }

        var form = document.querySelector('.editor-form') || (heroImageInput ? heroImageInput.closest('form') : null);
        var csrf = (form ? form.querySelector('input[name="csrf"]') : null);
        var catInput = (form ? form.querySelector('input[name="category_code"]') : null);
        var category = catInput ? catInput.value : 'villa';

        var origHtml = '';
        if (btnAiSort && !isAuto) {
          origHtml = btnAiSort.innerHTML;
          btnAiSort.disabled = true;
          btnAiSort.classList.add('ai-loading');
          btnAiSort.innerHTML = '<span class="ai-spinner">✨</span> AI Görselleri Sıralıyor...';
        }

        var body = new URLSearchParams();
        body.append('csrf', csrf ? csrf.value : '');
        body.append('category_code', category);
        body.append('hero_image', heroVal);
        body.append('gallery_images', galleryVal);
        body.append('ajax', '1');

        return fetch('/admin/ai/sort_photos', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: body.toString()
        })
          .then(function (res) {
            if (!res.ok) throw new Error('Yapay zeka sıralama isteği başarısız oldu (' + res.status + ')');
            return res.json();
          })
          .then(function (data) {
            if (btnAiSort && !isAuto) {
              btnAiSort.disabled = false;
              btnAiSort.classList.remove('ai-loading');
              btnAiSort.innerHTML = '✓ AI ile Sıralandı!';
              setTimeout(function () {
                btnAiSort.innerHTML = origHtml;
              }, 2500);
            }

            if (data && data.success) {
              // Cache AI Rank Metadata
              aiMetadataMap = {};
              if (data.ranked_items && data.ranked_items.length) {
                data.ranked_items.forEach(function (item) {
                  aiMetadataMap[item.url] = item;
                });
              }

              // Update Hero Image
              if (data.recommended_hero && heroImageInput) {
                heroImageInput.value = data.recommended_hero;
                if (heroPreviewImg) heroPreviewImg.src = data.recommended_hero;
                if (heroPreviewContainer) heroPreviewContainer.classList.remove('hidden');
              }

              // Update Gallery
              if (galleryImagesInput && data.sorted_gallery) {
                galleryImagesInput.value = data.sorted_gallery.join('\n');
                renderGalleryThumbs();
              }

              // Show AI Notification Banner
              if (aiSortBanner) {
                aiSortBanner.classList.remove('hidden');
                var descEl = aiSortBanner.querySelector('.ai-sort-desc');
                if (descEl && data.ranked_items && data.ranked_items.length) {
                  var storyFlow = data.ranked_items.map(function (r) {
                    return r.tag.replace(/ \(Kapak\)/g, '');
                  }).slice(0, 4).join(' ➔ ');
                  descEl.textContent = 'Görselleriniz OTA standartlarına göre sıralandı: ' + storyFlow;
                }
              }

              showAiToast('✨ Görseller yapay zeka ile platform standartlarına göre sıralandı!');
            }
          })
          .catch(function (err) {
            console.error('AI Sort Error:', err);
            if (btnAiSort && !isAuto) {
              btnAiSort.disabled = false;
              btnAiSort.classList.remove('ai-loading');
              btnAiSort.innerHTML = '⚠️ Tekrar Dene';
              setTimeout(function () {
                btnAiSort.innerHTML = origHtml;
              }, 2500);
            }
            if (!isAuto) showAiToast('Sıralama hatası: ' + err.message, true);
          });
      }

      // Render Gallery Thumbnails with AI Badges and Ordering Controls
      function renderGalleryThumbs() {
        if (!galleryGrid || !galleryImagesInput) return;
        galleryGrid.innerHTML = '';
        var urls = galleryImagesInput.value
          .split(/[\n,]+/)
          .map(function (s) { return s.trim(); })
          .filter(Boolean);

        urls.forEach(function (url, idx) {
          var item = document.createElement('div');
          item.className = 'gallery-thumb-item';
          var isAvif = url.indexOf('.avif') !== -1;
          var meta = aiMetadataMap[url];

          var rankBadgeHtml = '';
          var tagBadgeHtml = '';
          if (meta) {
            rankBadgeHtml = '<span class="gallery-thumb-rank" title="' + (meta.reason || '') + '">#' + meta.rank + ' (' + meta.score + ')</span>';
            tagBadgeHtml = '<span class="gallery-thumb-tag">' + meta.tag + '</span>';
          } else {
            rankBadgeHtml = '<span class="gallery-thumb-rank default">#' + (idx + 2) + '</span>';
          }

          item.innerHTML =
            '<div class="gallery-thumb-img-wrap">' +
              '<img src="' + url + '" alt="Galeri ' + (idx + 1) + '">' +
              rankBadgeHtml +
              tagBadgeHtml +
              (isAvif ? '<span class="gallery-thumb-format">AVIF</span>' : '') +
            '</div>' +
            '<div class="gallery-thumb-actions">' +
              '<button type="button" class="thumb-btn-act btn-make-hero" data-idx="' + idx + '" title="Bu görseli ana kapak yap">⭐ Kapak Yap</button>' +
              '<div class="thumb-btn-group-nav">' +
                '<button type="button" class="thumb-btn-act btn-move-left" data-idx="' + idx + '" title="Öne Taşı" ' + (idx === 0 ? 'disabled' : '') + '>◀</button>' +
                '<button type="button" class="thumb-btn-act btn-move-right" data-idx="' + idx + '" title="Arkaya Taşı" ' + (idx === urls.length - 1 ? 'disabled' : '') + '>▶</button>' +
                '<button type="button" class="thumb-btn-act btn-del" data-idx="' + idx + '" title="Sil">✕</button>' +
              '</div>' +
            '</div>';

          // Make Hero Handler
          var btnMakeHero = item.querySelector('.btn-make-hero');
          if (btnMakeHero) {
            btnMakeHero.addEventListener('click', function (e) {
              e.preventDefault();
              var oldHero = (heroImageInput ? heroImageInput.value : '').trim();
              var chosen = urls[idx];

              if (oldHero) {
                urls[idx] = oldHero;
              } else {
                urls.splice(idx, 1);
              }

              if (heroImageInput) {
                heroImageInput.value = chosen;
                if (heroPreviewImg) heroPreviewImg.src = chosen;
                if (heroPreviewContainer) heroPreviewContainer.classList.remove('hidden');
              }
              galleryImagesInput.value = urls.join('\n');
              renderGalleryThumbs();
              showAiToast('⭐ Kapak görseli güncellendi!');
            });
          }

          // Move Left Handler
          var btnMoveLeft = item.querySelector('.btn-move-left');
          if (btnMoveLeft && idx > 0) {
            btnMoveLeft.addEventListener('click', function (e) {
              e.preventDefault();
              var tmp = urls[idx];
              urls[idx] = urls[idx - 1];
              urls[idx - 1] = tmp;
              galleryImagesInput.value = urls.join('\n');
              renderGalleryThumbs();
            });
          }

          // Move Right Handler
          var btnMoveRight = item.querySelector('.btn-move-right');
          if (btnMoveRight && idx < urls.length - 1) {
            btnMoveRight.addEventListener('click', function (e) {
              e.preventDefault();
              var tmp = urls[idx];
              urls[idx] = urls[idx + 1];
              urls[idx + 1] = tmp;
              galleryImagesInput.value = urls.join('\n');
              renderGalleryThumbs();
            });
          }

          // Delete Handler
          var btnDel = item.querySelector('.btn-del');
          if (btnDel) {
            btnDel.addEventListener('click', function (e) {
              e.preventDefault();
              urls.splice(idx, 1);
              galleryImagesInput.value = urls.join('\n');
              renderGalleryThumbs();
              showAiToast('Görsel galeriden kaldırıldı.');
            });
          }

          galleryGrid.appendChild(item);
        });
      }

      // Hero Image Input & Preview
      if (heroImageInput) {
        heroImageInput.addEventListener('input', function () {
          var val = heroImageInput.value.trim();
          if (val && heroPreviewImg && heroPreviewContainer) {
            heroPreviewImg.src = val;
            heroPreviewContainer.classList.remove('hidden');
          } else if (heroPreviewContainer) {
            heroPreviewContainer.classList.add('hidden');
          }
        });
      }

      if (heroFileInput) {
        heroFileInput.addEventListener('change', function (e) {
          var file = e.target.files[0];
          if (!file) return;
          var dropzone = heroFileInput.closest('.media-dropzone');
          if (dropzone) dropzone.style.opacity = '0.5';

          showAiToast('⚡ Kapak fotoğrafı AVIF formatına dönüştürülüyor...');
          convertToAvif(file)
            .then(function (res) {
              var csrf = (document.querySelector('input[name="csrf"]') || {}).value || '';
              showAiToast('💾 AVIF optimize edildi (' + formatBytes(res.origSize) + ' ➔ ' + formatBytes(res.newSize) + '). Yükleniyor...');
              return uploadImageData(res.dataUrl, csrf);
            })
            .then(function (data) {
              if (dropzone) dropzone.style.opacity = '1';
              if (data.success && data.url) {
                heroImageInput.value = data.url;
                if (heroPreviewImg) heroPreviewImg.src = data.url;
                if (heroPreviewContainer) heroPreviewContainer.classList.remove('hidden');

                if (data.bunny_saved) {
                  showAiToast('☁️ Kapak görseli BunnyCDN ve yerel diske başarıyla kaydedildi!');
                } else {
                  showAiToast('📁 Kapak görseli AVIF olarak yerel diske başarıyla kaydedildi!');
                }

                if (chkAutoSort && chkAutoSort.checked && galleryImagesInput && galleryImagesInput.value.trim()) {
                  aiSortPhotos(true);
                }
              }
            })
            .catch(function (err) {
              if (dropzone) dropzone.style.opacity = '1';
              console.error('Hero AVIF upload error:', err);
              showAiToast('Görsel yüklenemedi: ' + err.message, true);
            });
        });
      }

      // Gallery Multi-File Upload with Auto AI Sorting
      if (galleryFileInput) {
        galleryFileInput.addEventListener('change', function (e) {
          var files = Array.from(e.target.files);
          if (!files.length) return;
          var dropzone = galleryFileInput.closest('.media-dropzone');
          if (dropzone) dropzone.style.opacity = '0.5';

          showAiToast('⚡ ' + files.length + ' adet fotoğraf taranıp AVIF formatına dönüştürülüyor...');
          var csrf = (document.querySelector('input[name="csrf"]') || {}).value || '';

          Promise.all(
            files.map(function (file) {
              return convertToAvif(file).then(function (res) {
                return uploadImageData(res.dataUrl, csrf);
              });
            })
          )
            .then(function (results) {
              if (dropzone) dropzone.style.opacity = '1';
              var added = 0;
              var existing = galleryImagesInput.value ? galleryImagesInput.value.split('\n') : [];
              results.forEach(function (r) {
                if (r && r.success && r.url) {
                  existing.push(r.url);
                  added++;
                }
              });
              galleryImagesInput.value = existing.join('\n');
              renderGalleryThumbs();
              var anyBunny = results.some(function (r) { return r && r.bunny_saved; });
              if (anyBunny) {
                showAiToast('☁️ ' + added + ' fotoğraf BunnyCDN ve yerel diske AVIF formatında eklendi!');
              } else {
                showAiToast('📁 ' + added + ' fotoğraf yerel diske AVIF formatında eklendi!');
              }

              // Automatic AI Sorting trigger if enabled
              if (chkAutoSort && chkAutoSort.checked) {
                showAiToast('🤖 Yapay zeka fotoğrafları analiz edip sıralıyor...');
                setTimeout(function () {
                  aiSortPhotos(true);
                }, 500);
              }
            })
            .catch(function (err) {
              if (dropzone) dropzone.style.opacity = '1';
              console.error('Gallery batch upload error:', err);
              showAiToast('Galeri yükleme hatası: ' + err.message, true);
            });
        });
      }

      if (galleryImagesInput) {
        galleryImagesInput.addEventListener('input', renderGalleryThumbs);
        renderGalleryThumbs();
      }

      // AI Sort Button Trigger
      if (btnAiSort) {
        btnAiSort.addEventListener('click', function (e) {
          e.preventDefault();
          aiSortPhotos(false);
        });
      }

      // Video Preview
      function updateVideoPreview(url) {
        if (!videoPreviewBox || !videoPreviewFrame) return;
        var trimmed = (url || '').trim();
        if (!trimmed) {
          videoPreviewBox.classList.add('hidden');
          videoPreviewFrame.innerHTML = '';
          return;
        }
        videoPreviewBox.classList.remove('hidden');

        var isYouTube = trimmed.indexOf('youtube.com') !== -1 || trimmed.indexOf('youtu.be') !== -1;
        var isVimeo = trimmed.indexOf('vimeo.com') !== -1;

        if (isYouTube) {
          var vid = '';
          if (trimmed.indexOf('v=') !== -1) {
            vid = trimmed.split('v=')[1].split('&')[0];
          } else if (trimmed.indexOf('youtu.be/') !== -1) {
            vid = trimmed.split('youtu.be/')[1].split('?')[0];
          }
          if (vid) {
            videoPreviewFrame.innerHTML =
              '<iframe src="https://www.youtube-nocookie.com/embed/' +
              vid +
              '" allowfullscreen frameborder="0" style="width:100%;height:100%;"></iframe>';
          }
        } else if (isVimeo) {
          var parts = trimmed.split('/');
          var vimeoId = parts[parts.length - 1];
          if (vimeoId) {
            videoPreviewFrame.innerHTML =
              '<iframe src="https://player.vimeo.com/video/' +
              vimeoId +
              '" allowfullscreen frameborder="0" style="width:100%;height:100%;"></iframe>';
          }
        } else {
          videoPreviewFrame.innerHTML =
            '<video controls src="' + trimmed + '" style="width:100%;height:100%;"></video>';
        }
      }

      if (videoUrlInput) {
        videoUrlInput.addEventListener('input', function () {
          updateVideoPreview(videoUrlInput.value);
        });
        if (videoUrlInput.value) {
          updateVideoPreview(videoUrlInput.value);
        }
      }

      // Category Preset Photos & Video
      if (btnPreset) {
        btnPreset.addEventListener('click', function (e) {
          e.preventDefault();
          var cat = btnPreset.getAttribute('data-category') || 'villa';
          var presets = {
            villa: {
              hero: 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80',
              gallery: [
                'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1000&q=80',
                'https://images.unsplash.com/photo-1613977257363-707ba9348227?auto=format&fit=crop&w=1000&q=80',
                'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=1000&q=80'
              ],
              video: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
            },
            hotel: {
              hero: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80',
              gallery: [
                'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1000&q=80',
                'https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1000&q=80',
                'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1000&q=80'
              ],
              video: 'https://www.youtube.com/watch?v=ScMzIvxBSi4'
            },
            yacht: {
              hero: 'https://images.unsplash.com/photo-1569263979104-865ab7cd8d13?auto=format&fit=crop&w=1200&q=80',
              gallery: [
                'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1000&q=80',
                'https://images.unsplash.com/photo-1506929562872-bb421503ef21?auto=format&fit=crop&w=1000&q=80'
              ],
              video: 'https://www.youtube.com/watch?v=ScMzIvxBSi4'
            },
            car: {
              hero: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=80',
              gallery: [
                'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1000&q=80',
                'https://images.unsplash.com/photo-1542282088-72c9c27ed0cd?auto=format&fit=crop&w=1000&q=80'
              ],
              video: ''
            }
          };

          var set = presets[cat] || presets.villa;
          if (heroImageInput) heroImageInput.value = set.hero;
          if (heroPreviewImg) heroPreviewImg.src = set.hero;
          if (heroPreviewContainer) heroPreviewContainer.classList.remove('hidden');

          if (galleryImagesInput) {
            galleryImagesInput.value = set.gallery.join('\n');
            renderGalleryThumbs();
          }

          if (videoUrlInput && set.video) {
            videoUrlInput.value = set.video;
            updateVideoPreview(set.video);
          }

          showAiToast('✨ Kategoriye (' + cat.toUpperCase() + ') özel örnek fotoğraflar ve video yerleştirildi!');

          // Automatic AI sorting on preset
          setTimeout(function () {
            aiSortPhotos(true);
          }, 300);
        });
      }
    }

    initMediaUploader();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initEditor);
  } else {
    initEditor();
  }
})();
