import { h } from "preact";
import { useEffect } from "preact/hooks";
import { LeaderboardView } from "./LeaderboardView";

interface LeaderboardModalProps {
  isOpen: boolean;
  onClose: () => void;
  refreshTrigger?: number;
}

export function LeaderboardModal({ isOpen, onClose, refreshTrigger }: LeaderboardModalProps) {
  if (!isOpen) return null;

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  return (
    <div
      data-testid="leaderboard-modal"
      class="modal-backdrop"
      onClick={onClose}
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

