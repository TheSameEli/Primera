import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';

import type { BackgroundPreference, Species } from '../types';
import { ServerPrefs, useServerPrefs } from '../useServerPrefs';
import { BackgroundPage } from './BackgroundPage';
import { SpeciesPage } from './SpeciesPage';

const donor = (await Bun.file(
  new URL(
    '../../../../../../modular_bandastation/sierra_background/data/skrell.json',
    import.meta.url,
  ),
).json()) as {
  castes: Record<string, { name: string; description: string }>;
};

function species(name: string): Species {
  return {
    name,
    desc: `Описание вида: ${name}`,
    lore: [`История вида: ${name}`],
    icon: name,
    use_skintones: false,
    sexes: true,
    enabled_features: [],
    perks: { positive: [], negative: [], neutral: [] },
  };
}

function setData(
  selectedSpecies = 'skrell',
  caste: string | null = 'Qerr-Katish',
  slot = 1,
) {
  const rows: BackgroundPreference[] =
    caste === null
      ? []
      : [
          {
            category: 'social',
            preference: 'skrell_caste',
            label: 'Каста',
            value: caste,
            choices: Object.keys(donor.castes),
          },
        ];
  store.set(gameDataAtom, {
    active_slot: slot,
    character_preview_view: 'test-preview',
    character_preferences: {
      misc: { species: selectedSpecies },
      manually_rendered_features: caste === null ? {} : { skrell_caste: caste },
    },
    sierra_background: rows,
  });
}

function TestBackground() {
  const defaults = useServerPrefs();
  if (!defaults) {
    throw new Error('Preference context defaults are missing.');
  }
  return (
    <ServerPrefs.Provider
      value={{
        ...defaults,
        sierra_background: {
          culture: {},
          homeworld: {},
          faction: {},
          subfaction: {},
          religion: {},
          social: donor.castes,
        },
      }}
    >
      <BackgroundPage />
    </ServerPrefs.Provider>
  );
}

function TestSpeciesPage() {
  const defaults = useServerPrefs();
  if (!defaults) {
    throw new Error('Preference context defaults are missing.');
  }
  return (
    <ServerPrefs.Provider
      value={{
        ...defaults,
        species: { human: species('Человек'), skrell: species('Скрелл') },
      }}
    >
      <SpeciesPage closeSpecies={() => {}} />
    </ServerPrefs.Provider>
  );
}

afterEach(() => {
  resetStore();
  sessionStorage.clear();
});

describe('Skrell social background', () => {
  it('offers all five Russian castes and their full source descriptions under Background', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      setData();
      const view = render(<TestBackground />);
      expect(screen.getByText('Каста')).toBeDefined();
      expect(Object.keys(donor.castes)).toEqual([
        'Qerr-Katish',
        'Malish-Katish',
        'Kanin-Katish',
        'Talum-Katish',
        'Raskinta-Katish',
      ]);
      for (const [id, caste] of Object.entries(donor.castes)) {
        fireEvent.click(screen.getByLabelText('Выбор: Каста'));
        fireEvent.click(screen.getByLabelText(`Просмотреть: ${caste.name}`));
        expect(screen.getByRole('dialog').textContent).toContain(
          caste.description,
        );
        expect(screen.queryByLabelText('Текст заметки: Каста')).toBeNull();
        if (id !== 'Qerr-Katish') {
          fireEvent.click(screen.getByText('Выбрать'));
          expect(sendAct).toHaveBeenLastCalledWith('sierra_background_choose', {
            preference: 'skrell_caste',
            value: id,
            slot: 1,
            species: 'skrell',
          });
        } else {
          expect(sendAct).not.toHaveBeenCalled();
          fireEvent.click(screen.getByText('Отмена'));
        }
        setData('skrell', id);
        view.rerender(<TestBackground />);
        expect(screen.getByLabelText('Выбор: Каста').textContent).toContain(
          caste.name,
        );
      }
    } finally {
      sendAct.mockRestore();
    }
  });

  it('shows social membership only when the backend supplies its row', () => {
    setData('human', null);
    const view = render(<TestBackground />);
    expect(screen.queryByText('Каста')).toBeNull();
    setData('skrell', null);
    view.rerender(<TestBackground />);
    expect(screen.queryByText('Каста')).toBeNull();
    setData();
    view.rerender(<TestBackground />);
    expect(screen.getByText('Каста')).toBeDefined();
    setData('human', null);
    view.rerender(<TestBackground />);
    expect(screen.queryByText('Каста')).toBeNull();
  });

  it('keeps caste out of SpeciesPage without changing the skrell_caste save key', () => {
    setData();
    const view = render(<TestSpeciesPage />);
    expect(screen.queryByText('Каста')).toBeNull();
    view.unmount();
    render(<TestBackground />);
    expect(screen.getByText('Каста')).toBeDefined();
  });

  it('shows the saved caste when changing slots and reopening Background', () => {
    setData();
    const view = render(<TestBackground />);
    fireEvent.click(screen.getByLabelText('Выбор: Каста'));
    expect(document.body.textContent).toContain(
      donor.castes['Qerr-Katish'].description,
    );
    setData('skrell', 'Talum-Katish', 2);
    view.rerender(<TestBackground />);
    expect(document.body.textContent).not.toContain(
      donor.castes['Qerr-Katish'].description,
    );
    fireEvent.click(screen.getByLabelText('Выбор: Каста'));
    expect(document.body.textContent).toContain(
      donor.castes['Talum-Katish'].description,
    );
    view.unmount();
    render(<TestBackground />);
    fireEvent.click(screen.getByLabelText('Выбор: Каста'));
    expect(document.body.textContent).toContain(
      donor.castes['Talum-Katish'].description,
    );
  });
});
