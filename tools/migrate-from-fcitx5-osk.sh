#!/usr/bin/env bash
# =============================================================================
#  オリジナルの fcitx5-osk から fcitx5-osk-ja へ移行するスクリプト
#
#  1. オリジナル版が cmake で入れたファイル（/usr・/usr/local・/etc）を削除
#  2. /etc/skel・/etc/xdg・/usr/share/kubuntu-default-settings などに置いた
#     設定ファイルの中の参照（ランチャー名・コマンド名・D-Bus 名・設定フォルダ名）を
#     fcitx5-osk-ja 用に書き換え
#  3. 新規ユーザーの既定の仮想キーボードを「Fcitx 5 Osk JA Kwin Launcher」にする
#     （/etc/xdg/kwinrc と、あれば /etc/skel/.config/kwinrc）
#  4. --include-home を付けたときは、既存ユーザーの ~/.config も同じように移行
#
#  使い方（fcitx5-osk-ja の deb をインストールしてから実行）:
#    sudo ./migrate-from-fcitx5-osk.sh                 何が変わるかを表示するだけ
#    sudo ./migrate-from-fcitx5-osk.sh --apply         実際に変更する
#    sudo ./migrate-from-fcitx5-osk.sh --apply --include-home   既存ユーザーも移行
#
#  変更・削除したファイルは /var/backups/fcitx5-osk-ja-migrate/<日時>/ に残します。
# =============================================================================
set -euo pipefail

NEW_LAUNCHER=/usr/share/applications/xyz.enoki.fcitx5.osk.KwinLauncher.desktop
BACKUP_ROOT=/var/backups/fcitx5-osk-ja-migrate/$(date +%Y%m%d-%H%M%S)

# 設定ファイルを探す場所（存在するものだけ）
SCAN_DIRS=(
    /etc/skel
    /etc/xdg
    /etc/sddm.conf.d
    /etc/sddm.conf
    /etc/environment.d
    /usr/share/kubuntu-default-settings
    /usr/local/share
    /usr/local/bin
)
# 中身を見て報告だけするところ（自動では書き換えない）
REPORT_ONLY_DIRS=(/etc/penguins-eggs.d /etc/calamares)

c_info=$'\e[1;36m'; c_ok=$'\e[1;32m'; c_warn=$'\e[1;33m'; c_err=$'\e[1;31m'; c_off=$'\e[0m'
info() { echo "${c_info}==>${c_off} $*"; }
ok()   { echo "${c_ok}✔${c_off} $*"; }
warn() { echo "${c_warn}⚠${c_off} $*"; }
die()  { echo "${c_err}✘ $*${c_off}" >&2; exit 1; }

APPLY=0 INCLUDE_HOME=0
for a in "$@"; do
    case "$a" in
        --apply) APPLY=1 ;;
        --include-home) INCLUDE_HOME=1 ;;
        -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "不明なオプション: $a" ;;
    esac
done
[ "$(id -u)" -eq 0 ] || die "sudo を付けて実行してください"
command -v python3 >/dev/null || die "python3 が必要です"

if [ ! -f "$NEW_LAUNCHER" ]; then
    if [ "$APPLY" = 1 ]; then
        die "fcitx5-osk-ja がインストールされていません（$NEW_LAUNCHER が無い）。先に deb をインストールしてください"
    fi
    warn "fcitx5-osk-ja がまだインストールされていません。--apply の前にインストールしてください"
fi

if [ "$APPLY" = 1 ]; then
    echo "${c_warn}【実行モード】変更します。バックアップ先: $BACKUP_ROOT${c_off}"
else
    echo "${c_info}【確認モード】何も変更しません。実行するには --apply を付けてください${c_off}"
fi
echo

