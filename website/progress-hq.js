import * as THREE from './progress-assets/vendor/three.module.js';
import { GLTFLoader } from './progress-assets/vendor/GLTFLoader.js';
import { OrbitControls } from './progress-assets/vendor/OrbitControls.js';

const get=id=>document.getElementById(id);
const stage=get('hq-stage');
const poster=get('hq-poster');
const canvasHost=get('hq-canvas');
const detail=get('hq-detail');
const loading=get('hq-loading');
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
let snapshot=null;
let selected=null;
let returnFocus=null;
let renderer,scene,camera,controls,model,mixer;
let frame=0,lastFrame=0,dirty=true,simple=false,paused=false;
let focusedTarget=null;
const initialTarget=new THREE.Vector3(0,.2,1);
const initialOffset=new THREE.Vector3(22,30,31);
const raycaster=new THREE.Raycaster();
const pointer=new THREE.Vector2();
const labelObjects=[];
const labels={center:'EQUIPSEVA',login:'LOGIN FLOW',hospital:'HOSPITAL',engineer:'ENGINEER',admin:'ADMIN',security:'SECURITY',qa:'QA LAB',plan:'NEXT PLAN',main:'GITHUB MAIN'};

function updateGates() {
  const status=window.EquipSevaDashboard.releaseReadiness(snapshot?.release);
  get('security-gate').textContent=status.security?'Checks passed':'Open checks';
  get('qa-gate').textContent=status.qa&&status.critic?'Reviews passed':'Review pending';
  get('main-gate').textContent=status.integrated?'Integration observed':status.ready?'Ready for review':'Locked';
  get('release-note').textContent=status.integrated?'Main integration is recorded. Signed-release verification remains separate.':status.ready?'Matching checks passed. Main integration has not been observed.':'Security, QA and critic evidence must match the Android candidate. Website reviews cannot unlock this lane.';
}
function showOffice(id,trigger=null) {
  id=id==='security_gate'?'security':id==='qa_gate'?'qa':id;
  if (!snapshot) { loading.hidden=false;loading.textContent='Project record unavailable. Use Check for a major milestone to retry.';return; }
  const office=snapshot.headquarters.find(item=>item.id===id);
  if (!office) return;
  selected=id;returnFocus=trigger??document.querySelector('[data-hq="'+id+'"]');
  get('hq-detail-title').textContent=office.name;
  get('hq-detail-status').textContent=office.status;
  for (const [key,id] of [['description','hq-detail-description'],['work','hq-detail-work'],['next','hq-detail-next'],['evidence','hq-detail-evidence']]) get(id).textContent=office[key];
  detail.hidden=false;
  document.querySelectorAll('[data-hq]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.hq===selected)));
  labelObjects.forEach(item=>item.element.classList.toggle('selected',item.id===selected));
  get('hq-detail-title').focus({preventScroll:true});
  detail.scrollIntoView({behavior:'instant',block:'nearest'});
  if (model&&!simple) {
    const anchor=model.getObjectByName('HQ_'+id);
    if (anchor) {
      focusedTarget=anchor.getWorldPosition(new THREE.Vector3());
      focusedTarget.y=.8;
      // The drawer takes the right third of desktop; retain the office in view.
      if(innerWidth>650) focusedTarget.add(new THREE.Vector3(2,0,-1.5));
      camera.zoom=id==='center'?1.1:1.75;camera.updateProjectionMatrix();
      if(reduced.matches||paused) moveToTarget(1);
      dirty=true;start();
    }
  }
}
function closeOffice() {
  detail.hidden=true;selected=null;
  document.querySelectorAll('[data-hq]').forEach(button=>button.setAttribute('aria-pressed','false'));
  labelObjects.forEach(item=>item.element.classList.remove('selected'));
  resetView();returnFocus?.focus({preventScroll:true});returnFocus?.scrollIntoView({behavior:'instant',block:'nearest'});
}
document.querySelectorAll('[data-hq]').forEach(button=>button.addEventListener('click',()=>showOffice(button.dataset.hq,button)));
get('hq-close').addEventListener('click',closeOffice);
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!detail.hidden){event.preventDefault();closeOffice();}});
function receiveSnapshot(data) {
  snapshot=data;updateGates();
  if(selected) {
    const trigger=returnFocus;
    // Updates arrive only for a new immutable major record, never on animation ticks.
    const office=snapshot.headquarters.find(item=>item.id===selected);
    if(office){
      for(const [key,id] of [['name','hq-detail-title'],['status','hq-detail-status'],['description','hq-detail-description'],['work','hq-detail-work'],['next','hq-detail-next'],['evidence','hq-detail-evidence']])get(id).textContent=office[key];
    }
    returnFocus=trigger;
  }
}
window.addEventListener('equipseva:milestone',event=>receiveSnapshot(event.detail));
if(window.EquipSevaDashboard?.getSnapshot()) receiveSnapshot(window.EquipSevaDashboard.getSnapshot());

