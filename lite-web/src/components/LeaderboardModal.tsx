import { h } from "preact";
import { LeaderboardView } from "./LeaderboardView";

interface LeaderboardModalProps {
  isOpen: boolean;
  onClose: () => void;
  refreshTrigger?: number;
}

export function LeaderboardModal({ isOpen, onClose, refreshTrigger }: LeaderboardModalProps) {
  if (!isOpen) return null;

  return (
    <div
      className="modal-backdrop fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg"
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
