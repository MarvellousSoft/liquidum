import { h } from 'preact';
import { useState, useEffect, useRef } from 'preact/hooks';
import { Grid } from './components/Grid';
import { parseGridData, Content, CellType, Corner, isLevelComplete, countWaterRow, countBoatRow, getAquariums, levelHasBoats } from './model/GridData';
import type { GridModelData } from './model/GridData';

import {
  TEST_LEVEL_KEYS,
  normalizeLevelKey,
  loadLevelData,
} from './engine/LevelDatabase';
import {
  UserLevelSaveData,
  saveDailyLevelProgress,
  loadDailyLevelProgress,
  clearDailyLevelProgress,
  saveLevelProgress,
  loadLevelProgress,
  LEVEL_SAVE_STORAGE_PREFIX,
} from './engine/UserLevelSaveData';
import { GridExporter } from './engine/GridExporter';
import { GridImpl, PureCell } from './engine/GridImpl';
import { E } from './engine/E';
import { LoadMode } from './engine/Grid';
import {
  load_daily_level_data,
  get_today_str,
  shiftDate,
  getTimeLeftTodaySeconds,
  formatTimeLeft,
  formatTimeLeftDetailed,
  generateDailyShareText,
} from './engine/DailyLevel';
import type { DailyLevelMeta } from './engine/DailyLevel';
import {
  getStreakData,
  recordDailyCompletion,
} from './engine/StreakManager';
import type { StreakData } from './engine/StreakManager';
import { LeaderboardModal } from './components/LeaderboardModal';
import { LeaderboardView } from './components/LeaderboardView';
import { playFabService } from './engine/PlayFabService';

export type GameMode = 'daily' | 'weekly' | 'custom' | 'test';

