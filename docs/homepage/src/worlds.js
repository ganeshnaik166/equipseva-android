/* Original procedural EquipSeva sculptures. No models or textures are downloaded.
 * World factories leave lighting, camera, visibility and disposal to the host.
 * Updates animate local parts only, so the host may transform either root group.
 */

function materials(THREE) {
  return {
    metal: new THREE.MeshStandardMaterial({
      color: 0xd8e1dc,
      metalness: 0.93,
      roughness: 0.2,
    }),
    brushed: new THREE.MeshStandardMaterial({
      color: 0x84958e,
      metalness: 0.88,
      roughness: 0.34,
    }),
    dark: new THREE.MeshStandardMaterial({
      color: 0x101815,
      metalness: 0.72,
      roughness: 0.3,
    }),
    lime: new THREE.MeshPhysicalMaterial({
      color: 0xb8ed25,
      metalness: 0.22,
      roughness: 0.26,
      clearcoat: 1,
    }),
    glow: new THREE.MeshStandardMaterial({
      color: 0xcaff52,
      emissive: 0xa8ef32,
      emissiveIntensity: 0.8,
      roughness: 0.35,
    }),
    white: new THREE.MeshStandardMaterial({
      color: 0xf0f2e8,
      metalness: 0.34,
      roughness: 0.28,
    }),
  };
}

function bevelPlate(THREE) {
  const shape = new THREE.Shape();
  shape.moveTo(-0.35, -0.5);
  shape.lineTo(0.35, -0.5);
  shape.lineTo(0.5, -0.35);
  shape.lineTo(0.5, 0.35);
  shape.lineTo(0.35, 0.5);
  shape.lineTo(-0.35, 0.5);
  shape.lineTo(-0.5, 0.35);
  shape.lineTo(-0.5, -0.35);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: 1,
    bevelEnabled: true,
    bevelSegments: 3,
    bevelSize: 0.035,
    bevelThickness: 0.035,
    steps: 1,
  });
  geometry.center();
  return geometry;
}

function addMesh(
  THREE,
  parent,
  geometry,
  material,
  position,
  scale = [1, 1, 1],
) {
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  parent.add(mesh);
  return mesh;
}

