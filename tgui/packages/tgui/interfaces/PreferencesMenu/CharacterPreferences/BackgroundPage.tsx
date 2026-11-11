import { useState } from 'react';
import { useBackend } from 'tgui/backend';
import { sanitizeText } from 'tgui/sanitize';
import {
  Box,
  Button,
  Input,
  Modal,
  NoticeBox,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';

import type {
  AntagonistBackground,
  AntagonistBackgroundChoice,
  BackgroundEntry,
  BackgroundPreference,
  PreferencesMenuData,
} from '../types';
import { useServerPrefs } from '../useServerPrefs';

export function BackgroundPage() {
  const { data } = useBackend<PreferencesMenuData>();
  const characterKey = `${data.active_slot}-${data.character_preferences?.misc?.species}`;
  return <BackgroundContents key={characterKey} />;
}

function BackgroundContents() {
  const { data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();
  const rows = data.sierra_background ?? [];
  const subfaction = rows.find((row) => row.category === 'subfaction');
  const faction = rows.find((row) => row.category === 'faction');

  return (
    <Stack vertical>
      {!rows.length && (
        <Stack.Item>
          <NoticeBox>Нет доступных настроек предыстории.</NoticeBox>
        </Stack.Item>
      )}
      {rows
        .filter((row) => row.category !== 'subfaction' || !faction)
        .map((preference) => (
          <Stack.Item key={preference.category}>
            <BackgroundCategory
              preference={preference}
              entries={
                serverData?.sierra_background?.[preference.category] ?? {}
              }
              subfaction={
                preference.category === 'faction' ? subfaction : undefined
              }
              childEntries={serverData?.sierra_background?.subfaction ?? {}}
            />
          </Stack.Item>
        ))}
      {data.sierra_antagonist && (
        <Stack.Item>
          <PrivateAntagonist profile={data.sierra_antagonist} />
        </Stack.Item>
      )}
    </Stack>
  );
}

function BackgroundCategory(props: {
  preference: BackgroundPreference;
  entries: Record<string, BackgroundEntry>;
  subfaction?: BackgroundPreference;
  childEntries: Record<string, BackgroundEntry>;
}) {
  const { preference, entries, subfaction, childEntries } = props;
  const { act } = useBackend<PreferencesMenuData>();
  const [choosing, setChoosing] = useState(false);
  const [showNotes, setShowNotes] = useState(false);
  const name =
    preference.selected_name ??
    entries[preference.value]?.name ??
    preference.value;
  const childName =
    subfaction && subfaction.value !== 'none'
      ? (subfaction.selected_name ??
        childEntries[subfaction.value]?.name ??
        subfaction.value)
      : undefined;

  return (
    <Section data-background-category={preference.category}>
      <Box className="Background__row">
        <Box bold className="Background__label">
          {preference.label}
        </Box>
        <Button
          className="Background__current"
          icon="chevron-right"
          iconPosition="right"
          aria-label={`Выбор: ${preference.label}`}
          onClick={() => setChoosing(true)}
        >
          {childName ? `${name} · ${childName}` : name || 'Не выбрано'}
        </Button>
        {preference.notes_preference && (
          <Button
            color="transparent"
            icon="pen"
            aria-label={`Личные подробности: ${preference.label}`}
            aria-expanded={showNotes}
            tooltip="Личные подробности"
            onClick={() => setShowNotes(!showNotes)}
          >
            {preference.notes ? 'Есть заметка' : 'Заметка'}
          </Button>
        )}
      </Box>
      {(preference.invalid_reason || subfaction?.invalid_reason) && (
        <NoticeBox danger mt={1}>
          Сохранённый выбор требует исправления:{' '}
          {preference.invalid_reason ? name : (childName ?? name)}.{' '}
          {preference.invalid_reason ?? subfaction?.invalid_reason}
        </NoticeBox>
      )}
      {(preference.reset_reason || subfaction?.reset_reason) && (
        <NoticeBox mt={1}>
          {preference.reset_reason ?? subfaction?.reset_reason}
        </NoticeBox>
      )}
      {preference.category === 'culture' && preference.language_names && (
        <Box color="label" mt={0.5}>
          Языки воспитания:{' '}
          {preference.language_names.join(', ') || 'дополнительных нет'}
        </Box>
      )}
      {showNotes && preference.notes_preference && (
        <Box mt={1}>
          <Box color="label" mb={0.5}>
            {preference.notes_prompt}
          </Box>
          <TextArea
            fluid
            height="6em"
            aria-label={`Текст заметки: ${preference.label}`}
            value={preference.notes ?? ''}
            maxLength={preference.notes_max_length}
            onBlur={(value) => {
              if (value !== (preference.notes ?? '')) {
                act('set_preference', {
                  preference: preference.notes_preference,
                  value,
                });
              }
            }}
          />
          <Box color="label" fontSize="0.9em" mt={0.5}>
            Видно только вам. Сохраняется при выходе из поля. Shift+Enter —
            новая строка.
          </Box>
        </Box>
      )}
      {choosing && (
        <BackgroundPicker
          preference={preference}
          entries={entries}
          subfaction={subfaction}
          childEntries={childEntries}
          close={() => setChoosing(false)}
        />
      )}
    </Section>
  );
}

function BackgroundPicker(props: {
  preference: BackgroundPreference;
  entries: Record<string, BackgroundEntry>;
  subfaction?: BackgroundPreference;
  childEntries: Record<string, BackgroundEntry>;
  close: () => void;
}) {
  const { preference, entries, subfaction, childEntries, close } = props;
  const { act, data } = useBackend<PreferencesMenuData>();
  const children = preference.choice_children ?? {};
  const options: { id: string; root: string; path: string[] }[] = [];
  const addBranch = (id: string, root: string, parents: string[] = []) => {
    if (parents.includes(id)) {
      return;
    }
    const path = [...parents, id];
    options.push({ id, root, path });
    for (const childId of children[id] ?? []) {
      addBranch(childId, root, path);
    }
  };
  for (const root of preference.choices) {
    addBranch(root, root);
  }
  const [query, setQuery] = useState('');
  const [preview, setPreview] = useState(preference.value);
  const [child, setChild] = useState(subfaction?.value ?? 'none');
  const [expanded, setExpanded] = useState<string[]>(
    () =>
      options.find(
        (option) =>
          option.root === preference.value && option.id === subfaction?.value,
      )?.path ?? [preference.value],
  );
  const contextChoices = preference.context_choices;
  const [showOther, setShowOther] = useState(
    () =>
      !!contextChoices &&
      preference.choices.includes(preference.value) &&
      !contextChoices.includes(preference.value),
  );
  const hasChild = child !== 'none';
  const entry = hasChild ? childEntries[child] : entries[preview];
  const draft = options.find(
    (option) =>
      option.root === preview && option.id === (hasChild ? child : preview),
  );
  const valid = !!draft && (!hasChild || draft.path.length > 1);
  const current =
    preview === preference.value && (!subfaction || child === subfaction.value);
  const effects = preference.choice_effects?.[hasChild ? child : preview] ?? [];
  const search = query.trim().toLocaleLowerCase();
  const nameFor = (id: string, root: string) =>
    (id === root ? entries[id]?.name : childEntries[id]?.name) ?? id;
  const matches = options.filter((option) =>
    nameFor(option.id, option.root).toLocaleLowerCase().includes(search),
  );
  const visibleOptions = options.filter(
    (option) =>
      (!contextChoices ||
        contextChoices.includes(option.root) ||
        showOther ||
        option.root === preference.value ||
        option.root === preview) &&
      (search
        ? matches.some(
            (match) =>
              option.root === match.root &&
              (option.path.includes(match.id) ||
                match.path.includes(option.id)),
          )
        : option.path.slice(0, -1).every((id) => expanded.includes(id))),
  );
  const hasOther =
    !!contextChoices &&
    preference.choices.some((id) => !contextChoices.includes(id));

  return (
    <Modal className="BackgroundPicker" onEscape={close}>
      <div
        className="BackgroundPicker__dialog"
        role="dialog"
        aria-modal="true"
        aria-label={`Выбор: ${preference.label}`}
      >
        <Box className="BackgroundPicker__header">
          <Box bold fontSize="1.2em">
            {preference.label}
          </Box>
          <Button
            icon="times"
            color="transparent"
            aria-label="Закрыть выбор"
            onClick={close}
          />
        </Box>
        <Box className="BackgroundPicker__body">
          <Box className="BackgroundPicker__navigation">
            <Input
              fluid
              autoFocus
              placeholder="Поиск по названию"
              aria-label="Поиск вариантов"
              value={query}
              onChange={setQuery}
            />
            {hasOther && (
              <Button
                fluid
                icon={showOther ? 'chevron-down' : 'chevron-right'}
                aria-expanded={showOther}
                onClick={() => setShowOther(!showOther)}
              >
                Другая среда / диаспора
              </Button>
            )}
            <Box
              className="BackgroundPicker__list"
              data-background-choices={preference.category}
            >
              {!preference.choices.length && (
                <NoticeBox>
                  {preference.empty_reason ??
                    'Нет доступных вариантов для текущих настроек персонажа.'}
                </NoticeBox>
              )}
              {!!preference.choices.length && !visibleOptions.length && (
                <Box color="label">Ничего не найдено.</Box>
              )}
              {visibleOptions.map(({ id, root, path }) => {
                const childIds = children[id] ?? [];
                const opened = expanded.includes(id) || !!search;
                return (
                  <Box
                    key={path.join('/')}
                    mb={0.25}
                    ml={(path.length - 1) * 1.5}
                  >
                    <Box className="BackgroundPicker__branch">
                      {!!childIds.length && (
                        <Button
                          color="transparent"
                          icon={opened ? 'chevron-down' : 'chevron-right'}
                          aria-label={`Подразделения: ${nameFor(id, root)}`}
                          aria-expanded={opened}
                          onClick={() =>
                            setExpanded(
                              opened
                                ? expanded.filter((value) => value !== id)
                                : [...expanded, id],
                            )
                          }
                        />
                      )}
                      <Button
                        fluid
                        className="BackgroundPicker__option"
                        selected={
                          preview === root &&
                          (hasChild ? child === id : id === root)
                        }
                        icon={
                          preference.value === root &&
                          (subfaction && subfaction.value !== 'none'
                            ? subfaction.value === id
                            : id === root)
                            ? 'check'
                            : undefined
                        }
                        aria-label={`Просмотреть: ${nameFor(id, root)}`}
                        onClick={() => {
                          setPreview(root);
                          setChild(id === root ? 'none' : id);
                        }}
                      >
                        {nameFor(id, root)}
                      </Button>
                    </Box>
                  </Box>
                );
              })}
            </Box>
          </Box>
          <Box className="BackgroundPicker__description">
            {hasChild && (
              <Box color="label" mb={0.5}>
                {(draft?.path.slice(0, -1) ?? [preview])
                  .map((id) => nameFor(id, preview))
                  .join(' → ')}
              </Box>
            )}
            <Box bold fontSize="1.25em" mb={1}>
              {entry?.name ?? preference.selected_name ?? preview}
            </Box>
            {entry ? (
              <>
                <Box
                  className="BackgroundPicker__text"
                  dangerouslySetInnerHTML={{
                    __html: sanitizeText(entry.description),
                  }}
                />
                {!!entry.extra && (
                  <Box
                    mt={1}
                    className="BackgroundPicker__text"
                    dangerouslySetInnerHTML={{
                      __html: sanitizeText(entry.extra),
                    }}
                  />
                )}
              </>
            ) : (
              <Box color="label">Описание выбранного варианта недоступно.</Box>
            )}
            {!valid && (
              <NoticeBox danger mt={1}>
                Этот вариант недоступен для текущей анкеты. Выберите другой.
              </NoticeBox>
            )}
            {preference.category === 'culture' &&
              preview === preference.value && (
                <Box mt={1}>
                  {preference.language_names && (
                    <Box>
                      <b>Языки воспитания:</b>{' '}
                      {preference.language_names.join(', ') ||
                        'Дополнительные языки не добавляются.'}
                    </Box>
                  )}
                  {!!preference.language_names?.length && (
                    <Box color="label">
                      Знание языка не гарантирует возможность говорить на нём.
                    </Box>
                  )}
                  {preference.name_generation && (
                    <Box mt={0.5}>
                      <b>Имена:</b> {preference.name_generation}
                    </Box>
                  )}
                </Box>
              )}
            {preference.category === 'culture' && (
              <Box color="label" mt={1}>
                Смена воспитания сохраняет введённое имя. Для нового имени
                используйте кнопку генерации.
              </Box>
            )}
            {!current && !!effects.length && (
              <NoticeBox mt={1}>
                <Box bold>При выборе изменится:</Box>
                {effects.map((effect) => (
                  <Box key={effect}>{effect}</Box>
                ))}
              </NoticeBox>
            )}
          </Box>
        </Box>
        <Box className="BackgroundPicker__footer">
          <Button onClick={close}>Отмена</Button>
          <Button
            icon="check"
            selected={current && valid}
            disabled={!valid || current}
            onClick={() => {
              act('sierra_background_choose', {
                preference: preference.preference,
                value: preview,
                ...(preference.category === 'faction'
                  ? { subfaction: child }
                  : {}),
                slot: data.active_slot,
                species: data.character_preferences?.misc?.species,
              });
              close();
            }}
          >
            {current && valid ? 'Выбрано' : 'Выбрать'}
          </Button>
        </Box>
      </div>
    </Modal>
  );
}

function PrivateAntagonist(props: { profile: AntagonistBackground }) {
  const { profile } = props;
  const { act } = useBackend<PreferencesMenuData>();
  const [expanded, setExpanded] = useState(false);
  const subgroup = profile.subgroup;

  return (
    <Section
      data-background-private="antagonist"
      title={
        <Button
          color="transparent"
          icon={expanded ? 'chevron-down' : 'chevron-right'}
          aria-expanded={expanded}
          onClick={() => setExpanded(!expanded)}
        >
          Антагонист
        </Button>
      }
    >
      <Box color="label">
        Необязательно. После получения роли предателя заметка видна только вам в
        его личном окне, отдельно от назначения. Она не влияет на получение роли
        или выбор нанимателя.
      </Box>
      {expanded && (
        <Box mt={1}>
          <AntagonistChoice label="Организация" choice={profile.organization} />
          {subgroup &&
            (subgroup.choices.length > 1 ||
              subgroup.value !== 'none' ||
              subgroup.invalid_reason) && (
              <Box
                ml={1}
                mt={1}
                pl={1}
                style={{ borderLeft: '2px solid var(--color-primary)' }}
              >
                <AntagonistChoice label="Подгруппа" choice={subgroup} />
              </Box>
            )}
          <Box bold mt={1}>
            Происхождение и связи
          </Box>
          <Box color="label" mb={0.5}>
            {profile.notes.prompt}
          </Box>
          <TextArea
            fluid
            height="5em"
            aria-label="Личные подробности: Антагонист"
            value={profile.notes.value}
            maxLength={profile.notes.max_length}
            onBlur={(value) => {
              if (value !== profile.notes.value) {
                act('set_preference', {
                  preference: profile.notes.preference,
                  value,
                });
              }
            }}
          />
        </Box>
      )}
    </Section>
  );
}

function AntagonistChoice(props: {
  label: string;
  choice: AntagonistBackgroundChoice;
}) {
  const { label, choice } = props;
  const { act } = useBackend<PreferencesMenuData>();
  const selected = choice.choices.find((entry) => entry.id === choice.value);
  const selectedName = choice.selected_name ?? selected?.name ?? choice.value;

  return (
    <Box>
      <Box bold mb={0.5}>
        {label} — {selectedName || 'Не выбрано'}
      </Box>
      {choice.invalid_reason && (
        <NoticeBox danger>
          Сохранённый выбор требует исправления: {selectedName}.{' '}
          {choice.invalid_reason}
        </NoticeBox>
      )}
      {choice.choices.length ? (
        choice.choices.map((entry) => (
          <Button
            key={entry.id}
            selected={entry.id === choice.value}
            style={{ whiteSpace: 'normal', maxWidth: '100%' }}
            onClick={() =>
              act('set_preference', {
                preference: choice.preference,
                value: entry.id,
              })
            }
          >
            {entry.name}
          </Button>
        ))
      ) : (
        <NoticeBox>
          {choice.empty_reason ?? 'Нет доступных вариантов.'}
        </NoticeBox>
      )}
      {selected && (
        <Box
          mt={0.5}
          style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}
        >
          {selected.description}
        </Box>
      )}
    </Box>
  );
}
