# 久々に Python を触ったら型周りが進化してた

すごい久々にちゃんと Python の知識を update しようとしてるのですが、見える世界が全く変わっていたのでその感動をメモしておきます。  
（当時から自分の知識が増えたことも大きいです。）

以下 mypy などの型チェッカーと使うことを前提にしています。

``` sh
> python --version
Python 3.13.1
```

**[目次]**

* typing.NamedTuple
  * typing.TypedDict との違い
* Literal の Union
* typing.Protocol
* typing.ReadOnly
* おわりに

<!-- more -->

## typing.NamedTuple
<!-- ## [typing.NamedTuple](https://docs.python.org/ja/3.13/library/typing.html#typing.NamedTuple) -->

typing.NamedTuple は Python v3.6 で追加されており、名前付きのタプルを生成できます。

型ヒントにより VSCode 等で補完が効くところが collections.namedtuple との違いです。

``` python
from typing import NamedTuple

class CompanyInfo(NamedTuple):
    name: str
    # default 値をとれる。
    phone: str | None = None

# c = CompanyInfo("sample", "123-4567") とするより好き。
c = CompanyInfo(name="sample", phone="123-4567")
print('c.name: ', c.name)

# tuple ぽさも当然あるが、意図しない挙動につながるため個人的には使いたくない。
# index access.
print('c[0]: ', c[0])
# unpacking.
name, phone = c
print('name: ', name)
# init with tuple.
c2 = CompanyInfo(*c)
print('c2: ', c2)
```

**結局は Tuple** であるため、インデックスアクセス・アンパッキングができることには注意が必要です。

### [typing.TypedDict](https://docs.python.org/ja/3.13/library/typing.html#typing.TypedDict) との違い

TypedDict は辞書由来の型ヒントを提供する NamedTuple のようなもので、その違いは辞書とタプルの違いがそのまま反映されてます。

フィールドへのアクセス方法の違い、ミュータブル性の違いなどがあります。

``` python
from typing import TypedDict

class CompanyInfoTypedDict(TypedDict):
    name: str
    # default 値をとれる。
    phone: str | None = None

typed_data = CompanyInfoTypedDict(name="Alice", phone="123-4567")
# TypedDict は辞書なので基本的には mutable.
typed_data['name'] = "Bob"
# typed_data:  {'name': 'Bob', 'phone': '123-4567'}
print('typed_data: ', typed_data)
```

特に希望がない場合は immutable な NamedTuple を使えば良さそうです。

## Literal の Union

TypeScript を使った時に Literal の Union に非常に感動したのですが、Python でも 3.8 から [typing.Literal](https://docs.python.org/ja/3.13/library/typing.html#typing.Literal) が使えるようになりました。

``` python
from typing import Literal

# 配列で渡すと Union になる。
type JobStatus = Literal["running", "stopped", "pending"]

class Job:
    def __init__(self):
        self.status = "running"
```

以下のように typo してしまった場合、mypy が教えてくれます。

``` python
...
class Job:
    def __init__(self) -> None:
        # running とすべきところを runningw としてしまった。
        self.status: JobStatus = "runningw"

job = Job()
print(job.status)
```

``` sh
$ uv run mypy typecheck.py
typecheck.py:8: error: Incompatible types in assignment (expression has type "Literal['runningw']", variable has type "Literal['running', 'stopped', 'pending']")  [assignment]
```

また Union と明示したり TypeScript のように `|` でも記述可能です。

``` python
# 同じ意味。
JobStatus = (
    Literal["running"]
    | Literal["stopped"]
    | Literal["pending"]
)
JobStatus = Union[
    Literal["running"],
    Literal["stopped"],
    Literal["pending"],
]
```

## [typing.Protocol](https://docs.python.org/ja/3.13/library/typing.html#typing.Protocol)

振る舞いを元にインターフェースを定義するためのもので、Python 3.8 で追加されています。

``` python
from typing import Protocol

class Animal(Protocol):
    def speak(self) -> None:
        pass

class Dog:
    def speak(self) -> None:
        print("Woof!")

def speak(animal: Animal) -> None:
    animal.speak()

dog = Dog()
speak(dog)
```

Protocol で定義したメソッドを満たさない場合は、mypy が教えてくれます。

``` python
class Foo:
    def bar(self) -> None:
        print("Bar!")

f = Foo()
speak(f)
```

``` sh
$ uv run mypy .
proto.py:22: error: Argument 1 to "speak" has incompatible type "Foo"; expected "Animal"  [arg-type]
```

## [typing.ReadOnly](https://docs.python.org/ja/3.13/library/typing.html#typing.ReadOnly)

読み取り専用の型ヒントを提供するもので、Python **3.13** で追加されてます。

先述の TypedDict と組み合わせることで、一部のフィールドのみ可変にできます。

``` python
from typing import ReadOnly, TypedDict

class CompanyInfoTypedDict(TypedDict):
    name: ReadOnly[str]
    # 特定の値のみ可変にする。
    phone: ReadOnly[str | None] = None
```

## おわりに

結局 typing モジュールの中で自分が興味を持ったものの紹介になってしまいました。

[typing](https://docs.python.org/ja/3.13/library/typing.html) はマイバージョン進化してそうなので、一通り眺めてみるのも良さそうです！
