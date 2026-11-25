# Fcitx 5 Osk JA（fcitx5-osk-ja）

Fcitx 5 と連携して動くオンスクリーンキーボード（画面キーボード）の日本語環境向け派生版です。KDE Plasma（KWin）の Wayland 環境、特にタブレット・2 in 1 PC での利用を想定しています。

- **オリジナル**: [fortime/fcitx5-osk](https://github.com/fortime/fcitx5-osk)（作者: fortime さん / MIT License）
- オリジナルの英語版 README は [README_ORIGINAL.md](README_ORIGINAL.md) にあります
- 変更履歴（オリジナル分）は [CHANGELOG.md](CHANGELOG.md) を参照してください

## オリジナルからの変更点

- **JIS配列（日本語109キーボード風）を内蔵**し、横画面の既定レイアウトにした
- **Enter・矢印キーなどが豆腐（□）になる問題を解消**（アイコン用フォントを Symbols Nerd Font に変更し、deb に同梱）
- **Ubuntu / Kubuntu 用のインストールスクリプト**を追加（deb パッケージを作って apt でインストール、アップデートにも対応）
- **アプリ名を `fcitx5-osk-ja` に変更**し、オリジナルと同時にインストールしても競合しないようにした
- **アイコンを新しいデザインに変更**

### オリジナルとの名前の対応

| 項目                               | オリジナル                       | この版（JA）                        |
| ---------------------------------- | -------------------------------- | ----------------------------------- |
| キーボード本体                     | `fcitx5-osk`                     | `fcitx5-osk-ja`                     |
| Key Helper                         | `fcitx5-osk-key-helper`          | `fcitx5-osk-ja-key-helper`          |
| KWin ランチャー                    | `fcitx5-osk-kwin-launcher`       | `fcitx5-osk-ja-kwin-launcher`       |
| systemd サービス                   | `fcitx5-osk-key-helper.service`  | `fcitx5-osk-ja-key-helper.service`  |
| D-Bus 名                           | `fyi.fortime.Fcitx5Osk` など     | `xyz.enoki.fcitx5.osk` など         |
| 仮想キーボード名（KDE の設定画面） | Fcitx 5 Osk Kwin Launcher        | Fcitx 5 Osk JA Kwin Launcher        |
| ユーザー設定フォルダ               | `~/.config/fcitx5-osk/`          | `~/.config/fcitx5-osk-ja/`          |
| データフォルダ                     | `/usr/(local/)share/fcitx5-osk/` | `/usr/(local/)share/fcitx5-osk-ja/` |
| Key Helper の設定                  | `/etc/fcitx5-osk-key-helper/`    | `/etc/fcitx5-osk-ja-key-helper/`    |

設定フォルダも別なので、オリジナルの設定は引き継がれません。必要ならコピーしてください。

```bash
cp -r ~/.config/fcitx5-osk ~/.config/fcitx5-osk-ja
```

> **同時インストールの注意**
>
> - ファイルは共存できますが、KDE の「仮想キーボード」で選べるのは 1 つだけです。
> - Key Helper は両方動かすこともできますが、使わない方は止めておくのがおすすめです（`sudo systemctl disable --now fcitx5-osk-key-helper`）。
> - 実験的な KWin エフェクトプラグイン（`-D BUILD_KWIN_PLUGIN=YES`）は名前を変えていません。オリジナルと両方でプラグインをビルド・インストールすると上書きし合います。

---

## 主な機能

- Wayland の各種コンポジタと X11（XWayland で確認）で動作
- D-Bus 経由で Fcitx 5 にキー入力を送信
- KDE のロック画面・ログイン画面（SDDM）でも使用可能（Kwin ランチャー使用時）
- 画面の回転を検出し、横画面・縦画面で別のレイアウトを使用
- レイアウト・キー・テーマを自由にカスタマイズ可能
- ドック表示／フロート表示
- クイックアクションバー、コンボモード、リピート、カスタムアクション

> オリジナル作者は KWin 6（Wayland / XWayland）でのみ動作確認しています。

### 構成コンポーネント

| 名前                          | 役割                                                                                                                                                                       |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fcitx5-osk-ja`               | キーボード本体                                                                                                                                                             |
| `fcitx5-osk-ja-key-helper`    | Shift などの修飾キーを evdev 経由で送るヘルパー（root 権限の systemd サービス）。Wayland では Fcitx 5 が修飾キーを正しく転送しないため、これが無いと大文字が入力できません |
| `fcitx5-osk-ja-kwin-launcher` | KWin と連携して、ログイン後・ロック画面・SDDM でキーボードを起動・表示する                                                                                                 |

---

## Ubuntu / Kubuntu へのインストール

### かんたんインストール（おすすめ）

```bash
git clone https://github.com/jikantoki/fcitx5-osk-ja.git
cd fcitx5-osk-ja
./install.sh --install
```

`install.sh` は **deb パッケージ `dist/fcitx5-osk-ja.deb` を作る**スクリプトです。`--install` を付けると、作った deb を `apt` でインストールするところまで自動で行います（途中で sudo のパスワードを聞かれます）。

root でも実行できます（`sudo ./install.sh --install`）。root のときは sudo を使わずにそのまま実行するので、
root でしか書き込めない場所（Motivnavi OS の `/motivnavi/fcitx5-osk-ja` など）にソースを置いた場合や、
Motivnavi Updater からのワンクリックインストールでも、途中で止まらずに最後まで進みます。

1. ビルドに必要なパッケージを apt で入れる
2. Rust（rustup の stable）を入れて最新にする（cmake が 4.1 未満なら snap 版を入れる）
3. ソースをビルドし、`dist/fcitx5-osk-ja.deb` を作る
4. `--install` 付きのとき: その deb を `apt` でインストールする（Key Helper サービスも自動で有効になる）

deb には、アイコン用フォント（Symbols Nerd Font）と、アップデート用のコマンド・メニュー項目も入っています。初回のビルドは時間がかかります。ソースに変更が無ければ、2回目以降はビルドをスキップします。

インストールが終わったら、次の設定をしてください。

1. **システム設定 → キーボード → 仮想キーボード** で **「Fcitx 5 Osk JA Kwin Launcher」** を選ぶ
2. Fcitx 5 の入力メソッド設定で、キーボードレイアウトを **「日本語」** にする
3. 一度ログアウトして、ログインし直す

### deb を作るだけ

```bash
./install.sh
```

`dist/fcitx5-osk-ja.deb` ができます。他の PC に持っていって、`sudo apt install ./fcitx5-osk-ja.deb` でインストールすることもできます。

### アップデート

次のどちらかで、ソースを `git pull` して新しい版があれば deb を作り直し、apt で入れ替えます（`./install.sh --update --install` と同じです）。

- ターミナルで `fcitx5-osk-ja-update` を実行
- アプリメニューの **「Fcitx 5 Osk JA を更新」** をクリック

ソースのフォルダに書き込めない場合（root 所有の `/motivnavi` など）は、自動で sudo を付けて実行します。
Motivnavi OS では、Motivnavi Updater からもアップデートできます。

新しい版は、ログインし直すと反映されます。

> アップデートは clone したフォルダの `origin` から取得します（`git remote -v` で確認できます）。

### `install.sh` のオプション

| コマンド | 内容 |
|---|---|
| `./install.sh` | `dist/fcitx5-osk-ja.deb` を作る |
| `./install.sh --install` | deb を作って apt でインストールする |
| `./install.sh --update` | `git pull` してから deb を作る |
| `./install.sh --update --install` | `git pull` → deb 作成 → インストール |
| `./install.sh --force` | バージョンが同じでも作り直す（`--install` と一緒なら入れ直しも） |
| `./install.sh --src <フォルダ>` | ソースの場所を指定する |

### アンインストール

```bash
sudo apt remove fcitx5-osk-ja
```

### オリジナル版（fcitx5-osk）からの移行

オリジナルの fcitx5-osk を cmake で入れていた環境では、fcitx5-osk-ja の deb をインストールしたあとに、移行スクリプトを実行してください。

```bash
sudo ./tools/migrate-from-fcitx5-osk.sh                          # 何が変わるかを表示するだけ
sudo ./tools/migrate-from-fcitx5-osk.sh --apply                  # 実行する
sudo ./tools/migrate-from-fcitx5-osk.sh --apply --include-home   # 既存ユーザーの設定も移行する
```

- オリジナル版が入れたファイル（`/usr/local` など）を削除します
- `/etc/skel`・`/etc/xdg`・`/etc/sddm.conf.d`・`/usr/share/kubuntu-default-settings` などにある設定の参照を fcitx5-osk-ja 用に書き換えます（パッケージ管理下のファイルは書き換えません）
- 新規ユーザーの既定の仮想キーボードを「Fcitx 5 Osk JA Kwin Launcher」にします（`/etc/xdg/kwinrc`、あれば `/etc/skel/.config/kwinrc`）
- 変更・削除したファイルは `/var/backups/fcitx5-osk-ja-migrate/<日時>/` に残ります

### 手動でビルドする（cmake）

deb を使わずに、`/usr/local` に直接インストールする方法です。

```bash
# 1. 必要なパッケージ（cmake は 4.1 以上。古い場合は sudo snap install cmake --classic）
sudo apt install -y build-essential cmake git pkg-config libssl-dev clang \
  curl unzip fontconfig fcitx5 fcitx5-mozc kde-config-fcitx5

# 2. Rust（Rust 1.100 でビルドを確認。1.97 ではコンパイルエラーになります）
sudo apt install -y rustup
rustup default stable
rustup update stable

# 3. ビルドとインストール
cmake -B build -S .
cmake --build build
sudo cmake --install build --component Fcitx5Osk
sudo cmake --install build --component Fcitx5OskKwinLauncher
sudo systemctl daemon-reload
sudo systemctl enable --now fcitx5-osk-ja-key-helper

# 4. アイコン用フォント（Symbols Nerd Font）
mkdir -p ~/.local/share/fonts/NerdFontsSymbolsOnly
curl -fL -o /tmp/sym.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
unzip -o /tmp/sym.zip '*.ttf' -d ~/.local/share/fonts/NerdFontsSymbolsOnly
fc-cache -f
```

その後の設定は「かんたんインストール」と同じです。

> **Ubuntu 特有の注意:** `-D CMAKE_INSTALL_PREFIX=/usr` を指定してビルドすると、Debian/Ubuntu では systemd ユニットが `/usr/lib/x86_64-linux-gnu/systemd/system` に入ってしまい、サービスが見つからなくなります。`/usr` に入れたい場合は `-D CMAKE_INSTALL_LIBDIR=lib` も付けてください。

> 手動インストールと deb を両方入れると二重になります。deb に切り替えるときは、先に `sudo xargs rm -v < build/install_manifest_Fcitx5Osk.txt`（ランチャーは `install_manifest_Fcitx5OskKwinLauncher.txt`）で手動インストール分を消してください。

### 手動で表示する

```bash
fcitx5-osk-ja force-show
```

アプリケーションメニューの「Fcitx 5 Osk JA」からも起動できます。

---

## JIS 配列について

横画面では、**内蔵の JIS 配列レイアウト**（`jis-landscape`）が標準で使われます。設定ファイルは必要ありません。

- 1段目: `半/全` `1`〜`0` `-` `^` `¥` `BS`
- 2段目: `Tab` `Q`〜`P` `@` `[` `Enter`
- 3段目: `Caps` `A`〜`L` `;` `:` `]` `Enter`
- 4段目: `Shift` `Z`〜`/` `\(ろ)` `Shift`
- 5段目: `Esc` `Ctrl` `Super` `Alt` `無変換` `Space` `変換` `かな` `Ctrl` `← ↑ ↓ →`

**前提:** Fcitx 5 の入力メソッド設定で、キーボードレイアウトを **「日本語」** にしてください。キーコードを jp レイアウト基準で指定しているので、US レイアウトのままだと `@` や `:` などがずれます。

縦画面は、オリジナルと同じ内蔵の `default-portrait` レイアウトを使います。

### US 配列に戻したいとき

US 配列のレイアウトは `us-landscape` という名前で入っています（`/etc/xdg/fcitx5-osk-ja/layouts/us-landscape.toml`）。`~/.config/fcitx5-osk-ja/config.toml` に次のように書くと切り替わります。

```toml
# すべての入力メソッドで US 配列にする
default_landscape_layout = "us-landscape"

# 入力メソッドごとに変える場合（名前はキーボード上のドロップダウンに出るもの）
[im_layout_mapping.landscape]
keyboard-us = "us-landscape"
```

`キー = 値` の行は、`[ ]` で始まる行より上に書いてください。

---

## SDDM（ログイン画面）で使う

`/etc/sddm.conf.d/` に設定ファイルを作り、`kwin_wayland` に入力メソッドを指定します。`/usr/local` にインストールした場合は、SDDM の `PATH` に `/usr/local/bin` が含まれないことがあるので、**絶対パス**で書いてください。

```ini
# /etc/sddm.conf.d/rootless.conf
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1 --inputmethod "/usr/local/bin/fcitx5-osk-ja-kwin-launcher --sddm"
```

---

## カスタマイズ

レイアウト・キーセット・テーマ・カスタムアクションは TOML ファイルで定義します。次の場所にある設定が読み込まれます。

- `$XDG_CONFIG_HOME/fcitx5-osk-ja/`（既定は `~/.config/fcitx5-osk-ja/`）
- `$XDG_CONFIG_DIRS/fcitx5-osk-ja/`（既定は `/etc/xdg/fcitx5-osk-ja/`）

フォルダは `layouts/`, `key_sets/`, `themes/`, `custom_actions/` に分かれています。カスタムアクションのひな形は `/usr/share/fcitx5-osk-ja/custom_actions/`（手動ビルドの場合は `/usr/local/share/...`）に入ります。

- レイアウトのひな形: [assets/layouts/jis-landscape.toml](assets/layouts/jis-landscape.toml)（JIS）、[assets/layouts/us-landscape.toml](assets/layouts/us-landscape.toml)（US）
- キーセットのひな形: [assets/key_sets/default.toml](assets/key_sets/default.toml)
- 書式の詳しい説明は [README_ORIGINAL.md](README_ORIGINAL.md) の「Custom Layouts, Keys, Themes and Actions」を参照してください（パスの `fcitx5-osk` は `fcitx5-osk-ja` に読み替えてください）

キーセットでよく使う項目:

| 項目 | 意味                                                                        |
| ---- | --------------------------------------------------------------------------- |
| `c`  | 入力する文字                                                                |
| `ks` | X の keysym（例: `0xff0d` = Enter）                                         |
| `s`  | キーに表示する文字                                                          |
| `kc` | X11 キーコード（負の値は Shift 同時押し）                                   |
| `f`  | フォント名（`"fcitx5 osk nerd"` は `default_nerd_font` で指定したフォント） |

---

## トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| Enter・矢印・ツールバーのアイコンが豆腐（□）になる | deb 版はフォント同梱なので、ログインし直す。手動ビルドの場合は Symbols Nerd Font を入れる（`fc-list : family \| grep -i nerd` で確認） |
| 大文字や記号（Shift が必要な文字）が入力できない | Key Helper が動いているか確認（`systemctl status fcitx5-osk-ja-key-helper`） |
| `install.sh` で `ソースが見つかりません` と出る | リポジトリのフォルダの中で `./install.sh --install` を実行する |
| `install.sh` で `git pull に失敗しました` と出る | ソースフォルダに手元の変更がある。`git status` で確認して、コミットするか元に戻す |
| Rust のビルドで `the ? operator can only be used in an async block that returns Result` と出る | Rust が古い。`rustup update stable` で更新する |
| JIS 配列で `@` `:` などがずれる | Fcitx 5 のキーボードレイアウトを「日本語」にする |
| オリジナル版のキーボードが出てくる | KDE の「仮想キーボード」で「Fcitx 5 Osk JA Kwin Launcher」を選び直し、ログインし直す |

---

## ライセンス

MIT License（[LICENSE](LICENSE)）。オリジナルの著作権は [fortime](https://github.com/fortime/fcitx5-osk) さんにあります。

アイコン（`assets/icons/fcitx5-osk.svg`）の「あ」の字形は [Noto Sans CJK JP](https://github.com/notofonts/noto-cjk)（SIL Open Font License 1.1）から作成しています。オリジナルのアイコンは `assets/icons/fcitx5-osk-original.svg` に残しています。