export function createHandWorld(THREE) {
  const group = new THREE.Group();
  group.name = "EquipSeva original precision hand";
  const m = materials(THREE);
  const plate = bevelPlate(THREE);
  const box = new THREE.BoxGeometry(1, 1, 1);
  const joint = new THREE.CylinderGeometry(1, 1, 1, 20);
  const ball = new THREE.SphereGeometry(1, 16, 12);
  const ring = new THREE.TorusGeometry(1, 0.045, 8, 40);
  const hand = new THREE.Group();
  hand.rotation.set(-0.1, -0.14, -0.06);
  group.add(hand);

  // Tapered metacarpal housing, raised armour and a recessed service panel.
  addMesh(THREE, hand, plate, m.brushed, [0, -0.34, -0.05], [1.58, 1.55, 0.5]);
  addMesh(THREE, hand, plate, m.metal, [0, -0.3, 0.2], [1.48, 1.47, 0.17]);
  addMesh(
    THREE,
    hand,
    plate,
    m.dark,
    [0.04, -0.25, 0.315],
    [1.12, 1.08, 0.075],
  );
  addMesh(
    THREE,
    hand,
    plate,
    m.lime,
    [0.05, -0.11, 0.372],
    [0.75, 0.78, 0.035],
  );
  const core = addMesh(
    THREE,
    hand,
    joint,
    m.dark,
    [0.05, -0.1, 0.414],
    [0.21, 0.038, 0.21],
  );
  core.rotation.x = Math.PI / 2;
  addMesh(THREE, hand, box, m.white, [0.05, -0.1, 0.438], [0.25, 0.064, 0.018]);
  addMesh(THREE, hand, box, m.white, [0.05, -0.1, 0.438], [0.064, 0.25, 0.018]);
  for (const x of [-0.55, 0.57]) {
    for (const y of [-0.83, 0.22]) {
      const screw = addMesh(
        THREE,
        hand,
        joint,
        m.dark,
        [x, y, 0.322],
        [0.045, 0.025, 0.045],
      );
      screw.rotation.x = Math.PI / 2;
      addMesh(THREE, hand, box, m.metal, [x, y, 0.34], [0.045, 0.011, 0.012]);
    }
  }
  for (let i = 0; i < 4; i += 1) {
    addMesh(
      THREE,
      hand,
      box,
      m.brushed,
      [-0.23 + i * 0.18, -0.7, 0.368],
      [0.07, 0.11, 0.021],
    );
  }

  const digits = [];
  const makeDigit = ({ x, y, length, width, spread, thumb = false }) => {
    const base = new THREE.Group();
    base.position.set(x, y, -0.035);
    base.rotation.z = spread;
    hand.add(base);
    let parent = base;
    const segments = thumb ? [0.53, 0.47] : [0.42, 0.34, 0.24];
    const hinges = [];
    segments.forEach((fraction, index) => {
      const segmentLength = length * fraction;
      const hinge = new THREE.Group();
      if (index > 0) hinge.position.y = length * segments[index - 1];
      parent.add(hinge);
      const axle = addMesh(
        THREE,
        hinge,
        joint,
        m.dark,
        [0, 0, 0],
        [width * 0.46, width * 1.04, width * 0.46],
      );
      axle.rotation.z = Math.PI / 2;
      for (const side of [-1, 1]) {
        const cap = addMesh(
          THREE,
          hinge,
          joint,
          m.metal,
          [side * width * 0.53, 0, 0],
          [width * 0.29, 0.034, width * 0.29],
        );
        cap.rotation.z = Math.PI / 2;
      }
      const taper = 1 - index * 0.075;
      addMesh(
        THREE,
        hinge,
        plate,
        m.metal,
        [0, segmentLength * 0.51, -0.025],
        [width * taper, segmentLength * 0.79, width * 0.7],
      );
      addMesh(
        THREE,
        hinge,
        plate,
        index === 1 ? m.brushed : m.lime,
        [0, segmentLength * 0.51, width * 0.365],
        [width * taper * 0.72, segmentLength * 0.66, width * 0.11],
      );
      addMesh(
        THREE,
        hinge,
        box,
        m.dark,
        [0, segmentLength * 0.63, width * 0.44],
        [width * 0.44, 0.019, 0.012],
      );
      if (index === segments.length - 1) {
        addMesh(
          THREE,
          hinge,
          ball,
          m.dark,
          [0, segmentLength * 0.88, -0.014],
          [width * 0.37, width * 0.29, width * 0.29],
        );
      }
      hinges.push(hinge);
      parent = hinge;
    });
    digits.push({ base, hinges, spread, phase: x * 1.7, thumb });
  };

  makeDigit({ x: -0.57, y: 0.39, length: 1.53, width: 0.32, spread: 0.14 });
  makeDigit({ x: -0.18, y: 0.45, length: 1.87, width: 0.34, spread: 0.015 });
  makeDigit({ x: 0.23, y: 0.43, length: 1.71, width: 0.33, spread: -0.07 });
  makeDigit({ x: 0.62, y: 0.29, length: 1.31, width: 0.28, spread: -0.23 });
  makeDigit({
    x: -0.68,
    y: -0.57,
    length: 1.18,
    width: 0.39,
    spread: 1.02,
    thumb: true,
  });

  // Exposed wrist bearings and a lime service cuff establish a mechanical silhouette.
  addMesh(THREE, hand, joint, m.dark, [0, -1.23, -0.03], [0.45, 0.43, 0.39]);
  addMesh(THREE, hand, plate, m.metal, [0, -1.59, -0.035], [1.05, 0.62, 0.66]);
  addMesh(THREE, hand, plate, m.lime, [0, -1.61, 0.321], [0.84, 0.4, 0.036]);
  for (const x of [-0.29, 0.29]) {
    addMesh(THREE, hand, box, m.dark, [x, -1.61, 0.349], [0.065, 0.29, 0.024]);
  }
  for (let i = 0; i < 3; i += 1) {
    const bearing = addMesh(
      THREE,
      hand,
      ring,
      m.metal,
      [0, -1.08 - i * 0.13, -0.03],
      [0.44, 0.38, 0.44],
    );
    bearing.rotation.x = Math.PI / 2;
  }

  // A handful of optical facets; transmission is limited to these small objects.
  const shardMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xd7eddd,
    metalness: 0.05,
    roughness: 0.08,
    transmission: 0.65,
    thickness: 0.24,
    ior: 1.48,
    transparent: true,
    opacity: 0.7,
    side: THREE.DoubleSide,
    depthWrite: false,
  });
  const shardShape = new THREE.Shape();
  shardShape.moveTo(-0.44, -0.36);
  shardShape.lineTo(0.4, -0.13);
  shardShape.lineTo(0.16, 0.46);
  shardShape.closePath();
  const shardGeometry = new THREE.ExtrudeGeometry(shardShape, {
    depth: 0.05,
    bevelEnabled: true,
    bevelSize: 0.008,
    bevelThickness: 0.008,
    bevelSegments: 1,
  });
  shardGeometry.center();
  const shards = [
    [-1.94, 0.52, -0.3],
    [1.59, 1.71, -0.65],
    [1.57, -0.76, 0.34],
    [-1.3, 1.93, -0.6],
  ].map((position, index) => {
    const shard = addMesh(
      THREE,
      group,
      shardGeometry,
      shardMaterial,
      position,
      [0.8, 0.8, 0.8],
    );
    shard.rotation.set(0.26 + index * 0.35, -0.4 + index * 0.57, index * 1.18);
    return { shard, y: position[1], phase: index * 1.67 };
  });

  return {
    group,
    update(time = 0, progress = 0) {
      const p = THREE.MathUtils.clamp(progress, 0, 1);
      hand.position.y = Math.sin(time * 0.55) * 0.055;
      hand.rotation.y = -0.14 + Math.sin(time * 0.25) * 0.1;
      digits.forEach(({ hinges, phase, thumb }) => {
        hinges.forEach((hinge, index) => {
          hinge.rotation.x =
            (thumb ? -0.12 : -0.05) +
            index * 0.04 +
            Math.sin(time * 0.65 + phase) * 0.025 +
            p * index * 0.04;
        });
      });
      shards.forEach(({ shard, y, phase }) => {
        shard.position.y = y + Math.sin(time * 0.4 + phase) * 0.12;
        shard.rotation.y =
          -0.4 + phase * 0.34 + Math.sin(time * 0.25 + phase) * 0.2;
      });
    },
  };
}

