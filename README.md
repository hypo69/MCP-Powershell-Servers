# MCPServerLauncher PowerShell Module

## Описание

**MCPServerLauncher** — это PowerShell модуль для автоматического запуска и управления MCP (Model Context Protocol) серверами. Модуль поддерживает работу с несколькими типами серверов:

- **STDIO сервер** — для выполнения PowerShell скриптов через стандартные потоки ввода-вывода
- **HTTPS сервер** — для предоставления REST API
- **WordPress CLI сервер** — для управления WordPress через командную строку

## Требования

- PowerShell 7.0 или выше
- Windows, Linux или macOS
- Права на запуск фоновых процессов

## Установка

### Вариант 1: Ручная установка

1. Скопируйте файлы модуля в одну из директорий PowerShell модулей:

```powershell
# Узнать доступные пути для модулей
$env:PSModulePath -split [IO.Path]::PathSeparator

# Рекомендуемая директория для пользовательских модулей
$modulePath = "$HOME\Documents\PowerShell\Modules\MCPServerLauncher"
```

2. Создайте директорию и скопируйте файлы:

```powershell
New-Item -Path $modulePath -ItemType Directory -Force
Copy-Item *.psd1, *.psm1 -Destination $modulePath
```

3. Импортируйте модуль:

```powershell
Import-Module MCPServerLauncher
```

### Вариант 2: Установка из локального репозитория

```powershell
# Из директории проекта
Install-Module -Name .\MCPServerLauncher -Scope CurrentUser
```

## Быстрый старт

### Импорт модуля

```powershell
Import-Module MCPServerLauncher
```

### Запуск всех серверов

```powershell
# Запуск с ожиданием (блокирующий режим)
Start-MCPServerLauncher

# Запуск без ожидания (фоновый режим)
Start-MCPServerLauncher -NoWait

# Краткая форма
Start-MCP
```

### Проверка статуса серверов

```powershell
# Полная форма
Get-MCPServerStatus

# Краткая форма
Get-MCPStatus
```

### Остановка всех серверов

```powershell
# Полная форма
Stop-MCPServers

# Краткая форма
Stop-MCP
```

### Перезапуск серверов

```powershell
# Полная форма
Restart-MCPServers

# Краткая форма
Restart-MCP
```

## Доступные команды

### Start-MCPServerLauncher

Запускает все доступные MCP серверы.

**Параметры:**

- `-ConfigPath` — путь к директории с конфигурациями (по умолчанию: `src\config`)
- `-NoWait` — не ожидать после запуска серверов

**Примеры:**

```powershell
# Запуск с параметрами по умолчанию
Start-MCPServerLauncher

# Запуск с пользовательским путем к конфигурациям
Start-MCPServerLauncher -ConfigPath 'C:\MyProject\config'

# Запуск в фоновом режиме
Start-MCPServerLauncher -NoWait
```

### Stop-MCPServers

Останавливает все запущенные MCP серверы.

**Примеры:**

```powershell
Stop-MCPServers
```

### Get-MCPServerStatus

Отображает статус всех зарегистрированных MCP серверов.

**Примеры:**

```powershell
Get-MCPServerStatus
```

**Пример вывода:**

```
=== СТАТУС MCP СЕРВЕРОВ ===

  ✓ powershell-stdio (PID: 12345)
  ✓ powershell-https (PID: 12346)
  ✗ wordpress-cli (остановлен)

Запущено серверов: 2 / 3
```

### Restart-MCPServers

Перезапускает все MCP серверы (останавливает и запускает заново).

**Параметры:**

- `-ConfigPath` — путь к директории с конфигурациями

**Примеры:**

```powershell
Restart-MCPServers
```

### Test-MCPServerRunning

Проверяет, запущен ли указанный сервер.

**Параметры:**

- `-ServerName` — имя сервера для проверки

**Возвращает:** `$true` если сервер запущен, иначе `$false`

**Примеры:**

```powershell
if (Test-MCPServerRunning -ServerName 'powershell-stdio') {
    Write-Host 'STDIO сервер запущен'
}
```

### Get-MCPServerLog

Отображает логи MCP launcher.

**Параметры:**

- `-Tail` — количество последних строк для отображения (по умолчанию: 50)
- `-Follow` — следить за обновлениями лог-файла в реальном времени

**Примеры:**

```powershell
# Показать последние 50 строк
Get-MCPServerLog

# Показать последние 100 строк
Get-MCPServerLog -Tail 100

# Следить за логами в реальном времени
Get-MCPServerLog -Follow

# Комбинация параметров
Get-MCPServerLog -Tail 20 -Follow
```

