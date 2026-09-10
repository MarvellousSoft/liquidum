# Liquidum Lite

A lightweight web implementation of the Liquidum puzzle game. 

## Getting Started

Make sure you have Node.js installed, then install the dependencies and start the development server:

```bash
npm install
npm run dev
```

Then open the local URL (usually `http://localhost:5173/`) in your browser.

## Testing

To run the unit tests for the core puzzle engine logic:

```bash
npm test
```

## Structure

- `src/engine/` - Contains the core game logic (`GridImpl.ts`), DFS logic, and data models (`GridData.ts`).
- `src/components/` - Preact components for rendering the grid, cells, and hints.
- `tests/` - Tests validating the game's physics (water falling, air floating up, enclosed volumes, etc).