export function createCityWorld(THREE) {
  const group = new THREE.Group();
  group.name = "EquipSeva original connected care campus";
  const m = materials(THREE);
  const box = new THREE.BoxGeometry(1, 1, 1);
  const cylinder = new THREE.CylinderGeometry(1, 1, 1, 64);
  const plate = bevelPlate(THREE);
  const cone = new THREE.ConeGeometry(1, 1, 7);
  const ring = new THREE.TorusGeometry(1, 0.023, 8, 80);
  const ground = -1.16;
  const campus = new THREE.Group();
  group.add(campus);

  addMesh(
    THREE,
    campus,
    cylinder,
    m.brushed,
    [0, ground - 0.17, 0],
    [2.73, 0.22, 2.73],
  );
  addMesh(
    THREE,
    campus,
    cylinder,
    m.dark,
    [0, ground - 0.035, 0],
    [2.66, 0.065, 2.66],
  );
  const perimeter = addMesh(
    THREE,
    campus,
    ring,
    m.lime,
    [0, ground + 0.025, 0],
    [2.56, 2.56, 2.56],
  );
  perimeter.rotation.x = Math.PI / 2;

  // Cross-campus routes and inset stepping lights remain readable at a distance.
  for (const angle of [0, Math.PI / 2]) {
    const road = addMesh(
      THREE,
      campus,
      box,
      m.brushed,
      [0, ground + 0.012, 0],
      [0.5, 0.025, 4.74],
    );
    road.rotation.y = angle;
    const stripe = addMesh(
      THREE,
      campus,
      box,
      m.lime,
      [0, ground + 0.028, 0],
      [0.026, 0.012, 4.74],
    );
    stripe.rotation.y = angle;
  }
  const innerPath = addMesh(
    THREE,
    campus,
    ring,
    m.brushed,
    [0, ground + 0.025, 0],
    [1.37, 1.37, 1.37],
  );
  innerPath.rotation.x = Math.PI / 2;

  // The main hospital is a layered, circular building with a roof landing deck.
  addMesh(
    THREE,
    campus,
    cylinder,
    m.white,
    [0, ground + 0.15, 0],
    [1.02, 0.26, 0.89],
  );
  addMesh(
    THREE,
    campus,
    cylinder,
    m.dark,
    [0, ground + 0.51, 0],
    [0.9, 0.51, 0.77],
  );
  for (const y of [0.29, 0.49, 0.71]) {
    addMesh(
      THREE,
      campus,
      cylinder,
      m.metal,
      [0, ground + y, 0],
      [0.94, 0.043, 0.81],
    );
  }
  addMesh(
    THREE,
    campus,
    cylinder,
    m.white,
    [0, ground + 0.83, 0],
    [0.95, 0.17, 0.82],
  );
  addMesh(
    THREE,
    campus,
    cylinder,
    m.dark,
    [0, ground + 0.932, 0],
    [0.7, 0.035, 0.61],
  );
  const roofRing = addMesh(
    THREE,
    campus,
    ring,
    m.lime,
    [0, ground + 0.956, 0],
    [0.5, 0.43, 0.5],
  );
  roofRing.rotation.x = Math.PI / 2;
  addMesh(
    THREE,
    campus,
    box,
    m.lime,
    [0, ground + 0.96, 0],
    [0.35, 0.015, 0.08],
  );
  addMesh(
    THREE,
    campus,
    box,
    m.lime,
    [0, ground + 0.96, 0],
    [0.08, 0.015, 0.35],
  );
  const lobby = addMesh(
    THREE,
    campus,
    plate,
    m.lime,
    [0, ground + 0.19, 0.94],
    [0.61, 0.26, 0.4],
  );
  lobby.rotation.x = Math.PI / 2;

  const windowTransforms = [];
  for (let i = 0; i < 28; i += 1) {
    const angle = (i / 28) * Math.PI * 2;
    windowTransforms.push({
      position: [
        Math.sin(angle) * 0.902,
        ground + 0.51,
        Math.cos(angle) * 0.774,
      ],
      scale: [0.042, 0.4, 0.026],
      rotation: angle,
    });
  }

  const buildings = [
    [-1.59, -0.95, 0.69, 0.62, 0.56],
    [-1.61, 0.65, 0.66, 0.99, 0.59],
    [1.57, 0.66, 0.74, 0.59, 0.64],
    [1.54, -1.03, 0.53, 1.11, 0.55],
    [-0.65, -1.94, 0.66, 0.38, 0.4],
    [0.43, -1.98, 0.49, 0.53, 0.39],
    [-0.74, 1.81, 0.56, 0.43, 0.51],
    [0.74, 1.78, 0.63, 0.38, 0.48],
  ];
  buildings.forEach(([x, z, width, height, depth], index) => {
    addMesh(
      THREE,
      campus,
      box,
      m.white,
      [x, ground + height / 2 + 0.04, z],
      [width, height, depth],
    );
    addMesh(
      THREE,
      campus,
      box,
      m.dark,
      [x, ground + height + 0.055, z],
      [width * 0.94, 0.055, depth * 0.92],
    );
    addMesh(
      THREE,
      campus,
      box,
      index % 3 === 0 ? m.lime : m.metal,
      [x, ground + height + 0.11, z],
      [width * 0.68, 0.07, depth * 0.69],
    );
    for (let row = 0; row < Math.max(2, Math.floor(height / 0.18)); row += 1) {
      for (const face of [-1, 1]) {
        windowTransforms.push({
          position: [
            x,
            ground + 0.14 + row * 0.16,
            z + face * (depth / 2 + 0.005),
          ],
          scale: [width * 0.73, 0.064, 0.015],
          rotation: 0,
        });
      }
    }
  });
  const windows = new THREE.InstancedMesh(box, m.dark, windowTransforms.length);
  const matrix = new THREE.Matrix4();
  const quaternion = new THREE.Quaternion();
  const position = new THREE.Vector3();
  const scale = new THREE.Vector3();
  windowTransforms.forEach((item, index) => {
    position.set(...item.position);
    scale.set(...item.scale);
    quaternion.setFromAxisAngle(new THREE.Vector3(0, 1, 0), item.rotation);
    matrix.compose(position, quaternion, scale);
    windows.setMatrixAt(index, matrix);
  });
  windows.instanceMatrix.needsUpdate = true;
  campus.add(windows);

  // An engineering gateway and sensor tower frame the hospital rather than obscure it.
  const portal = new THREE.Group();
  portal.position.set(0.05, ground + 0.84, -1.05);
  campus.add(portal);
  const portalRing = new THREE.Mesh(
    new THREE.TorusGeometry(0.92, 0.083, 12, 80),
    m.metal,
  );
  portal.add(portalRing);
  const portalLight = new THREE.Mesh(
    new THREE.TorusGeometry(0.922, 0.026, 8, 80),
    m.glow,
  );
  portalLight.position.z = 0.079;
  portal.add(portalLight);
  for (const x of [-0.79, 0.79]) {
    addMesh(THREE, portal, box, m.metal, [x, -0.53, 0], [0.17, 0.54, 0.25]);
  }
  addMesh(
    THREE,
    campus,
    cylinder,
    m.metal,
    [-1.03, ground + 0.84, -1.43],
    [0.075, 1.61, 0.075],
  );
  addMesh(
    THREE,
    campus,
    cylinder,
    m.dark,
    [-1.03, ground + 1.4, -1.43],
    [0.2, 0.22, 0.2],
  );
  const beacon = addMesh(
    THREE,
    campus,
    cylinder,
    m.glow,
    [-1.03, ground + 1.6, -1.43],
    [0.082, 0.17, 0.082],
  );

  // Instanced landscaping keeps the dense miniature affordable on mobile GPUs.
  const treePositions = [];
  for (let i = 0; i < 22; i += 1) {
    const a = (i / 22) * Math.PI * 2 + 0.12;
    if (Math.abs(Math.sin(a)) < 0.15 || Math.abs(Math.cos(a)) < 0.15) continue;
    treePositions.push([Math.sin(a) * 2.31, Math.cos(a) * 2.31]);
  }
  const trunks = new THREE.InstancedMesh(box, m.brushed, treePositions.length);
  const crowns = new THREE.InstancedMesh(cone, m.lime, treePositions.length);
  quaternion.identity();
  treePositions.forEach(([x, z], index) => {
    const height = 0.23 + (index % 3) * 0.035;
    position.set(x, ground + 0.11, z);
    scale.set(0.043, 0.2, 0.043);
    matrix.compose(position, quaternion, scale);
    trunks.setMatrixAt(index, matrix);
    position.set(x, ground + 0.17 + height / 2, z);
    scale.set(0.105, height, 0.105);
    matrix.compose(position, quaternion, scale);
    crowns.setMatrixAt(index, matrix);
  });
  trunks.instanceMatrix.needsUpdate = true;
  crowns.instanceMatrix.needsUpdate = true;
  campus.add(trunks, crowns);

  const vehicle = new THREE.Group();
  vehicle.position.set(0.24, ground + 0.075, 1.45);
  campus.add(vehicle);
  addMesh(THREE, vehicle, plate, m.white, [0, 0.07, 0], [0.18, 0.17, 0.37]);
  addMesh(THREE, vehicle, box, m.dark, [0, 0.135, 0.075], [0.15, 0.04, 0.15]);
  addMesh(THREE, vehicle, box, m.lime, [0, 0.17, -0.08], [0.12, 0.027, 0.055]);

  return {
    group,
    update(time = 0, progress = 0) {
      const p = THREE.MathUtils.clamp(progress, 0, 1);
      group.userData.chapterProgress = p;
      beacon.scale.y = 0.17 + Math.sin(time * 1.4) * 0.012;
      portalLight.material.emissiveIntensity =
        0.78 + Math.sin(time * 0.8) * 0.12;
      vehicle.position.z = 1.47 + Math.sin(time * 0.23) * 0.28;
    },
  };
}
