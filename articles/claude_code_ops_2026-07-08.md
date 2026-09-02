# Claude Code 運用改善メモ[2026/7-8]

2026 年 7〜8 月に手を入れた Claude Code まわりの設定と hook のメモ。同時期の shell / WezTerm 側は「開発環境改善メモ[2026/7-8]」に分けて書いています。

<!-- more -->

## 目次

* [目次](#目次)
* [現在の環境](#現在の環境)
* [改善ポイント](#改善ポイント)
  * [path-scoped rules が Write の新規作成で効かない穴を hook で塞ぐ](#path-scoped-rules-が-write-の新規作成で効かない穴を-hook-で塞ぐ)
  * [settings.json の hook 配線を lint で守る](#settingsjson-の-hook-配線を-lint-で守る)
  * [sandbox の excludedCommands を引数付きにも効かせる](#sandbox-の-excludedcommands-を引数付きにも効かせる)

## 現在の環境

- PC: macOS / m4 Mac mini
- AI 開発支援: Claude Code, Codex
- 設定管理: dotfiles リポジトリの `dot_claude/` を `~/.claude/` へ symlink / 反映

## 改善ポイント

### path-scoped rules が Write の新規作成で効かない穴を hook で塞ぐ

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/d080144904fb9830d2e17f7df5fd16e82557b0b6)

**元々の課題**

Claude Code には path-scoped rules という仕組みがあります。`.claude/rules/` へ置いた md の frontmatter で `paths` を指定すると、該当するファイルを触る時だけそのルールが注入されます。「GitHub Actions の workflow を書く時はこう」といった限定的なルールを、常時 CLAUDE.md へ置かずに済む機能です。

ただしこのルールは **Read した時** に注入されます。Write で新規ファイルを作る場合は事前の Read が無いので、ルールが注入されません。新規作成こそ規約を守ってほしい場面なのに、そこだけ抜けている状態でした。

Edit / MultiEdit は事前 Read が必須なので標準機構でカバーされています。穴は Write による新規作成だけです。

関連 issue は 2 つ見つけましたが、どちらも NOT_PLANNED でクローズされていました。

**対応内容**

`PreToolUse(Write)` hook を書いて、その穴だけを埋めました。

```json
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "command -v python3 >/dev/null 2>&1 && python3 \"$HOME/.claude/hooks/inject-rules-on-write.py\" || true",
      "timeout": 5
    }
  ]
}
```

hook 側は、対象ファイルが **まだ存在しない時だけ** 注入します。既存ファイルへの Write は Read 済みのはずで標準機構がカバーしているので、二重注入を避けるためです。

設計で意識したのは、標準機構を置き換えないことでした。`.claude/rules/` の場所と名前はそのままなので、Anthropic が Write に対応したら settings.json から hook を外すだけで標準の挙動へ戻ります。

塞ぎきれていない穴も、あえて残しました。

- `/compact` で初回 Read の注入が落ちた後、再 Read せずに Edit するケース
- Bash でのファイル作成（Write ツールを通らないので hook で捕まえられない）

Edit や Read まで hook 対象を広げれば前者は減りますが、二重注入が増えるだけで割に合わないと判断しています。

`paths` の glob は挙動が直感と違うことがあるので、テストで固定しました。`*` は 1 セグメントのみ（`*/go.mod` は `a/go.mod` にマッチするが `a/b/go.mod` にはしない）、`**` は任意階層、という違いです。

### settings.json の hook 配線を lint で守る

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/83226bc0a73238292d365449332f0cbbf805ccfd)

**元々の課題**

`~/.claude/settings.json` は Claude Code 本体からも書き換わるので、dotfiles リポジトリ側と双方向に同期する運用をしています。live 側の変更を取り込む `make claude-pull` は、live の内容で repo を丸ごと上書きします。

ここに罠がありました。repo 側で hook を書いたまま live へ反映し忘れている状態で `claude-pull` すると、**repo からもその配線が消えます**。しかも消えるのは JSON の一部なので、`git diff` を流し読みすると見落とします。実際、一度 hook が黙って消えており、動いていないとしばらく気付けませんでした。

**対応内容**

hook の配線を検査するシェルスクリプトを書き、`claude-pull` / `claude-apply` の両方に組み込みました。

検査は 2 方向です。

1. `dot_claude/hooks/` にある hook の実体が、すべて settings.json から参照されているか
2. settings.json が参照している hook が、repo に実在するか

```sh
# 1. hooks 実体がすべて settings.json から参照されていること
for path in "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/*.py; do
  [ -e "$path" ] || continue
  f="$(basename "$path")"
  case " $UNWIRED " in *" $f "*) continue ;; esac
  case "$f" in test-*) continue ;; esac
  if ! grep -q "hooks/$f" "$SETTINGS"; then
    echo "ERROR: $HOOKS_DIR/$f is not wired in $SETTINGS" >&2
    fail=1
  fi
done
```

意図的に配線していない hook は `UNWIRED` に列挙してあります。「今は使っていないが消したくない」ものを、検査を黙らせるためだけに消さなくて済みます。

大事なのは、これを `claude-pull` の中に入れた点です。

```makefile
claude-pull:	## ~/.claude/settings.json の変更を repo に取り込む (要 git diff レビュー)
	jq -S . "$(LIVE_CLAUDE_SETTINGS)" | ./claude-normalize-home.sh | jq -S . > "$(DOT_CLAUDE_SETTINGS)"
	@./claude-lint-settings.sh || { echo "hook wiring was dropped by pull. restore it in $(DOT_CLAUDE_SETTINGS) before committing."; exit 1; }
```

配線が落ちうる操作そのものに検査を貼っているので、`make claude-lint` を別途思い出す必要がありません。落ちた時のメッセージに復旧手順も書いてあります。

```sh
$ make claude-lint
OK: hook wiring is consistent
```

### sandbox の excludedCommands を引数付きにも効かせる

[対応コミット](https://github.com/kokoichi206/dotfiles/commit/1569347bf5cc448c202180f82926b1e2018f3b8b)

**元々の課題**

Claude Code の Bash sandbox には、sandbox の外で実行するコマンドを列挙する `excludedCommands` があります。ここに `git` や `docker` を書いていました。

しかし実際に使うのは `git push origin main` のように引数付きです。コマンド名だけの登録では引数付きにマッチせず、期待通りに除外されていませんでした。

**対応内容**

各コマンドについて、素の名前と `コマンド *` の 2 つを列挙しました。合わせて、モバイル検証で使う `adb` と `sim-use` も追加しています。

```json
"excludedCommands": [
  "adb",
  "adb *",
  "docker",
  "docker *",
  "git",
  "git *",
  "ssh",
  "ssh *"
]
```

冗長ではありますが、パターンの意味が明示されるので、後から見て「なぜ 2 行あるのか」が分かる形にしました。

## おわりに

7〜8 月は、設定ファイルに書いただけでは守られないものを、hook と lint で機械的に検査できる形へ移す作業が中心でした。

ルールを文章で書いておくだけだと、守られたかどうかは後からしか分かりません。hook なら実行前に止まりますし、lint なら commit 前に落ちます。特に settings.json の配線のように「壊れても静かなもの」は、検査を足しておく価値が大きいと感じました。

一方で、path-scoped rules の穴埋め hook のように、本家の仕様が変われば不要になるものもあります。そういう回避策は、外すのが簡単な形で書いておくのが大事でした。
