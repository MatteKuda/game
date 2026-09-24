import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

/**
 * Draw-call reduction. Everything procedural is authored as many small meshes (readable code),
 * then baked here into a few merged meshes.
 */

function prep(g: THREE.BufferGeometry, m: THREE.Matrix4, color?: THREE.Color) {
  const c = g.index ? g.toNonIndexed() : g.clone();
  c.applyMatrix4(m);
  for (const k of Object.keys(c.attributes)) if (!['position', 'normal', 'uv'].includes(k)) c.deleteAttribute(k);
  if (!c.attributes.uv) c.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(c.attributes.position.count * 2), 2));
  if (!c.attributes.normal) c.computeVertexNormals();
  if (color) {
    const n = c.attributes.position.count;
    const arr = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) { arr[i * 3] = color.r; arr[i * 3 + 1] = color.g; arr[i * 3 + 2] = color.b; }
    c.setAttribute('color', new THREE.BufferAttribute(arr, 3));
  }
  return c;
}

const isKept = (o: THREE.Object3D, root: THREE.Object3D) => {
  for (let p: THREE.Object3D | null = o; p && p !== root; p = p.parent) if (p.userData.dynamic) return true;
  return false;
};

/** Merge all static meshes under `root` by material. Objects (or ancestors) flagged userData.dynamic are left alone. */
export function mergeByMaterial(root: THREE.Object3D) {
  root.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(root.matrixWorld).invert();
  const buckets = new Map<THREE.Material, { geos: THREE.BufferGeometry[]; cast: boolean }>();
  const remove: THREE.Mesh[] = [];
  root.traverse((o) => {
    const m = o as THREE.Mesh;
    if (!m.isMesh || (m as unknown as THREE.InstancedMesh).isInstancedMesh || Array.isArray(m.material) || isKept(m, root)) return;
    if (m.renderOrder !== 0) return;
    const rel = new THREE.Matrix4().multiplyMatrices(inv, m.matrixWorld);
    const b = buckets.get(m.material) ?? { geos: [], cast: false };
    b.geos.push(prep(m.geometry, rel));
    b.cast ||= m.castShadow;
    buckets.set(m.material, b);
    remove.push(m);
  });
  for (const m of remove) m.removeFromParent();
  for (const [material, b] of buckets) {
    const g = mergeGeometries(b.geos, false);
    if (!g) continue;
    const mesh = new THREE.Mesh(g, material);
    mesh.castShadow = b.cast; mesh.receiveShadow = true;
    root.add(mesh);
  }
}

const vcMats = new Map<string, THREE.MeshStandardMaterial>();
function vcMaterial(rough: number) {
  const k = rough.toFixed(1);
  let m = vcMats.get(k);
  if (!m) { m = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: rough }); vcMats.set(k, m); }
  return m;
}

/**
 * Merge the direct mesh children of each rigid part (a Group) into a single vertex-coloured mesh.
 * Only plain coloured MeshStandardMaterials are merged; anything textured or flagged dynamic stays.
 */
export function mergeRigidPart(part: THREE.Object3D) {
  part.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(part.matrixWorld).invert();
  const geos: THREE.BufferGeometry[] = [];
  const remove: THREE.Mesh[] = [];
  let roughSum = 0;
  for (const o of [...part.children]) {
    const m = o as THREE.Mesh;
    if (!m.isMesh || o.userData.dynamic || Array.isArray(m.material)) continue;
    const mat = m.material as THREE.MeshStandardMaterial;
    if (!mat.isMeshStandardMaterial || mat.map || mat.transparent || mat.emissiveIntensity > 0.01 && mat.emissive.getHex() !== 0) continue;
    m.updateMatrixWorld(true);
    const rel = new THREE.Matrix4().multiplyMatrices(inv, m.matrixWorld);
    geos.push(prep(m.geometry, rel, mat.color));
    roughSum += mat.roughness;
    remove.push(m);
  }
  if (geos.length < 2) return;
  for (const m of remove) m.removeFromParent();
  const g = mergeGeometries(geos, false);
  if (!g) return;
  const mesh = new THREE.Mesh(g, vcMaterial(Math.round((roughSum / remove.length) * 10) / 10));
  mesh.castShadow = true; mesh.receiveShadow = true;
  part.add(mesh);
}