function formatSolveTime(totalSeconds: number): string {
  const mins = Math.floor(totalSeconds / 60);
  const secs = totalSeconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

function toEngineCorner(c: Corner | E.Corner): E.Corner {
  switch (c) {
    case Corner.TopLeft: return E.Corner.TopLeft;
    case Corner.TopRight: return E.Corner.TopRight;
    case Corner.BottomLeft: return E.Corner.BottomLeft;
    case Corner.BottomRight: return E.Corner.BottomRight;
    default: return E.Corner.TopLeft;
  }
}

export function App() {
  const [gridData, setGridData] = useState<GridModelData | null>(null);
  const [currentLevelKey, setCurrentLevelKey] = useState<string>("Level 01/01");
  const [completedLevels, setCompletedLevels] = useState<Set<string>>(new Set());
  const [gameMode, setGameMode] = useState<GameMode>("daily");
  const [isDailyMode, setIsDailyMode] = useState<boolean>(false);
  const [dailyDate, setDailyDate] = useState<string>(() => get_today_str());
  const [dailyMeta, setDailyMeta] = useState<DailyLevelMeta | null>(null);
  const [isLoadingDaily, setIsLoadingDaily] = useState<boolean>(false);
  const [copiedShare, setCopiedShare] = useState<boolean>(false);
  const [timeLeftSeconds, setTimeLeftSeconds] = useState<number>(() => getTimeLeftTodaySeconds());
  const [streakData, setStreakData] = useState<StreakData>(() => getStreakData());

  const isDailyModeRef = useRef(isDailyMode);
  isDailyModeRef.current = isDailyMode;
  const dailyDateRef = useRef(dailyDate);
  dailyDateRef.current = dailyDate;
  const [isPointerDown, setIsPointerDown] = useState(false);
  const [mouseHoldStatus, setMouseHoldStatus] = useState<E.MouseDragState>(E.MouseDragState.None);
  const mouseHoldStatusRef = useRef<E.MouseDragState>(E.MouseDragState.None);
  const [won, setWon] = useState(false);
  const [autoFloodAir, setAutoFloodAir] = useState(false);
  const [selectedTool, setSelectedTool] = useState<Content.Water | Content.Boat | Content.NoWater | Content.NoBoat>(Content.Water);
  const [mistakes, setMistakes] = useState<number>(0);
  const mistakesRef = useRef(mistakes);
  mistakesRef.current = mistakes;
  const [blinkingCells, setBlinkingCells] = useState<Map<string, { corner: Corner, timestamp: number }>>(new Map());
  const [mistakePulse, setMistakePulse] = useState<boolean>(false);
  const hasBoats = levelHasBoats(gridData);
  const hasBoatsRef = useRef(hasBoats);
  hasBoatsRef.current = hasBoats;

  const [showShortcuts, setShowShortcuts] = useState<boolean>(false);
  const showShortcutsRef = useRef(showShortcuts);
  showShortcutsRef.current = showShortcuts;

  const [showLevelsModal, setShowLevelsModal] = useState<boolean>(false);
  const showLevelsModalRef = useRef(showLevelsModal);
  showLevelsModalRef.current = showLevelsModal;

  const [showLeaderboardModal, setShowLeaderboardModal] = useState<boolean>(false);
  const [leaderboardRefreshKey, setLeaderboardRefreshKey] = useState<number>(0);
  const [hasStarted, setHasStarted] = useState<boolean>(false);
  const hasStartedRef = useRef(hasStarted);
  hasStartedRef.current = hasStarted;

  const [secondsElapsed, setSecondsElapsed] = useState<number>(0);
  const secondsElapsedRef = useRef(secondsElapsed);
  secondsElapsedRef.current = secondsElapsed;

  // Countdown timer for daily puzzle deadline (UTC midnight)
  useEffect(() => {
    setTimeLeftSeconds(getTimeLeftTodaySeconds());
    const interval = setInterval(() => {
      setTimeLeftSeconds(getTimeLeftTodaySeconds());
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  // Refresh streak data on mount
  useEffect(() => {
    setStreakData(getStreakData());
  }, []);

  // Solving timer: ticks every 1 second when started and level not yet won
  useEffect(() => {
    if (!hasStarted || won) return;
    const interval = setInterval(() => {
      setSecondsElapsed((s) => s + 1);
    }, 1000);
    return () => clearInterval(interval);
  }, [hasStarted, won]);

  const hoveredCellRef = useRef<{ row: number; col: number; corner: Corner } | null>(null);
  const currentBrushKeyRef = useRef<string | null>(null);

  const selectedToolRef = useRef(selectedTool);
  selectedToolRef.current = selectedTool;
  const currentLevelKeyRef = useRef(currentLevelKey);
  currentLevelKeyRef.current = currentLevelKey;
  const autoFloodAirRef = useRef(autoFloodAir);
  autoFloodAirRef.current = autoFloodAir;
  const wonRef = useRef(won);
  wonRef.current = won;

  const [canUndo, setCanUndo] = useState<boolean>(false);
  const [canRedo, setCanRedo] = useState<boolean>(false);
  const engineRef = useRef<GridImpl | null>(null);

  const saveProgress = (forceWon?: boolean) => {
    const engine = engineRef.current;
    if (!engine || !hasStartedRef.current) return;

    const isLevelWon = forceWon !== undefined ? forceWon : wonRef.current;
    const isEmpty = engine.is_empty();
    const curMistakes = mistakesRef.current;
    const curTime = secondsElapsedRef.current;
    const gridDataExport = engine.export_data();

    const existing = isDailyModeRef.current
      ? loadDailyLevelProgress(dailyDateRef.current)
      : loadLevelProgress(currentLevelKeyRef.current);

    const save = new UserLevelSaveData(
      gridDataExport,
      isEmpty,
      curMistakes,
      curTime
    );

    if (existing) {
      save.best_mistakes = existing.best_mistakes;
      save.best_time_secs = existing.best_time_secs;
    }

    if (isLevelWon) {
      save.save_completion(curMistakes, curTime);
    }

    if (isDailyModeRef.current) {
      if (dailyDateRef.current) {
        saveDailyLevelProgress(dailyDateRef.current, save);
      }
    } else {
      if (currentLevelKeyRef.current) {
        saveLevelProgress(currentLevelKeyRef.current, save);
      }
    }
  };

  const saveProgressRef = useRef(saveProgress);
  saveProgressRef.current = saveProgress;

  // Persist timer & progress on each second tick
  useEffect(() => {
    if (hasStarted) {
      saveProgressRef.current();
    }
  }, [secondsElapsed]);

  // Persist progress before unload / refresh
  useEffect(() => {
    const onBeforeUnload = () => {
      saveProgressRef.current();
    };
    window.addEventListener('beforeunload', onBeforeUnload);
    return () => window.removeEventListener('beforeunload', onBeforeUnload);
  }, []);

  // Submit daily score on first victory & update streak
  useEffect(() => {
    if (won) {
      saveProgressRef.current(true);
    }

    if (won && isDailyModeRef.current && dailyDateRef.current) {
      const todayStr = get_today_str();
      const isToday = dailyDateRef.current === todayStr;

      if (isToday) {
        // Record streak for today's puzzle
        const streakResult = recordDailyCompletion(dailyDateRef.current, mistakesRef.current);
        setStreakData({
          currentStreak: streakResult.currentStreak,
          bestStreak: streakResult.bestStreak,
          lastCompletedDay: todayStr,
        });

        // Submit score to PlayFab
        playFabService
          .submitDailyScore(
            secondsElapsedRef.current,
            mistakesRef.current,
            dailyDateRef.current,
            streakResult.currentStreak
          )
          .then((res) => {
            if (res.submitted) {
              console.log("PlayFab daily score submitted successfully!");
              setLeaderboardRefreshKey((k) => k + 1);
              setShowLeaderboardModal(true);
            } else if (res.reason === "already_submitted") {
              console.log("Daily score already submitted for this day.");
            } else if (res.reason === "older_level") {
              console.log("Older level, skipping score submission.");
            }
          })
          .catch((err) => {
            console.warn("PlayFab score submission skipped or failed:", err);
          });
      }
    }
  }, [won]);

  const handleUndo = () => {
    const engine = engineRef.current;
    if (!engine) return;
    if (engine.undo()) {
      const next = engine.to_grid_data();
      setGridData(next);
      setWon(isLevelComplete(next));
      setCanUndo(engine.can_undo());
      setCanRedo(engine.can_redo());
      saveProgressRef.current();
    }
  };

  const handleRedo = () => {
    const engine = engineRef.current;
    if (!engine) return;
    if (engine.redo()) {
      const next = engine.to_grid_data();
      setGridData(next);
      setWon(isLevelComplete(next));
      setCanUndo(engine.can_undo());
      setCanRedo(engine.can_redo());
      saveProgressRef.current();
    }
  };

  const handleUndoRef = useRef(handleUndo);
  handleUndoRef.current = handleUndo;
  const handleRedoRef = useRef(handleRedo);
  handleRedoRef.current = handleRedo;

  const handlePointerUp = () => {
    setIsPointerDown(false);
    mouseHoldStatusRef.current = E.MouseDragState.None;
    setMouseHoldStatus(E.MouseDragState.None);
    currentBrushKeyRef.current = null;
    if (engineRef.current) {
      while (
        engineRef.current.undo_stack.length > 0 &&
        engineRef.current.undo_stack[engineRef.current.undo_stack.length - 1].changes.length === 0
      ) {
        engineRef.current.undo_stack.pop();
      }
      setCanUndo(engineRef.current.can_undo());
      setCanRedo(engineRef.current.can_redo());
      saveProgressRef.current();
    }
  };

  useEffect(() => {
    if (!hasBoats && (selectedTool === Content.Boat || selectedTool === Content.NoBoat)) {
      setSelectedTool(Content.Water);
    }
  }, [hasBoats, selectedTool]);

  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false;
    return localStorage.getItem('liquidum_theme') === 'dark';
  });

  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('liquidum_theme', isDarkMode ? 'dark' : 'light');
    }
  }, [isDarkMode]);

  const isTestMode = typeof window !== 'undefined' && (
    new URLSearchParams(window.location.search).get('mode') === 'test'
  );

  const loadLevelFromString = (levelStr: string, preserveContents: boolean = false) => {
    try {
      setIsDailyMode(false);
      setDailyMeta(null);
      const engine = GridImpl.from_str(levelStr, preserveContents ? LoadMode.Testing : LoadMode.SolutionNoClear);
      if (!preserveContents) {
        for (let r = 0; r < engine.rows(); r++) {
          for (let c = 0; c < engine.cols(); c++) {
            const pure = engine.pure_cells[r][c];
            if (pure.c_left !== Content.Block) pure.c_left = Content.Nothing;
            if (pure.c_right !== Content.Block) pure.c_right = Content.Nothing;
          }
        }
      }
      engine.undo_stack = [];
      engine.redo_stack = [];
      engine.maybe_update_hints();
      engineRef.current = engine;
      const data = engine.to_grid_data();
      setGridData(data);
      setWon(preserveContents ? isLevelComplete(data) : false);
      setMistakes(0);
      setBlinkingCells(new Map());
      setCanUndo(false);
      setCanRedo(false);
    } catch (e) {
      console.error("Failed to load level from string", e);
    }
  };

  const loadLevel = async (levelKeyOrShort: string) => {
    try {
      setIsDailyMode(false);
      setDailyMeta(null);
      setGameMode('test');

      const norm = normalizeLevelKey(levelKeyOrShort);
      const canonicalKey = norm ? norm.key : levelKeyOrShort;
      setCurrentLevelKey(canonicalKey);

      if (typeof window !== 'undefined') {
        const url = new URL(window.location.href);
        if (url.searchParams.has('daily') || url.searchParams.has('date') || url.searchParams.get('mode') === 'daily') {
          url.searchParams.delete('daily');
          url.searchParams.delete('date');
          url.searchParams.delete('mode');
        }
        url.searchParams.delete('testLevel');
        if (norm) {
          url.searchParams.set('level', `${norm.section}/${norm.level}`);
        } else {
          url.searchParams.set('level', canonicalKey);
        }
        window.history.replaceState({}, '', url.toString());
      }

      const rawLevel = await loadLevelData(canonicalKey);
      if (!rawLevel) {
        console.error(`Failed to load level data for ${canonicalKey}`);
        return;
      }

      const data = parseGridData(rawLevel);

      const solution_c_left: Content[][] = [];
      const solution_c_right: Content[][] = [];
      let hasSolutionCells = false;
      for (let r = 0; r < data.cells.length; r++) {
        solution_c_left.push([]);
        solution_c_right.push([]);
        for (let c = 0; c < data.cells[r].length; c++) {
          solution_c_left[r].push(data.cells[r][c].c_left);
          solution_c_right[r].push(data.cells[r][c].c_right);
          if (
            data.cells[r][c].c_left === Content.Water ||
            data.cells[r][c].c_left === Content.Boat ||
            data.cells[r][c].c_right === Content.Water ||
            data.cells[r][c].c_right === Content.Boat
          ) {
            hasSolutionCells = true;
          }
        }
      }
      if (hasSolutionCells) {
        data.solution_c_left = solution_c_left;
        data.solution_c_right = solution_c_right;
      }

      for (let r = 0; r < data.cells.length; r++) {
        for (let c = 0; c < data.cells[r].length; c++) {
          if (data.cells[r][c].c_left !== Content.Block) data.cells[r][c].c_left = Content.Nothing;
          if (data.cells[r][c].c_right !== Content.Block) data.cells[r][c].c_right = Content.Nothing;
        }
      }

      const engine = GridImpl.load_from_grid_data(data);
      engine.undo_stack = [];
      engine.redo_stack = [];
      engine.maybe_update_hints();
      engineRef.current = engine;

      const saved = loadLevelProgress(canonicalKey);
      if (saved && saved.grid_data) {
        try {
          new GridExporter().load_data(engine, saved.grid_data, LoadMode.ContentOnly, PureCell);
          const restoredData = engine.to_grid_data();
          const isComplete = isLevelComplete(restoredData);
          setGridData(restoredData);
          setWon(isComplete);
          setMistakes(saved.mistakes || 0);
          setSecondsElapsed(Math.floor(saved.timer_secs) || 0);
        } catch (e) {
          console.warn("Failed to restore test level progress:", e);
          setGridData(data);
          setWon(false);
          setMistakes(0);
          setSecondsElapsed(0);
        }
      } else {
        setGridData(data);
        setWon(false);
        setMistakes(0);
        setSecondsElapsed(0);
      }

      setBlinkingCells(new Map());
      setCanUndo(false);
      setCanRedo(false);
      setHasStarted(true);
    } catch (e) {
      console.error(e);
    }
  };

  const loadDailyLevel = async (dateStr?: string) => {
    const todayStr = get_today_str();
    let targetDate = (dateStr && dateStr !== 'today') ? dateStr : (dailyDateRef.current || todayStr);
    if (targetDate > todayStr) {
      targetDate = todayStr;
    }
    setIsLoadingDaily(true);
    setIsDailyMode(true);
    setGameMode('daily');
    setDailyDate(targetDate);
    setCopiedShare(false);

    if (typeof window !== 'undefined') {
      const url = new URL(window.location.href);
      if (targetDate < todayStr) {
        url.searchParams.set('daily', targetDate);
      } else {
        url.searchParams.delete('daily');
        url.searchParams.delete('date');
      }
      url.searchParams.delete('testLevel');
      url.searchParams.delete('level');
      url.searchParams.delete('mode');
      const search = url.searchParams.toString();
      const newUrl = url.pathname + (search ? `?${search}` : '') + url.hash;
      window.history.replaceState({}, '', newUrl);
    }

    try {
      const result = await load_daily_level_data(targetDate);
      if (!result) {
        console.error("Failed to generate daily level for", targetDate);
        setIsLoadingDaily(false);
        return;
      }
      const { engine, gridData: data, meta } = result;
      engineRef.current = engine;
      setDailyMeta(meta);

      const saved = loadDailyLevelProgress(targetDate);
      if (saved && saved.grid_data) {
        try {
          new GridExporter().load_data(engine, saved.grid_data, LoadMode.ContentOnly, PureCell);
          const restoredData = engine.to_grid_data();
          const isComplete = isLevelComplete(restoredData);
          setGridData(restoredData);
          setWon(isComplete);
          setMistakes(saved.mistakes || 0);
          setSecondsElapsed(Math.floor(saved.timer_secs) || 0);
          setHasStarted(!saved.is_empty || saved.timer_secs > 0 || isComplete);
        } catch (e) {
          console.warn("Failed to restore daily level progress:", e);
          setGridData(data);
          setWon(false);
          setMistakes(0);
          setSecondsElapsed(0);
          setHasStarted(false);
        }
      } else {
        setGridData(data);
        setWon(false);
        setMistakes(0);
        setSecondsElapsed(0);
        setHasStarted(false);
      }

      setBlinkingCells(new Map());
      setCanUndo(false);
      setCanRedo(false);
    } catch (err) {
      console.error("Error loading daily level:", err);
    } finally {
      setIsLoadingDaily(false);
    }
  };

  const handleRestart = () => {
    setSecondsElapsed(0);
    if (isDailyModeRef.current) {
      clearDailyLevelProgress();
      loadDailyLevel(dailyDateRef.current).then(() => {
        setHasStarted(true);
      });
    } else {
      try {
        localStorage.removeItem(LEVEL_SAVE_STORAGE_PREFIX + currentLevelKeyRef.current);
      } catch {}
      loadLevel(currentLevelKeyRef.current);
    }
  };

  const handleShare = async () => {
    const text = generateDailyShareText({
      dateStr: dailyDateRef.current,
      seconds: secondsElapsedRef.current,
      mistakes: mistakesRef.current,
    });

    const markCopied = () => {
      setCopiedShare(true);
      setTimeout(() => setCopiedShare(false), 2500);
    };

    const isMobile =
      typeof window !== 'undefined' &&
      (('ontouchstart' in window) ||
        (navigator?.maxTouchPoints && navigator.maxTouchPoints > 0) ||
        /Mobi|Android|iPhone|iPad|iPod/i.test(navigator?.userAgent || ''));

    if (isMobile && typeof navigator?.share === 'function') {
      try {
        await navigator.share({
          title: "Liquidum",
          text,
        });
        return;
      } catch (err) {
        if ((err as Error)?.name === 'AbortError') {
          return;
        }
      }
    }

    if (navigator?.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(markCopied).catch(() => {
        try {
          const ta = document.createElement('textarea');
          ta.value = text;
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          document.body.appendChild(ta);
          ta.focus();
          ta.select();
          document.execCommand('copy');
          document.body.removeChild(ta);
          markCopied();
        } catch {
          markCopied();
        }
      });
    } else {
      try {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.focus();
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        markCopied();
      } catch {
        markCopied();
      }
    }
  };

  const loadLevelRef = useRef(loadLevel);
  loadLevelRef.current = loadLevel;
  const loadDailyLevelRef = useRef(loadDailyLevel);
  loadDailyLevelRef.current = loadDailyLevel;
  const handleRestartRef = useRef(handleRestart);
  handleRestartRef.current = handleRestart;

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const levelParam = params.get('testLevel') || params.get('level');
    const dailyParam = params.get('daily') || params.get('date');
    const mode = params.get('mode');

    if (levelParam) {
      const norm = normalizeLevelKey(levelParam);
      if (norm) {
        setGameMode('test');
        loadLevel(norm.key);
      } else {
        setGameMode('custom');
        loadLevelFromString(levelParam);
      }
    } else if (dailyParam) {
      const todayStr = get_today_str();
      const requestedDate = dailyParam !== 'today' ? dailyParam : todayStr;
      const dateToLoad = requestedDate > todayStr ? todayStr : requestedDate;
      loadDailyLevel(dateToLoad);
    } else if (mode === 'test') {
      setGameMode('test');
      loadLevel("Level 01/01");
    } else if (mode === 'weekly') {
      setGameMode('weekly');
      loadDailyLevel();
    } else {
      loadDailyLevel();
    }

    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement)?.tagName === 'INPUT' || (e.target as HTMLElement)?.tagName === 'TEXTAREA') {
        return;
      }
      const key = e.key.toLowerCase();

      // Ignore browser auto-repeat for shortcuts, tool selection, and modal toggles
      if (e.repeat && key !== 'z' && key !== 'y') {
        return;
      }

      // Escape closes shortcuts and levels modals
      if (e.key === 'Escape') {
        setShowShortcuts(false);
        setShowLevelsModal(false);
        return;
      }

      // Help / shortcuts popup toggle
      if (e.key === '?' || (e.key === '/' && e.shiftKey)) {
        e.preventDefault();
        setShowShortcuts(s => !s);
        return;
      }

      // Undo
      if ((key === 'z' && (e.ctrlKey || e.metaKey)) || (key === 'z' && !e.shiftKey)) {
        if (!e.shiftKey) {
          e.preventDefault();
          handleUndoRef.current();
          return;
        } else {
          e.preventDefault();
          handleRedoRef.current();
          return;
        }
      }

      // Redo
      if ((key === 'y' && (e.ctrlKey || e.metaKey)) || key === 'y') {
        e.preventDefault();
        handleRedoRef.current();
        return;
      }

      // Restart shortcut (R without modifier) - only enabled for non-daily levels
      if (key === 'r' && !e.ctrlKey && !e.metaKey) {
        if (!isDailyModeRef.current) {
          e.preventDefault();
          handleRestartRef.current();
        }
        return;
      }

      // Tool cycling: Tab / Shift+Tab
      if (e.key === 'Tab') {
        e.preventDefault();
        const availableTools: (Content.Water | Content.Boat | Content.NoWater | Content.NoBoat)[] = [
          Content.Water,
          Content.NoWater,
          ...(hasBoatsRef.current ? ([Content.Boat, Content.NoBoat] as (Content.Boat | Content.NoBoat)[]) : [])
        ];
        const idx = availableTools.indexOf(selectedToolRef.current);
        if (idx !== -1) {
          const nextIdx = e.shiftKey
            ? (idx - 1 + availableTools.length) % availableTools.length
            : (idx + 1) % availableTools.length;
          setSelectedTool(availableTools[nextIdx]);
        }
        return;
      }

      const isBrushKey = key === 'w' || key === 'x' || (key === 'b' && hasBoatsRef.current) || (key === 'n' && hasBoatsRef.current);
      if (isBrushKey && currentBrushKeyRef.current !== null) {
        return;
      }

      // Hover cell shortcuts (when hovering over a cell):
      // W -> Water, X -> NoWater, B -> Boat, N -> NoBoat
      if (hoveredCellRef.current && !wonRef.current) {
        const { row: hr, col: hc, corner: hCorner } = hoveredCellRef.current;
        if (key === 'w') {
          e.preventDefault();
          currentBrushKeyRef.current = 'w';
          const status = applyToolToCellRef.current(hr, hc, hCorner, Content.Water, false);
          if (status !== E.MouseDragState.None) {
            mouseHoldStatusRef.current = status;
            setMouseHoldStatus(status);
            setIsPointerDown(true);
          }
          return;
        }
        if (key === 'x') {
          e.preventDefault();
          currentBrushKeyRef.current = 'x';
          const status = applyToolToCellRef.current(hr, hc, hCorner, Content.NoWater, false);
          if (status !== E.MouseDragState.None) {
            mouseHoldStatusRef.current = status;
            setMouseHoldStatus(status);
            setIsPointerDown(true);
          }
          return;
        }
        if (key === 'b' && hasBoatsRef.current) {
          e.preventDefault();
          currentBrushKeyRef.current = 'b';
          const status = applyToolToCellRef.current(hr, hc, hCorner, Content.Boat, false);
          if (status !== E.MouseDragState.None) {
            mouseHoldStatusRef.current = status;
            setMouseHoldStatus(status);
            setIsPointerDown(true);
          }
          return;
        }
        if (key === 'n' && hasBoatsRef.current) {
          e.preventDefault();
          currentBrushKeyRef.current = 'n';
          const status = applyToolToCellRef.current(hr, hc, hCorner, Content.NoBoat, false);
          if (status !== E.MouseDragState.None) {
            mouseHoldStatusRef.current = status;
            setMouseHoldStatus(status);
            setIsPointerDown(true);
          }
          return;
        }
      }

      // Direct Tool selection: 1, 2, 3, 4 (or W, X, B, N when not hovering a cell)
      if (e.key === '1' || key === 'w') setSelectedTool(Content.Water);
      else if (e.key === '2' || key === 'x') setSelectedTool(Content.NoWater);
      else if ((e.key === '3' || key === 'b') && hasBoatsRef.current) setSelectedTool(Content.Boat);
      else if ((e.key === '4' || key === 'n') && hasBoatsRef.current) setSelectedTool(Content.NoBoat);
    };

    const handleKeyUp = (e: KeyboardEvent) => {
      const key = e.key.toLowerCase();
      if (key === currentBrushKeyRef.current || key === 'w' || key === 'x' || key === 'b' || key === 'n') {
        currentBrushKeyRef.current = null;
        handlePointerUp();
      }
    };

    const handleBlur = () => {
      currentBrushKeyRef.current = null;
      handlePointerUp();
    };

    const handleAuxClick = (e: MouseEvent) => {
      if (e.button === 1) e.preventDefault();
    };

    window.addEventListener('pointerup', handlePointerUp);
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    window.addEventListener('auxclick', handleAuxClick);
    window.addEventListener('blur', handleBlur);
    return () => {
      window.removeEventListener('pointerup', handlePointerUp);
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
      window.removeEventListener('auxclick', handleAuxClick);
      window.removeEventListener('blur', handleBlur);
    };
  }, []);

  useEffect(() => {
    (window as any).loadLevelString = loadLevelFromString;
    (window as any).loadLevelKey = loadLevel;
    (window as any).loadDailyLevel = loadDailyLevel;
    (window as any).getDailyDate = () => dailyDateRef.current;
    (window as any).isDaily = () => isDailyModeRef.current;
    (window as any).restartLevel = handleRestart;
    (window as any).startPuzzle = () => setHasStarted(true);
    (window as any).hasStarted = () => hasStartedRef.current;
    (window as any).openLeaderboard = () => setShowLeaderboardModal(true);
    (window as any).getTime = () => secondsElapsedRef.current;
    (window as any).setTool = (tool: Content.Water | Content.Boat | Content.NoWater | Content.NoBoat) => {
      if ((tool === Content.Boat || tool === Content.NoBoat) && !hasBoatsRef.current) {
        return;
      }
      setSelectedTool(tool);
    };
    (window as any).setAutoFloodAir = (val: boolean) => setAutoFloodAir(val);
    (window as any).setDarkMode = (val: boolean) => setIsDarkMode(val);
    (window as any).exportLevelString = () => {
      if (engineRef.current) return engineRef.current.to_str();
      if (!gridData) return '';
      return GridImpl.load_from_grid_data(gridData).to_str();
    };
    (window as any).isWon = () => won;
    (window as any).getGridData = () => gridData;
    (window as any).getMistakes = () => mistakesRef.current;
    (window as any).putCellAction = (r: number, c: number, corner: Corner, content: Content) => {
      const engine = engineRef.current;
      if (!engine) return;
      const eCorner = toEngineCorner(corner);
      const cell = engine.get_cell(r, c) as any;
      if (cell.block_at(eCorner)) return;

      engine.push_empty_undo();
      if (content === Content.Water) {
        cell.put_water(eCorner, false);
      } else if (content === Content.NoWater) {
        cell.put_nowater(eCorner, false, autoFloodAir);
      } else if (content === Content.Boat) {
        cell.put_boat(false);
      } else if (content === Content.NoBoat) {
        cell.put_noboat(eCorner, false);
      } else if (content === Content.Nothing) {
        cell.remove_content(eCorner, false, autoFloodAir);
      }

      handlePointerUp();
      const next = engine.to_grid_data();
      setGridData(next);
      setCanUndo(engine.can_undo());
      setCanRedo(engine.can_redo());
      if (isLevelComplete(next)) {
        setWon(true);
        if (!isDailyModeRef.current) {
          setCompletedLevels(comp => new Set(comp).add(currentLevelKey));
        }
      }
    };
    (window as any).undo = () => handleUndoRef.current();
    (window as any).redo = () => handleRedoRef.current();
    (window as any).canUndo = () => engineRef.current?.can_undo() ?? false;
    (window as any).canRedo = () => engineRef.current?.can_redo() ?? false;
    (window as any).setShowShortcuts = (val: boolean) => setShowShortcuts(val);
    (window as any).getShowShortcuts = () => showShortcutsRef.current;
    (window as any).setShowLevelsModal = (val: boolean) => setShowLevelsModal(val);
    (window as any).getShowLevelsModal = () => showLevelsModalRef.current;
    (window as any).setHoveredCell = (r: number, c: number, corner: Corner = Corner.TopLeft) => {
      hoveredCellRef.current = { row: r, col: c, corner };
    };
  }, [gridData, won, isDarkMode, mistakes, canUndo, canRedo, showShortcuts, showLevelsModal]);

  const triggerMistake = (r: number, c: number, corner: Corner) => {
    setMistakes(m => m + 1);
    setMistakePulse(true);
    setTimeout(() => setMistakePulse(false), 400);

    const cellKey = `${r}-${c}`;
    setBlinkingCells(prev => {
      const next = new Map(prev);
      next.set(cellKey, { corner, timestamp: Date.now() });
      return next;
    });

    setTimeout(() => {
      setBlinkingCells(prev => {
        if (!prev.has(cellKey)) return prev;
        const next = new Map(prev);
        next.delete(cellKey);
        return next;
      });
    }, 800);

    setIsPointerDown(false);
    mouseHoldStatusRef.current = E.MouseDragState.None;
    setMouseHoldStatus(E.MouseDragState.None);

    if (engineRef.current) {
      while (
        engineRef.current.undo_stack.length > 0 &&
        engineRef.current.undo_stack[engineRef.current.undo_stack.length - 1].changes.length === 0
      ) {
        engineRef.current.undo_stack.pop();
      }
      setCanUndo(engineRef.current.can_undo());
      setCanRedo(engineRef.current.can_redo());
    }
  };

  const applyToolToCell = (
    r: number,
    c: number,
    corner: Corner,
    tool: Content,
    isSecondary: boolean = false
  ): E.MouseDragState => {
    if (wonRef.current) return E.MouseDragState.None;
    const engine = engineRef.current;
    if (!engine) return E.MouseDragState.None;

    const eCorner = toEngineCorner(corner);
    const cell = engine.get_cell(r, c) as any;
    if (cell.block_at(eCorner)) return E.MouseDragState.None;

    engine.push_empty_undo();
    let status = E.MouseDragState.None;

    if (isSecondary) {
      if (cell.nowater_at(eCorner)) {
        status = E.MouseDragState.RemoveNoWater;
        cell.remove_nowater(eCorner, false);
      } else if (cell.noboat_at(eCorner)) {
        status = E.MouseDragState.RemoveNoBoat;
        cell.remove_noboat(eCorner, false);
      } else if (cell.has_boat()) {
        status = E.MouseDragState.RemoveBoat;
        cell.remove_content(eCorner, false);
      } else {
        if (selectedToolRef.current === Content.Boat) {
          status = E.MouseDragState.NoBoat;
          cell.put_noboat(eCorner, false);
        } else {
          status = E.MouseDragState.NoWater;
          cell.put_nowater(eCorner, false, autoFloodAirRef.current);
        }
      }
    } else if (tool === Content.Water) {
      if (cell.water_at(eCorner)) {
        status = E.MouseDragState.RemoveWater;
        cell.remove_content(eCorner, false, autoFloodAirRef.current);
      } else {
        status = E.MouseDragState.Water;
        const added = cell.put_water(eCorner, false);
        if (added <= 0.0) {
          triggerMistake(r, c, corner);
          return E.MouseDragState.None;
        }
      }
    } else if (tool === Content.NoWater) {
      if (cell.nowater_at(eCorner)) {
        status = E.MouseDragState.RemoveNoWater;
        cell.remove_nowater(eCorner, false);
      } else {
        status = E.MouseDragState.NoWater;
        cell.put_nowater(eCorner, false, autoFloodAirRef.current);
      }
    } else if (tool === Content.Boat) {
      if (cell.has_boat()) {
        status = E.MouseDragState.RemoveBoat;
        cell.remove_content(E.Corner.BottomLeft, false);
      } else {
        status = E.MouseDragState.Boat;
        const success = cell.put_boat(false);
        if (!success) {
          triggerMistake(r, c, corner);
          return E.MouseDragState.None;
        }
      }
    } else if (tool === Content.NoBoat) {
      if (cell.noboat_at(eCorner)) {
        status = E.MouseDragState.RemoveNoBoat;
        cell.remove_noboat(eCorner, false);
      } else {
        status = E.MouseDragState.NoBoat;
        cell.put_noboat(eCorner, false);
      }
    }

    const next = engine.to_grid_data();
    setGridData(next);
    setCanUndo(engine.can_undo());
    setCanRedo(engine.can_redo());
    const complete = isLevelComplete(next);
    if (complete) {
      setWon(true);
      setIsPointerDown(false);
      mouseHoldStatusRef.current = E.MouseDragState.None;
      setMouseHoldStatus(E.MouseDragState.None);
      if (!isDailyModeRef.current) {
        setCompletedLevels(comp => new Set(comp).add(currentLevelKeyRef.current));
      }
    }
    saveProgressRef.current(complete);

    return status;
  };

  const applyToolToCellRef = useRef(applyToolToCell);
  applyToolToCellRef.current = applyToolToCell;

  const handleCellDown = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    if (won) return;
    let status = E.MouseDragState.None;

    if (e.button === 1) {
      // Middle button (Auxiliary click): Put / Remove Boat - Port of Godot MOUSE_BUTTON_MIDDLE
      e.preventDefault();
      status = applyToolToCell(r, c, corner, Content.Boat, false);
    } else if (e.button === 2) {
      // Secondary button (Right Click) - Port of Godot cell_pressed_second_button
      status = applyToolToCell(r, c, corner, Content.NoWater, true);
    } else if (e.button === 0) {
      // Primary button (Left Click) - Port of Godot _process_click
      status = applyToolToCell(r, c, corner, selectedTool, false);
    } else {
      return;
    }

    if (status !== E.MouseDragState.None) {
      mouseHoldStatusRef.current = status;
      setMouseHoldStatus(status);
      setIsPointerDown(true);
    }
  };

  const handleCellEnter = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    hoveredCellRef.current = { row: r, col: c, corner };
    if (won) return;
    const engine = engineRef.current;
    if (!engine) return;

    const dragStatus = mouseHoldStatusRef.current;
    if (!isPointerDown || dragStatus === E.MouseDragState.None) return;

    const eCorner = toEngineCorner(corner);
    const cell = engine.get_cell(r, c) as any;
    if (cell.block_at(eCorner)) return;

    let madeChange = false;

    // Port of Godot _on_cell_mouse_entered:
    if (dragStatus === E.MouseDragState.Water && cell.nothing_at(eCorner)) {
      const added = cell.put_water(eCorner, false);
      if (added <= 0.0) {
        triggerMistake(r, c, corner);
        return;
      }
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.NoWater && (cell.noboat_at(eCorner) || cell.nothing_at(eCorner))) {
      cell.put_nowater(eCorner, false, autoFloodAir);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.NoBoat && (cell.nowater_at(eCorner) || cell.nothing_at(eCorner))) {
      cell.put_noboat(eCorner, false);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.Boat && cell.nothing_at(eCorner)) {
      const success = cell.put_boat(false);
      if (!success) {
        triggerMistake(r, c, corner);
        return;
      }
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.RemoveWater && cell.water_at(eCorner)) {
      cell.remove_content(eCorner, false, autoFloodAir);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.RemoveNoWater && cell.nowater_at(eCorner)) {
      cell.remove_nowater(eCorner, false);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.RemoveNoBoat && cell.noboat_at(eCorner)) {
      cell.remove_noboat(eCorner, false);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.RemoveBoat && cell.has_boat()) {
      cell.remove_content(eCorner, false);
      madeChange = true;
    }

    if (madeChange) {
      const next = engine.to_grid_data();
      setGridData(next);
      setCanUndo(engine.can_undo());
      setCanRedo(engine.can_redo());
      const complete = isLevelComplete(next);
      if (complete) {
        setWon(true);
        setIsPointerDown(false);
        mouseHoldStatusRef.current = E.MouseDragState.None;
        setMouseHoldStatus(E.MouseDragState.None);
        if (!isDailyModeRef.current) {
          setCompletedLevels(comp => new Set(comp).add(currentLevelKey));
        }
      }
      saveProgressRef.current(complete);
    }
  };

  const handleCellMove = (r: number, c: number, corner: Corner) => {
    hoveredCellRef.current = { row: r, col: c, corner };
  };

  const handleCellLeave = (r: number, c: number) => {
    if (hoveredCellRef.current?.row === r && hoveredCellRef.current?.col === c) {
      hoveredCellRef.current = null;
    }
  };

  // Compute current stats for hints header
  let currentWater = 0;
  let currentBoats = 0;
  let foundAquariums: { size: number, boats: number }[] = [];
  if (gridData) {
    for (let r = 0; r < gridData.cells.length; r++) {
      currentWater += countWaterRow(gridData, r);
      currentBoats += countBoatRow(gridData, r);
    }
    foundAquariums = getAquariums(gridData);
  }

  const getActualCount = (targetSize: number) => {
    return foundAquariums.filter(aq => Math.abs(aq.size - targetSize) < 0.01).length;
  };

  const levelKeys = TEST_LEVEL_KEYS;
  const currentIndex = levelKeys.indexOf(currentLevelKey);
  const nextLevelKey = currentIndex >= 0 && currentIndex < levelKeys.length - 1 ? levelKeys[currentIndex + 1] : null;

  return (
    <div
      class={`game-container ${isDarkMode ? 'theme-dark' : ''}`}
      onPointerUp={handlePointerUp}
      onPointerLeave={handlePointerUp}
      onContextMenu={(e) => e.preventDefault()}
    >
      <div class="game-bg" />

      {!isTestMode && (
        <div class="level-picker">
          <button
            data-testid="btn-daily-mode"
            onClick={() => {
              if (!isDailyMode) {
                loadDailyLevel();
              }
            }}
            class={`level-btn level-btn-daily ${isDailyMode ? 'level-btn-daily-active' : ''}`}
            title="Play Daily Level"
          >
            <span>📅 Daily Level</span>
          </button>

          {isDailyMode && (
            <button
              data-testid="btn-leaderboard"
              onClick={() => setShowLeaderboardModal(true)}
              class="level-btn lg:hidden"
              title="View Daily Leaderboard"
            >
              <span>🏆 Leaderboard</span>
            </button>
          )}

          <button
            data-testid="btn-open-levels-modal"
            onClick={() => setShowLevelsModal(true)}
            class={`level-btn ${!isDailyMode ? 'level-btn-current' : 'level-btn-unsolved'}`}
            title="Fixed levels for testing"
          >
            <span>🧪 Test Levels {!isDailyMode ? `(${currentLevelKey})` : ''}</span>
          </button>
        </div>
      )}

      <div class="controls-toolbar">
        <label class="toolbar-toggle">
          <input
            type="checkbox"
            data-testid="auto-flood-air"
            checked={autoFloodAir}
            onChange={(e) => setAutoFloodAir(e.currentTarget.checked)}
            class="checkbox-input"
          />
          <span>Auto-Flood Air (✕)</span>
        </label>

        <div class="tool-selector">
          <button
            data-testid="tool-water"
            onClick={() => setSelectedTool(Content.Water)}
            class={`tool-btn ${selectedTool === Content.Water ? 'tool-btn-water-active' : 'tool-btn-water-inactive'}`}
            title="Water (1)"
            aria-label="Water"
          >
            <span class="text-base leading-none">💧</span>
          </button>
          <button
            data-testid="tool-air"
            onClick={() => setSelectedTool(Content.NoWater)}
            class={`tool-btn ${selectedTool === Content.NoWater ? 'tool-btn-air-active' : 'tool-btn-air-inactive'}`}
            title="Air (2)"
            aria-label="Air"
          >
            <img src="/icons/nowater.png" class="w-4 h-4 object-contain" alt="air" />
          </button>
          {hasBoats && (
            <>
              <button
                data-testid="tool-boat"
                onClick={() => setSelectedTool(Content.Boat)}
                class={`tool-btn ${selectedTool === Content.Boat ? 'tool-btn-boat-active' : 'tool-btn-boat-inactive'}`}
                title="Boat (3)"
                aria-label="Boat"
              >
                <img src="/icons/boat_small.png" class="w-4 h-4 object-contain" alt="boat" />
              </button>
              <button
                data-testid="tool-maybeboat"
                data-tool-id="noboat"
                onClick={() => setSelectedTool(Content.NoBoat)}
                class={`tool-btn ${selectedTool === Content.NoBoat ? 'tool-btn-maybeboat-active' : 'tool-btn-maybeboat-inactive'}`}
                title="Maybe Boat (4)"
                aria-label="Maybe Boat"
              >
                <div class="relative w-4 h-4 flex items-center justify-center pointer-events-none">
                  <img src="/icons/boat_small.png" class="w-full h-full object-contain" alt="maybe boat" />
                  <img src="/icons/question_mark.png" class="absolute inset-0 w-full h-full object-contain filter-mint" alt="?" />
                </div>
              </button>
            </>
          )}
        </div>

        <div class="undo-redo-group">
          <button
            data-testid="btn-undo"
            onClick={handleUndo}
            class={`btn-action btn-undo ${!canUndo ? 'btn-disabled' : ''}`}
            title="Undo (Z or Ctrl+Z)"
            aria-label="Undo"
            disabled={!canUndo}
          >
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 7v6h6" />
              <path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13" />
            </svg>
            <span>Undo</span>
          </button>
          <button
            data-testid="btn-redo"
            onClick={handleRedo}
            class={`btn-action btn-redo ${!canRedo ? 'btn-disabled' : ''}`}
            title="Redo (Y or Ctrl+Y)"
            aria-label="Redo"
            disabled={!canRedo}
          >
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 7v6h-6" />
              <path d="M3 17a9 9 0 0 1 9-9 9 9 0 0 1 6 2.3L21 13" />
            </svg>
            <span>Redo</span>
          </button>
        </div>

        {!isDailyMode && (
          <button
            data-testid="btn-restart"
            onClick={handleRestart}
            class="btn-restart"
            title="Restart Level (R)"
          >
            <img src="/icons/restart_normal.png" class="w-4 h-4 object-contain" alt="restart" />
            <span>Restart</span>
          </button>
        )}

        <button
          data-testid="btn-shortcuts"
          onClick={() => setShowShortcuts(true)}
          class="btn-shortcuts"
          title="Shortcuts & Controls (?)"
          aria-label="Shortcuts"
        >
          <span class="text-base">⌨️</span>
          <span>Shortcuts</span>
        </button>

        {isDailyMode && (
          <div
            data-testid="daily-streak-badge"
            class="flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-950/70 border border-amber-500/50 text-amber-300 text-xs font-semibold cursor-help"
            title={`Daily Streak: Consecutive daily levels with at most 2 mistakes (Best: ${streakData.bestStreak})`}
          >
            <span>🔥</span>
            <span>{streakData.currentStreak}</span>
          </div>
        )}

        <button
          data-testid="btn-theme-toggle"
          onClick={() => setIsDarkMode(!isDarkMode)}
          class="btn-theme-toggle"
          title={isDarkMode ? "Switch to Aquatic Light Mode" : "Switch to Deep Ocean Dark Mode"}
        >
          <span>{isDarkMode ? '☀️' : '🌙'}</span>
        </button>
      </div>

      <h1 class="game-title">
        Liquidum Lite
      </h1>

      {isDailyMode && dailyMeta && (
        <div class="daily-banner" data-testid="daily-banner">
          <div class="daily-info" data-testid="daily-info">
            <span class="daily-emoji">{dailyMeta.emoji}</span>
            <span class="font-bold text-base text-[var(--game-mint)]">{dailyMeta.flavorName}</span>
            <span class="opacity-80 text-sm">({dailyMeta.date})</span>
            <span class="text-xs opacity-75">— {dailyMeta.description}</span>
          </div>
          {dailyDate === get_today_str() && (
            <div
              data-testid="daily-time-left-banner"
              class="ml-auto hidden sm:flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-cyan-950/60 border border-cyan-500/30 text-cyan-300 text-xs font-mono"
              title="Time left today to solve the daily level"
            >
              <span>⏳</span>
              <span data-testid="time-left-text">{formatTimeLeft(timeLeftSeconds)}</span>
            </div>
          )}
        </div>
      )}

      <div class="banner-slot">
        {won && (
          <div data-testid="win-banner" class="win-banner">
            <div class="win-title">
              {isDailyMode ? `🎉 Daily Complete! 🎉` : `🎉 Level Complete! 🎉`}
            </div>
            {isDailyMode && (
              <div class="text-sm font-semibold opacity-95 text-[var(--game-mint)] flex items-center justify-center gap-2 flex-wrap">
                <span>{dailyMeta?.emoji} {dailyMeta?.flavorName}</span>
                <span>•</span>
                <span data-testid="win-time">⏱️ {formatSolveTime(secondsElapsed)}</span>
                <span>•</span>
                <span>{mistakes === 0 ? "🏆 0 Mistakes!" : `❌ ${mistakes} ${mistakes === 1 ? 'Mistake' : 'Mistakes'}`}</span>
                <span>•</span>
                <span data-testid="win-streak" title={`Daily Streak (Best: ${streakData.bestStreak})`}>🔥 Streak: {streakData.currentStreak}</span>
              </div>
            )}
            <div class="flex items-center gap-2 flex-wrap justify-center">
              {!isDailyMode && (
                <button
                  data-testid="btn-play-again"
                  onClick={handleRestart}
                  class="win-btn-again"
                >
                  <img src="/icons/restart_normal.png" class="w-4 h-4 object-contain" alt="restart" />
                  <span>Play Again</span>
                </button>
              )}
              {isDailyMode ? (
                <>
                  <button
                    data-testid="btn-leaderboard-win"
                    onClick={() => setShowLeaderboardModal(true)}
                    class="level-btn flex items-center gap-1.5"
                    title="View Daily Leaderboard"
                  >
                    <span>🏆</span>
                    <span>Leaderboard</span>
                  </button>
                  <button
                    data-testid="btn-share-result"
                    onClick={handleShare}
                    class="btn-share"
                    title="Share result"
                  >
                    <span>{copiedShare ? "✓ Copied!" : "📋 Share Result"}</span>
                  </button>
                </>
              ) : (
                nextLevelKey && (
                  <button
                    data-testid="btn-next-level"
                    onClick={() => loadLevel(nextLevelKey)}
                    class="win-btn-next"
                  >
                    <span>Next Level ({nextLevelKey})</span>
                    <span>→</span>
                  </button>
                )
              )}
            </div>

            {/* Steam Promo */}
            <div class="flex flex-col items-center gap-1.5 mt-3 pt-2 border-t border-slate-700/40 w-full">
              <span data-testid="steam-promo-text" class="text-xs text-slate-300 font-medium">
                Want More? Download liquidum on Steam
              </span>
              <a
                data-testid="btn-steam-link"
                href="https://store.steampowered.com/app/2690070/Liquidum/"
                target="_blank"
                rel="noopener noreferrer"
                class="btn-steam flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-blue-700 hover:bg-blue-600 text-white font-semibold text-xs transition shadow-md w-full max-w-[280px]"
                title="Play the full game on Steam"
              >
                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                  <path d="M12 2a10 10 0 0 0-9.98 9.24l5.36 2.22a2.86 2.86 0 0 1 2.22-.55l2.48-3.6a3.86 3.86 0 0 1-.08-.71 3.9 3.9 0 1 1 3.9 3.9c-.24 0-.48-.03-.7-.08l-3.58 2.5a2.86 2.86 0 0 1-.58 2.2l2.22 5.38A10 10 0 1 0 12 2zm3.9 7.6a2.4 2.4 0 1 0 0 4.8 2.4 2.4 0 0 0 0-4.8z"/>
                </svg>
                <span>Liquidum on Steam</span>
              </a>
            </div>
          </div>
        )}
      </div>

      {isLoadingDaily ? (
        <div class="daily-loading" data-testid="daily-loading">
          <div class="loading-spinner" />
          <span>Generating Daily Level for {dailyDate}...</span>
        </div>
      ) : gridData ? (
        <div class="flex flex-col lg:flex-row items-center lg:items-start justify-center gap-6 w-full max-w-7xl mx-auto px-2">
          <div class="relative flex flex-col items-center">
          {/* Start Puzzle Overlay for Daily Mode */}
          {isDailyMode && !hasStarted && (
            <div
              data-testid="start-puzzle-overlay"
              class="absolute inset-0 z-30 flex flex-col items-center justify-center bg-slate-950/70 backdrop-blur-md rounded-2xl p-6 text-center"
            >
              <div class="text-5xl mb-2">{dailyMeta?.emoji || "🐟"}</div>
              <h3 class="text-2xl font-bold text-cyan-300 mb-1">
                {dailyMeta?.flavorName || "Daily Puzzle"}
              </h3>
              <p class="text-xs text-slate-300 opacity-90 mb-4 max-w-xs">
                {dailyMeta?.description || "Solve the daily puzzle as fast as you can with minimal mistakes!"}
              </p>

              <div class="flex items-center gap-2.5 mb-5 flex-wrap justify-center">
                {dailyDate === get_today_str() && (
                  <div
                    data-testid="daily-time-left"
                    class="flex items-center gap-1 px-3 py-1 rounded-full bg-cyan-950/80 border border-cyan-500/40 text-cyan-300 text-xs font-mono"
                    title="Time remaining to solve today's daily puzzle"
                  >
                    <span>⏳</span>
                    <span>{formatTimeLeft(timeLeftSeconds)}</span>
                  </div>
                )}
                <div
                  data-testid="daily-streak-display"
                  class="flex items-center gap-1 px-3 py-1 rounded-full bg-amber-950/80 border border-amber-500/50 text-amber-300 text-xs font-semibold cursor-help"
                  title={`Consecutive daily levels with at most 2 mistakes (Best: ${streakData.bestStreak})`}
                >
                  <span>🔥</span>
                  <span>Streak: {streakData.currentStreak}</span>
                </div>
              </div>

              <button
                data-testid="btn-start-puzzle"
                onClick={() => {
                  setHasStarted(true);
                  hasStartedRef.current = true;
                  saveProgressRef.current();
                }}
                class="btn-start-puzzle"
              >
                <span>▶ Start Puzzle</span>
              </button>
            </div>
          )}

          <div class={`flex flex-col items-center transition-all duration-300 ${isDailyMode && !hasStarted ? 'filter blur-md pointer-events-none select-none' : ''}`}>
            {/* Grid Hints Header */}
            {(() => {
              const hasTotalWater = gridData.grid_hints.total_water >= 0;
              const hasTotalBoats = gridData.grid_hints.total_boats > 0;
              const aquariumEntries = Object.entries(gridData.grid_hints.expected_aquariums || {})
                .filter(([_, v]) => v !== -1 && v >= 0)
                .sort(([a], [b]) => parseFloat(a) - parseFloat(b));
              const hasAquariums = aquariumEntries.length > 0;

              return (
                <div class="grid-hints-card" data-testid="grid-hints-card">
                  {/* Timer for Daily Mode */}
                  {isDailyMode && (
                    <div
                      data-testid="hint-timer"
                      class="hint-stat-card hint-stat-normal"
                      title="Time elapsed"
                    >
                      <span class="hint-stat-icon">⏱️</span>
                      <span class="hint-stat-label">Time</span>
                      <span data-testid="timer-value" class="hint-stat-value godot-text-outline font-mono">
                        {formatSolveTime(secondsElapsed)}
                      </span>
                    </div>
                  )}

                  {/* Mistake Counter */}
                  <div
                    data-testid="mistake-counter"
                    class={`hint-stat-card hint-stat-mistake ${mistakePulse ? 'hint-stat-mistake-bump' : ''}`}
                    title="Mistakes made"
                  >
                    <span class="hint-stat-icon">❌</span>
                    <span class="hint-stat-label">Mistakes</span>
                    <span data-testid="mistake-count" class="hint-stat-value godot-text-outline">
                      {mistakes}
                    </span>
                  </div>

                {hasTotalWater && (
                  <div
                    data-testid="hint-water-counter"
                    class={`hint-stat-card ${currentWater === gridData.grid_hints.total_water ? 'hint-stat-satisfied' :
                      currentWater > gridData.grid_hints.total_water ? 'hint-stat-over' :
                        'hint-stat-normal'
                      }`}
                    title={`Total water: ${currentWater} / ${gridData.grid_hints.total_water} placed`}
                  >
                    <span class="hint-stat-icon">💧</span>
                    <span class="hint-stat-label">Water</span>
                    <span class="hint-stat-value godot-text-outline">
                      {currentWater} / {gridData.grid_hints.total_water}
                    </span>
                    {currentWater === gridData.grid_hints.total_water ? (
                      <span class="hint-status-badge badge-satisfied">✓</span>
                    ) : currentWater > gridData.grid_hints.total_water ? (
                      <span class="hint-status-badge badge-over">⚠ Over</span>
                    ) : null}
                  </div>
                )}

                {hasTotalBoats && (
                  <div
                    data-testid="hint-boat-counter"
                    class={`hint-stat-card ${currentBoats === gridData.grid_hints.total_boats ? 'hint-stat-satisfied' :
                      currentBoats > gridData.grid_hints.total_boats ? 'hint-stat-over' :
                        'hint-stat-normal'
                      }`}
                    title={`Total boats: ${currentBoats} / ${gridData.grid_hints.total_boats} placed`}
                  >
                    <img src="/icons/boat_small.png" class="hint-boat-img" alt="boat" />
                    <span class="hint-stat-label">Boats</span>
                    <span class="hint-stat-value godot-text-outline">
                      {currentBoats} / {gridData.grid_hints.total_boats}
                    </span>
                    {currentBoats === gridData.grid_hints.total_boats ? (
                      <span class="hint-status-badge badge-satisfied">✓</span>
                    ) : currentBoats > gridData.grid_hints.total_boats ? (
                      <span class="hint-status-badge badge-over">⚠ Over</span>
                    ) : null}
                  </div>
                )}

                {hasAquariums && (
                  <div class={`aquarium-section ${(hasTotalWater || hasTotalBoats) ? 'has-counters' : ''}`} data-testid="aquarium-section">
                    <div class="aquarium-header">
                      <span class="aquarium-icon">🌊</span>
                      <span class="aquarium-label">Aquariums:</span>
                    </div>
                    <div class="aquarium-items">
                      {aquariumEntries.map(([sizeStr, expectedCount]) => {
                        const targetSize = parseFloat(sizeStr);
                        const actualCount = getActualCount(targetSize);
                        const isSatisfied = actualCount === expectedCount;
                        const isOver = actualCount > expectedCount;
                        const cardClass = isSatisfied ? 'aquarium-card-satisfied' : isOver ? 'aquarium-card-over' : 'aquarium-card-normal';
                        return (
                          <div
                            key={sizeStr}
                            data-testid={`aquarium-hint-${sizeStr}`}
                            class={`aquarium-card ${cardClass}`}
                            title={`Aquarium of size ${targetSize}: ${actualCount} / ${expectedCount} placed`}
                          >
                            <div class={`aq-tank ${targetSize === 0.5 ? 'aq-tank-half' : ''}`}>
                              {targetSize > 0 && (
                                <div class={`aq-tank-water ${targetSize === 0.5 ? 'aq-tank-water-half' : ''}`} />
                              )}
                              {targetSize === 0.5 && (
                                <svg class="aq-diag-line">
                                  <line x1="0" y1="0" x2="100%" y2="100%" stroke="var(--cell-wall)" stroke-width="2" />
                                </svg>
                              )}
                              <span class={`aq-tank-size ${targetSize === 0.5 ? 'aq-size-half' : ''}`}>
                                {targetSize}
                              </span>
                            </div>
                            <div class="aq-info">
                              <span class="aq-expected-count">×{expectedCount}</span>
                              <span class={`aq-status-pill ${isSatisfied ? 'aq-pill-satisfied' :
                                isOver ? 'aq-pill-over' :
                                  'aq-pill-normal'
                                }`}>
                                {isSatisfied ? `✓ ${actualCount}` : `${actualCount}/${expectedCount}`}
                              </span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            );
          })()}

          <div class={`grid-board-card ${won ? 'is-won pointer-events-none' : ''}`}>
            <Grid
              gridData={gridData}
              blinkingCells={blinkingCells}
              onCellPointerDown={handleCellDown}
              onCellPointerEnter={handleCellEnter}
              onCellPointerMove={handleCellMove}
              onCellPointerLeave={handleCellLeave}
            />
          </div>
        </div>
      </div>

        {/* Desktop Side-by-Side Leaderboard (only in daily mode on lg+ screens) */}
        {isDailyMode && (
          <div
            data-testid="desktop-leaderboard"
            class="hidden lg:flex flex-col w-80 xl:w-96 flex-shrink-0 self-stretch max-w-sm"
          >
            <LeaderboardView
              isSidePanel={true}
              refreshTrigger={leaderboardRefreshKey}
            />
          </div>
        )}
      </div>
      ) : (
        <p>Loading...</p>
      )}

      {showShortcuts && (
        <div
          data-testid="shortcuts-modal"
          class="modal-backdrop"
          onClick={() => setShowShortcuts(false)}
        >
          <div
            class="shortcuts-dialog"
            onClick={(e) => e.stopPropagation()}
          >
            <div class="shortcuts-header">
              <div class="flex items-center gap-2">
                <span class="text-xl">⌨️</span>
                <h2 class="shortcuts-title godot-text-outline">Controls & Shortcuts</h2>
              </div>
              <button
                data-testid="btn-close-shortcuts"
                onClick={() => setShowShortcuts(false)}
                class="shortcuts-close-btn"
                title="Close (Esc)"
                aria-label="Close"
              >
                ✕
              </button>
            </div>

            <div class="shortcuts-content">
              {/* Mouse & Touch */}
              <div class="shortcut-section">
                <h3 class="shortcut-section-title">🖱️ Mouse & Touch Controls</h3>
                <div class="shortcut-list">
                  <div class="shortcut-item">
                    <span class="shortcut-key">Tap / Left Click</span>
                    <span class="shortcut-desc">Place selected tool (or clear matching content)</span>
                  </div>
                  <div class="shortcut-item">
                    <span class="shortcut-key">Right Click</span>
                    <span class="shortcut-desc">Air (✕) / clear pencil marks</span>
                  </div>
                  <div class="shortcut-item">
                    <span class="shortcut-key">Middle Click</span>
                    <span class="shortcut-desc">Place / remove Boat (⛵)</span>
                  </div>
                  <div class="shortcut-item">
                    <span class="shortcut-key">Click & Drag</span>
                    <span class="shortcut-desc">Draw or erase across multiple cells</span>
                  </div>
                </div>
              </div>

              {/* Hover Keys */}
              <div class="shortcut-section">
                <h3 class="shortcut-section-title">✨ Quick Hover Keys</h3>
                <p class="shortcut-section-hint">Hover mouse over any cell and press or hold:</p>
                <div class="shortcut-list">
                  <div class="shortcut-item">
                    <div class="flex gap-1.5"><kbd class="kbd">W</kbd></div>
                    <span class="shortcut-desc">Place or remove Water (💧)</span>
                  </div>
                  <div class="shortcut-item">
                    <div class="flex gap-1.5"><kbd class="kbd">X</kbd></div>
                    <span class="shortcut-desc">Place or remove Air (✕)</span>
                  </div>
                  <div class="shortcut-item">
                    <div class="flex gap-1.5"><kbd class="kbd">B</kbd></div>
                    <span class="shortcut-desc">Place or remove Boat (⛵)</span>
                  </div>
                  <div class="shortcut-item">
                    <div class="flex gap-1.5"><kbd class="kbd">N</kbd></div>
                    <span class="shortcut-desc">Place or remove Maybe Boat (?)</span>
                  </div>
                </div>
              </div>

              {/* Tool Selection */}
              <div class="shortcut-section">
                <h3 class="shortcut-section-title">🎯 Tool Selection</h3>
                <div class="shortcut-list">
                  <div class="shortcut-item">
                    <div class="flex gap-1.5">
                      <kbd class="kbd">1</kbd>
                      <kbd class="kbd">2</kbd>
                      <kbd class="kbd">3</kbd>
                      <kbd class="kbd">4</kbd>
                    </div>
                    <span class="shortcut-desc">Select Water, Air, Boat, Maybe Boat</span>
                  </div>
                  <div class="shortcut-item">
                    <div class="flex gap-1.5">
                      <kbd class="kbd">Tab</kbd> / <kbd class="kbd">Shift+Tab</kbd>
                    </div>
                    <span class="shortcut-desc">Next / Previous tool</span>
                  </div>
                </div>
              </div>

              {/* Actions & Game */}
              <div class="shortcut-section">
                <h3 class="shortcut-section-title">⚡ Game Actions</h3>
                <div class="shortcut-list">
                  <div class="shortcut-item">
                    <div class="flex gap-1.5">
                      <kbd class="kbd">Z</kbd> / <kbd class="kbd">Ctrl+Z</kbd>
                    </div>
                    <span class="shortcut-desc">Undo last move</span>
                  </div>
                  <div class="shortcut-item">
                    <div class="flex gap-1.5">
                      <kbd class="kbd">Y</kbd> / <kbd class="kbd">Ctrl+Y</kbd>
                    </div>
                    <span class="shortcut-desc">Redo move</span>
                  </div>
                  <div class="shortcut-item">
                    <div class="flex gap-1.5"><kbd class="kbd">R</kbd></div>
                    <span class="shortcut-desc">Restart current level</span>
                  </div>
                  <div class="shortcut-item">
                    <div class="flex gap-1.5"><kbd class="kbd">Esc</kbd> / <kbd class="kbd">?</kbd></div>
                    <span class="shortcut-desc">Toggle / close shortcuts popup</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {showLevelsModal && (
        <div
          data-testid="levels-modal"
          class="modal-backdrop"
          onClick={() => setShowLevelsModal(false)}
        >
          <div
            class="shortcuts-dialog"
            onClick={(e) => e.stopPropagation()}
            style={{ maxWidth: '440px' }}
          >
            <div class="shortcuts-header">
              <div class="flex items-center gap-2">
                <span class="text-xl">🧪</span>
                <h2 class="shortcuts-title godot-text-outline">Test Levels</h2>
              </div>
              <button
                data-testid="btn-close-levels-modal"
                onClick={() => setShowLevelsModal(false)}
                class="shortcuts-close-btn"
                title="Close (Esc)"
                aria-label="Close"
              >
                ✕
              </button>
            </div>

            <div class="shortcuts-content">
              <p class="text-xs opacity-75 mb-3 text-[var(--game-mint)]">
                Fixed levels for testing (will be removed later):
              </p>
              <div class="grid grid-cols-2 gap-2">
                {levelKeys.map(key => {
                  const isCurrent = !isDailyMode && key === currentLevelKey;
                  const isDone = completedLevels.has(key);
                  const statusClass = isCurrent ? 'level-btn-current' : isDone ? 'level-btn-done' : 'level-btn-unsolved';
                  return (
                    <button
                      key={key}
                      onClick={() => {
                        loadLevel(key);
                        setShowLevelsModal(false);
                      }}
                      class={`level-btn ${statusClass} justify-center w-full`}
                    >
                      {isDone && <img src="/icons/checkmark.png" class="w-3.5 h-3.5 object-contain" alt="done" />}
                      <span>{key}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      )}

      <LeaderboardModal
        isOpen={showLeaderboardModal}
        onClose={() => setShowLeaderboardModal(false)}
        refreshTrigger={leaderboardRefreshKey}
      />
    </div>
  );
}
