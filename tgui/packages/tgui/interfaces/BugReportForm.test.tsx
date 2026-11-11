import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from '../events/act';
import { gameDataAtom, resetStore, store } from '../events/store';

import { BugReportForm } from './BugReportForm';

const details = {
  title: 'Сломанная дверь',
  expected_behavior: 'Дверь открывается',
  description: 'Дверь остаётся закрытой',
  consequences: 'Нельзя выйти',
  steps: 'Нажать на дверь',
  log: '<test> && "quoted"',
  approver_note: '',
};

function setData(reviewing = false, fields = {}) {
  store.set(gameDataAtom, {
    report_details: fields,
    awaiting_approval: reviewing,
    sending: false,
    author: 'Reporter',
    title_limit: 256,
    text_limit: 4096,
    log_limit: 8192,
  });
}

afterEach(resetStore);

describe('BugReportForm', () => {
  it('blocks incomplete reports and hides the staff note from authors', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    setData();
    render(<BugReportForm />);
    expect(
      screen.queryByLabelText('Примечание проверяющего (необязательно)'),
    ).toBeNull();
    fireEvent.click(screen.getByText('Отправить на проверку'));
    expect(sendAct).not.toHaveBeenCalled();
    sendAct.mockRestore();
  });

  it('submits the visible fields including unmodified logs', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    setData(false, details);
    render(<BugReportForm />);
    fireEvent.change(screen.getByLabelText('Заголовок'), {
      target: { value: 'Новое название' },
    });
    fireEvent.click(screen.getByText('Отправить на проверку'));
    expect(sendAct).toHaveBeenCalledWith('confirm', {
      ...details,
      title: 'Новое название',
    });
    sendAct.mockRestore();
  });

  it('lets staff review and edit a report before publishing', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    setData(true, details);
    render(<BugReportForm />);
    fireEvent.change(
      screen.getByLabelText('Примечание проверяющего (необязательно)'),
      {
        target: { value: 'Воспроизводится' },
      },
    );
    fireEvent.click(screen.getByText('Опубликовать на GitHub'));
    expect(sendAct).toHaveBeenCalledWith('confirm', {
      ...details,
      approver_note: 'Воспроизводится',
    });
    sendAct.mockRestore();
  });
});