## Псевдонимы

Для удобства использования доступны короткие псевдонимы:

| Полная команда | Псевдоним |
|----------------|-----------|
| `Start-MCPServerLauncher` | `Start-MCP` |
| `Stop-MCPServers` | `Stop-MCP` |
| `Get-MCPServerStatus` | `Get-MCPStatus` |
| `Restart-MCPServers` | `Restart-MCP` |

## Структура проекта

Модуль ищет серверные скрипты в следующих локациях (в порядке приоритета):

1. `<ProjectRoot>\src\servers\<ServerScript>`
2. `<ProjectRoot>\servers\<ServerScript>`
3. `<ProjectRoot>\<ServerScript>`

Где `<ProjectRoot>` — это директория, в которой находится модуль.

## Логирование

Модуль создает лог-файл в временной директории пользователя:

```powershell
# Путь к лог-файлу
$env:TEMP\mcp-launcher.log
```

Для просмотра логов используйте команду:

```powershell
Get-MCPServerLog -Follow
```

## Серверы

Модуль поддерживает следующие серверы:

### 1. PowerShell STDIO сервер

**Скрипт:** `Start-McpStdioServer.ps1`

**Описание:** Сервер для выполнения PowerShell скриптов через стандартные потоки ввода-вывода

**Лог-файл:** `$env:TEMP\mcp-server.log`

### 2. PowerShell HTTPS сервер

**Скрипт:** `Start-McpHTTPSServer.ps1`

**Описание:** HTTPS сервер для предоставления REST API

### 3. WordPress CLI сервер

**Скрипт:** `Start-McpWPCLIServer.ps1`

**Описание:** Сервер для управления WordPress через командную строку

## Примеры использования

### Пример 1: Базовый запуск

```powershell
# Импорт модуля
Import-Module MCPServerLauncher

# Запуск всех серверов
Start-MCP

# Проверка статуса
Get-MCPStatus

# Остановка всех серверов
Stop-MCP
```

### Пример 2: Автоматический запуск при старте системы

Добавьте в ваш PowerShell профиль (`$PROFILE`):

```powershell
# Автоматический импорт и запуск MCP серверов
Import-Module MCPServerLauncher
Start-MCPServerLauncher -NoWait
```

### Пример 3: Мониторинг серверов

```powershell
# Запуск серверов в фоне
Start-MCP -NoWait

# Мониторинг статуса каждые 10 секунд
while ($true) {
    Clear-Host
    Get-MCPStatus
    Start-Sleep -Seconds 10
}
```

### Пример 4: Проверка и перезапуск остановленного сервера

```powershell
if (-not (Test-MCPServerRunning -ServerName 'powershell-stdio')) {
    Write-Host 'STDIO сервер остановлен, перезапуск...'
    Restart-MCP
}
```

## Устранение неполадок

### Серверы не запускаются

1. Проверьте, что скрипты серверов находятся в правильных директориях
2. Проверьте права на выполнение скриптов:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

3. Проверьте логи:

```powershell
Get-MCPServerLog -Tail 100
```

### Серверы запускаются, но сразу останавливаются

1. Проверьте логи серверов
2. Убедитесь, что все зависимости установлены
3. Проверьте конфигурационные файлы серверов

### Модуль не импортируется

1. Проверьте, что модуль находится в одной из директорий `$env:PSModulePath`
2. Проверьте версию PowerShell:

```powershell
$PSVersionTable.PSVersion
```

Требуется PowerShell 7.0 или выше.

## Конфигурация

### Переменные окружения

Модуль поддерживает следующие переменные окружения для серверов:

- `POWERSHELL_EXECUTION_POLICY` — политика выполнения для серверных процессов (по умолчанию: `RemoteSigned`)

### Рабочая директория

Все серверы запускаются с рабочей директорией, установленной в корень проекта, что обеспечивает правильную работу относительных путей.

## Лицензия

MIT License

Copyright (c) 2025 hypo69

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Автор

**hypo69**

- GitHub: [https://github.com/hypo69/hypo](https://github.com/hypo69/hypo)

## Поддержка

Для сообщений об ошибках и предложений используйте GitHub Issues.

## История изменений

### Version 1.0.1

- Автоматический запуск MCP серверов
- Управление жизненным циклом серверов
- Поддержка STDIO, HTTPS и WordPress CLI серверов
- Подробное логирование
- Мониторинг статуса серверов
- Псевдонимы команд для удобства
- Полная документация и примеры