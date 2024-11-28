# Telegram plugin

This Telegram plugin will automatically send you attack notifications on a Telegram chat.

# Prerequisites

Please read the [plugins section](https://docs.bunkerweb.io/latest/plugins/?utm_campaign=self&utm_source=github) of the BunkerWeb documentation first.

# Setup

See the [plugins section](https://docs.bunkerweb.io/latest/plugins/?utm_campaign=self&utm_source=github) of the BunkerWeb documentation for the installation procedure depending on your integration.

There is no additional services to setup besides the plugin itself.

## Docker

```yaml
version: '3'

services:

  bunkerweb:
    image: bunkerity/bunkerweb:1.5.12
    ...
    environment:
      - USE_TELEGRAM=yes
      - TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
      - TELEGRAM_CHAT_ID=123456789
    ...
```

# Settings

| Setting                    | Default                      | Context   | Multiple | Description                                                                                          |
| -------------------------- | ---------------------------- | --------- | -------- | ---------------------------------------------------------------------------------------------------- |
| `USE_TELEGRAM`              | `no`                         | multisite | no       | Enable sending alerts to a Telegram chat.                                                           |
| `TELEGRAM_BOT_TOKEN`        |     | global    | no       | The token looks something like 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11.                                                                              |
| `TELEGRAM_CHAT_ID` |                         | global    | no       | Unique identifier for the target chat or username of the target channel.|

