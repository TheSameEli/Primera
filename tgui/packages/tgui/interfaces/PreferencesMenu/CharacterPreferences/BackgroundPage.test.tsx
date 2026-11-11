import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';

import type {
  AntagonistBackground,
  BackgroundCategory,
  BackgroundEntry,
  BackgroundPreference,
} from '../types';
import { ServerPrefs, useServerPrefs } from '../useServerPrefs';
import { BackgroundPage } from './BackgroundPage';

async function readCatalogFile(name: string) {
  return Bun.file(
    new URL(
      `../../../../../../modular_bandastation/sierra_background/data/${name}.json`,
      import.meta.url,
    ),
  ).json();
}
const [cultures, worlds, factions, religions, wiki] = await Promise.all(
  ['cultures', 'worlds', 'factions', 'religions', 'wiki_species'].map(
    readCatalogFile,
  ),
);
const catalog: Record<BackgroundCategory, Record<string, BackgroundEntry>> = {
  culture: { ...cultures.entries, ...wiki.cultures },
  homeworld: { ...worlds.entries, ...wiki.worlds },
  faction: factions.entries,
  subfaction: factions.entries,
  social: {},
  religion: { ...religions.entries, ...wiki.religions },
};

function preferences(): BackgroundPreference[] {
  return [
    ['faction', 'Фракция', 'none'],
    ['homeworld', 'Место жительства', 'Earth'],
    ['culture', 'Культура', 'tsf_solar'],
    ['religion', 'Вера', 'none'],
  ].map(([category, label, value]) => ({
    category: category as BackgroundCategory,
    label,
    preference: `sierra_${category}`,
    value,
    choices: Object.keys(catalog[category]),
    notes: '',
    notes_preference: `sierra_${category}_notes`,
    notes_max_length: 4000,
    notes_prompt: `Подробнее о персонаже: ${label}`,
  }));
}
function setData(
  rows = preferences(),
  slot = 1,
  species = 'human',
  antagonist?: AntagonistBackground,
) {
  store.set(gameDataAtom, {
    active_slot: slot,
    character_preferences: { misc: { species } },
    sierra_background: rows,
    sierra_antagonist: antagonist,
  });
}
function TestBackground() {
  const defaults = useServerPrefs();
  if (!defaults) {
    throw new Error('Preference context defaults are missing.');
  }
  return (
    <ServerPrefs.Provider value={{ ...defaults, sierra_background: catalog }}>
      <BackgroundPage />
    </ServerPrefs.Provider>
  );
}
function sectionFor(category: string) {
  const section = document.querySelector(
    `[data-background-category="${category}"]`,
  );
  if (!(section instanceof HTMLElement)) {
    throw new Error(`Missing category: ${category}`);
  }
  return section;
}
function open(row: BackgroundPreference) {
  fireEvent.click(
    within(sectionFor(row.category)).getByLabelText(`Выбор: ${row.label}`),
  );
  return screen.getByRole('dialog');
}
function browse(category: BackgroundCategory, id: string) {
  fireEvent.click(
    within(screen.getByRole('dialog')).getByLabelText(
      `Просмотреть: ${catalog[category][id].name}`,
    ),
  );
}
function plainHtml(html: string) {
  const element = document.createElement('div');
  element.innerHTML = html;
  return element.textContent;
}
afterEach(() => {
  resetStore();
});

