export class SubsetSum {
    private static memo = new Map<string, boolean>();

    private static _dp(goal: number, numbers: number[]): boolean {
        if (goal < -1e-6) return false;
        if (Math.abs(goal) < 1e-6) return true;
        if (numbers.length === 0) return false;

        const key = `${Math.round(goal * 1000) / 1000}:${numbers.join(',')}`;
        if (this.memo.has(key)) return this.memo.get(key)!;

        const next = numbers.slice(0, numbers.length - 1);
        const last = numbers[numbers.length - 1];

        let result = false;
        if (this._dp(goal - last, next)) {
            result = true;
        } else if (this._dp(goal, next)) {
            result = true;
        }

        this.memo.set(key, result);
        return result;
    }

    static can_be_solved(goal: number, numbers: number[]): boolean {
        if (this.memo.size > 10000) {
            this.memo.clear();
        }
        const sorted = [...numbers].sort((a, b) => a - b);
        return this._dp(goal, sorted);
    }
}

export class OptionsSum {
    private static memo = new Map<string, boolean>();

    private static _dp(goal: number, options: number[][]): boolean {
        if (Math.abs(goal) < 1e-6 && options.length === 0) return true;
        if (goal < -1e-6 || options.length === 0) return false;

        const key = `${Math.round(goal * 1000) / 1000}:${options.map(o => o.join(',')).join(';')}`;
        if (this.memo.has(key)) return this.memo.get(key)!;

        const next = options.slice(0, options.length - 1);
        const lastOption = options[options.length - 1];

        let any = false;
        for (const opt of lastOption) {
            if (this._dp(goal - opt, next)) {
                any = true;
                break;
            }
        }

        this.memo.set(key, any);
        return any;
    }

    static can_be_solved(goal: number, options: number[][]): boolean {
        if (this.memo.size > 10000) {
            this.memo.clear();
        }
        // Normalize: ensure each option is sorted and options are sorted
        const sorted = options.map(o => [...o].sort((a, b) => a - b)).sort((a, b) => {
            for (let i = 0; i < Math.min(a.length, b.length); i++) {
                if (a[i] !== b[i]) return a[i] - b[i];
            }
            return a.length - b.length;
        });
        return this._dp(goal, sorted);
    }
}
