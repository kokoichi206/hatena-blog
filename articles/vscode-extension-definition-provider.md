# コードジャンプする VSCode 拡張の作り方

今回初めて VSCode の拡張機能を作ってみたのですが、予想より簡単で面白かったためその紹介です。

**目次**

```
* [環境](#環境)
* [今回作ったもの](#今回作ったもの)
  * [背景](#背景)
  * [ざっくり方針](#ざっくり方針)
  * [1. 拡張機能開発ハロワ](#1.-拡張機能開発ハロワ)
  * [2. ワークスペース内のファイル一覧を取得し、タグ名とマッチするファイルの URI を検索](#2.-ワークスペース内のファイル一覧を取得し、タグ名とマッチするファイルの-uri-を検索)
  * [3. コードジャンプ時のイベントを登録](#3.-コードジャンプ時のイベントを登録)
  * [4. 拡張機能を有効にするスコープの設定](#4.-拡張機能を有効にするスコープの設定)
  * [5. 他の人と共有する方法](#5.-他の人と共有する方法)
* [Links](#links)
* [おわりに](#おわりに)
```

## 環境

```json
{
    "devDependencies": {
        "@types/mocha": "^10.0.1",
        "@types/node": "16.x",
        "@types/vscode": "^1.82.0",
        "@typescript-eslint/eslint-plugin": "^6.4.1",
        "@typescript-eslint/parser": "^6.4.1",
        "@vscode/test-electron": "^2.3.4",
        "eslint": "^8.47.0",
        "glob": "^10.3.3",
        "mocha": "^10.2.0",
        "ts-loader": "^9.4.4",
        "typescript": "^5.1.6",
        "webpack": "^5.88.2",
        "webpack-cli": "^5.1.4"
    },
    "engines": {
        "vscode": "^1.82.0"
    }
}
```

## 今回作ったもの

ある規則（フォルダ構成に沿ったもの）に従って命名されたコンポーネントに対し、オリジナルなコードジャンプが可能な VSCode の拡張を作りました。

### 背景

components に分かれたフロントエンドのデザインを考えます。
また各々のコンポーネントが、何かしらの手段で Vue などの global components として、**ディレクトリ構造に沿ったコンポーネント名**で登録されてるとします。

例えば `src` 配下のディレクトリが

``` sh
.
├── components
│   └── ecosystems
│       └── UsersWidget
│          └── index.vue
│   ├── atomics
│   │   └── ...
│   ├── ...
└── assets
    ├── ...
```

のようになっている時、`index.vue` が `ecosystems-user-widget` というコンポーネント名で登録されてるとします。

この時、利用する側のテンプレート内では `<ecosystems-user-widget />` のように呼び出すことになるのですが、自分の所属する一部プロジェクトではこちらのカスタムタグへのコードジャンプができない状況でした。

### ざっくり方針

1. （VSCode の拡張を作ることが初めてだったので）ハロワ
2. ワークスペース内のファイル一覧を取得し、タグ名とマッチするファイルの URI を検索
3. コードジャンプ時のイベントを登録
4. 拡張機能を有効にするスコープの設定
5. 他の人と共有できるよう .vsix ファイルにビルド

各について軽く説明してみます。

### 1. 拡張機能開発ハロワ

