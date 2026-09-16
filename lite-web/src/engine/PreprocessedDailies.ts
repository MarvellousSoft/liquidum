// src/engine/PreprocessedDailies.ts

export class PreprocessedDailies {
    private _success_states: bigint[] = [];

    constructor() {
        this._success_states = new Array(31 * 12).fill(0n);
    }

    static load_data(data: string[] | null | undefined): PreprocessedDailies {
        const preprocessed = new PreprocessedDailies();
        if (!data) {
            return preprocessed;
        }
        preprocessed._success_states = data.map(x => BigInt(x));
        return preprocessed;
    }

    _idx(month: number, day: number): number {
        return (month - 1) * 31 + day - 1;
    }

    success_state(month: number, day: number): bigint {
        const idx = this._idx(month, day);
        return (idx >= 0 && idx < this._success_states.length) ? this._success_states[idx] : 0n;
    }

    set_success_state(month: number, day: number, state: bigint): void {
        this._success_states[this._idx(month, day)] = state;
    }
}
