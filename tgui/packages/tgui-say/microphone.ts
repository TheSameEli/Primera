export function microphoneError(error: unknown): string {
  if (error instanceof Error) {
    if (error.name === 'NotAllowedError' || error.name === 'SecurityError') {
      return `Клиент отклонил доступ к микрофону (${error.name}). В обычном BYOND 516 пока нет запроса разрешения микрофона для TGUI. Отдельный переключатель BYOND в Windows искать не нужно: настройками сервера эту блокировку не снять.`;
    }
    if (error.name === 'NotFoundError')
      return 'Микрофон не найден. Проверьте подключение устройства и настройки звука Windows.';
    if (error.name === 'NotReadableError')
      return 'Микрофон недоступен для записи: проверьте драйвер и другие программы, использующие устройство.';
    return error.message;
  }
  return 'Не удалось получить доступ к микрофону.';
}
