export class RandomNumberGenerator {
  private state: bigint = 0n;
  private inc: bigint = 0n;

  // PCG32 Multiplier
  private static readonly MULTIPLIER = 6364136223846793005n;

  constructor(seed?: number | bigint) {
    if (seed !== undefined) {
      this.set_seed(BigInt(seed));
    }
  }

  set_seed(seed: bigint) {
    this.state = 0n;
    this.inc = (seed << 1n) | 1n;
    this.randi();
    this.state += seed;
    this.randi();
  }

  // Returns a 32-bit unsigned integer
  randi(): number {
    const oldstate = this.state;
    // Advance state
    this.state = (oldstate * RandomNumberGenerator.MULTIPLIER + this.inc) & 0xFFFFFFFFFFFFFFFFn;
    
    // Calculate output function (XSH RR)
    const xorshifted = Number(((oldstate >> 18n) ^ oldstate) >> 27n) >>> 0;
    const rot = Number(oldstate >> 59n);
    return ((xorshifted >>> rot) | (xorshifted << ((-rot) & 31))) >>> 0;
  }

  randf(): number {
    return this.randi() / 4294967296.0;
  }

  randi_range(from: number, to: number): number {
    if (from > to) {
      const temp = from;
      from = to;
      to = temp;
    }
    const range = (to - from + 1) >>> 0;
    if (range === 0) return from;
    return (from + (this.randi() % range)) >>> 0;
  }
}
