import { afterEach, describe, expect, it } from 'bun:test';
import { render, screen } from '@testing-library/react';
import { gameDataAtom, resetStore, store } from '../events/store';

import { AntagInfoTraitor } from './AntagInfoTraitor';

function setData(personal_background?: {
  organization: string | null;
  subgroup: string | null;
  notes: string;
}) {
  store.set(gameDataAtom, {
    intro: 'Вы назначены агентом Donk Corporation.',
    allies: 'Штатные обязанности.',
    goal: 'Штатное предложение нанимателя.',
    objectives: [],
    given_uplink: 0,
    has_codewords: 0,
    personal_background,
  });
}

afterEach(resetStore);

describe('Private character biography in the traitor window', () => {
  it('keeps a conflicting biography separate from the real introduction on every opening', () => {
    setData({
      organization: 'Cybersun Industries',
      subgroup: 'Gorlex Marauders',
      notes: 'PRIVATE_SENTINEL: прежняя служба.\nВторая строка.',
    });
    const view = render(<AntagInfoTraitor />);
    expect(
      screen.getByText('Вы назначены агентом Donk Corporation.'),
    ).toBeDefined();
    expect(screen.getByText('Личная предыстория')).toBeDefined();
    expect(screen.getByText(/PRIVATE_SENTINEL/).textContent).toBe(
      'PRIVATE_SENTINEL: прежняя служба.\nВторая строка.',
    );
    expect(screen.getByText(/Организация из анкеты/).textContent).toBe(
      'Организация из анкеты: Cybersun Industries → Gorlex Marauders',
    );
    expect(screen.getByText(/не зависят от неё/)).toBeDefined();
    view.unmount();
    render(<AntagInfoTraitor />);
    expect(screen.getByText(/PRIVATE_SENTINEL/)).toBeDefined();
  });

  it('renders a text-only biography literally without executing markup', () => {
    setData({
      organization: null,
      subgroup: null,
      notes: '<img src=x onerror="alert(1)"><script>unsafe()</script>',
    });
    const { container } = render(<AntagInfoTraitor />);
    expect(screen.queryByText(/Организация из анкеты/)).toBeNull();
    expect(screen.getByText(/<img src=x/).textContent).toBe(
      '<img src=x onerror="alert(1)"><script>unsafe()</script>',
    );
    expect(container.querySelector('img, script')).toBeNull();
  });

  it('keeps the native window when the server supplies no private note', () => {
    setData();
    render(<AntagInfoTraitor />);
    expect(screen.queryByText('Личная предыстория')).toBeNull();
    expect(
      screen.getByText('Вы назначены агентом Donk Corporation.'),
    ).toBeDefined();
    expect(screen.getByText('Ваши текущие задачи:')).toBeDefined();
  });
});