公式の [Your First Extension](https://code.visualstudio.com/api/get-started/your-first-extension)（タイトルがいい！）に沿って進めます。

- 必要なコマンド(yo) のインストール
- デバッグ方法の習得

自分はこの時 command を実行しても何も起きなかったのですが、どうやら **VSCode を最新バージョンにアップデート**する必要があるみたいです。
（参考: [VSCode拡張開発時、HelloWorldの実行ができない問題の解決方法](https://zenn.dev/b7472/articles/dbe2fba3125b1c)）

自分は typescript のプロジェクトを webpack ありで初めてみました。

### 2. ワークスペース内のファイル一覧を取得し、タグ名とマッチするファイルの URI を検索

workspace 内のファイルを検索するのに [findFiles](https://code.visualstudio.com/api/references/vscode-api#:~:text=%29%3A%20FileSystemWatcher-,findFiles,-%28include%3A) を使いました。

第二引数には検索対象から除外する [GlobPattern](https://code.visualstudio.com/api/references/vscode-api#GlobPattern) も指定できるので、node modules は除外しておきました。

``` ts
const files = await vscode.workspace.findFiles(
  `**/*.vue`,
  "**/node_modules/**"
);
```

### 3. コードジャンプ時のイベントを登録

[DefinitionProvider](https://code.visualstudio.com/api/references/vscode-api?source=post_page-----94656da18431----------------------#:~:text=DefinitionLink%3A%20LocationLink-,DefinitionProvider,-The%20definition%20provider) のインタフェースを使います。

Provider を実装したクラスを作成し [registerDefinitionProvider](https://code.visualstudio.com/api/references/vscode-api?source=post_page-----94656da18431----------------------#:~:text=registerDefinitionProvider) で登録してあげる形です。
（コードジャンプに DefinitionProvider を使うのが肝です。）

`CustomCodeJumpProvider.ts`

``` ts
import * as vscode from "vscode";

export class CustomCodeJumpProvider implements vscode.DefinitionProvider {
  provideDefinition(
    document: vscode.TextDocument,
    position: vscode.Position,
    token: vscode.CancellationToken
  ): vscode.ProviderResult<vscode.Definition | vscode.LocationLink[]> {
    const targetText = document.getText();
    const editor = vscode.window.activeTextEditor;

    const selection = document.getWordRangeAtPosition(
      editor?.selection.active ?? new vscode.Position(0, 0)
    );
    const selectedText = document.getText(selection);

    return new Promise((resolve, reject) => {
      this.searchFile(selectedText)
        .then((uri) => {
          if (uri) {
            resolve(new vscode.Location(uri, new vscode.Position(0, 0)));
          } else {
            resolve(null);
          }
        })
        .catch((err) => {
          reject(err);
        });
    });
  }

  private async searchFile(
    selectedText: string
  ): Promise<vscode.Uri | undefined> {
    const parts = selectedText.split("-");

    const capitalize = (str: string) =>
      str.charAt(0).toUpperCase() + str.slice(1);
    const componentName = parts[0];
    const folderName = parts.slice(1).map(capitalize).join("");

    const files = await vscode.workspace.findFiles(
      `**/*.vue`,
      "**/node_modules/**"
    );
    for (const v of files) {
      const path = v.path;
      if (path.includes(componentName) && path.includes(folderName)) {
        return v;
      }
    }

    return;
  }
}
```

`extension.ts`

``` ts
import * as vscode from "vscode";
import { CustomCodeJumpProvider } from "./CustomCodeJumpProvider";

export function activate(context: vscode.ExtensionContext) {
  // DefinitionProvider を実装したクラスを registerDefinitionProvider する。
  context.subscriptions.push(
    vscode.languages.registerDefinitionProvider(
      { scheme: "file", language: "vue" },
      new CustomCodeJumpProvider()
    )
  );
  context.subscriptions.push(disposable);
}
export function deactivate() {}
```

[Language Features Listing](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#language-features-listing) とかに他にも面白そうな API があるので、眺める会でもやりたいですね！

### 4. 拡張機能を有効にするスコープの設定

ハローわールードでは拡張機能を start (activate) させることで使っていましたが、実用では多少不便です。

実は以下のように、[Activation Events](https://code.visualstudio.com/api/references/activation-events) を package.json に記載することで設定できます。

``` json
{
  ...
  "activationEvents": [
    "onLanguage:typescript",
    "onLanguage:vue"
  ],
  ...
}
```

プログラミング言語の識別子については[こちら](https://code.visualstudio.com/docs/languages/identifiers)にまとまってます。

### 5. 他の人と共有する方法

ここまでで機能としては完成したので、あとはどのように VSCode を共有するかです。

公式の [Publishing Extensions](https://code.visualstudio.com/api/working-with-extensions/publishing-extension) のページを見ながら進めていきます。

Marketplace（VSCode のサイドバーからインストールできるやつ）に出すのが一番多くの人に使ってもらえるのですが、まだ上げたくない人や private に共有したい人は [Packaging extensions](https://code.visualstudio.com/api/working-with-extensions/publishing-extension#packaging-extensions) なる方法が使えます。

とはいっても、vsix 形式でビルド・何かしらの方法で共有するのみです。

**vsix 形式でビルド**

``` sh
# この時 README がデフォルトのままだとビルドできないので注意
# （一旦）基本 y
npx vsce package
```

**Install**

1. Download the `.vsix` file.
2. Command + P > Extension: Install From VSIX

## Links

- [Your First Extension](https://code.visualstudio.com/api/get-started/your-first-extension)
- [VSCode拡張開発時、HelloWorldの実行ができない問題の解決方法](https://zenn.dev/b7472/articles/dbe2fba3125b1c)
- [Language Features Listing](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#language-features-listing) 
- [VS Code API](https://code.visualstudio.com/api/references/vscode-api)
- [Activation Events](https://code.visualstudio.com/api/references/activation-events)
- [Publishing Extensions](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)

## おわりに

初めて VSCode の拡張機能を作ってみたんですが、想像よりも簡単にできて面白かったです。

yo code と打つと色々と選択肢が出てくるので、他のものもぜひ触ってみたいと思います！
