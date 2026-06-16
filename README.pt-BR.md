# ASUS Vivobook X1404VA — driver do NumberPad para Linux

🇺🇸 **[Read in English »](README.md)**

Ative o **NumberPad** (o teclado numérico iluminado embutido no touchpad, com
o ícone de liga/desliga no canto superior direito) do **ASUS Vivobook X1404VA**
no Linux.

A ASUS só fornece esse recurso para Windows. No Linux não existe driver de
kernel — ele funciona através de um daemon em espaço de usuário. Este
repositório é um instalador **automático e sem telemetria** em volta do
excelente driver oficial
[`asus-linux-drivers/asus-numberpad-driver`](https://github.com/asus-linux-drivers/asus-numberpad-driver)
(GPL-2.0). Ele escolhe o layout certo para o X1404VA, configura grupos, regras
udev e o serviço systemd do usuário, e pula os menus interativos e os relatórios
anônimos do instalador oficial.

## Por que usar este repo em vez do instalador oficial?

O projeto oficial dá suporte a dezenas de notebooks e o instalador dele é todo
interativo (menus de layout, recursos opcionais, prompts de telemetria anônima).
Este wrapper:

- ✅ **Não-interativo** — um comando, sem menus.
- ✅ **Sem telemetria** — nunca envia nenhum relatório anônimo.
- ✅ **Layout certo de primeira** — `e210ma`, que corresponde ao touchpad do X1404VA.
- ✅ **Idempotente** — pode rodar de novo sem quebrar.
- ✅ **Release do upstream fixada**, para instalações reproduzíveis.

Ele **não** copia nem faz fork do driver: baixa uma release fixada do upstream na
hora da instalação, então você continua recebendo as correções deles e todo o
crédito permanece com o projeto original.

## Hardware suportado

Alvo principal: **ASUS Vivobook X1404VA** (touchpad `093A:200B`, layout
`e210ma`).

O **mesmo touchpad + layout** também cobre estes modelos (devem funcionar com as
configurações padrão):

| Modelo | ID do touchpad | Layout |
|--------|----------------|--------|
| Vivobook X1404VA / X1404VAP / X1404VAPF | `093A:200B` | `e210ma` |
| Vivobook X1404ZA | `093A:200B` | `e210ma` |
| Vivobook Go E1404FA / E1404GA | `093A:200B` | `e210ma` |
| ExpertBook B1403CVA | `093A:200B` | `e210ma` |

Tem outro modelo ASUS? Veja [Usando outro layout](#usando-outro-layout).

## Requisitos

- **Ubuntu / Debian** (ou derivados que usam `apt`).
- Uma sessão gráfica — **Wayland ou X11** (detectado automaticamente).
- Privilégios de `sudo`.

> Testado no Ubuntu 26.04 (kernel 7.x, Python 3.14), Wayland/GNOME.

## Instalação

```bash
git clone https://github.com/john8blade/asus-x1404va-numberpad-linux.git
cd asus-x1404va-numberpad-linux
./install.sh
```

Depois **reinicie** (ou faça logout/login). O reboot é necessário para que a
sua sessão carregue os novos grupos (`i2c`, `input`, `uinput`, `numberpad`)
antes do serviço iniciar.

## Como usar

Depois de reiniciar:

- **Ligar/desligar o NumberPad:** toque e segure (~1 segundo) o **ícone no canto
  superior direito** do touchpad. Os números acendem e a área do touchpad vira
  um teclado numérico. Toque e segure de novo para desligar.
- **Ajustar o brilho dos LEDs:** deslize a partir do **canto superior esquerdo**
  para dentro.

## Gerenciando o serviço

```bash
# status / reiniciar / parar
systemctl --user status  asus_numberpad_driver@$USER.service
systemctl --user restart asus_numberpad_driver@$USER.service
systemctl --user stop    asus_numberpad_driver@$USER.service

# logs ao vivo (para diagnóstico)
journalctl --user -u asus_numberpad_driver@$USER.service -f
```

## Configuração

Um arquivo de configuração é criado automaticamente na primeira execução em:

```
/usr/share/asus-numberpad-driver/numberpad_dev
```

Lá você pode ajustar sensibilidade, brilho ocioso, repetição de teclas, os
gestos dos cantos e mais. Reinicie o serviço depois de editar.

## Usando outro layout

O instalador aceita variáveis de ambiente:

```bash
# escolher outro layout (veja a pasta `layouts/` do upstream para a lista completa)
LAYOUT=up5401ea ./install.sh

# fixar outra release do upstream
UPSTREAM_REF=v7.0.1 ./install.sh
```

Para descobrir o ID do seu touchpad:

```bash
grep -i touchpad /proc/bus/input/devices
```

Os layouts disponíveis ficam no repositório do upstream em
[`layouts/`](https://github.com/asus-linux-drivers/asus-numberpad-driver/tree/master/layouts).

## Desinstalação

```bash
./uninstall.sh
```

Isso para/desabilita o serviço e remove o driver, as regras udev e a
configuração de carga de módulos. Os grupos são mantidos (remova manualmente se
quiser um estado totalmente limpo).

## Como funciona

`install.sh`:

1. Instala as dependências de build via `apt`.
2. Cria os grupos `i2c`/`input`/`uinput`/`numberpad`, adiciona o seu usuário e
   carrega + persiste os módulos `uinput` e `i2c-dev`.
3. Instala regras udev que dão ao seu usuário acesso a `/dev/uinput` e
   `/dev/i2c-*`.
4. Baixa a release fixada do upstream, copia `numberpad.py` + layouts para
   `/usr/share/asus-numberpad-driver` e cria um ambiente Python (venv) isolado.
5. Gera um serviço systemd **do usuário** (template Wayland ou X11) com o layout
   `e210ma` — e **sem** telemetria.

## Créditos

Todo o trabalho de verdade é do driver oficial:
**[asus-linux-drivers/asus-numberpad-driver](https://github.com/asus-linux-drivers/asus-numberpad-driver)**
(GPL-2.0). Por favor, dê uma ⭐ e apoie o projeto.

Este wrapper apenas automatiza uma instalação limpa e sem telemetria para o
X1404VA.

## Licença

Os scripts deste repositório são distribuídos sob a [Licença MIT](LICENSE).
O driver do upstream baixado permanece sob a licença GPL-2.0 dele.
