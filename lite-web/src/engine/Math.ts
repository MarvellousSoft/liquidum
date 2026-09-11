// src/engine/Math.ts

export class Vector2i {
    x: number;
    y: number;
    
    constructor(x: number, y: number) {
        this.x = x;
        this.y = y;
    }
}

export class Vector3i {
    x: number;
    y: number;
    z: number;
    
    constructor(x: number, y: number, z: number) {
        this.x = x;
        this.y = y;
        this.z = z;
    }
}

export class Rect2i {
    position: Vector2i;
    size: Vector2i;

    constructor(x: number, y: number, width: number, height: number) {
        this.position = new Vector2i(x, y);
        this.size = new Vector2i(width, height);
    }

    has_point(v: Vector2i): boolean {
        return v.x >= this.position.x && v.x < this.position.x + this.size.x &&
               v.y >= this.position.y && v.y < this.position.y + this.size.y;
    }

    intersection(other: Rect2i): Rect2i {
        const x1 = Math.max(this.position.x, other.position.x);
        const y1 = Math.max(this.position.y, other.position.y);
        const x2 = Math.min(this.position.x + this.size.x, other.position.x + other.size.x);
        const y2 = Math.min(this.position.y + this.size.y, other.position.y + other.size.y);
        if (x2 <= x1 || y2 <= y1) {
            return new Rect2i(0, 0, 0, 0);
        }
        return new Rect2i(x1, y1, x2 - x1, y2 - y1);
    }
}
