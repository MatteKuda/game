// Global tuning + world layout constants.
// Tile = 1 metre. Tile (x, z) has its centre at world (x + 0.5, z + 0.5).

export const MAP_W = 44;
export const MAP_H = 34;

// Street layout (z rows)
export const SIDEWALK_Z0 = 16; // near sidewalk rows 16..18
export const SIDEWALK_Z1 = 19;
export const ROAD_Z0 = 19; // road rows 19..24
export const ROAD_Z1 = 25;
export const FAR_WALK_Z0 = 25; // far sidewalk rows 25..26
export const FAR_WALK_Z1 = 27;

export const WALL_H = 3.0;

// Time: game minutes advanced per real second at 1x speed
export const MIN_PER_SEC = 2;
export const DAY_OPEN = 7 * 60;
export const DAY_CLOSE = 22 * 60;

export const PAL = {
  cream: 0xfff1dc,
  paper: 0xfbf6ee,
  terracotta: 0xe0663c,
  terracottaDark: 0xb44a28,
  teal: 0x1f8a86,
  tealDark: 0x136361,
  mustard: 0xf2b33d,
  ink: 0x1f2a44,
  mint: 0x86d6b4,
  rose: 0xf08f86,
  sky: 0x9fd0ee,
  lilac: 0xb9a6e0,
  wood: 0xc98b52,
  woodDark: 0x8a5a35,
  steel: 0xc3cad2,
  steelDark: 0x5b6570,
  asphalt: 0x4a4f58,
  curb: 0xc9c2b6,
  grass: 0x8fbf6a,
  leaf: 0x5fa35a,
};

export type Rect = { x0: number; z0: number; x1: number; z1: number }; // x1/z1 exclusive

export interface StageLayout {
  interior: Rect;
  doors: number[]; // x of door tiles on the front row (front row = interior.z1 - 1)
}

export const STAGE_LAYOUTS: StageLayout[] = [
  { interior: { x0: 18, z0: 10, x1: 26, z1: 16 }, doors: [22, 23] },
  { interior: { x0: 10, z0: 6, x1: 26, z1: 16 }, doors: [13, 14, 22, 23] },
];

export const TURKISH_NAMES = [
  'Ayşe', 'Mehmet', 'Zeynep', 'Emre', 'Elif', 'Can', 'Fatma', 'Hasan', 'Deniz', 'Selin',
  'Burak', 'Hatice', 'Mustafa', 'Ece', 'Kerem', 'Gül', 'Oğuz', 'Seda', 'Tarık', 'Nermin',
  'Yusuf', 'Melek', 'Cem', 'Derya', 'Kaan', 'Sibel', 'Levent', 'Pınar', 'Tuncay', 'Aslı',
  'Halil', 'Esra', 'Onur', 'Filiz', 'Serkan', 'Nazlı', 'İlker', 'Songül', 'Barış', 'Dilek',
];
