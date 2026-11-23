export function square(n: number): number {
  const r = n * n;
  return r;
}
export function sum(xs: number[]): number {
  return xs.reduce((a, b) => a + b, 0);
}
