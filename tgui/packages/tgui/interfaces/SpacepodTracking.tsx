import { Box, LabeledList, ProgressBar, Section } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Pod = {
  name: string;
  x: number;
  y: number;
  z: number;
  pilot: string;
  passengers: string;
  integrity: number | null;
  charge: number | null;
};

export const SpacepodTracking = () => {
  const { data } = useBackend<{ pods: Pod[] }>();
  return (
    <Window width={520} height={520} title="Слежение за челноками">
      <Window.Content scrollable>
        {!data.pods.length && (
          <Box color="label">Маяки челноков не обнаружены.</Box>
        )}
        {data.pods.map((pod, index) => (
          <Section key={index} title={pod.name}>
            <LabeledList>
              <LabeledList.Item label="Координаты">
                X: {pod.x}, Y: {pod.y}, Z: {pod.z}
              </LabeledList.Item>
              <LabeledList.Item label="Пилот">{pod.pilot}</LabeledList.Item>
              <LabeledList.Item label="Пассажиры">
                {pod.passengers}
              </LabeledList.Item>
              {pod.integrity !== null && (
                <LabeledList.Item label="Корпус">
                  <ProgressBar
                    value={pod.integrity}
                    minValue={0}
                    maxValue={100}
                  >
                    {pod.integrity}%
                  </ProgressBar>
                </LabeledList.Item>
              )}
              {pod.charge !== null && (
                <LabeledList.Item label="Батарея">
                  <ProgressBar value={pod.charge} minValue={0} maxValue={100}>
                    {pod.charge}%
                  </ProgressBar>
                </LabeledList.Item>
              )}
            </LabeledList>
          </Section>
        ))}
      </Window.Content>
    </Window>
  );
};
