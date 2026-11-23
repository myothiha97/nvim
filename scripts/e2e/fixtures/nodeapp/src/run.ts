import { square } from "./math";

const values: number[] = [1, 2, 3];
let acc = 0;
for (const v of values) {
  acc += square(v);
}
console.log("acc", acc);