function resetView() {
  if(!camera)return;
  focusedTarget=null;controls.target.copy(initialTarget);camera.position.copy(initialTarget).add(initialOffset);camera.zoom=1;camera.updateProjectionMatrix();controls.update();dirty=true;start();
}
get('hq-reset').addEventListener('click',resetView);
function syncPause() {
  const stopped=paused||reduced.matches;
  get('hq-pause').setAttribute('aria-pressed',String(stopped));
  get('hq-pause').textContent=reduced.matches?'Reduced motion':paused?'Resume bots':'Pause bots';
  get('hq-pause').disabled=reduced.matches;
  dirty=true;start();
}
get('hq-pause').addEventListener('click',()=>{paused=!paused;syncPause();});
reduced.addEventListener('change',syncPause);
function setSimple(value,reason='') {
  simple=value;
  try {localStorage.setItem('equipseva-hq-simple',String(value));} catch (_) {}
  canvasHost.hidden=value;get('hq-labels').hidden=value;poster.hidden=!value&&Boolean(model);
  get('hq-simple').setAttribute('aria-pressed',String(value));get('hq-simple').textContent=value?'3D view':'Simple view';
  get('hq-reset').disabled=value;
  if(reason){loading.textContent=reason;loading.hidden=false;}else loading.hidden=Boolean(model)||value;
  if(value){cancelAnimationFrame(frame);frame=0;}else{dirty=true;start();}
}
get('hq-simple').addEventListener('click',()=>{if(!model&&simple){loading.hidden=false;loading.textContent='3D could not load. Office buttons and the milestone record remain available.';return;}setSimple(!simple);});
function resize() {
  if(!renderer)return;
  const {width,height}=stage.getBoundingClientRect();
  const aspect=width/height;
  const span=aspect<1.2?35/aspect:28;
  camera.left=-span*aspect/2;camera.right=span*aspect/2;camera.top=span/2;camera.bottom=-span/2;
  camera.updateProjectionMatrix();renderer.setSize(width,height,false);dirty=true;start();
}
function moveToTarget(amount) {
  if(!focusedTarget)return;
  const delta=new THREE.Vector3().subVectors(focusedTarget,controls.target).multiplyScalar(amount);
  controls.target.add(delta);camera.position.add(delta);
  if(delta.length()<.008)focusedTarget=null;
}
function tick(time) {
  frame=0;
  if(document.hidden||simple||!renderer)return;
  const delta=Math.min((time-lastFrame)/1000,.05);
  if(time-lastFrame>=32){
    const moving=!paused&&!reduced.matches;
    if(moving&&mixer)mixer.update(delta);
    if(focusedTarget){moveToTarget(reduced.matches||paused?1:.14);dirty=true;}
    controls.update();
    if(moving||dirty){
      renderer.render(scene,camera);
      const rect=stage.getBoundingClientRect();
      for(const item of labelObjects){
        const p=item.object.getWorldPosition(new THREE.Vector3()).project(camera);
        item.element.style.left=((p.x+1)/2*rect.width)+'px';item.element.style.top=((-p.y+1)/2*rect.height)+'px';
        item.element.hidden=p.z>1||p.z< -1;
      }
      dirty=false;
    }
    lastFrame=time;
  }
  frame=requestAnimationFrame(tick);
}
function start(){if(renderer&&!frame&&!document.hidden&&!simple){lastFrame=performance.now();frame=requestAnimationFrame(tick);}}
document.addEventListener('visibilitychange',()=>{if(document.hidden){cancelAnimationFrame(frame);frame=0;}else{dirty=true;start();}});

