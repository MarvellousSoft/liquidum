import { h } from "preact";
import { useEffect } from "preact/hooks";
import { LeaderboardView } from "./LeaderboardView";
import { useModalScrollLock } from "../utils/scrollLock";

interface LeaderboardModalProps {
  isOpen: boolean;
  onClose: () => void;
  refreshTrigger?: number;
}

export function LeaderboardModal({ isOpen, onClose, refreshTrigger }: LeaderboardModalProps) {
  useModalScrollLock(isOpen);

  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div
      data-testid="leaderboard-modal"
      class="modal-backdrop"
      onClick={onClose}
      onTouchMove={(e) => {
        if (e.target === e.currentTarget) {
          e.preventDefault();
        }
      }}
    >
      <div
        class="w-full max-w-lg flex justify-center"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="leaderboard-title"
      >
        <LeaderboardView
          onClose={onClose}
          isSidePanel={false}
          refreshTrigger={refreshTrigger}
        />
      </div>
    </div>
  );
}

