/* EquipSeva — global JS
   GSAP + ScrollTrigger + Lenis smooth scroll + nav + reveal + counters
*/
(function () {
  const ready = (fn) => document.readyState !== 'loading' ? fn() : document.addEventListener('DOMContentLoaded', fn);

  // ---------- year stamp ----------
  ready(() => {
    const y = document.getElementById('year');
    if (y) y.textContent = new Date().getFullYear();
  });

  // ---------- nav scroll state + mobile burger ----------
  ready(() => {
    const nav = document.getElementById('nav');
    const setNav = () => nav && nav.classList.toggle('scrolled', window.scrollY > 8);
    setNav();
    window.addEventListener('scroll', setNav, { passive: true });

    const burger = document.querySelector('.burger');
    const menu = document.querySelector('.mobile-menu');
    if (burger && menu) {
      burger.addEventListener('click', () => menu.classList.toggle('open'));
      menu.querySelectorAll('a').forEach(a => a.addEventListener('click', () => menu.classList.remove('open')));
    }
  });

  // ---------- wait for GSAP & Lenis to load (deferred scripts) ----------
  function whenReady(check, cb, tries = 100) {
    if (check()) return cb();
    if (tries <= 0) return;
    setTimeout(() => whenReady(check, cb, tries - 1), 50);
  }

  whenReady(() => window.gsap && window.ScrollTrigger && window.Lenis, () => {
    const { gsap, ScrollTrigger, Lenis } = window;
    gsap.registerPlugin(ScrollTrigger);

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    // ---------- Lenis smooth scroll ----------
    const lenis = new Lenis({
      duration: 1.15,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      smoothWheel: true,
    });
    function raf(time) { lenis.raf(time); requestAnimationFrame(raf); }
    requestAnimationFrame(raf);
    lenis.on('scroll', ScrollTrigger.update);

    // hash navigation (cross-page-safe)
    document.querySelectorAll('a[href^="#"]').forEach(a => {
      a.addEventListener('click', (e) => {
        const id = a.getAttribute('href');
        if (!id || id === '#') return;
        const el = document.querySelector(id);
        if (el) { e.preventDefault(); lenis.scrollTo(el, { offset: -80 }); }
      });
    });

    // ---------- progress bar ----------
    const bar = document.querySelector('.scroll-progress span');
    if (bar) {
      ScrollTrigger.create({
        start: 0, end: 'max',
        onUpdate: self => { bar.style.width = (self.progress * 100) + '%'; },
      });
    }

    if (reduced) {
      document.querySelectorAll('.reveal,.split-up').forEach(el => { el.style.opacity = 1; el.style.transform = 'none'; });
      return;
    }

    // ---------- hero split-up entrance ----------
    gsap.utils.toArray('.split-up').forEach((el, i) => {
      gsap.to(el, {
        opacity: 1, y: 0, duration: 0.9, ease: 'power3.out',
        delay: 0.15 + i * 0.08,
      });
    });

    // ---------- universal reveal on scroll ----------
    gsap.utils.toArray('.reveal').forEach((el) => {
      gsap.to(el, {
        opacity: 1, y: 0, duration: 0.8, ease: 'power3.out',
        scrollTrigger: { trigger: el, start: 'top 88%', once: true },
      });
    });

    // ---------- stat counters ----------
    document.querySelectorAll('[data-counter]').forEach(node => {
      const target = parseFloat(node.dataset.counter);
      const dec = parseInt(node.dataset.decimal || '0', 10);
      const suffix = node.dataset.suffix || '';
      const obj = { v: 0 };
      ScrollTrigger.create({
        trigger: node, start: 'top 90%', once: true,
        onEnter: () => gsap.to(obj, {
          v: target, duration: 1.6, ease: 'power2.out',
          onUpdate: () => {
            const v = dec ? (Math.floor(obj.v) + '.' + Math.floor((obj.v % 1) * 10)) : Math.floor(obj.v);
            node.textContent = v + suffix;
          },
        }),
      });
    });

    // ---------- hero phone parallax ----------
    const phone = document.querySelector('.hero-phone');
    if (phone) {
      gsap.to(phone, {
        y: -40,
        scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true },
      });
    }

    // ---------- pinned steps (how it works) ----------
    const stepsWrap = document.getElementById('steps');
    if (stepsWrap) {
      const stepEls = stepsWrap.querySelectorAll('.step');
      const screens = stepsWrap.querySelectorAll('.ss');
      stepEls.forEach((step, i) => {
        ScrollTrigger.create({
          trigger: step, start: 'top 60%', end: 'bottom 60%',
          onEnter: () => activate(i),
          onEnterBack: () => activate(i),
        });
      });
      function activate(i) {
        stepEls.forEach((s, k) => s.classList.toggle('active', k === i));
        screens.forEach((s, k) => s.classList.toggle('active', k === i));
      }
    }

    // ---------- feature cards stagger ----------
    const grid = document.querySelector('.feature-grid');
    if (grid) {
      gsap.from(grid.children, {
        y: 30, opacity: 0, duration: 0.7, ease: 'power3.out', stagger: 0.08,
        scrollTrigger: { trigger: grid, start: 'top 80%', once: true },
      });
    }

    // ---------- background blobs gentle parallax ----------
    gsap.utils.toArray('.blob').forEach((b, i) => {
      gsap.to(b, {
        y: i % 2 ? 80 : -80, x: i % 2 ? -40 : 40,
        scrollTrigger: { trigger: b.closest('.hero, .page-hero') || document.body, start: 'top top', end: 'bottom top', scrub: true },
      });
    });

    // refresh after fonts load
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(() => ScrollTrigger.refresh());
    }
  });
})();