async function init() {
  try {
    renderer=new THREE.WebGLRenderer({antialias:true,alpha:false,powerPreference:'low-power'});
    renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.outputColorSpace=THREE.SRGBColorSpace;
    renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.35;
    renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
    canvasHost.append(renderer.domElement);
    renderer.domElement.addEventListener('webglcontextlost',event=>{event.preventDefault();setSimple(true,'3D paused by this device. The headquarters and milestone record remain available.');});
    scene=new THREE.Scene();scene.background=new THREE.Color('#e6eee6');
    camera=new THREE.OrthographicCamera(-25,25,14,-14,.1,160);camera.position.copy(initialTarget).add(initialOffset);
    controls=new OrbitControls(camera,renderer.domElement);controls.target.copy(initialTarget);controls.enableDamping=true;controls.dampingFactor=.12;
    controls.enablePan=false;controls.enableZoom=false;controls.minPolarAngle=.35;controls.maxPolarAngle=1.15;
    controls.touches.ONE=THREE.TOUCH.ROTATE;controls.touches.TWO=THREE.TOUCH.DOLLY_ROTATE;
    controls.addEventListener('change',()=>{dirty=true;});
    // Avoid one-finger orbit trapping page scrolling on phones; office buttons
    // still expose the same information and focus the model when selected.
    controls.enabled=innerWidth>650;
    scene.add(new THREE.HemisphereLight('#fff9ee','#67887c',3.2));
    const sun=new THREE.DirectionalLight('#fff5df',4.0);sun.position.set(-8,22,12);sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);
    sun.shadow.camera.left=-20;sun.shadow.camera.right=20;sun.shadow.camera.top=20;sun.shadow.camera.bottom=-20;sun.shadow.normalBias=.04;scene.add(sun);
    const fill=new THREE.DirectionalLight('#c7efff',1.6);fill.position.set(16,12,-12);scene.add(fill);
    const gltf=await new GLTFLoader().loadAsync('/progress-assets/equipseva-headquarters.glb');
    model=gltf.scene;scene.add(model);
    model.traverse(object=>{if(object.isMesh){object.castShadow=true;object.receiveShadow=true;}});
    mixer=new THREE.AnimationMixer(model);gltf.animations.forEach(clip=>mixer.clipAction(clip).play());
    for(const [id,label] of Object.entries(labels)){
      const object=model.getObjectByName('Anchor_'+id);if(!object)continue;
      const element=document.createElement('span');element.className='hq-label';element.textContent=label;get('hq-labels').append(element);labelObjects.push({id,object,element});
    }
    let down=null;
    renderer.domElement.addEventListener('pointerdown',event=>{down={x:event.clientX,y:event.clientY};});
    renderer.domElement.addEventListener('pointerup',event=>{
      if(!down||Math.hypot(event.clientX-down.x,event.clientY-down.y)>6)return;down=null;
      const rect=renderer.domElement.getBoundingClientRect();pointer.set((event.clientX-rect.left)/rect.width*2-1,-(event.clientY-rect.top)/rect.height*2+1);
      raycaster.setFromCamera(pointer,camera);
      for(const hit of raycaster.intersectObject(model,true)){
        let object=hit.object;
        while(object){if(object.userData.hq){showOffice(object.userData.hq);return;}object=object.parent;}
      }
    });
    new ResizeObserver(()=>{controls.enabled=innerWidth>650;renderer.domElement.style.touchAction=controls.enabled?'none':'pan-y';resize();}).observe(stage);
    loading.hidden=true;poster.hidden=true;
    let savedSimple=false;try{savedSimple=localStorage.getItem('equipseva-hq-simple')==='true';}catch(_){}
    resize();syncPause();setSimple(savedSimple);
  } catch (_) {
    setSimple(true,'3D unavailable on this device. Use the headquarters buttons below.');
    get('hq-pause').disabled=true;get('hq-reset').disabled=true;
  }
}
syncPause();init();
