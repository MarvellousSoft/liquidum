import { useRef, useEffect, useState } from 'preact/hooks';

export interface DrawingCanvasProps {
  isDrawingMode: boolean;
  isEraserMode: boolean;
  drawColor: string;
  drawWidth?: number;
  eraserWidth?: number;
  clearTrigger: number;
  onToggleEraser?: () => void;
}

const BACKING_RES = 2000;

export function DrawingCanvas({
  isDrawingMode,
  isEraserMode,
  drawColor,
  drawWidth = 4,
  eraserWidth = 24,
  clearTrigger,
  onToggleEraser
}: DrawingCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const backingCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const isPointerDownRef = useRef(false);
  const activeStrokeIsEraserRef = useRef(false);
  const [isRightClickActive, setIsRightClickActive] = useState(false);
  const lastPosRef = useRef<{ x: number; y: number } | null>(null);

  // Initialize backing canvas once
  if (!backingCanvasRef.current && typeof document !== 'undefined') {
    const backing = document.createElement('canvas');
    backing.width = BACKING_RES;
    backing.height = BACKING_RES;
    backingCanvasRef.current = backing;
  }

  // Redraw backing canvas to visible canvas
  const syncToVisibleCanvas = () => {
    const canvas = canvasRef.current;
    const backing = backingCanvasRef.current;
    if (!canvas || !backing) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const rect = canvas.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const dpr = window.devicePixelRatio || 1;
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;

    ctx.save();
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, rect.width, rect.height);
    ctx.drawImage(backing, 0, 0, rect.width, rect.height);
    ctx.restore();
  };

  // Handle clear trigger
  useEffect(() => {
    if (clearTrigger > 0) {
      const backing = backingCanvasRef.current;
      if (backing) {
        const bCtx = backing.getContext('2d');
        if (bCtx) {
          bCtx.save();
          bCtx.setTransform(1, 0, 0, 1, 0, 0);
          bCtx.clearRect(0, 0, BACKING_RES, BACKING_RES);
          bCtx.restore();
        }
      }
      const canvas = canvasRef.current;
      if (canvas) {
        const ctx = canvas.getContext('2d');
        if (ctx) {
          ctx.save();
          ctx.setTransform(1, 0, 0, 1, 0, 0);
          ctx.clearRect(0, 0, canvas.width, canvas.height);
          ctx.restore();
        }
      }
    }
  }, [clearTrigger]);

  // Handle ResizeObserver
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    syncToVisibleCanvas();

    const ro = new ResizeObserver(() => {
      syncToVisibleCanvas();
    });
    ro.observe(canvas);

    return () => {
      ro.disconnect();
    };
  }, []);

  const handlePointerDown = (e: PointerEvent) => {
    if (!isDrawingMode) return;

    // Accept left-click (0) or right-click (2)
    if (e.button !== 0 && e.button !== 2) return;

    // Right-click inverts the current tool for consistency:
    // When on brush: right-click erases. When on eraser: right-click paints.
    const isErase = e.button === 2 ? !isEraserMode : isEraserMode;
    if (e.button === 2) {
      e.preventDefault();
      setIsRightClickActive(true);
    }

    const canvas = canvasRef.current;
    if (!canvas) return;

    try {
      canvas.setPointerCapture(e.pointerId);
    } catch {}

    isPointerDownRef.current = true;
    activeStrokeIsEraserRef.current = isErase;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    lastPosRef.current = { x, y };

    drawSegment(x, y, x, y, rect.width, rect.height, isErase);
  };

  const handlePointerMove = (e: PointerEvent) => {
    if (!isDrawingMode || !isPointerDownRef.current || !lastPosRef.current) return;

    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const isErase = activeStrokeIsEraserRef.current;
    drawSegment(lastPosRef.current.x, lastPosRef.current.y, x, y, rect.width, rect.height, isErase);
    lastPosRef.current = { x, y };
  };

  const handlePointerUp = (e: PointerEvent) => {
    isPointerDownRef.current = false;
    activeStrokeIsEraserRef.current = false;
    setIsRightClickActive(false);
    lastPosRef.current = null;
    const canvas = canvasRef.current;
    if (canvas) {
      try {
        canvas.releasePointerCapture(e.pointerId);
      } catch {}
    }
  };

  const drawSegment = (
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    width: number,
    height: number,
    isErase: boolean
  ) => {
    if (width <= 0 || height <= 0) return;

    const canvas = canvasRef.current;
    const backing = backingCanvasRef.current;
    if (!canvas || !backing) return;

    const ctx = canvas.getContext('2d');
    const bCtx = backing.getContext('2d');
    if (!ctx || !bCtx) return;

    const dpr = window.devicePixelRatio || 1;

    // 1. Draw to visible canvas
    ctx.save();
    ctx.scale(dpr, dpr);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    if (isErase) {
      ctx.globalCompositeOperation = 'destination-out';
      ctx.lineWidth = eraserWidth;
    } else {
      ctx.globalCompositeOperation = 'source-over';
      ctx.strokeStyle = drawColor;
      ctx.lineWidth = drawWidth;
    }

    ctx.beginPath();
    ctx.moveTo(fromX, fromY);
    ctx.lineTo(toX, toY);
    ctx.stroke();
    ctx.restore();

    // 2. Draw to backing canvas (normalized to BACKING_RES)
    const scaleX = BACKING_RES / width;
    const scaleY = BACKING_RES / height;

    bCtx.save();
    bCtx.lineCap = 'round';
    bCtx.lineJoin = 'round';

    if (isErase) {
      bCtx.globalCompositeOperation = 'destination-out';
      bCtx.lineWidth = eraserWidth * scaleX;
    } else {
      bCtx.globalCompositeOperation = 'source-over';
      bCtx.strokeStyle = drawColor;
      bCtx.lineWidth = drawWidth * scaleX;
    }

    bCtx.beginPath();
    bCtx.moveTo(fromX * scaleX, fromY * scaleY);
    bCtx.lineTo(toX * scaleX, toY * scaleY);
    bCtx.stroke();
    bCtx.restore();
  };

  const isEraserCursor = isRightClickActive ? !isEraserMode : isEraserMode;

  return (
    <canvas
      ref={canvasRef}
      data-testid="drawing-canvas"
      class={`drawing-canvas ${isDrawingMode ? 'is-active' : 'is-inactive'} ${isEraserCursor ? 'is-eraser' : ''}`}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
      onContextMenu={(e) => {
        if (isDrawingMode) {
          e.preventDefault();
        }
      }}
    />
  );
}