CHANGES=0
is_old_file() {   # 手順1で削除するファイル（またはその中）なら真
    local o
    for o in "${OLD_FILES[@]}"; do
        [ "$1" = "$o" ] && return 0
        case "$1" in "$o"/*) return 0 ;; esac
    done
    return 1
}
owned_by_package() { dpkg -S "$1" >/dev/null 2>&1; }
backup() {
    local f="$1"
    [ -e "$f" ] || [ -L "$f" ] || return 0
    mkdir -p "$BACKUP_ROOT$(dirname "$f")"
    cp -a "$f" "$BACKUP_ROOT$f"
}

# ---- 1. オリジナル版のファイルを削除 --------------------------------------------
info "1. オリジナル版（fcitx5-osk）のファイル"
OLD_FILES=()
for P in /usr/local /usr; do
    OLD_FILES+=(
        "$P/bin/fcitx5-osk" "$P/bin/fcitx5-osk-key-helper" "$P/bin/fcitx5-osk-kwin-launcher"
        "$P/share/applications/fyi.fortime.Fcitx5Osk.desktop"
        "$P/share/applications/fyi.fortime.Fcitx5Osk.KwinLauncher.desktop"
        "$P/share/dbus-1/services/fyi.fortime.Fcitx5Osk.service"
        "$P/share/dbus-1/services/fyi.fortime.Fcitx5Osk.KwinLauncher.service"
        "$P/share/dbus-1/system.d/fyi.fortime.Fcitx5OskKeyHelper.conf"
        "$P/share/icons/hicolor/scalable/apps/fyi.fortime.Fcitx5Osk.svg"
        "$P/lib/systemd/system/fcitx5-osk-key-helper.service"
        "$P/lib/x86_64-linux-gnu/systemd/system/fcitx5-osk-key-helper.service"
        "$P/share/fcitx5-osk" "$P/share/licenses/fcitx5-osk" "$P/share/licenses/fcitx5-osk-kwin-launcher"
    )
done
OLD_FILES+=(
    /etc/dbus-1/system.d/fyi.fortime.Fcitx5OskKeyHelper.conf
    /etc/systemd/system/fcitx5-osk-key-helper.service
    /etc/systemd/system/multi-user.target.wants/fcitx5-osk-key-helper.service
    /etc/xdg/fcitx5-osk
    /etc/fcitx5-osk-key-helper
)
found_old=0
for f in "${OLD_FILES[@]}"; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    if owned_by_package "$f"; then
        warn "  パッケージ管理下なのでスキップ: $f（$(dpkg -S "$f" 2>/dev/null | cut -d: -f1)）"
        continue
    fi
    found_old=1; CHANGES=$((CHANGES + 1))
    echo "  削除: $f"
done
[ "$found_old" = 1 ] || ok "  残っていません"
if [ "$APPLY" = 1 ] && [ "$found_old" = 1 ]; then
    systemctl disable --now fcitx5-osk-key-helper.service >/dev/null 2>&1 || true
    for f in "${OLD_FILES[@]}"; do
        { [ -e "$f" ] || [ -L "$f" ]; } || continue
        owned_by_package "$f" && continue
        backup "$f"; rm -rf "$f"
    done
    systemctl daemon-reload >/dev/null 2>&1 || true
    ok "  削除しました"
fi
echo

# ---- 2. 設定ファイルの参照を書き換え ----------------------------------------------
# 書き換えルール（perl）。fcitx5-osk-ja には二重に当たらないようにしている
REWRITE='
s#(?:/usr/local|/usr)/share/applications/fyi\.fortime\.Fcitx5Osk\.KwinLauncher\.desktop#/usr/share/applications/xyz.enoki.fcitx5.osk.KwinLauncher.desktop#g;
s#fyi\.fortime\.Fcitx5OskKeyHelper#xyz.enoki.fcitx5.osk.KeyHelper#g;
s#fyi\.fortime\.Fcitx5Osk#xyz.enoki.fcitx5.osk#g;
s#/usr/local/bin/fcitx5-osk(-kwin-launcher|-key-helper)?(?![\w-])#/usr/bin/fcitx5-osk-ja$1#g;
s#(?<![\w-])fcitx5-osk(-kwin-launcher|-key-helper)(?![\w-])#fcitx5-osk-ja$1#g;
s#(?<![\w-])fcitx5-osk(?=/|\s|["\x27=;:,]|$)#fcitx5-osk-ja#g;
'
PATTERN='fyi\.fortime\.Fcitx5Osk|fcitx5-osk([^-]|-kwin-launcher|-key-helper|$)'

rewrite_file() {   # $1 = ファイル。差分を表示し、--apply なら書き換える
    local f="$1" tmp
    tmp="$(mktemp)"
    perl -pe "$REWRITE" "$f" > "$tmp"
    if cmp -s "$f" "$tmp"; then rm -f "$tmp"; return 1; fi
    echo "  書き換え: $f"
    diff -u "$f" "$tmp" | sed -n '3,$p' | grep '^[-+]' | sed 's/^/      /' || true
    if [ "$APPLY" = 1 ]; then
        backup "$f"
        cat "$tmp" > "$f"     # 権限・持ち主はそのまま
    fi
    rm -f "$tmp"
    return 0
}

scan_and_rewrite() {   # $@ = 探す場所
    local found=0 f
    while IFS= read -r -d '' f; do
        case "$f" in
            *.md|*.png|*.svg|*.jpg|*.mo|*.qm) continue ;;
            "$NEW_LAUNCHER"|*/xyz.enoki.fcitx5.osk*|*/fcitx5-osk-ja/*) continue ;;
        esac
        is_old_file "$f" && continue   # 手順1で消すもの
        if owned_by_package "$f"; then
            warn "  パッケージ管理下なので書き換えません（/etc/xdg 側の設定で上書きします）: $f"
            continue
        fi
        if rewrite_file "$f"; then found=1; CHANGES=$((CHANGES + 1)); fi
    done < <(grep -rlIZE "$PATTERN" "$@" 2>/dev/null || true)
    [ "$found" = 1 ] || ok "  書き換えるものはありません"
}

info "2. 設定ファイルの中の参照（/etc/skel・/etc/xdg・/usr/share/kubuntu-default-settings など）"
dirs=()
for d in "${SCAN_DIRS[@]}"; do [ -e "$d" ] && dirs+=("$d"); done
scan_and_rewrite "${dirs[@]}"
echo

# ---- 3. 設定フォルダの名前（~/.config/fcitx5-osk → fcitx5-osk-ja） --------------
move_config_dir() {   # $1 = .config のパス
    local old="$1/fcitx5-osk" new="$1/fcitx5-osk-ja"
    [ -d "$old" ] || return 1
    if [ -e "$new" ]; then
        warn "  $new が既にあるので、$old はそのまま残します（不要なら手で消してください）"
        return 1
    fi
    echo "  フォルダ名を変更: $old → $new"
    if [ "$APPLY" = 1 ]; then
        backup "$old"
        mv "$old" "$new"
    fi
    return 0
}
info "3. 設定フォルダ（/etc/skel/.config/fcitx5-osk）"
if move_config_dir /etc/skel/.config; then CHANGES=$((CHANGES + 1)); else ok "  変更なし"; fi
echo

# ---- 4. 既定の仮想キーボード -----------------------------------------------------
set_input_method() {   # $1 = kwinrc。[Wayland] InputMethod を新しいランチャーにする
    local f="$1" cur
    cur="$(python3 - "$f" <<'PY'
import sys
group = None
try:
    for line in open(sys.argv[1], encoding="utf-8"):
        s = line.strip()
        if s.startswith("["):
            group = s
        elif group == "[Wayland]" and s.split("=", 1)[0].strip() == "InputMethod":
            print(s.split("=", 1)[1].strip()); break
except FileNotFoundError:
    pass
PY
)"
    if [ "$cur" = "$NEW_LAUNCHER" ]; then
        ok "  $f: 設定済み"
        return 1
    fi
    echo "  $f: InputMethod を ${cur:-（未設定）} → $NEW_LAUNCHER"
    if [ "$APPLY" = 1 ]; then
        backup "$f"
        mkdir -p "$(dirname "$f")"
        python3 - "$f" "$NEW_LAUNCHER" <<'PY'
import os, sys
path, value = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().splitlines() if os.path.exists(path) else []
out, group, done, in_wayland = [], None, False, False
for line in lines:
    s = line.strip()
    if s.startswith("["):
        if in_wayland and not done:
            out.append(f"InputMethod={value}"); done = True
        group = s; in_wayland = (s == "[Wayland]")
        out.append(line); continue
    if in_wayland and s.split("=", 1)[0].strip() == "InputMethod":
        if not done:
            out.append(f"InputMethod={value}"); done = True
        continue
    out.append(line)
if in_wayland and not done:
    out.append(f"InputMethod={value}"); done = True
if not done:
    if out and out[-1].strip():
        out.append("")
    out += ["[Wayland]", f"InputMethod={value}"]
open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
PY
        chmod 644 "$f"
    fi
    return 0
}

info "4. 新規ユーザーの既定の仮想キーボード"
if set_input_method /etc/xdg/kwinrc; then CHANGES=$((CHANGES + 1)); fi
if [ -f /etc/skel/.config/kwinrc ]; then
    if set_input_method /etc/skel/.config/kwinrc; then CHANGES=$((CHANGES + 1)); fi
fi
# /etc/xdg より優先される場所に古い設定が無いか確認
for f in /etc/xdg/xdg-*/kwinrc; do
    [ -f "$f" ] || continue
    if grep -q '^InputMethod=' "$f"; then
        if owned_by_package "$f"; then
            warn "  $f（パッケージ管理下）に InputMethod があり、/etc/xdg/kwinrc より優先されます。内容を確認してください"
        elif set_input_method "$f"; then
            CHANGES=$((CHANGES + 1))
        fi
    fi
done
echo

# ---- 5. 既存ユーザー（--include-home のときだけ） --------------------------------
if [ "$INCLUDE_HOME" = 1 ]; then
    info "5. 既存ユーザーの設定"
    while IFS=: read -r user _ uid _ _ home _; do
        [ "$uid" -ge 1000 ] 2>/dev/null && [ "$uid" -lt 60000 ] || continue
        [ -d "$home/.config" ] || continue
        echo "  [$user]"
        if move_config_dir "$home/.config"; then CHANGES=$((CHANGES + 1)); fi
        if [ -f "$home/.config/kwinrc" ]; then
            if set_input_method "$home/.config/kwinrc"; then CHANGES=$((CHANGES + 1)); fi
            [ "$APPLY" = 1 ] && chown "$user": "$home/.config/kwinrc"
        fi
        hdirs=()
        for d in "$home/.config/autostart" "$home/.local/share/applications" "$home/.config/plasma-org.kde.plasma.desktop-appletsrc"; do
            [ -e "$d" ] && hdirs+=("$d")
        done
        [ ${#hdirs[@]} -gt 0 ] && scan_and_rewrite "${hdirs[@]}"
    done < /etc/passwd
    echo
else
    info "5. 既存ユーザー（--include-home を付けると移行します）"
    while IFS=: read -r user _ uid _ _ home _; do
        [ "$uid" -ge 1000 ] 2>/dev/null && [ "$uid" -lt 60000 ] || continue
        if grep -qs 'fyi.fortime.Fcitx5Osk' "$home/.config/kwinrc" || [ -d "$home/.config/fcitx5-osk" ]; then
            echo "  $user: 古い設定が残っています"
        fi
    done < /etc/passwd
    echo
fi

# ---- 6. 報告だけ（penguins-eggs など） -------------------------------------------
info "6. 自動では書き換えない場所（必要なら手で直してください）"
rep=() out=""
for d in "${REPORT_ONLY_DIRS[@]}"; do [ -e "$d" ] && rep+=("$d"); done
if [ ${#rep[@]} -gt 0 ]; then
    out="$(grep -rnIE "$PATTERN" "${rep[@]}" 2>/dev/null | grep -v 'fcitx5-osk-ja' | head -40 || true)"
fi
if [ -n "$out" ]; then echo "$out" | sed 's/^/  /'; else ok "  見つかりません"; fi
echo

# ---- まとめ ---------------------------------------------------------------------
if [ "$APPLY" = 1 ]; then
    ok "移行が終わりました（変更 $CHANGES 件）。バックアップ: $BACKUP_ROOT"
    echo "  ログインし直すと反映されます。新規ユーザーは最初から Fcitx 5 Osk JA になります。"
else
    if [ "$CHANGES" -gt 0 ]; then
        echo "${c_warn}変更予定: $CHANGES 件。実行するには: sudo $0 --apply$([ "$INCLUDE_HOME" = 1 ] && echo " --include-home")${c_off}"
    else
        ok "変更するものはありません"
    fi
fi
