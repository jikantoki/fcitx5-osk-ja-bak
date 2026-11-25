#!/usr/bin/env bash
# =============================================================================
#  fcitx5-osk-ja deb パッケージ作成スクリプト（Ubuntu / Kubuntu 用）
#
#  ソースからビルドして dist/fcitx5-osk-ja.deb を作ります。
#  --install を付けると、作った deb を apt でインストールまで行います。
#
#  使い方:
#    ./install.sh                     dist/fcitx5-osk-ja.deb を作る
#    ./install.sh --install           deb を作って apt でインストールする
#    ./install.sh --update            ソースを git pull してから deb を作る
#    ./install.sh --update --install  git pull → deb 作成 → インストール
#    ./install.sh --force             バージョンが同じでも作り直す
#    ./install.sh --src DIR           ソースの場所を指定する
#
#  普通のユーザーで実行すると、必要なところだけ sudo を使います。
#  root でも実行できます（sudo ./install.sh --install、Motivnavi Updater からの実行など）。
#
#  インストール後は「fcitx5-osk-ja-update」コマンド、またはアプリメニューの
#  「Fcitx 5 Osk JA を更新」で --update --install と同じことができます。
# =============================================================================
set -euo pipefail

APP=fcitx5-osk-ja
REPO_URL="${FCITX5_OSK_JA_REPO:-https://github.com/jikantoki/fcitx5-osk-ja.git}"
BRANCH="${FCITX5_OSK_JA_BRANCH:-main}"
MAINTAINER="${DEBFULLNAME:-enoki} <${DEBEMAIL:-enoki@localhost}>"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APP"
DEFAULT_SRC="${XDG_DATA_HOME:-$HOME/.local/share}/$APP/src"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip"
MIN_CMAKE="4.1"

c_info=$'\e[1;36m'; c_ok=$'\e[1;32m'; c_warn=$'\e[1;33m'; c_err=$'\e[1;31m'; c_off=$'\e[0m'
info() { echo "${c_info}==>${c_off} $*"; }
ok()   { echo "${c_ok}✔${c_off} $*"; }
warn() { echo "${c_warn}⚠${c_off} $*" >&2; }
die()  { echo "${c_err}✘ $*${c_off}" >&2; exit 1; }

version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

is_root() { [ "$(id -u)" -eq 0 ]; }

# root で実行されているときは sudo を付けずに、普通のユーザーなら sudo で実行する
as_root() {
    if is_root; then "$@"; else sudo "$@"; fi
}
# apt-get を対話なしで実行する（画面のないアップデーターから呼ばれても止まらないように）
apt_root() { as_root env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }

# ソースのフォルダに対する git。root で他人のフォルダを触っても止まらないよう safe.directory を付け、
# chmod で権限だけ変わったファイルを「変更あり」と扱わないよう core.fileMode=false にする
src_git() { git -c safe.directory="$src" -c core.fileMode=false -C "$src" "$@"; }

# root で実行していて、ソースのフォルダが普通のユーザーの持ち物なら、そのユーザーとして実行する
# （git pull で root 所有のファイルが混ざらないように）
as_src_owner() {
    local uid user
    uid="$(stat -c %u "$src" 2>/dev/null || echo 0)"
    if is_root && [ "$uid" != 0 ] && user="$(getent passwd "$uid" | cut -d: -f1)" && [ -n "$user" ]; then
        runuser -u "$user" -- "$@"
    else
        "$@"
    fi
}

pause_if_terminal_launch() {
    # アプリメニューから起動したとき、ウィンドウがすぐ閉じないようにする
    if [ "${FCITX5_OSK_JA_PAUSE:-0}" = 1 ]; then
        read -r -p "Enter キーで閉じます..." _ || true
    fi
}

