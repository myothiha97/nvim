import { add, user } from "./lib.js";

function greet(u) {
  const msg = `hi ${u.name} (${u.age})`;
  return msg;
}

let total = 0;
for (let i = 0; i < 5; i++) {
  total += add(i, total);
}
const s = greet(user);
console.log(s, total);
if (process.argv[2] === "throw") {
  throw new Error("boom from index");
}
console.log("done");
