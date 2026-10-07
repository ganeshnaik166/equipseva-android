import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

// The sculpture is decorative. The static illustration and all content work without JS/WebGL.
const canvas = document.querySelector('#care-scene');
const wrapper = canvas?.parentElement;
const toggle = document.querySelector('#motion-toggle');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let renderer;
try {
  if (!canvas || !wrapper || !toggle) throw new Error('Scene host unavailable');
  renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: 'low-power' });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.75));
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(34, 1, .1, 60);
  camera.position.set(0, .1, 11.5);
  const studio = new RoomEnvironment();
  const generator = new THREE.PMREMGenerator(renderer);
  const environment = generator.fromScene(studio, .035);
  scene.environment = environment.texture;
  studio.dispose();
  generator.dispose();
  scene.add(new THREE.HemisphereLight(0xffffff, 0x6a7854, 1.8));
  const light = new THREE.DirectionalLight(0xffffff, 2.5);
  light.position.set(-3, 5, 6);
  scene.add(light);
  const limeLight = new THREE.DirectionalLight(0xd4ff95, 1.2);
  limeLight.position.set(4, -1, 1);
  scene.add(limeLight);

  const chrome = new THREE.MeshStandardMaterial({ color: 0xdce3d2, metalness: 1, roughness: .19 });
  const lime = new THREE.MeshPhysicalMaterial({ color: 0x9ae51c, metalness: .12, roughness: .24, clearcoat: 1, clearcoatRoughness: .17 });
  const dark = new THREE.MeshStandardMaterial({ color: 0x171d11, metalness: .6, roughness: .32 });
  const white = new THREE.MeshStandardMaterial({ color: 0xf1ffcf, metalness: .3, roughness: .24 });
  const sculpture = new THREE.Group();
  scene.add(sculpture);
  const cross = new THREE.Shape();
  const a = .7, b = 1.8;
  cross.moveTo(-a, b);
  for (const [x, y] of [[a,b],[a,a],[b,a],[b,-a],[a,-a],[a,-b],[-a,-b],[-a,-a],[-b,-a],[-b,a],[-a,a],[-a,b]]) cross.lineTo(x,y);
  const bodyGeometry = new THREE.ExtrudeGeometry(cross, { depth: .43, bevelEnabled: true, bevelSegments: 6, steps: 1, bevelSize: .13, bevelThickness: .13, curveSegments: 16 });
  bodyGeometry.center();
  const body = new THREE.Mesh(bodyGeometry, chrome);
  sculpture.add(body);
  const faceGeometry = new THREE.ExtrudeGeometry(cross, { depth: .06, bevelEnabled: true, bevelSegments: 5, steps: 1, bevelSize: .075, bevelThickness: .065 });
  faceGeometry.center();
  const face = new THREE.Mesh(faceGeometry, lime);
  face.scale.set(.91,.91,1);
  face.position.z = .32;
  sculpture.add(face);
  const inset = new THREE.Mesh(new THREE.CylinderGeometry(.5,.5,.09,64), dark);
  inset.rotation.x = Math.PI / 2;
  inset.position.z = .45;
  sculpture.add(inset);
  const pulse = new THREE.Group();
  for (const [w,h] of [[.44,.095],[.095,.44]]) {
    const line = new THREE.Mesh(new THREE.BoxGeometry(w,h,.035), lime);
    line.position.z = .51;
    pulse.add(line);
  }
  sculpture.add(pulse);
  const boltGeometry = new THREE.CylinderGeometry(.035,.035,.015,16);
  for (const [x,y] of [[-.44,1.5],[.44,1.5],[-.44,-1.5],[.44,-1.5],[-1.5,-.44],[-1.5,.44],[1.5,-.44],[1.5,.44]]) {
    const bolt = new THREE.Mesh(boltGeometry, dark);
    bolt.rotation.x = Math.PI / 2;
    bolt.position.set(x,y,.44);
    sculpture.add(bolt);
  }
  const ring = new THREE.Mesh(new THREE.TorusGeometry(2.44,.046,16,160), chrome);
  ring.rotation.set(.6,.45,-.3);
  sculpture.add(ring);
  const ringInner = new THREE.Mesh(new THREE.TorusGeometry(2.32,.012,8,128), white);
  ringInner.rotation.set(.6,.45,-.3);
  sculpture.add(ringInner);
  const orbit = new THREE.Group();
  orbit.rotation.copy(ring.rotation);
  sculpture.add(orbit);
  const satellite = new THREE.Mesh(new THREE.SphereGeometry(.19,32,24), chrome);
  satellite.position.set(-2.05,1.32,0);
  orbit.add(satellite);
  const second = new THREE.Mesh(new THREE.SphereGeometry(.12,24,16), lime);
  second.position.set(1.85,-1.59,0);
  orbit.add(second);
  // An original soft contact shadow; no remote textures, trackers or APIs.
  const shadowCanvas = document.createElement('canvas');
  shadowCanvas.width = shadowCanvas.height = 128;
  const ctx = shadowCanvas.getContext('2d');
  if (ctx) {
    const gradient = ctx.createRadialGradient(64,64,0,64,64,64);
    gradient.addColorStop(0,'rgba(35,49,18,0.19)');
    gradient.addColorStop(.55,'rgba(35,49,18,0.06)');
    gradient.addColorStop(1,'rgba(35,49,18,0)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0,0,128,128);
    const shadow = new THREE.Mesh(new THREE.PlaneGeometry(5.7,1.2), new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(shadowCanvas), transparent:true, depthWrite:false}));
    shadow.position.set(.15,-2.72,-1);
    scene.add(shadow);
  }

  let paused = reducedMotion.matches;
  let visible = true;
  let lost = false;
  let frame = 0;
  let previous = 0;
  let elapsed = 0;
  const pointer = {x:0,y:0};
  const running = () => !paused && visible && !document.hidden && !lost;
  const updateButton = () => {
    toggle.setAttribute('aria-pressed', String(paused));
    toggle.querySelector('.motion-label').textContent = paused ? 'Play motion' : 'Pause motion';
    toggle.querySelector('.motion-icon').textContent = paused ? '▷' : 'Ⅱ';
  };
  const paint = () => {
    sculpture.rotation.set(.14 + pointer.y * .075, -.3 + pointer.x * .1, -.23);
    if (!paused) {
      sculpture.rotation.y += Math.sin(elapsed * .42) * .13;
      sculpture.rotation.x += Math.cos(elapsed * .35) * .04;
      sculpture.position.y = Math.sin(elapsed * .8) * .1;
    }
    renderer.render(scene,camera);
  };
  const tick = now => {
    frame = 0;
    if (!running()) return;
    if (now - previous >= 1000/40) {
      elapsed += Math.min((now - previous)/1000,.05);
      previous = now;
      paint();
    }
    frame = requestAnimationFrame(tick);
  };
  const sync = () => {
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    previous = performance.now();
    if (!lost && !document.hidden && visible) paint();
    if (running()) frame = requestAnimationFrame(tick);
  };
  const resize = () => {
    const {width,height} = wrapper.getBoundingClientRect();
    if (!width || !height || lost) return;
    camera.aspect = width/height;
    camera.position.z = camera.aspect < .85 ? 13 : 11.5;
    camera.updateProjectionMatrix();
    renderer.setSize(width,height,false);
    sync();
  };
  toggle.addEventListener('click', () => { paused = !paused; updateButton(); sync(); });
  reducedMotion.addEventListener('change', () => { paused = reducedMotion.matches; pointer.x=pointer.y=0; updateButton(); sync(); });
  document.addEventListener('visibilitychange', sync);
  document.querySelector('.hero').addEventListener('pointermove', event => {
    if (!running() || event.pointerType === 'touch') return;
    const rect = wrapper.getBoundingClientRect();
    pointer.x = THREE.MathUtils.clamp((event.clientX-rect.left)/rect.width-.5,-.5,.5);
    pointer.y = THREE.MathUtils.clamp((event.clientY-rect.top)/rect.height-.5,-.5,.5);
  }, {passive:true});
  document.querySelector('.hero').addEventListener('pointerleave', () => {pointer.x=pointer.y=0;});
  new IntersectionObserver(([entry]) => {visible=entry.isIntersecting;sync();}, {threshold:0}).observe(wrapper);
  new ResizeObserver(resize).observe(wrapper);
  canvas.addEventListener('webglcontextlost', event => {
    event.preventDefault();
    lost = true;
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    wrapper.classList.remove('scene-ready');
    toggle.hidden = true;
  });
  // Keep the static fallback after context loss; a page refresh can recreate the GPU context.
  resize();
  updateButton();
  toggle.hidden = false;
  wrapper.classList.add('scene-ready');
} catch {
  renderer?.dispose();
  wrapper?.classList.remove('scene-ready');
  if (toggle) toggle.hidden = true;
}
