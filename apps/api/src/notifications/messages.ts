import type { AppLocale } from '../generated/prisma/client.js';

/**
 * Push texts. They are rendered on the server in the device's language
 * (kk, ru, en), so they live here instead of the app's ARB files. Russian
 * forms avoid past-tense verbs, which would need the actor's gender.
 */
export type NotificationType = 'assigned' | 'mentioned' | 'dueTomorrow';

export interface MessageArgs {
  actor: string;
  card: string;
  board: string;
  /** Comment text (mentions only). */
  text: string;
}

type Template = (a: MessageArgs) => { title: string; body: string };

const TEMPLATES: Record<NotificationType, Record<AppLocale, Template>> = {
  assigned: {
    en: (a) => ({
      title: 'You have a new task',
      body: `${a.actor} assigned you “${a.card}” on ${a.board}`,
    }),
    ru: (a) => ({
      title: 'Вам назначена задача',
      body: `«${a.card}» на доске «${a.board}» · от ${a.actor}`,
    }),
    kk: (a) => ({
      title: 'Сізге тапсырма берілді',
      body: `${a.actor} сізге «${a.card}» тапсырмасын берді («${a.board}» тақтасы)`,
    }),
  },
  mentioned: {
    en: (a) => ({
      title: `${a.actor} mentioned you`,
      body: `“${a.card}”: ${a.text}`,
    }),
    ru: (a) => ({
      title: 'Вас упомянули',
      body: `${a.actor} в «${a.card}»: ${a.text}`,
    }),
    kk: (a) => ({
      title: `${a.actor} сізді атап өтті`,
      body: `«${a.card}»: ${a.text}`,
    }),
  },
  dueTomorrow: {
    en: (a) => ({ title: 'Due tomorrow', body: `“${a.card}” on ${a.board}` }),
    ru: (a) => ({
      title: 'Срок — завтра',
      body: `«${a.card}» на доске «${a.board}»`,
    }),
    kk: (a) => ({
      title: 'Мерзімі — ертең',
      body: `«${a.card}», «${a.board}» тақтасы`,
    }),
  },
};

const MAX_TEXT = 120;

/** Shortens long comment texts for the notification body. */
export const excerpt = (text: string): string => {
  const flat = text.replace(/\s+/g, ' ').trim();
  return flat.length <= MAX_TEXT ? flat : `${flat.slice(0, MAX_TEXT - 1)}…`;
};

export function renderMessage(
  type: NotificationType,
  locale: AppLocale,
  args: MessageArgs,
): { title: string; body: string } {
  return TEMPLATES[type][locale](args);
}
