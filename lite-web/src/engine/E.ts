// src/engine/E.ts

export namespace E {
    export enum Side { Top = 1, Right = 2, Bottom = 3, Left = 4 }
    export enum Corner { TopLeft = 5, TopRight = 6, BottomRight = 7, BottomLeft = 8 }
    export enum Diagonal { Inc = 9, Dec = 10 }
    
    export enum CellType { IncDiag = 9, DecDiag = 10, Single = 11 }
    export enum Walls { Top = 1, Right = 2, Bottom = 3, Left = 4, IncDiag = 9, DecDiag = 10 }
    export enum Waters { TopLeft = 5, TopRight = 6, BottomRight = 7, BottomLeft = 8, Single = 11 }
    
    export enum MouseDragState { None, Water, NoWater, Boat, NoBoat, Wall, Block, RemoveWater, RemoveNoWater, RemoveBoat, RemoveNoBoat, RemoveWall, RemoveBlock }
    
    export enum BrushMode { Water, NoWater, Boat, NoBoat, Wall, Block, CellHints }
    
    export enum HintContent { Water, Boat }
    export enum HintType { Hidden, Together, Separated, Zero }
    export enum HintStatus { Normal, Wrong, Satisfied }
    
    export function corner_is_left(corner: Corner): boolean {
        return corner === Corner.TopLeft || corner === Corner.BottomLeft;
    }
    
    export function corner_is_top(corner: Corner): boolean {
        return corner === Corner.TopLeft || corner === Corner.TopRight;
    }
    
    export function corner_is_side(corner: Corner, side: Side): boolean {
        switch (side) {
            case Side.Left: return corner_is_left(corner);
            case Side.Right: return !corner_is_left(corner);
            case Side.Top: return corner_is_top(corner);
            case Side.Bottom: return !corner_is_top(corner);
        }
        throw new Error("Invalid side");
    }
    
    export function corner_to_diag(corner: Corner): Diagonal {
        if (corner === Corner.BottomLeft || corner === Corner.TopRight) {
            return Diagonal.Dec;
        } else {
            return Diagonal.Inc;
        }
    }
    
    export function diag_to_corner(cell: CellType, side: Side): Corner {
        if (cell === CellType.IncDiag) {
            switch (side) {
                case Side.Top:
                case Side.Left:
                    return Corner.TopLeft;
                case Side.Bottom:
                case Side.Right:
                    return Corner.BottomRight;
            }
        } else { // DecDiag or Single
            switch (side) {
                case Side.Top:
                case Side.Right:
                    return Corner.TopRight;
                case Side.Bottom:
                case Side.Left:
                    return Corner.BottomLeft;
            }
        }
        throw new Error("Invalid side");
    }
    
    export function corner_to_waters(corner: Corner, type: CellType): Waters {
        if (type === CellType.Single) {
            return Waters.Single;
        } else {
            return corner as unknown as Waters;
        }
    }
    
    export function waters_size(waters: Waters): number {
        if (waters === Waters.Single) {
            return 1.0;
        } else {
            return 0.5;
        }
    }
    
    export function waters_to_corner(waters: Waters): Corner {
        if (waters === Waters.Single) {
            return Corner.TopLeft;
        } else {
            return waters as unknown as Corner;
        }
    }
}
