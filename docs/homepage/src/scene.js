import * as THREE from "three";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";
import { createHandWorld, createCityWorld } from "./worlds.js";

// Content/navigation remain usable without WebGL. No remote assets or analytics.
const reduced = matchMedia("(prefers-reduced-motion: reduce)");
const sections = [...document.querySelectorAll(".chapter")];
const stageLinks = [...document.querySelectorAll(".chapter-track a")];
const menu = document.querySelector("#chapter-menu");
const menuToggle = document.querySelector(".menu-toggle");
const motionToggle = document.querySelector("#motion-toggle");
const soundToggle = document.querySelector("#sound-toggle");
let paused = reduced.matches;
let stage = 0;
let target = 0;
let onScroll = () => {};

function closeMenu(restoreFocus = false) {
  menu.hidden = true;
  menuToggle.setAttribute("aria-expanded", "false");
  menuToggle.setAttribute("aria-label", "Open chapter menu");
  document.body.classList.remove("menu-open");
  if (restoreFocus) menuToggle.focus();
}
menuToggle.hidden = false;
document.querySelector(".no-script-menu").hidden = true;
menuToggle.addEventListener("click", () => {
  if (!menu.hidden) return closeMenu(true);
  menu.hidden = false;
  menuToggle.setAttribute("aria-expanded", "true");
  menuToggle.setAttribute("aria-label", "Close chapter menu");
  document.body.classList.add("menu-open");
  menu.querySelector("a").focus();
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !menu.hidden) closeMenu(true);
});
document.addEventListener("pointerdown", (e) => {
  if (
    !menu.hidden &&
    !menu.contains(e.target) &&
    !menuToggle.contains(e.target)
  )
    closeMenu();
});
menu.querySelectorAll("a").forEach((link) =>
  link.addEventListener("click", () => {
    closeMenu();
    const heading = document.querySelector(link.hash)?.querySelector("h1,h2");
    if (heading) {
      heading.tabIndex = -1;
      heading.focus({ preventScroll: true });
    }
  }),
);

function readScroll() {
  const offsets = sections.map((section) => section.offsetTop);
  let current = 0;
  for (let i = 0; i < offsets.length; i++)
    if (scrollY >= offsets[i]) current = i;
  const next = Math.min(current + 1, offsets.length - 1);
  const distance =
    next === current
      ? sections[current].offsetHeight
      : offsets[next] - offsets[current];
  target = Math.min(
    4,
    current + Math.max(0, (scrollY - offsets[current]) / distance),
  );
  const nearest = Math.min(4, Math.round(target));
  if (stage !== nearest) {
    stage = nearest;
    stageLinks.forEach((link, index) => {
      if (index === stage) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    });
    document.querySelector(".scene-index").textContent = [
      "001 — THE BEGINNING",
      "002 — HOSPITALS",
      "003 — ENGINEERS",
      "004 — TEAMS",
      "005 — CONNECT",
    ][stage];
  }
  onScroll();
}
window.addEventListener("scroll", readScroll, { passive: true });
window.addEventListener("resize", readScroll, { passive: true });