main() {
    local mode=build force=0 do_install=0 src=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --update) mode=update ;;
            --force) force=1 ;;
            --install) do_install=1 ;;
            --src) shift; src="${1:?--src にはフォルダを指定してください}" ;;
            -h|--help) sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; trap - EXIT; exit 0 ;;
            *) die "不明なオプション: $1（--help で使い方を表示）" ;;
        esac
        shift
    done

    if is_root; then info "root で実行しています（sudo は使いません）"; fi
    command -v apt-get >/dev/null || die "apt が見つかりません。Ubuntu / Kubuntu で実行してください"

    # ---- ソースの場所を決める -------------------------------------------------
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
    if [ -z "$src" ]; then
        if [ -n "$script_dir" ] && [ -f "$script_dir/CMakeLists.txt" ] && [ -d "$script_dir/fcitx5-osk" ]; then
            src="$script_dir"
        elif [ -f "$STATE_DIR/source-dir" ] && [ -d "$(cat "$STATE_DIR/source-dir")" ]; then
            src="$(cat "$STATE_DIR/source-dir")"
        else
            src="$DEFAULT_SRC"
        fi
    fi

    # ---- 1. 必要なパッケージ ---------------------------------------------------
    info "必要なパッケージを確認しています"
    local pkgs=(build-essential cmake git pkg-config libssl-dev clang curl unzip fontconfig dpkg-dev)
    local missing=()
    for p in "${pkgs[@]}"; do
        dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || missing+=("$p")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        info "インストールします: ${missing[*]}"
        apt_root update
        apt_root install -y "${missing[@]}"
    fi
    ok "パッケージ OK"

    # ---- 2. cmake のバージョン ------------------------------------------------
    local cmake_bin=cmake cmake_ver
    cmake_ver="$(cmake --version | head -n1 | awk '{print $3}')"
    if ! version_ge "$cmake_ver" "$MIN_CMAKE"; then
        if [ -x /snap/bin/cmake ] && version_ge "$(/snap/bin/cmake --version | head -n1 | awk '{print $3}')" "$MIN_CMAKE"; then
            cmake_bin=/snap/bin/cmake
        elif command -v snap >/dev/null; then
            info "cmake $cmake_ver は古いので、snap 版の cmake を入れます"
            as_root snap install cmake --classic
            cmake_bin=/snap/bin/cmake
        else
            die "cmake $MIN_CMAKE 以上が必要です（今は $cmake_ver）"
        fi
    fi
    ok "cmake $("$cmake_bin" --version | head -n1 | awk '{print $3}')"

    # ---- 3. Rust（rustup の stable を最新に） --------------------------------
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! command -v rustup >/dev/null; then
        if command -v cargo >/dev/null && ! dpkg -S "$(command -v cargo)" >/dev/null 2>&1; then
            : # 自分で入れた cargo があればそれを使う
        else
            info "rustup をインストールします"
            apt_root install -y rustup || {
                warn "apt の rustup が使えないので、公式スクリプトで入れます"
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
            }
        fi
    fi
    if command -v rustup >/dev/null; then
        rustup toolchain list 2>/dev/null | grep -q '^stable' || rustup toolchain install stable --profile minimal
        rustup default >/dev/null 2>&1 || rustup default stable
        info "Rust (stable) を最新にしています"
        rustup update stable --no-self-update >/dev/null
    fi
    ok "$(rustc --version)"

    # ---- 4. ソースの取得／更新 -------------------------------------------------
    if [ ! -f "$src/CMakeLists.txt" ]; then
        [[ "$REPO_URL" != *CHANGE_ME* ]] || die "ソースが見つかりません。リポジトリの中で実行するか、FCITX5_OSK_JA_REPO にURLを指定してください"
        info "ソースを取得します: $REPO_URL → $src"
        mkdir -p "$(dirname "$src")"
        git clone --branch "$BRANCH" "$REPO_URL" "$src"
    elif [ "$mode" = update ]; then
        if [ -d "$src/.git" ] && src_git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
            info "ソースを更新しています（git pull）"
            as_src_owner git -c safe.directory="$src" -c core.fileMode=false -C "$src" pull --ff-only \
                || die "git pull に失敗しました。$src の変更を確認してください"
        else
            warn "追跡するリモートブランチが無いので、git pull はスキップします"
        fi
    fi
    mkdir -p "$STATE_DIR"
    echo "$src" > "$STATE_DIR/source-dir"
    if is_root; then
        # root でインストールしたときは、普通のユーザーの fcitx5-osk-ja-update からも場所が分かるようにする
        mkdir -p /var/lib/$APP
        echo "$src" > /var/lib/$APP/source-dir
    fi
    ok "ソース: $src"

    # ---- 5. バージョン番号 -----------------------------------------------------
    local base count hash version
    base="$(grep -m1 '^version' "$src/Cargo.toml" | sed -E 's/.*"([^"]+)".*/\1/')"
    if [ -d "$src/.git" ] && src_git rev-parse -q --verify HEAD >/dev/null; then
        count="$(src_git rev-list --count HEAD)"
        hash="$(src_git rev-parse --short HEAD)"
        version="${base}+git${count}.${hash}"
        if [ -n "$(src_git status --porcelain --untracked-files=no)" ]; then
            version="${version}.local$(date +%Y%m%d%H%M)"
        fi
    else
        version="${base}+$(date +%Y%m%d%H%M)"
    fi

    local dist="$src/dist"
    local deb="$dist/$APP.deb"
    local built=""
    [ -f "$deb" ] && built="$(dpkg-deb -f "$deb" Version 2>/dev/null || true)"
    if [ "$built" = "$version" ] && [ "$force" = 0 ]; then
        ok "dist/$APP.deb は最新です（$version）。作り直す場合は --force"
    else
        info "バージョン: ${built:-なし} → $version"
        build_deb "$src" "$version" "$mode" "$cmake_bin" "$deb"
        # root で普通のユーザーのフォルダにビルドしたときは、できたファイルの持ち主を戻す
        local owner
        owner="$(stat -c %u:%g "$src")"
        if is_root && [ "${owner%%:*}" != 0 ]; then
            chown -R "$owner" "$src/build-deb" "$dist" 2>/dev/null || true
        fi
    fi

    if [ "$do_install" = 0 ]; then
        echo
        echo "インストールするには: ./install.sh --install"
        echo "                  または: sudo apt install $deb"
        return 0
    fi
    install_deb "$deb" "$version" "$force"
}

# ---- deb を作る ------------------------------------------------------------------
build_deb() {
    local src="$1" version="$2" mode="$3" cmake_bin="$4" deb="$5"
    local build="$src/build-deb" pkg="$src/build-deb/pkgroot" dist
    dist="$(dirname "$deb")"
    local arch
    arch="$(dpkg --print-architecture)"
    info "ビルドしています（初回は時間がかかります）"
    "$cmake_bin" -S "$src" -B "$build" \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_INSTALL_PREFIX=/usr \
        -D CMAKE_INSTALL_LIBDIR=lib \
        -D DBUS_CONFIG_PARENT_DIR=/usr/share >/dev/null
    "$cmake_bin" --build "$build"

    rm -rf "$pkg"
    DESTDIR="$pkg" "$cmake_bin" --install "$build" --component Fcitx5Osk >/dev/null
    DESTDIR="$pkg" "$cmake_bin" --install "$build" --component Fcitx5OskKwinLauncher >/dev/null

    # アイコン用フォント（Symbols Nerd Font / MIT License）を同梱
    local fontzip="$build/NerdFontsSymbolsOnly.zip"
    if [ ! -s "$fontzip" ] || [ "$mode" = update ]; then
        info "Symbols Nerd Font をダウンロードしています"
        curl -fL --retry 3 -o "$fontzip.tmp" "$NERD_FONT_URL" && mv "$fontzip.tmp" "$fontzip"
    fi
    install -d "$pkg/usr/share/fonts/truetype/$APP" "$pkg/usr/share/doc/$APP"
    unzip -o -q -j "$fontzip" 'SymbolsNerdFont-Regular.ttf' -d "$pkg/usr/share/fonts/truetype/$APP"
    unzip -o -q -j "$fontzip" 'LICENSE' -d "$build/font-license" && \
        install -m644 "$build/font-license/LICENSE" "$pkg/usr/share/doc/$APP/LICENSE.SymbolsNerdFont"
    install -m644 "$src/LICENSE" "$pkg/usr/share/doc/$APP/copyright"

    # アップデート用コマンド（ソースの install.sh を --update --install で呼ぶ）
    install -d "$pkg/usr/bin"
    cat > "$pkg/usr/bin/$APP-update" <<'EOF'
#!/bin/sh
# fcitx5-osk-ja を最新版にアップデートする（git pull → deb 作成 → apt インストール）
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/fcitx5-osk-ja/source-dir"
[ -f "$STATE" ] || STATE=/var/lib/fcitx5-osk-ja/source-dir
if [ ! -f "$STATE" ]; then
    echo "ソースの場所が分かりません。ソースのフォルダで ./install.sh --install を一度実行してください" >&2
    [ "${FCITX5_OSK_JA_PAUSE:-0}" = 1 ] && { printf "Enter キーで閉じます..."; read -r _; }
    exit 1
fi
SRC="$(cat "$STATE")"
# ソースのフォルダに書き込めない（root 所有の /motivnavi など）ときは sudo で実行する
if [ "$(id -u)" -ne 0 ] && { [ ! -w "$SRC" ] || [ ! -r "$SRC/install.sh" ]; }; then
    exec sudo env FCITX5_OSK_JA_PAUSE="${FCITX5_OSK_JA_PAUSE:-0}" bash "$SRC/install.sh" --update --install "$@"
fi
exec bash "$SRC/install.sh" --update --install "$@"
EOF
    chmod 755 "$pkg/usr/bin/$APP-update"
    install -d "$pkg/usr/share/applications"
    cat > "$pkg/usr/share/applications/xyz.enoki.fcitx5.osk.Update.desktop" <<EOF
[Desktop Entry]
Name=Fcitx 5 Osk JA を更新
Comment=fcitx5-osk-ja を最新版にアップデートします
Exec=env FCITX5_OSK_JA_PAUSE=1 /usr/bin/$APP-update
Icon=xyz.enoki.fcitx5.osk
Terminal=true
Type=Application
Categories=System;Settings;
EOF

    # ---- deb パッケージ作成 ------------------------------------------------------
    info "deb パッケージを作っています"
    local depends="fcitx5, dbus"
    local shlib_dir="$build/shlibdeps"
    rm -rf "$shlib_dir"; mkdir -p "$shlib_dir/debian"
    printf 'Source: %s\n\nPackage: %s\nArchitecture: any\n' "$APP" "$APP" > "$shlib_dir/debian/control"
    local shlibs
    if shlibs="$(cd "$shlib_dir" && dpkg-shlibdeps -O \
            "$pkg/usr/bin/$APP" "$pkg/usr/bin/$APP-key-helper" "$pkg/usr/bin/$APP-kwin-launcher" 2>/dev/null \
            | sed -n 's/^shlibs:Depends=//p')" && [ -n "$shlibs" ]; then
        depends="$shlibs, $depends"
    else
        warn "依存ライブラリの自動判定に失敗したので、最低限の依存だけ書きます"
        depends="libc6, libssl3t64 | libssl3, $depends"
    fi

    install -d "$pkg/DEBIAN"
    cat > "$pkg/DEBIAN/control" <<EOF
Package: $APP
Version: $version
Architecture: $arch
Maintainer: $MAINTAINER
Installed-Size: $(du -sk --exclude=DEBIAN "$pkg" | cut -f1)
Depends: $depends
Recommends: fcitx5-mozc, kde-config-fcitx5
Section: utils
Priority: optional
Homepage: ${REPO_URL%.git}
Description: On-screen keyboard for Fcitx 5 (Japanese JIS layout edition)
 fcitx5-osk-ja is a fork of fcitx5-osk (https://github.com/fortime/fcitx5-osk)
 with a built-in Japanese JIS keyboard layout, bundled icon font and
 a renamed set of binaries / D-Bus names so it can coexist with the original.
EOF

    cat > "$pkg/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    if [ -z "$2" ]; then
        systemctl enable --now fcitx5-osk-ja-key-helper.service >/dev/null 2>&1 || true
    else
        systemctl try-restart fcitx5-osk-ja-key-helper.service >/dev/null 2>&1 || true
    fi
    systemctl reload dbus.service >/dev/null 2>&1 || true
    fc-cache -f /usr/share/fonts/truetype/fcitx5-osk-ja >/dev/null 2>&1 || true
    command -v update-desktop-database >/dev/null && update-desktop-database -q /usr/share/applications || true
    command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t /usr/share/icons/hicolor || true
fi
exit 0
EOF
    cat > "$pkg/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = remove ]; then
    systemctl disable --now fcitx5-osk-ja-key-helper.service >/dev/null 2>&1 || true
fi
exit 0
EOF
    cat > "$pkg/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
systemctl daemon-reload >/dev/null 2>&1 || true
fc-cache -f >/dev/null 2>&1 || true
exit 0
EOF
    chmod 755 "$pkg/DEBIAN/postinst" "$pkg/DEBIAN/prerm" "$pkg/DEBIAN/postrm"

    mkdir -p "$dist"
    dpkg-deb --build --root-owner-group "$pkg" "$deb.tmp" >/dev/null
    mv -f "$deb.tmp" "$deb"
    ok "作成: $deb（$version）"
}

# ---- apt でインストール ------------------------------------------------------------
install_deb() {
    local deb="$1" version="$2" force="$3"
    local installed=""
    installed="$(dpkg-query -W -f='${db:Status-Status}|${Version}' "$APP" 2>/dev/null || true)"
    if [[ "$installed" == installed\|* ]]; then installed="${installed#installed|}"; else installed=""; fi
    if [ "$installed" = "$version" ] && [ "$force" = 0 ]; then
        ok "最新版（$version）がインストール済みです"
        return 0
    fi

    if [ -e /usr/local/bin/$APP ]; then
        warn "/usr/local に cmake で手動インストールした $APP が残っています。"
        warn "  二重になるので、削除をおすすめします: sudo xargs rm -v < <ビルドフォルダ>/install_manifest_Fcitx5Osk.txt"
    fi

    # apt の「サンドボックス外でダウンロード」警告を避けるため /tmp にコピーしてから入れる
    local tmpdeb="/tmp/${APP}_${version}.deb"
    cp "$deb" "$tmpdeb"; chmod 644 "$tmpdeb"
    info "apt でインストールしています"
    if [ "$force" = 1 ] && [ "$installed" = "$version" ]; then
        apt_root install -y --reinstall "$tmpdeb"
    else
        apt_root install -y "$tmpdeb"
    fi
    rm -f "$tmpdeb"

    echo
    ok "fcitx5-osk-ja $version をインストールしました（${installed:-新規} → $version）"
    if [ -z "$installed" ]; then
        cat <<EOF

次の設定をしてください:
  1. システム設定 → キーボード → 仮想キーボード で
     「Fcitx 5 Osk JA Kwin Launcher」を選ぶ
  2. Fcitx 5 の入力メソッド設定で、キーボードレイアウトを「日本語」にする
  3. 一度ログアウトして、ログインし直す

アップデートは「fcitx5-osk-ja-update」コマンドか、
アプリメニューの「Fcitx 5 Osk JA を更新」から行えます。
EOF
    else
        echo "新しい版は、ログインし直すと反映されます。"
    fi
}

trap pause_if_terminal_launch EXIT
main "$@"
exit 0
