export type Display = 'shelf' | 'fridge' | 'basket' | 'produce';
export type ProductShape = 'bag' | 'bar' | 'box' | 'bottle' | 'cup' | 'ring' | 'loaf' | 'fruit' | 'carton' | 'jug';

export interface ProductDef {
  id: string;
  name: string;
  brand: string;
  display: Display;
  cost: number; // wholesale unit cost (₺)
  basePrice: number; // "fair" shelf price customers expect
  color: number;
  accent: number;
  shape: ProductShape;
  impulse?: boolean; // grabbed from checkout area
  stage: number; // unlocked at stage index
}

export const PRODUCTS: ProductDef[] = [
  { id: 'cips', name: 'Cips', brand: 'ÇITIR', display: 'shelf', cost: 9, basePrice: 20, color: 0xf6b93b, accent: 0xd8402b, shape: 'bag', stage: 0 },
  { id: 'cikolata', name: 'Çikolata', brand: 'KAKAO+', display: 'shelf', cost: 6, basePrice: 14, color: 0x5a2f22, accent: 0xf0c35a, shape: 'bar', impulse: true, stage: 0 },
  { id: 'biskuvi', name: 'Bisküvi', brand: 'ÇAYYANI', display: 'shelf', cost: 8, basePrice: 17, color: 0x2e6db4, accent: 0xf6d67e, shape: 'box', stage: 0 },
  { id: 'kola', name: 'Kola', brand: 'KÖPÜK', display: 'fridge', cost: 11, basePrice: 25, color: 0xd8352c, accent: 0xffffff, shape: 'bottle', stage: 0 },
  { id: 'ayran', name: 'Ayran', brand: 'YAYLA', display: 'fridge', cost: 7, basePrice: 15, color: 0xf6f8fb, accent: 0x2b7fd8, shape: 'cup', stage: 0 },
  { id: 'simit', name: 'Simit', brand: 'FIRIN', display: 'basket', cost: 5, basePrice: 12, color: 0xc9803e, accent: 0xf3dcae, shape: 'ring', stage: 0 },
  { id: 'ekmek', name: 'Ekmek', brand: 'FIRIN', display: 'basket', cost: 6, basePrice: 12, color: 0xd99a55, accent: 0xf7e2b8, shape: 'loaf', stage: 0 },
  // Stage 1 (Mahalle Marketi)
  { id: 'domates', name: 'Domates', brand: 'BAHÇE', display: 'produce', cost: 14, basePrice: 26, color: 0xe2432f, accent: 0x3f8f3a, shape: 'fruit', stage: 1 },
  { id: 'elma', name: 'Elma', brand: 'BAHÇE', display: 'produce', cost: 12, basePrice: 22, color: 0x9ccc3a, accent: 0xd6452e, shape: 'fruit', stage: 1 },
  { id: 'sut', name: 'Süt', brand: 'YAYLA', display: 'fridge', cost: 18, basePrice: 32, color: 0xf7f7f2, accent: 0x33a4d8, shape: 'carton', stage: 1 },
  { id: 'deterjan', name: 'Deterjan', brand: 'PARLAK', display: 'shelf', cost: 38, basePrice: 65, color: 0x3fb6a8, accent: 0xffffff, shape: 'jug', stage: 1 },
];

export const PRODUCT_MAP: Record<string, ProductDef> = Object.fromEntries(PRODUCTS.map((p) => [p.id, p]));

export const DISPLAY_LABEL: Record<Display, string> = {
  shelf: 'Raf',
  fridge: 'Soğutucu',
  basket: 'Fırın sepeti',
  produce: 'Manav tezgâhı',
};