// An original generative ambient score. No recordings/samples from the reference.
// Deliberate opt-in only; pause when hidden, and never auto-resume sound on return.
let audio;
let master;
let soundOn = false;
let audioBusy = false;
function updateSoundButton() {
  soundToggle.setAttribute("aria-pressed", String(soundOn));
  soundToggle.querySelector(".sound-label").textContent = soundOn
    ? "Sound on"
    : "Sound off";
}
function createScore() {
  audio = new (window.AudioContext || window.webkitAudioContext)();
  master = audio.createGain();
  master.gain.value = 0;
  const compressor = audio.createDynamicsCompressor();
  compressor.threshold.value = -20;
  compressor.ratio.value = 5;
  master.connect(compressor).connect(audio.destination);
  const filter = audio.createBiquadFilter();
  filter.type = "lowpass";
  filter.frequency.value = 650;
  filter.Q.value = 0.3;
  filter.connect(master);
  const delay = audio.createDelay(2);
  delay.delayTime.value = 0.67;
  const feedback = audio.createGain();
  feedback.gain.value = 0.25;
  delay.connect(feedback).connect(delay);
  delay.connect(master);
  // A suspended open F-sharp minor/ninth chord, with slow beating harmonics.
  [92.499, 138.591, 184.997, 219.999, 277.183, 415.305].forEach(
    (frequency, index) => {
      const oscillator = audio.createOscillator();
      oscillator.type = index < 2 ? "sine" : "triangle";
      oscillator.frequency.value = frequency;
      oscillator.detune.value = index % 2 ? 3 : -3;
      const voice = audio.createGain();
      voice.gain.value = 0.07 / (index + 1);
      oscillator.connect(voice).connect(filter);
      voice.connect(delay);
      const drift = audio.createOscillator();
      drift.frequency.value = 0.04 + index * 0.013;
      const amount = audio.createGain();
      amount.gain.value = 0.006 / (index + 1);
      drift.connect(amount).connect(voice.gain);
      oscillator.start();
      drift.start();
    },
  );
}
if (window.AudioContext || window.webkitAudioContext)
  soundToggle.hidden = false;
soundToggle.addEventListener("click", async () => {
  if (audioBusy) return;
  audioBusy = true;
  try {
    if (!audio) createScore();
    if (soundOn) {
      master.gain.cancelScheduledValues(audio.currentTime);
      master.gain.setTargetAtTime(0, audio.currentTime, 0.12);
      soundOn = false;
      await audio.suspend();
    } else {
      await audio.resume();
      if (document.hidden) {
        await audio.suspend();
        soundOn = false;
      } else {
        master.gain.cancelScheduledValues(audio.currentTime);
        master.gain.setTargetAtTime(0.7, audio.currentTime, 1.2);
        soundOn = audio.state === "running";
      }
    }
  } catch {
    soundOn = false;
    if (master && audio) master.gain.setValueAtTime(0, audio.currentTime);
  } finally {
    updateSoundButton();
    audioBusy = false;
  }
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden && audio) {
    soundOn = false;
    master.gain.cancelScheduledValues(audio.currentTime);
    master.gain.setValueAtTime(0, audio.currentTime);
    audio.suspend().catch(() => {});
    updateSoundButton();
  }
});
window.addEventListener("pagehide", () => {
  soundOn = false;
  if (audio && master) {
    master.gain.cancelScheduledValues(audio.currentTime);
    master.gain.setValueAtTime(0, audio.currentTime);
    audio.suspend().catch(() => {});
  }
  updateSoundButton();
});