describe('BandaStation character background browser', () => {
  it('starts with compact current selections and collapsed personal fields', () => {
    const rows = preferences();
    setData(rows);
    render(<TestBackground />);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.queryByRole('textbox')).toBeNull();
    for (const row of rows) {
      const section = sectionFor(row.category);
      expect(section.textContent).toContain(
        catalog[row.category][row.value].name,
      );
      expect(section.querySelector('.BackgroundPicker__text')).toBeNull();
      expect(
        within(section)
          .getByLabelText(`Личные подробности: ${row.label}`)
          .getAttribute('aria-expanded'),
      ).toBe('false');
    }
  });

  for (const { category, choices } of preferences()) {
    for (const id of choices) {
      it(`previews ${category}/${id} without saving or showing archival metadata`, () => {
        const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
        try {
          const rows = preferences();
          const row = rows.find((entry) => entry.category === category)!;
          setData(rows);
          render(<TestBackground />);
          const dialog = open(row);
          const entry = catalog[row.category][id];
          fireEvent.click(
            within(dialog).getByLabelText(`Просмотреть: ${entry.name}`),
          );
          const description = dialog.querySelector('.BackgroundPicker__text');
          expect(description?.textContent).toBe(plainHtml(entry.description));
          if (entry.extra) {
            expect(dialog.textContent).toContain(plainHtml(entry.extra));
          }
          fireEvent.click(within(dialog).getByText('Отмена'));
          expect(sendAct).not.toHaveBeenCalled();
        } finally {
          sendAct.mockRestore();
        }
      });
    }
  }

  it('saves only after explicit confirmation and waits for authoritative data', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const rows = preferences();
      const row = rows[1];
      const next = row.choices.find((id) => id !== row.value)!;
      setData(rows, 3);
      const view = render(<TestBackground />);
      open(row);
      expect(
        screen
          .getByText('Выбрано')
          .closest('.Button')
          ?.classList.contains('Button--disabled'),
      ).toBe(true);
      browse(row.category, next);
      expect(sendAct).not.toHaveBeenCalled();
      fireEvent.click(screen.getByText('Выбрать'));
      expect(sendAct).toHaveBeenLastCalledWith('sierra_background_choose', {
        preference: row.preference,
        value: next,
        slot: 3,
        species: 'human',
      });
      expect(screen.queryByRole('dialog')).toBeNull();
      expect(sectionFor(row.category).textContent).toContain(
        catalog[row.category][row.value].name,
      );
      row.value = next;
      setData(rows, 3);
      view.rerender(<TestBackground />);
      expect(sectionFor(row.category).textContent).toContain(
        catalog[row.category][next].name,
      );
    } finally {
      sendAct.mockRestore();
    }
  });

  it('cancels browsing with either Cancel, close or Escape', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const row = preferences()[1];
      setData([row]);
      render(<TestBackground />);
      for (const action of ['cancel', 'close', 'escape']) {
        open(row);
        browse(row.category, row.choices.find((id) => id !== row.value)!);
        if (action === 'cancel') {
          fireEvent.click(screen.getByText('Отмена'));
        }
        if (action === 'close') {
          fireEvent.click(screen.getByLabelText('Закрыть выбор'));
        }
        if (action === 'escape') {
          fireEvent.keyDown(screen.getByLabelText('Поиск вариантов'), {
            key: 'Escape',
          });
        }
        expect(screen.queryByRole('dialog')).toBeNull();
      }
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  it('filters names without exposing choices not supplied by the server', () => {
    const row = preferences()[1];
    row.choices = ['Earth', 'Boron'];
    setData([row]);
    render(<TestBackground />);
    open(row);
    fireEvent.change(screen.getByLabelText('Поиск вариантов'), {
      target: { value: catalog.homeworld.Boron.name.toLocaleUpperCase() },
    });
    expect(
      screen.getByLabelText(`Просмотреть: ${catalog.homeworld.Boron.name}`),
    ).toBeDefined();
    expect(
      screen.queryByLabelText(`Просмотреть: ${catalog.homeworld.Earth.name}`),
    ).toBeNull();
    fireEvent.change(screen.getByLabelText('Поиск вариантов'), {
      target: { value: 'такого варианта нет' },
    });
    expect(screen.getByText('Ничего не найдено.')).toBeDefined();
  });

  it('browses a faction tree and applies a new parent and child together', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const row = preferences()[0];
      row.choices = ['none', 'Nanotrasen'];
      row.choice_children = { Nanotrasen: ['SecTech'] };
      row.choice_effects = { SecTech: ['Место жительства будет сброшено.'] };
      const subfaction: BackgroundPreference = {
        category: 'subfaction',
        preference: 'sierra_subfaction',
        label: 'Подразделение',
        value: 'none',
        choices: ['none'],
      };
      setData([row, subfaction]);
      render(<TestBackground />);
      expect(
        document.querySelector('[data-background-category="subfaction"]'),
      ).toBeNull();
      open(row);
      expect(
        screen.queryByLabelText(
          `Просмотреть: ${catalog.subfaction.SecTech.name}`,
        ),
      ).toBeNull();
      fireEvent.click(
        screen.getByLabelText(
          `Подразделения: ${catalog.faction.Nanotrasen.name}`,
        ),
      );
      browse('subfaction', 'SecTech');
      expect(
        screen
          .getByRole('dialog')
          .querySelector('.BackgroundPicker__description')?.textContent,
      ).toContain(catalog.subfaction.SecTech.description);
      expect(
        screen.getByText('Место жительства будет сброшено.'),
      ).toBeDefined();
      expect(sendAct).not.toHaveBeenCalled();
      fireEvent.click(screen.getByText('Выбрать'));
      expect(sendAct).toHaveBeenLastCalledWith('sierra_background_choose', {
        preference: row.preference,
        value: 'Nanotrasen',
        subfaction: 'SecTech',
        slot: 1,
        species: 'human',
      });
    } finally {
      sendAct.mockRestore();
    }
  });

  it('finds nested choices through search and allows the parent without a subdivision', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const row = preferences()[0];
      row.value = 'Nanotrasen';
      row.choices = ['none', 'Nanotrasen'];
      row.choice_children = { Nanotrasen: ['SecTech'] };
      const subfaction: BackgroundPreference = {
        category: 'subfaction',
        preference: 'sierra_subfaction',
        label: 'Подразделение',
        value: 'SecTech',
        choices: ['none', 'SecTech'],
      };
      setData([row, subfaction]);
      render(<TestBackground />);
      expect(sectionFor('faction').textContent).toContain(
        catalog.subfaction.SecTech.name,
      );
      open(row);
      expect(
        screen
          .getByLabelText(`Просмотреть: ${catalog.subfaction.SecTech.name}`)
          .querySelector('.Button--icon'),
      ).not.toBeNull();
      fireEvent.change(screen.getByLabelText('Поиск вариантов'), {
        target: { value: catalog.subfaction.SecTech.name },
      });
      expect(
        screen.getByLabelText(
          `Просмотреть: ${catalog.subfaction.SecTech.name}`,
        ),
      ).toBeDefined();
      browse('faction', 'Nanotrasen');
      fireEvent.click(screen.getByText('Выбрать'));
      expect(sendAct).toHaveBeenLastCalledWith('sierra_background_choose', {
        preference: row.preference,
        value: 'Nanotrasen',
        subfaction: 'none',
        slot: 1,
        species: 'human',
      });
    } finally {
      sendAct.mockRestore();
    }
  });

  for (const selected of ['FreeCartel', 'WitherVit']) {
    it(`saves the root and selected node of a three-level faction tree: ${selected}`, () => {
      const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
      try {
        const row = preferences()[0];
        row.choices = ['none', 'Free', 'Nanotrasen'];
        row.choice_children = {
          Free: ['Seekers', 'FreeCartel', 'OrdoLex'],
          FreeCartel: ['ExagonIchiwaka', 'WitherVit', 'HumanRealm'],
          Seekers: ['SeekersWings', 'SeekersClaws', 'SeekersTails'],
          Nanotrasen: ['SecTech'],
        };
        row.choice_effects = {
          Free: ['Эффект родителя'],
          [selected]: ['Эффект выбранного объединения'],
        };
        const subgroup: BackgroundPreference = {
          category: 'subfaction',
          preference: 'sierra_subfaction',
          label: 'Подразделение',
          value: 'none',
          choices: ['none'],
        };
        setData([row, subgroup]);
        render(<TestBackground />);
        open(row);
        fireEvent.click(
          screen.getByLabelText(`Подразделения: ${catalog.faction.Free.name}`),
        );
        fireEvent.click(
          screen.getByLabelText(
            `Подразделения: ${catalog.subfaction.FreeCartel.name}`,
          ),
        );
        browse('subfaction', selected);
        const description = screen
          .getByRole('dialog')
          .querySelector('.BackgroundPicker__description')!;
        expect(description.textContent).toContain(
          plainHtml(catalog.subfaction[selected].description),
        );
        expect(description.textContent).toContain(
          selected === 'WitherVit'
            ? `${catalog.faction.Free.name} → ${catalog.subfaction.FreeCartel.name}`
            : catalog.faction.Free.name,
        );
        expect(description.textContent).toContain(
          'Эффект выбранного объединения',
        );
        expect(description.textContent).not.toContain('Эффект родителя');
        expect(sendAct).not.toHaveBeenCalled();
        fireEvent.click(screen.getByText('Выбрать'));
        expect(sendAct).toHaveBeenLastCalledWith('sierra_background_choose', {
          preference: row.preference,
          value: 'Free',
          subfaction: selected,
          slot: 1,
          species: 'human',
        });
      } finally {
        sendAct.mockRestore();
      }
    });
  }

  it('opens the full saved path and finds deep branches without unrelated siblings', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const row = preferences()[0];
      row.value = 'Free';
      row.choices = ['none', 'Free'];
      row.choice_children = {
        Free: ['FreeCartel', 'Seekers', 'OrdoLex'],
        FreeCartel: ['WitherVit'],
        Seekers: ['SeekersWings', 'SeekersTails'],
      };
      const subgroup: BackgroundPreference = {
        category: 'subfaction',
        preference: 'sierra_subfaction',
        label: 'Подразделение',
        value: 'WitherVit',
        choices: ['none', 'WitherVit'],
      };
      setData([row, subgroup]);
      render(<TestBackground />);
      open(row);
      for (const id of ['Free', 'FreeCartel']) {
        expect(
          screen
            .getByLabelText(`Подразделения: ${catalog.faction[id].name}`)
            .getAttribute('aria-expanded'),
        ).toBe('true');
      }
      expect(
        screen.getByLabelText(
          `Просмотреть: ${catalog.subfaction.WitherVit.name}`,
        ),
      ).toBeDefined();
      fireEvent.change(screen.getByLabelText('Поиск вариантов'), {
        target: { value: catalog.subfaction.SeekersWings.name },
      });
      for (const id of ['Free', 'Seekers', 'SeekersWings']) {
        expect(
          screen.getByLabelText(`Просмотреть: ${catalog.faction[id].name}`),
        ).toBeDefined();
      }
      for (const id of ['FreeCartel', 'WitherVit', 'SeekersTails', 'OrdoLex']) {
        expect(
          screen.queryByLabelText(
            `Просмотреть: ${catalog.subfaction[id].name}`,
          ),
        ).toBeNull();
      }
      browse('subfaction', 'SeekersWings');
      fireEvent.click(screen.getByText('Отмена'));
      expect(sendAct).not.toHaveBeenCalled();
      expect(sectionFor('faction').textContent).toContain(
        catalog.subfaction.WitherVit.name,
      );
    } finally {
      sendAct.mockRestore();
    }
  });

  it('rejects a deep draft when the server removes its ancestry while open', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const row = preferences()[0];
      row.choices = ['none', 'Free'];
      row.choice_children = {
        Free: ['FreeCartel'],
        FreeCartel: ['WitherVit'],
      };
      setData([row]);
      const view = render(<TestBackground />);
      open(row);
      fireEvent.change(screen.getByLabelText('Поиск вариантов'), {
        target: { value: catalog.subfaction.WitherVit.name },
      });
      browse('subfaction', 'WitherVit');
      row.choice_children.Free = [];
      setData([row]);
      view.rerender(<TestBackground />);
      expect(
        screen.getByText(
          'Этот вариант недоступен для текущей анкеты. Выберите другой.',
        ),
      ).toBeDefined();
      fireEvent.click(screen.getByText('Выбрать'));
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  for (const [category, primary, diaspora, restricted] of [
    ['homeworld', 'Boron', 'Moges', 'Earth'],
    ['culture', 'skrell_imperial', 'kssp', 'elysian'],
  ] as const) {
    it(`offers contextual ${category} first and only server-valid diaspora on request`, () => {
      const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
      try {
        const row = preferences().find((row) => row.category === category)!;
        row.value = primary;
        row.choices = [primary, diaspora, 'other'];
        row.context_choices = [primary, 'other', restricted];
        setData([row], 1, 'skrell');
        render(<TestBackground />);
        open(row);
        expect(
          screen.getByLabelText(
            `Просмотреть: ${catalog[category][primary].name}`,
          ),
        ).toBeDefined();
        expect(
          screen.queryByLabelText(
            `Просмотреть: ${catalog[category][diaspora].name}`,
          ),
        ).toBeNull();
        fireEvent.click(screen.getByText('Другая среда / диаспора'));
        expect(
          screen.queryByLabelText(
            `Просмотреть: ${catalog[category][restricted].name}`,
          ),
        ).toBeNull();
        browse(category, diaspora);
        fireEvent.click(screen.getByText('Выбрать'));
        expect(sendAct).toHaveBeenLastCalledWith('sierra_background_choose', {
          preference: row.preference,
          value: diaspora,
          slot: 1,
          species: 'skrell',
        });
      } finally {
        sendAct.mockRestore();
      }
    });
  }

  it('keeps a saved diaspora visible and refreshes the contextual pool while browsing', () => {
    const row = preferences()[1];
    row.value = 'Boron';
    row.choices = ['Earth', 'Boron', 'Moges', 'other'];
    row.context_choices = ['Earth', 'other'];
    setData([row]);
    const view = render(<TestBackground />);
    open(row);
    expect(
      screen
        .getByText('Другая среда / диаспора')
        .closest('.Button')
        ?.getAttribute('aria-expanded'),
    ).toBe('true');
    fireEvent.click(screen.getByText('Другая среда / диаспора'));
    expect(
      screen.getByLabelText(`Просмотреть: ${catalog.homeworld.Boron.name}`),
    ).toBeDefined();
    expect(
      screen.queryByLabelText(`Просмотреть: ${catalog.homeworld.Moges.name}`),
    ).toBeNull();
    row.context_choices = ['Moges', 'other'];
    setData([row]);
    view.rerender(<TestBackground />);
    expect(
      screen.getByLabelText(`Просмотреть: ${catalog.homeworld.Moges.name}`),
    ).toBeDefined();
    expect(
      screen.queryByLabelText(`Просмотреть: ${catalog.homeworld.Earth.name}`),
    ).toBeNull();
    expect(
      screen.getByLabelText(`Просмотреть: ${catalog.homeworld.Boron.name}`),
    ).toBeDefined();
  });

  it('reports an incompatible saved value cleared on load without marking the neutral choice invalid', () => {
    const row = preferences()[1];
    row.value = 'other';
    row.reset_reason =
      'Сохранённый вариант несовместим с видом и очищен; личный текст сохранён.';
    setData([row]);
    render(<TestBackground />);
    expect(screen.getByText(row.reset_reason)).toBeDefined();
    expect(
      screen.queryByText(/Сохранённый выбор требует исправления/),
    ).toBeNull();
    open(row);
    expect(screen.getByText('Выбрано')).toBeDefined();
    expect(
      screen.queryByText(
        'Этот вариант недоступен для текущей анкеты. Выберите другой.',
      ),
    ).toBeNull();
  });

  it('keeps optional personal notes collapsed and saves plain text on blur', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const rows = preferences();
      setData(rows);
      render(<TestBackground />);
      for (const row of rows) {
        fireEvent.click(
          within(sectionFor(row.category)).getByLabelText(
            `Личные подробности: ${row.label}`,
          ),
        );
        const field = screen.getByLabelText(
          `Текст заметки: ${row.label}`,
        ) as HTMLTextAreaElement;
        expect(field.maxLength).toBe(4000);
        const text = `Личная история: ${row.label}\n<b>Обычный текст</b>`;
        act(() => field.focus());
        fireEvent.change(field, { target: { value: text } });
        expect(sendAct).not.toHaveBeenCalled();
        act(() => field.blur());
        expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
          preference: row.notes_preference,
          value: text,
        });
        expect(field.querySelector('b')).toBeNull();
        sendAct.mockClear();
      }
    } finally {
      sendAct.mockRestore();
    }
  });

  it('closes the browser and personal fields on slot or species changes', () => {
    const rows = preferences();
    rows[1].notes = 'Первый персонаж';
    setData(rows);
    const view = render(<TestBackground />);
    for (const [slot, species] of [
      [2, 'human'],
      [2, 'skrell'],
    ] as const) {
      fireEvent.click(
        screen.getByLabelText(`Личные подробности: ${rows[1].label}`),
      );
      open(rows[1]);
      const nextRows = preferences();
      nextRows[1].notes = 'Другой персонаж';
      setData(nextRows, slot, species);
      view.rerender(<TestBackground />);
      expect(screen.queryByRole('dialog')).toBeNull();
      expect(screen.queryByRole('textbox')).toBeNull();
    }
    fireEvent.click(
      screen.getByLabelText(`Личные подробности: ${rows[1].label}`),
    );
    expect(
      (
        screen.getByLabelText(
          `Текст заметки: ${rows[1].label}`,
        ) as HTMLTextAreaElement
      ).value,
    ).toBe('Другой персонаж');
  });

  it('retains historical descriptions and notes without permitting an unavailable selection', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const row = preferences()[1];
      row.choices = [];
      row.invalid_reason = 'Недоступно для этого вида.';
      row.empty_reason = 'Нет подходящих поселений.';
      row.notes = 'Прежняя биография';
      setData([row]);
      render(<TestBackground />);
      expect(sectionFor(row.category).textContent).toContain(
        row.invalid_reason,
      );
      open(row);
      expect(screen.getByRole('dialog').textContent).toContain(
        plainHtml(catalog.homeworld.Earth.description),
      );
      expect(screen.getByText(row.empty_reason)).toBeDefined();
      fireEvent.click(screen.getByText('Выбрать'));
      expect(sendAct).not.toHaveBeenCalled();
      fireEvent.click(screen.getByText('Отмена'));
      fireEvent.click(
        screen.getByLabelText(`Личные подробности: ${row.label}`),
      );
      expect(
        (
          screen.getByLabelText(
            `Текст заметки: ${row.label}`,
          ) as HTMLTextAreaElement
        ).value,
      ).toBe(row.notes);
    } finally {
      sendAct.mockRestore();
    }
  });

  it('does not apply a preview removed by a backend update', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const row = preferences()[1];
      setData([row]);
      const view = render(<TestBackground />);
      open(row);
      const next = row.choices.find((id) => id !== row.value)!;
      browse(row.category, next);
      row.choices = [row.value];
      setData([row]);
      view.rerender(<TestBackground />);
      expect(
        screen.getByText(
          'Этот вариант недоступен для текущей анкеты. Выберите другой.',
        ),
      ).toBeDefined();
      fireEvent.click(screen.getByText('Выбрать'));
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  it('shows authoritative culture effects without attributing them to another preview', () => {
    const rows = preferences();
    const row = rows[2];
    row.language_names = ['Общий', 'Неорусский'];
    row.name_generation = 'Именослов выбранного воспитания';
    setData(rows);
    const view = render(<TestBackground />);
    expect(sectionFor('culture').textContent).toContain('Общий, Неорусский');
    open(row);
    expect(screen.getByRole('dialog').textContent).toContain(
      row.name_generation,
    );
    const next = row.choices.find((id) => id !== row.value)!;
    browse('culture', next);
    expect(screen.getByRole('dialog').textContent).not.toContain(
      row.name_generation,
    );
    fireEvent.click(screen.getByText('Отмена'));
    row.language_names = [];
    row.name_generation = undefined;
    setData(rows);
    view.rerender(<TestBackground />);
    expect(sectionFor('culture').textContent).toContain('дополнительных нет');
  });

  it('handles an empty response without inventing controls', () => {
    setData([]);
    const view = render(<TestBackground />);
    expect(
      screen.getByText('Нет доступных настроек предыстории.'),
    ).toBeDefined();
    expect(screen.queryByRole('textbox')).toBeNull();
    store.set(gameDataAtom, {});
    view.rerender(<TestBackground />);
    expect(
      screen.getByText('Нет доступных настроек предыстории.'),
    ).toBeDefined();
  });

  it('keeps private antagonist data hidden until expanded and saves native separate preferences', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const profile: AntagonistBackground = {
        organization: {
          preference: 'sierra_antagonist_faction',
          value: 'none',
          choices: [
            { id: 'none', name: 'Не задано', description: '' },
            {
              id: 'test_org',
              name: 'Приватная организация',
              description: 'Описание организации.',
            },
          ],
        },
        notes: {
          preference: 'sierra_antagonist_notes',
          value: 'Секретная история',
          max_length: 1000,
          prompt: 'Происхождение и связи',
        },
      };
      setData(preferences(), 1, 'human', profile);
      const view = render(<TestBackground />);
      expect(screen.queryByText('Приватная организация')).toBeNull();
      expect(screen.queryByDisplayValue(profile.notes.value)).toBeNull();
      fireEvent.click(screen.getByText('Антагонист'));
      fireEvent.click(screen.getByText('Приватная организация'));
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: profile.organization.preference,
        value: 'test_org',
      });
      const field = screen.getByLabelText(
        'Личные подробности: Антагонист',
      ) as HTMLTextAreaElement;
      act(() => field.focus());
      fireEvent.change(field, { target: { value: '<b>Личный текст</b>' } });
      act(() => field.blur());
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: profile.notes.preference,
        value: '<b>Личный текст</b>',
      });
      setData(preferences(), 2);
      view.rerender(<TestBackground />);
      expect(screen.queryByDisplayValue('<b>Личный текст</b>')).toBeNull();
      expect(screen.queryByText('Антагонист')).toBeNull();
    } finally {
      sendAct.mockRestore();
    }
  });
});
