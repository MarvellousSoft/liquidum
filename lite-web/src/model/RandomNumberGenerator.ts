export class RandomNumberGenerator {
  // PCG32 Multiplier and Default Increment
  private static readonly MULTIPLIER = 6364136223846793005n;
  private static readonly PCG_DEFAULT_INC_64 = 1442695040888963407n;

  private state: bigint = 0n;
  private inc: bigint = (RandomNumberGenerator.PCG_DEFAULT_INC_64 << 1n) | 1n;

  private currentSeed: bigint = 0n;

  constructor(seed?: number | bigint) {
    if (seed !== undefined) {
      this.set_seed(seed);
    }
  }

  set_seed(seed: number | bigint) {
    const s = BigInt(seed);
    this.currentSeed = s;
    this.state = 0n;
    this.inc = (RandomNumberGenerator.PCG_DEFAULT_INC_64 << 1n) | 1n;
    this.randi();
    this.state = (this.state + s) & 0xFFFFFFFFFFFFFFFFn;
    this.randi();
  }

  get_seed(): bigint {
    return this.currentSeed;
  }

  get_state(): bigint {
    return BigInt.asIntN(64, this.state);
  }

  set_state(state: number | bigint) {
    this.state = BigInt.asUintN(64, BigInt(state));
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
    const proto_exp_offset = this.randi();
    if (proto_exp_offset === 0) {
      return 0;
    }
    const clz = Math.clz32(proto_exp_offset);
    return Math.fround(Math.fround((this.randi() | 0x80000001) >>> 0) * Math.pow(2, -32 - clz));
  }

  randf_range(from: number, to: number): number {
    return this.randf() * (to - from) + from;
  }

  private bounded_rand(bound: number): number {
    const threshold = ((-bound >>> 0) % bound) >>> 0;
    while (true) {
      const r = this.randi();
      if (r >= threshold) {
        return r % bound;
      }
    }
  }

  randi_range(from: number, to: number): number {
    if (from === to) {
      return from;
    }
    const min = Math.min(from, to);
    const max = Math.max(from, to);
    const bound = (max - min + 1) >>> 0;
    return min + this.bounded_rand(bound);
  }
}
