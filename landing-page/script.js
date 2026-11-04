/* MediQ — landing page interactions (no dependencies). */
(function () {
  'use strict';

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------------------------- Sticky header --------------------------- */
  var header = document.getElementById('siteHeader');
  var ticking = false;

  function updateHeader() {
    if (!header) return;
    header.classList.toggle('is-scrolled', window.scrollY > 12);
    ticking = false;
  }

  window.addEventListener('scroll', function () {
    if (!ticking) {
      ticking = true;
      window.requestAnimationFrame(updateHeader);
    }
  }, { passive: true });

  updateHeader();

  /* ---------------------------- Mobile drawer --------------------------- */
  var menuToggle = document.getElementById('menuToggle');
  var menu = document.getElementById('mobileMenu');
  var lastFocused = null;

  function menuIsOpen() {
    return !!menu && menu.classList.contains('is-open');
  }

  function setMenu(open, returnFocus) {
    if (!menu || !menuToggle) return;

    menu.classList.toggle('is-open', open);
    menu.inert = !open;
    menu.setAttribute('aria-hidden', String(!open));
    menuToggle.setAttribute('aria-expanded', String(open));
    menuToggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    document.body.classList.toggle('menu-open', open);

    if (open) {
      lastFocused = document.activeElement;
      var firstLink = menu.querySelector('a');
      if (firstLink) {
        window.setTimeout(function () {
          firstLink.focus({ preventScroll: true });
        }, 120);
      }
    } else if (returnFocus !== false && lastFocused && typeof lastFocused.focus === 'function') {
      lastFocused.focus({ preventScroll: true });
    }
  }

  if (menuToggle && menu) {
    menuToggle.addEventListener('click', function () {
      setMenu(!menuIsOpen());
    });

    menu.addEventListener('click', function (event) {
      if (event.target.closest('a')) setMenu(false, false);
    });

    document.addEventListener('click', function (event) {
      if (!menuIsOpen()) return;
      if (menu.contains(event.target) || menuToggle.contains(event.target)) return;
      setMenu(false);
    });

    document.addEventListener('keydown', function (event) {
      if (!menuIsOpen()) return;

      if (event.key === 'Escape') {
        event.preventDefault();
        setMenu(false);
        return;
      }

      if (event.key !== 'Tab') return;

      var focusable = menu.querySelectorAll('a[href], button:not([disabled])');
      if (!focusable.length) return;

      var first = focusable[0];
      var last = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    });

    window.addEventListener('resize', function () {
      if (window.innerWidth > 980 && menuIsOpen()) setMenu(false, false);
    });
  }

  /* ------------------------------ Role tabs ----------------------------- */
  var tabs = Array.prototype.slice.call(document.querySelectorAll('.role-tab'));

  function activateTab(tab, focus) {
    tabs.forEach(function (item) {
      var selected = item === tab;
      var panel = document.getElementById(item.getAttribute('aria-controls'));

      item.setAttribute('aria-selected', String(selected));
      item.tabIndex = selected ? 0 : -1;
      if (panel) panel.hidden = !selected;
    });

    if (focus) tab.focus();
  }

  if (tabs.length) {
    tabs.forEach(function (tab, index) {
      tab.addEventListener('click', function () {
        activateTab(tab, false);
      });

      tab.addEventListener('keydown', function (event) {
        var next = null;

        if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
          next = tabs[(index + 1) % tabs.length];
        } else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
          next = tabs[(index - 1 + tabs.length) % tabs.length];
        } else if (event.key === 'Home') {
          next = tabs[0];
        } else if (event.key === 'End') {
          next = tabs[tabs.length - 1];
        }

        if (next) {
          event.preventDefault();
          activateTab(next, true);
        }
      });
    });
  }

  /* ------------------------------ Scroll spy ---------------------------- */
  var navLinks = Array.prototype.slice.call(document.querySelectorAll('[data-nav]'));
  var sections = navLinks
    .map(function (link) {
      return document.getElementById(link.getAttribute('data-nav'));
    })
    .filter(Boolean);

  if ('IntersectionObserver' in window && sections.length) {
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var id = entry.target.id;

        navLinks.forEach(function (link) {
          var active = link.getAttribute('data-nav') === id;
          link.classList.toggle('is-active', active);
          if (active) {
            link.setAttribute('aria-current', 'true');
          } else {
            link.removeAttribute('aria-current');
          }
        });
      });
    }, { rootMargin: '-45% 0px -50% 0px', threshold: 0 });

    sections.forEach(function (section) {
      spy.observe(section);
    });
  }

  /* --------------------------- Reveal on scroll ------------------------- */
  var revealItems = Array.prototype.slice.call(document.querySelectorAll('.reveal'));

  if (reduceMotion || !('IntersectionObserver' in window)) {
    revealItems.forEach(function (item) {
      item.classList.add('is-visible');
    });
  } else {
    var revealObserver = new IntersectionObserver(function (entries, observer) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

    revealItems.forEach(function (item) {
      revealObserver.observe(item);
    });
  }

  /* ------------------------- Single-open accordion ---------------------- */
  var faqItems = Array.prototype.slice.call(document.querySelectorAll('.faq-item'));

  faqItems.forEach(function (item) {
    item.addEventListener('toggle', function () {
      if (!item.open) return;
      faqItems.forEach(function (other) {
        if (other !== item) other.open = false;
      });
    });
  });

  /* -------------------------------- Year -------------------------------- */
  var year = document.getElementById('year');
  if (year) year.textContent = String(new Date().getFullYear());
})();
