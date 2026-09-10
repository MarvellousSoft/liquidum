import { h } from 'preact';
import { useState, useEffect } from 'preact/hooks';
import { Grid } from './components/Grid';
import { parseGridData, Content, CellType, Corner, isLevelComplete } from './model/GridData';
import type { GridModelData } from './model/GridData';

const LEVELS: Record<string, any> = {
  "Level 01/01": {"description":"FIRST_LEVEL_DESCRIPTION","full_name":"LEVEL_01_01","grid_data":{"0":1,"11":[{"4":2,"5":0,"6":-1,"7":0},{"4":1,"5":0,"6":-1,"7":0},{"4":3,"5":0,"6":-1,"7":0}],"12":[{"4":1,"5":0,"6":-1,"7":0},{"4":2,"5":0,"6":-1,"7":0},{"4":3,"5":0,"6":-1,"7":0}],"13":[[{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}]],"14":[[1,1,1],[1,1,1]],"15":[[1,1],[1,1],[1,1]],"16":{"8":-1,"9":0,"10":{}}},"version":1, "tutorial":"mouse1"},
  "Level 02/01": {"full_name":"LEVEL_02_01","grid_data":{"0":1,"11":[{"4":3,"5":2,"6":-1,"7":0},{"4":3,"5":2,"6":-1,"7":0},{"4":3,"5":1,"6":-1,"7":0},{"4":2,"5":1,"6":-1,"7":0}],"12":[{"4":3,"5":2,"6":-1,"7":0},{"4":3,"5":2,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":3,"5":1,"6":-1,"7":0}],"13":[[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":11}]],"14":[[1,1,1,1],[1,1,1,1],[1,1,1,1]],"15":[[1,1,1],[1,1,0],[1,1,1],[1,1,1]],"16":{"8":-1,"9":0,"10":{}}},"version":1, "tutorial": "together_separate"},
  "Level 03/01": {"full_name":"LEVEL_03_01","grid_data":{"0":1,"11":[{"4":0.5,"5":0,"6":-1,"7":0},{"4":1.5,"5":0,"6":-1,"7":0},{"4":1,"5":0,"6":-1,"7":0},{"4":2.5,"5":0,"6":-1,"7":0}],"12":[{"4":-1,"5":0,"6":-1,"7":0},{"4":1.5,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":0.5,"5":0,"6":-1,"7":0}],"13":[[{"1":1,"2":2,"3":9},{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":10}],[{"1":1,"2":1,"3":10},{"1":1,"2":2,"3":9},{"1":2,"2":2,"3":10},{"1":2,"2":2,"3":11}],[{"1":1,"2":2,"3":9},{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":11},{"1":2,"2":1,"3":10}],[{"1":2,"2":1,"3":10},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":2,"2":2,"3":11}]],"14":[[0,0,0,0],[0,0,0,0],[1,1,1,1]],"15":[[0,0,0],[0,0,0],[0,1,0],[0,0,1]],"16":{"8":-1,"9":0,"10":{}}},"version":1},
  "Level 03/07": {"full_name":"LEVEL_03_07","grid_data":{"0":1,"11":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"12":[{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"13":[[{"1":3,"2":0,"3":9},{"1":0,"2":3,"3":10},{"1":3,"2":3,"3":11},{"1":3,"2":0,"3":9},{"1":0,"2":3,"3":10},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":3,"3":9}],[{"1":3,"2":0,"3":10},{"1":0,"2":3,"3":9},{"1":3,"2":1,"3":10},{"1":1,"2":1,"3":11},{"1":1,"2":3,"3":9},{"1":0,"2":0,"3":11},{"1":3,"2":3,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":3,"3":10},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":1,"3":10},{"1":3,"2":3,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":3,"3":10},{"1":3,"2":1,"3":10},{"1":1,"2":3,"3":10},{"1":3,"2":3,"3":11},{"1":1,"2":3,"3":10}],[{"1":1,"2":3,"3":9},{"1":0,"2":0,"3":11},{"1":0,"2":3,"3":9},{"1":3,"2":3,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":3,"3":9}],[{"1":3,"2":3,"3":11},{"1":1,"2":3,"3":9},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11}]],"14":[[0,0,1,0,0,1,1],[0,0,0,0,0,0,1],[1,1,1,1,1,0,1],[0,0,1,1,1,1,1],[0,0,0,1,0,1,0],[1,0,1,1,1,1,1]],"15":[[0,1,1,0,1,1],[0,0,0,0,0,0],[0,1,0,0,1,1],[0,1,1,1,1,1],[0,0,1,0,1,1],[1,0,1,1,0,0],[1,1,1,1,1,1]],"16":{"8":-1,"9":0,"10":{}}},"version":1},
  "Level 04/01": {"full_name":"LEVEL_04_01","grid_data":{"0":1,"11":[{"4":-1,"5":0,"6":2,"7":0},{"4":-1,"5":0,"6":2,"7":0},{"4":4.5,"5":0,"6":-1,"7":0}],"12":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"13":[[{"1":4,"2":4,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":4,"2":4,"3":11}],[{"1":1,"2":1,"3":11},{"1":4,"2":4,"3":11},{"1":0,"2":0,"3":11},{"1":4,"2":4,"3":11},{"1":0,"2":1,"3":10}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":10},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":0,"3":10}]],"14":[[0,1,1,1,0],[0,0,0,0,0]],"15":[[0,0,0,0],[1,0,0,1],[0,0,0,0]],"16":{"8":-1,"9":-1,"10":{}}},"version":1, "tutorial": "boats"},
  "Level 05/01": {"full_name":"LEVEL_05_01","grid_data":{"0":1,"11":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"12":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"13":[[{"1":1,"2":1,"3":10},{"1":1,"2":1,"3":9},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":3,"3":9},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}]],"14":[[0,0,0,0,0],[1,1,1,0,1]],"15":[[0,1,0,0],[0,1,0,1],[0,0,0,0]],"16":{"8":-1,"9":0,"10":{"0":0,"2.5":1,"3":1}}},"version":1},
  "Level 06/01": {"full_name":"LEVEL_06_01","grid_data":{"0":1,"11":[{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0}],"12":[{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0}],"13":[[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}]],"14":[[1,1,1,1],[1,1,1,1],[1,0,1,1]],"15":[[0,1,1],[1,0,1],[1,1,1],[1,1,0]],"16":{"8":-1,"9":0,"10":{}}},"version":1}
};

import { GridImpl } from './engine/GridImpl';

export function App() {
  const [gridData, setGridData] = useState<GridModelData | null>(null);
  const [isPointerDown, setIsPointerDown] = useState(false);
  const [dragAction, setDragAction] = useState<{ corner: Corner, content: Content } | null>(null);
  const [won, setWon] = useState(false);
  const [autoFloodAir, setAutoFloodAir] = useState(false);

  useEffect(() => {
    loadLevel("Level 01/01");
    const handleUp = () => setIsPointerDown(false);
    window.addEventListener('pointerup', handleUp);
    return () => window.removeEventListener('pointerup', handleUp);
  }, []);

  const loadLevel = (levelKey: string) => {
    try {
      const data = parseGridData(LEVELS[levelKey]);
      for (let r = 0; r < data.cells.length; r++) {
        for (let c = 0; c < data.cells[r].length; c++) {
          if (data.cells[r][c].c_left !== Content.Block) data.cells[r][c].c_left = Content.Nothing;
          if (data.cells[r][c].c_right !== Content.Block) data.cells[r][c].c_right = Content.Nothing;
        }
      }
      setGridData(data);
      setWon(false);
    } catch (e) {
      console.error(e);
    }
  };

  const executeEngineAction = (r: number, c: number, action: { corner: Corner, content: Content }) => {
    setGridData(prev => {
      if (!prev) return prev;
      const engine = GridImpl.load_from_grid_data(prev);
      
      const currContent = (engine.get_cell(r, c) as any).pure()._content_at(action.corner as unknown as any);
      if (currContent === Content.Block) return prev;
      
      if (action.content === Content.Water) {
        (engine.get_cell(r, c) as any).put_water(action.corner as unknown as any);
      } else if (action.content === Content.NoWater) {
        (engine.get_cell(r, c) as any).put_nowater(action.corner as unknown as any, false, autoFloodAir);
      } else if (action.content === Content.Nothing) {
        (engine.get_cell(r, c) as any).remove_content(action.corner as unknown as any, false, autoFloodAir);
      }
      
      const next = engine.to_grid_data();
      setWon(isLevelComplete(next));
      return next;
    });
  };

  const handleCellDown = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    setIsPointerDown(true);
    if (!gridData) return;
    const cell = gridData.cells[r][c];
    
    let currentContent = Content.Nothing;
    if (cell.type === CellType.Single) {
      currentContent = cell.c_left;
    } else {
      currentContent = (corner === Corner.TopLeft || corner === Corner.BottomLeft) ? cell.c_left : cell.c_right;
    }
    
    if (currentContent === Content.Block) return;

    let targetContent = Content.Nothing;
    if (e.button === 2) {
      targetContent = currentContent === Content.NoWater ? Content.Nothing : Content.NoWater;
    } else {
      targetContent = currentContent === Content.Water ? Content.Nothing : Content.Water;
    }
    
    setDragAction({ corner, content: targetContent });
    executeEngineAction(r, c, { corner, content: targetContent });
  };

  const handleCellEnter = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    if (isPointerDown && dragAction) {
      executeEngineAction(r, c, { corner: corner, content: dragAction.content });
    }
  };

  return (
    <div 
      class="min-h-screen flex flex-col items-center justify-center p-4 relative"
      onPointerUp={() => setIsPointerDown(false)}
      onPointerLeave={() => setIsPointerDown(false)}
      onContextMenu={(e) => e.preventDefault()}
    >
      <div class="absolute inset-0 bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 -z-10" />
      
      <div class="mb-4 flex flex-wrap gap-2 max-w-2xl justify-center">
        {Object.keys(LEVELS).map(key => (
          <button 
            key={key}
            onClick={() => loadLevel(key)}
            class={`px-3 py-1 md:px-4 md:py-2 text-sm md:text-base font-bold transition-colors rounded ${
               gridData && LEVELS[key].full_name === gridData.full_name ? 'bg-emerald-600 text-white' : 'bg-blue-600 hover:bg-blue-500 text-white'
            }`}
          >
            {key}
          </button>
        ))}
      </div>
      
      <div class="mb-4">
        <label class="flex items-center space-x-2 text-white font-bold cursor-pointer bg-white/10 px-4 py-2 rounded-full border border-white/20 hover:bg-white/20 transition-colors">
          <input 
             type="checkbox" 
             checked={autoFloodAir} 
             onChange={(e) => setAutoFloodAir(e.currentTarget.checked)}
             class="w-5 h-5 rounded border-gray-300 text-blue-600 focus:ring-blue-600 focus:ring-2 cursor-pointer"
          />
          <span>Auto-Flood Air (✕) Upwards</span>
        </label>
      </div>

      <h1 class="text-4xl md:text-6xl font-black text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-emerald-400 mb-8 drop-shadow-lg">
        Liquidum Lite
      </h1>

      {won && (
        <div class="mb-6 p-4 bg-green-500/20 border border-green-500 text-green-300 rounded-xl text-xl font-bold animate-pulse">
          🎉 Level Complete! 🎉
        </div>
      )}

      {gridData ? (
        <div class="backdrop-blur-md bg-white/5 p-4 md:p-8 rounded-3xl border border-white/10 shadow-[0_0_40px_rgba(0,0,0,0.3)]">
          <Grid 
            gridData={gridData} 
            onCellPointerDown={handleCellDown}
            onCellPointerEnter={handleCellEnter}
          />
        </div>
      ) : (
        <p>Loading...</p>
      )}
    </div>
  );
}