const canvas = document.querySelector("#care-scene");
const host = document.querySelector(".world");
let renderer;
try {
  renderer = new THREE.WebGLRenderer({
    canvas,
    alpha: true,
    antialias: true,
    powerPreference: "low-power",
  });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.9;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(39, 1, 0.1, 70);
  const environmentScene = new RoomEnvironment();
  const pmrem = new THREE.PMREMGenerator(renderer);
  const environment = pmrem.fromScene(environmentScene, 0.025);
  scene.environment = environment.texture;
  environmentScene.dispose();
  pmrem.dispose();
  const key = new THREE.DirectionalLight(0xf0ffe5, 3.8);
  key.position.set(-4, 7, 5);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0xbfff4f, 3);
  rim.position.set(5, 1, -2);
  scene.add(rim);
  scene.add(new THREE.HemisphereLight(0xaccfb6, 0x061408, 1.2));
  const hand = createHandWorld(THREE);
  const city = createCityWorld(THREE);
  scene.add(hand.group, city.group);
  // Original equipment monitor for the hospital chapter.
  const monitor = new THREE.Group();
  const shell = new THREE.MeshStandardMaterial({
    color: 0x637d70,
    metalness: 0.9,
    roughness: 0.22,
  });
  const dark = new THREE.MeshStandardMaterial({
    color: 0x071811,
    metalness: 0.4,
    roughness: 0.24,
  });
  const glow = new THREE.MeshStandardMaterial({
    color: 0xc3f53c,
    emissive: 0x92b52c,
    emissiveIntensity: 1.3,
  });
  const housing = new THREE.Mesh(
    new RoundedBoxGeometry(3.6, 2.7, 0.55, 4, 0.17),
    shell,
  );
  monitor.add(housing);
  const screen = new THREE.Mesh(
    new RoundedBoxGeometry(3.23, 2.2, 0.06, 4, 0.14),
    dark,
  );
  screen.position.set(0, 0.03, 0.3);
  monitor.add(screen);
  const wave = [
    [-1.35, 0],
    [-0.9, 0],
    [-0.75, 0.16],
    [-0.62, -0.2],
    [-0.42, 0.8],
    [-0.22, -0.55],
    [-0.03, 0.1],
    [0.2, 0],
    [1.3, 0],
  ];
  const pulsePoints = wave.map(([x, y]) => new THREE.Vector3(x, y, 0.36));
  for (let i = 1; i < pulsePoints.length; i++) {
    const a = pulsePoints[i - 1],
      b = pulsePoints[i];
    const tube = new THREE.Mesh(
      new THREE.CylinderGeometry(0.022, 0.022, a.distanceTo(b), 8),
      glow,
    );
    tube.position.copy(a).add(b).multiplyScalar(0.5);
    tube.quaternion.setFromUnitVectors(
      new THREE.Vector3(0, 1, 0),
      b.clone().sub(a).normalize(),
    );
    monitor.add(tube);
  }
  for (let i = 0; i < 3; i++) {
    const light = new THREE.Mesh(new THREE.SphereGeometry(0.036, 12, 8), glow);
    light.position.set(-1.1 + i * 0.14, -1.2, 0.29);
    monitor.add(light);
  }
  const stem = new THREE.Mesh(
    new THREE.CylinderGeometry(0.13, 0.2, 1.25, 24),
    shell,
  );
  stem.position.y = -1.87;
  monitor.add(stem);
  const foot = new THREE.Mesh(
    new RoundedBoxGeometry(1.7, 0.13, 1.05, 3, 0.055),
    shell,
  );
  foot.position.y = -2.48;
  monitor.add(foot);
  scene.add(monitor);
  // Light ribbons and deterministic particles give the stage atmospheric depth.
  const atmosphere = new THREE.Group();
  scene.add(atmosphere);
  const ringMaterial = new THREE.MeshBasicMaterial({
    color: 0x779e65,
    transparent: true,
    opacity: 0.22,
  });
  for (let i = 0; i < 3; i++) {
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(3 + i * 0.6, 0.008, 6, 120),
      ringMaterial,
    );
    ring.rotation.set(0.9 + i * 0.2, 0.25, i * 0.5);
    atmosphere.add(ring);
  }
  const points = new Float32Array(150 * 3);
  for (let i = 0; i < 150; i++) {
    points[i * 3] = Math.sin(i * 127.1) * 8;
    points[i * 3 + 1] = Math.cos(i * 311.7) * 7;
    points[i * 3 + 2] = Math.sin(i * 74.7) * 6 - 3;
  }
  const particleGeometry = new THREE.BufferGeometry();
  particleGeometry.setAttribute(
    "position",
    new THREE.BufferAttribute(points, 3),
  );
  const particles = new THREE.Points(
    particleGeometry,
    new THREE.PointsMaterial({
      color: 0xd7fcb9,
      size: 0.017,
      transparent: true,
      opacity: 0.5,
    }),
  );
  scene.add(particles);

  let lost = false,
    visible = true,
    frame = 0,
    previous = 0,
    time = 0,
    current = target;
  const pointer = { x: 0, y: 0 };
  const look = new THREE.Vector3();
  const blend = THREE.MathUtils.smoothstep;
  const running = () => !paused && !document.hidden && visible && !lost;
  function paint() {
    const p = reduced.matches ? Math.round(target) : current;
    const cityAmount = blend(p, 2.45, 3.2);
    const monitorAmount = Math.max(0, 1 - Math.abs(p - 1));
    const handAmount = Math.max(0, 1 - monitorAmount) * (1 - cityAmount);
    const mobile = innerWidth < 680;
    hand.group.visible = handAmount > 0.01;
    monitor.visible = monitorAmount > 0.01;
    city.group.visible = cityAmount > 0.01;
    hand.group.scale.setScalar(
      Math.max(0.001, handAmount) * (mobile ? 1 : 1.05),
    );
    hand.group.position.set(
      p < 1 ? 0 : mobile ? 0 : 1.4,
      p < 1 ? 0.65 : 0.6,
      -0.3,
    );
    hand.group.rotation.set(0.06, -0.22 + Math.sin(time * 0.16) * 0.13, -0.08);
    hand.update(time, Math.min(1, p / 2));
    monitor.scale.setScalar(
      Math.max(0.001, monitorAmount) * (mobile ? 0.9 : 1.35),
    );
    monitor.position.set(mobile ? 0 : 2.4, mobile ? 1.5 : 0.5, -0.6);
    monitor.rotation.set(0.09, -0.34 + Math.sin(time * 0.18) * 0.07, 0.06);
    city.group.scale.setScalar(
      Math.max(0.001, cityAmount) * (mobile ? 1.12 : 1.6),
    );
    city.group.position.set(0, 0.3, 0);
    city.group.rotation.y = -0.4 + Math.sin(time * 0.11) * 0.08;
    city.update(time, Math.max(0, p - 3));
    atmosphere.rotation.y = time * 0.018;
    atmosphere.position.y = 0.8;
    particles.rotation.y = time * 0.008;
    const distance = mobile ? 11.8 : 10.2;
    camera.position.set(
      cityAmount * 4 + pointer.x * 0.15,
      cityAmount * 5.1 + pointer.y * 0.12,
      distance - cityAmount * 0.8,
    );
    look.set(0, cityAmount * 0.2, 0);
    camera.lookAt(look);
    renderer.render(scene, camera);
  }
  function tick(now) {
    frame = 0;
    if (!running()) return;
    if (now - previous >= 1000 / 35) {
      time += Math.min((now - previous) / 1000, 0.06);
      previous = now;
      current += (target - current) * 0.09;
      paint();
    }
    frame = requestAnimationFrame(tick);
  }
  function sync() {
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    previous = performance.now();
    if (!lost && !document.hidden && visible) {
      if (paused) current = target;
      paint();
    }
    if (running()) frame = requestAnimationFrame(tick);
  }
  function updateMotion() {
    motionToggle.setAttribute("aria-pressed", String(paused));
    motionToggle.querySelector(".motion-label").textContent = paused
      ? "Play motion"
      : "Pause motion";
    motionToggle.querySelector(".motion-icon").textContent = paused ? "▷" : "Ⅱ";
  }
  motionToggle.addEventListener("click", () => {
    paused = !paused;
    updateMotion();
    sync();
  });
  reduced.addEventListener("change", () => {
    paused = reduced.matches;
    pointer.x = pointer.y = 0;
    updateMotion();
    sync();
  });
  document.addEventListener("visibilitychange", sync);
  document.addEventListener(
    "pointermove",
    (e) => {
      if (running() && e.pointerType !== "touch") {
        pointer.x = e.clientX / innerWidth - 0.5;
        pointer.y = e.clientY / innerHeight - 0.5;
      }
    },
    { passive: true },
  );
  onScroll = () => {
    if (paused) {
      current = target;
      sync();
    }
  };
  function resize() {
    if (lost) return;
    camera.aspect = innerWidth / innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(innerWidth, innerHeight, false);
    sync();
  }
  window.addEventListener("resize", resize, { passive: true });
  new IntersectionObserver(([entry]) => {
    visible = entry.isIntersecting;
    sync();
  }).observe(document.querySelector("main"));
  canvas.addEventListener("webglcontextlost", (e) => {
    e.preventDefault();
    lost = true;
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    host.classList.remove("scene-ready");
    motionToggle.hidden = true;
  });
  window.addEventListener("pagehide", () => {
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
  });
  window.addEventListener("pageshow", sync);
  resize();
  updateMotion();
  motionToggle.hidden = false;
  host.classList.add("scene-ready");
} catch {
  renderer?.dispose();
  host.classList.remove("scene-ready");
  motionToggle.hidden = true;
}
readScroll();
