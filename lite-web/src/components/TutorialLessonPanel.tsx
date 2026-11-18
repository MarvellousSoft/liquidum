import { h } from 'preact';
import { useTranslation } from '../i18n';
import { ALL_MECHANICS } from './HelpModal';
import {
  TUTORIAL_STEPS,
  getTutorialStep,
  getTutorialStepNumber,
} from '../engine/TutorialProgress';

export interface TutorialLessonPanelProps {
  levelKey: string;
  solved: boolean;
  onOpenSection: () => void;
  onOpenControls: () => void;
}

/**
 * The lesson that sits under the board while a tutorial level is being played:
 * what it teaches, in words and in the same little diagrams the help modal
 * uses. Both the wording and the diagrams are reused from ALL_MECHANICS rather
 * than written again, so the tutorial can never drift from the help screen and
 * no new translation is needed for the rules themselves.
 *
 * The first tutorial also has to say how to draw on the board at all, since a
 * player arriving here may never have touched the game.
 */
export function TutorialLessonPanel({
  levelKey,
  solved,
  onOpenSection,
  onOpenControls,
}: TutorialLessonPanelProps) {
  const { t } = useTranslation();
  const step = getTutorialStep(levelKey);
  if (!step) return null;

  const number = getTutorialStepNumber(levelKey);
  const mechanics = step.mechanics
    .map(key => ALL_MECHANICS.find(m => m.key === key))
    .filter((m): m is NonNullable<typeof m> => m != null);

  return (
    <div class="tutorial-lesson" data-testid="tutorial-lesson">
      <div class="tutorial-lesson-header">
        <span class="tutorial-lesson-step" data-testid="tutorial-lesson-step">
          {t('tutorial.step_of', { current: number, total: TUTORIAL_STEPS.length })}
        </span>
        <button
          data-testid="btn-tutorial-lesson-back"
          class="tutorial-lesson-link"
          onClick={onOpenSection}
        >
          {t('tutorial.all_steps')}
        </button>
      </div>

      {step.teachesControls && (
        <div class="tutorial-lesson-mechanic" data-testid="tutorial-lesson-controls">
          <div class="tutorial-lesson-name godot-text-outline">
            <span aria-hidden="true">🖱️</span>
            <span>{t('tutorial.controls_title')}</span>
          </div>
          <p class="tutorial-lesson-desc">{t('tutorial.controls_desc')}</p>
          <div>
            <button
              data-testid="btn-tutorial-controls"
              class="btn-secondary text-xs px-3 py-1"
              onClick={onOpenControls}
            >
              {t('tutorial.controls_button')}
            </button>
          </div>
        </div>
      )}

      {step.teachesWaterCounter && (
        <div class="tutorial-lesson-mechanic" data-testid="tutorial-lesson-water-counter">
          <div class="tutorial-lesson-name godot-text-outline">
            <span aria-hidden="true">💧</span>
            <span>{t('tutorial.counter_title')}</span>
          </div>
          <p class="tutorial-lesson-desc">{t('tutorial.counter_desc')}</p>
        </div>
      )}

      {mechanics.map(m => (
        <div class="tutorial-lesson-mechanic" key={m.key} data-testid={`tutorial-lesson-${m.key}`}>
          <div class="tutorial-lesson-name godot-text-outline">
            <span aria-hidden="true">{m.icon}</span>
            <span>{t(`mechanics.${m.key}.name`, m.name)}</span>
          </div>
          <p class="tutorial-lesson-desc">{t(`mechanics.${m.key}.desc`)}</p>
          <div class="tutorial-lesson-examples">{m.tutorial}</div>
        </div>
      ))}

      {solved && (
        <p class="tutorial-lesson-solved" data-testid="tutorial-lesson-solved">
          {t('tutorial.step_solved')}
        </p>
      )}
    </div>
  );
}
