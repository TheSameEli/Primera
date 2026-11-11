import { useState } from 'react';
import {
  Box,
  Button,
  Input,
  NoticeBox,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type ReportDetails = {
  title: string;
  expected_behavior: string;
  description: string;
  consequences: string;
  steps: string;
  log: string;
  approver_note: string;
};

type Data = {
  report_details: Partial<ReportDetails>;
  awaiting_approval: BooleanLike;
  sending: BooleanLike;
  author: string;
  title_limit: number;
  text_limit: number;
  log_limit: number;
};

// Adapted from Paradise #30376, using the local TGUI components.
export function BugReportForm() {
  const { act, data } = useBackend<Data>();
  const {
    awaiting_approval,
    sending,
    author,
    title_limit,
    text_limit,
    log_limit,
  } = data;
  const [fields, setFields] = useState<ReportDetails>({
    title: '',
    expected_behavior: '',
    description: '',
    consequences: '',
    steps: '',
    log: '',
    approver_note: '',
    ...data.report_details,
  });
  const required = [
    'title',
    'expected_behavior',
    'description',
    'consequences',
    'steps',
  ] as const;
  const complete = required.every((field) => fields[field].trim().length > 0);
  const labels = {
    expected_behavior: 'Что должно было произойти? *',
    description: 'Что произошло вместо этого? *',
    consequences: 'Какие проблемы вызывает баг? *',
    steps: 'Как воспроизвести баг? *',
    log: 'Логи (необязательно)',
    approver_note: 'Примечание проверяющего (необязательно)',
  };

  return (
    <Window title="Сообщить о баге" width={650} height={760}>
      <Window.Content scrollable>
        <NoticeBox info>
          {awaiting_approval
            ? `Автор: ${author}. Подтверждение опубликует этот отчёт на GitHub.`
            : 'Опишите баг подробно. Администрация проверит отчёт перед публикацией на GitHub. Между отправками — 5 минут.'}
        </NoticeBox>
        <Section title="Заголовок *">
          <Input
            aria-label="Заголовок"
            fluid
            value={fields.title}
            maxLength={title_limit}
            onChange={(value) => setFields({ ...fields, title: value })}
          />
        </Section>
        {Object.entries(labels).map(([field, label]) =>
          field === 'approver_note' && !awaiting_approval ? null : (
            <Section key={field} title={label}>
              <TextArea
                aria-label={label}
                fluid
                height={field === 'steps' || field === 'log' ? '100px' : '70px'}
                value={fields[field]}
                maxLength={field === 'log' ? log_limit : text_limit}
                onChange={(value) => setFields({ ...fields, [field]: value })}
              />
            </Section>
          ),
        )}
        <Box mb={1}>Поля со звёздочкой обязательны.</Box>
        <Stack>
          <Stack.Item grow>
            <Button
              fluid
              color="bad"
              disabled={!!sending}
              onClick={() => act('cancel')}
            >
              {awaiting_approval ? 'Отклонить' : 'Отмена'}
            </Button>
          </Stack.Item>
          <Stack.Item grow>
            <Button
              fluid
              color="good"
              disabled={!complete || !!sending}
              onClick={() => act('confirm', fields)}
            >
              {awaiting_approval
                ? 'Опубликовать на GitHub'
                : 'Отправить на проверку'}
            </Button>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}
