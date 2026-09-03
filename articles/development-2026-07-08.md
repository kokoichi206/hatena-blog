# 開発環境改善メモ[2026/7-8]

2026 年 7〜8 月に改善した開発環境のメモ。今回は shell と WezTerm まわりが中心です。

## 目次

* [目次](#目次)
* [現在の環境](#現在の環境)
* [改善ポイント](#改善ポイント)
  * [zsh の起動ファイルを役割で分ける](#zsh-の起動ファイルを役割で分ける)
  * [.zshrc を責務別ファイルに分割する](#zshrc-を責務別ファイルに分割する)
  * [WezTerm で pane を分割・close した時にタブ全体を均等化する](#wezterm-で-pane-を分割・close-した時にタブ全体を均等化する)
  * [WezTerm で素のクリックがリンクを開かないようにする](#wezterm-で素のクリックがリンクを開かないようにする)
  * [cd のたびに出る zoxide の警告を消す](#cd-のたびに出る-zoxide-の警告を消す)
  * [リポジトリごとの mise trust をやめる](#リポジトリごとの-mise-trust-をやめる)
  * [貼り付けた snippet のコメント行で止まらないようにする](#貼り付けた-snippet-のコメント行で止まらないようにする)

## 現在の環境

- PC: macOS / m4 Mac mini
- Terminal: WezTerm
- Shell: zsh
- Shell 周辺: sheldon / starship / zsh-abbr / fzf-tab / zoxide
- Editor: VSCode / Windsurf, Zed, Neovim
- 環境管理: nix-darwin, home-manager, mise, Homebrew
- AI 開発支援: Claude Code, Codex

<!-- more -->

## 改善ポイント

### zsh の起動ファイルを役割で分ける

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/0c081dcd7d6230f4589256252b9d3ab0b2284535)

**元々の課題**

環境変数から PATH まで、すべて `.zshrc` に入れていました。

`.zshrc` は対話シェルを起動するたびに読まれます。そのため、ログイン時に一度で足りる `brew shellenv` や `path=(...)` の組み立てまで毎回走っていました。

さらに PATH を追記し続けた結果、同じディレクトリが何度も並んでいる状態でした。

**対応内容**

zsh が読む 3 つのファイルに、役割で分けました。

- `.zshenv`: 全ての zsh から参照する、実行を伴わない環境変数だけ
- `.zprofile`: ログイン時に一度だけでいい PATH とツール環境の初期化
- `.zshrc`: 対話シェルの設定

`.zshenv` は「実行を伴わない」ものだけに絞ります。

```sh
# 全ての zsh から参照する、実行を伴わない環境変数だけを定義する。
export XDG_CONFIG_HOME="$HOME/.config"
export EDITOR="nvim"
export LANG="en_US.UTF-8"
```

PATH の重複は `typeset -U` で解決しました。`-U` は配列の要素を unique にするので、以降どこかで同じ path を足しても勝手に一意になります。

```sh
# ログイン時に一度だけ必要なPATHとツール環境を初期化する。
typeset -U path PATH

eval "$(/opt/homebrew/bin/brew shellenv)"

path=(
  "$HOME/.local/bin"
  "$HOME/.local/share/mise/shims"
  "$HOME/go/bin"
  "/opt/homebrew/opt/openssl@3/bin"
  $path
)
export PATH
```

zsh には `path` という配列と `PATH` という文字列があり、片方を書き換えるともう片方へ反映されます。

配列として `path=(...)` で書けるので、`PATH="$HOME/.local/bin:$PATH"` を延々と重ねるより見通しが良くなりました。

`-U` の効き方は手元で確認できます。

```sh
$ zsh -f -c 'typeset -U path PATH; path=(/a /b /a /c $path); print -l $path | head -3'
/a
/b
/c
```

`/a` を 2 回書いても 1 つに畳まれています。

### .zshrc を責務別ファイルに分割する

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/2562765f68bece9e6a4c81260dfe2e2472fb8f81)

**元々の課題**

前項の整理をしてもなお `.zshrc` は 371 行ありました。alias、history 設定、自作関数が一続きに並んでいる状態です。

何かを直したい時は、そのブロックを探すところから始まります。

**対応内容**

`$XDG_CONFIG_HOME/zsh/` 配下に責務ごとのファイルを置き、`.zshrc` からは source するだけにしました。

```sh
source "$XDG_CONFIG_HOME/zsh/aliases.zsh"
source "$XDG_CONFIG_HOME/zsh/history.zsh"
source "$XDG_CONFIG_HOME/zsh/functions.zsh"
source "$XDG_CONFIG_HOME/zsh/claude-functions.zsh"
source "$XDG_CONFIG_HOME/zsh/codex-functions.zsh"

# precmd/chpwd hookとpromptの初期化は、他の定義を読み込んだ後に行う。
source "$XDG_CONFIG_HOME/zsh/integrations.zsh"
```

順序に意味があるのは `integrations.zsh` だけです。ここには zoxide と starship の初期化を置いていて、これらは `precmd` / `chpwd` hook を登録するので、他の定義を読み終えた後に呼ぶ必要があります。

逆に言うと、それ以外は順不同です。迷わず足せます。

**良くなったこと**

`.zshrc` は 438 行から 40 行になりました。

```sh
$ wc -l .zshrc .zshenv .zprofile .config/zsh/*.zsh
      50 .zshrc
      26 .zshenv
      12 .zprofile
      55 .config/zsh/aliases.zsh
      98 .config/zsh/claude-functions.zsh
      98 .config/zsh/codex-functions.zsh
      39 .config/zsh/functions.zsh
      34 .config/zsh/history.zsh
      55 .config/zsh/integrations.zsh
```

### WezTerm で pane を分割・close した時にタブ全体を均等化する

[対応コミット（分割時）](https://github.com/kokoichi206/dotfiles/commit/668ab6c7b7b981f0367fcadd22c14518e5fc0c37) / [対応コミット（close 時）](https://github.com/kokoichi206/dotfiles/commit/7cc545ef145b59734a314d1a6c644b118a6e292e)

**元々の課題**

WezTerm の pane 分割は、常に「アクティブな pane を半分に割る」挙動です。3 分割すると 50% / 25% / 25% になり、4 つ目を足すとさらに偏ります。

結果、分割するたびに手で `AdjustPaneSize` を叩いて幅を揃えていました。

**対応内容**

pane を分割したら、そのタブの全 pane が等幅・等高になるよう自動で調整するようにしました。

実装で厄介だったのは、WezTerm の Lua API が split tree の構造を公開していない点です。

取れるのは `panes_with_info()` による各 pane の座標とサイズだけ。そこから split tree を再構築しています。

さらに `AdjustPaneSize` は「内部 tree で最も近い祖先の split」を対象にします。ところが同じ見た目のレイアウトを作る binary tree は複数あり得るので、再構築した tree と内部 tree が一致する保証はありません。

そこで +1 の調整を試しに入れ、意図した境界の両側の pane が動いたかを確認してから本調整をかけています。

close 側はもう少し単純ですが、こちらにも制約がありました。WezTerm には `pane-closed` イベントが存在しないのです。

代わりに `CloseCurrentPane` を実行した後、pane 数が減ったことをポーリングで検知してから均等化しています。確認ダイアログをキャンセルした場合は pane 数が減らないため、タイムアウトして何もしません。

```lua
-- Paneを閉じる leader + x（close 後にタブ全体を均等化）
{ key = "x", mods = "LEADER", action = equalize.close_and_equalize() },
```

### WezTerm で素のクリックがリンクを開かないようにする

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/8a864f7140f115fecb09112bd8ba66cfc7928766)

**元々の課題**

ターミナルに出力されたファイルパスや URL をダブルクリックでコピーしようとすると、クリックが hyperlink として解釈され、ブラウザや Finder が開いてしまっていました。

コピーしたいだけなのに毎回何かが起動する。地味ですが、それなりのストレスでした。

**対応内容**

`mouse_bindings` で「素のクリックは選択のみ」「リンクを開くのは CMD+クリック」に分離しました。

```lua
config.mouse_bindings = {
	-- 素の左クリック/ドラッグ選択はリンク上でも開かず、選択をクリップボードへコピーする。
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = act.CompleteSelection("ClipboardAndPrimarySelection"),
	},
	-- ダブルクリックの単語選択もクリップボードへコピーする。
	{
		event = { Up = { streak = 2, button = "Left" } },
		mods = "NONE",
		action = act.CompleteSelection("ClipboardAndPrimarySelection"),
	},
	-- CMD+左クリックでカーソル位置のリンクを開く（従来の挙動）。
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "CMD",
		action = act.OpenLinkAtMouseCursor,
	},
	-- CMD+クリックの Down を無効化し、開くときに選択が始まる誤動作を防ぐ。
	{
		event = { Down = { streak = 1, button = "Left" } },
		mods = "CMD",
		-- これが無いと CMD+クリックで開く際に Down 側で選択が始まってしまい、
		-- リンクを開きつつ範囲選択が残るという中途半端な状態になります。
		action = act.Nop,
	},
}
```

### cd のたびに出る zoxide の警告を消す

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/1801a3158545cf9a7366c850c9f0cf66eac6033b)

**元々の課題**

Claude Code の中で `cd` するたびに、zoxide のセットアップが壊れているという警告が出ていました。手元の対話シェルでは出ません。

原因の説明に前提が 2 つ要るので、先にそれぞれ触れておきます。

**chpwd hook とは**

zsh には、特定のタイミングで自動実行される関数を登録する仕組みがあります。`chpwd` はそのうち「カレントディレクトリが変わった時」に発火するものです。

登録には `add-zsh-hook` を使います。

```sh
$ zsh -f -c 'autoload -Uz add-zsh-hook
  _demo() { echo "[chpwd fired] $PWD" }
  add-zsh-hook chpwd _demo
  cd /tmp; cd /usr'
[chpwd fired] /tmp
[chpwd fired] /usr
```

zoxide はこれを使って「今どのディレクトリにいたか」を記録しています。  
`cd` するたびに hook が発火し、その履歴が後の補完に使われる、という仕組みです。

登録の実体は `chpwd_functions` という配列で、ここに関数名が入っているかどうかが「登録済みか」の判定になります。

**スナップショットの再生とは**

Claude Code は Bash ツールを実行する際、毎回 `.zshrc` を読み直しません。  
あらかじめシェルの状態をダンプしておいたファイルを読み込んで起動します。

実体は `~/.claude/shell-snapshots/` に溜まっていく、ただのシェルスクリプトです。

```sh
$ SNAP=$(ls -t ~/.claude/shell-snapshots/*.sh | head -1)
$ grep -oE '^[a-z-]+ ' "$SNAP" | sort | uniq -c | sort -rn | head -4
   4 unalias
   3 function
   2 setopt
   2 alias
```

alias、関数定義、setopt など、いずれも `alias` や `typeset -f` でテキストとしてダンプできるものです。  
一方で、配列の中身は復元されません。

**何が起きていたか**

この 2 つが噛み合って誤検知が起きていました。スナップショットには `__zoxide_hook` の関数定義は入っているのに、それを `chpwd_functions` へ登録する行が無いのです。

```sh
$ grep -cE 'chpwd_functions=|add-zsh-hook chpwd' "$SNAP"
0
```

zoxide の doctor は、まさにこの配列を見て初期化の成否を判定しています。

```sh
__zoxide_doctor () {
	[[ ${_ZO_DOCTOR:-1} -ne 0 ]] || return 0
	[[ ${chpwd_functions[(Ie)__zoxide_hook]:-} -eq 0 ]] || return 0
	# ここから警告メッセージ
```

関数はある、配列への登録は無い。よって「初期化されていない」と判定され、`cd` のたびに警告が出ていた、というわけです。

**対応内容**

doctor を無効化しました。

```sh
# Claude Code 等のスナップショット再生シェルでは chpwd hook が復元されず
# zoxide doctor が誤検知して cd のたびに警告を出すため、doctor を無効化する
export _ZO_DOCTOR=0
eval "$(zoxide init zsh --cmd cd)"
```

診断を切っているので、本当に初期化が壊れた時も黙ります。

ただ初期化が壊れれば `cd` の補完が効かなくなるため、すぐ気付くはずです。毎回出る誤検知の方がコストは高いと判断しました。

### リポジトリごとの mise trust をやめる

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/1801a3158545cf9a7366c850c9f0cf66eac6033b)

**元々の課題**

mise は `mise.toml` を含むディレクトリへ入るたびに `mise trust` を要求します。任意のコードを実行しうる設定ファイルなので、当然の挙動ではあります。

ただ `ghq` 配下には自分のリポジトリと業務リポジトリしか置いていません。

**対応内容**

`~/ghq` 以下をまとめて信頼するようにしました。

```toml
# ghq 配下は自リポジトリ・業務リポジトリのみを置く運用のため一括で信頼し、
# リポジトリごとの `mise trust` 手動実行を不要にする
[settings]
trusted_config_paths = ["~/ghq"]
```

前提として「`ghq` 配下には素性の分かるリポジトリしか置かない」という運用が要ります。試しに他人のリポジトリを clone する時は `ghq` の外に置く、という使い分けにしました。

### 貼り付けた snippet のコメント行で止まらないようにする

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/a02a9606046dce0fb9c1a3ad09f42e7590d09bdf)

**元々の課題**

ドキュメントやチャットからコマンドを貼り付ける時、`# コメント` 付きの snippet がそのまま通りませんでした。

zsh は対話シェルだと、デフォルトで `#` をコメント扱いしません。  
ただの引数として渡します。

```sh
# 対話シェルでの挙動（INTERACTIVE_COMMENTS なし）
$ echo one # c1
one # c1

$ ls *.txt # glob comment
ls: #: No such file or directory
ls: glob: No such file or directory
ls: comment: No such file or directory
```

`echo` なら余計な文字列が出るだけですが、`ls` のように引数を解釈するコマンドでは `#` 以降が全部ファイル名として扱われます。

**対応内容**

`INTERACTIVE_COMMENTS` を有効にしました。

```sh
# 貼り付けた shell snippet のコメント行を対話シェルでも無視する
setopt INTERACTIVE_COMMENTS
```

1 行で済む上に、貼り付け前にコメントを消す手間がなくなります。  
bash はデフォルトで有効なので、bash から来ると気付きにくい差分でした。
