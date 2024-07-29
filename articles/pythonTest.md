# python で初めての Unit Test
突然ですが皆さん、テスト書いてますか？

個人開発だとあんまり積極的に書かないかもしれませんが、ある程度からは必須のスキルだと思っています。

かく言う自分もまともに書いたことありませんが、今日から意識して書いていこうと思います！


## UnitTest

単体テストと呼ばれることもあり、小さな機能を１つの単位（ユニット）としてその動きが正しいかをテストするものである。

通常は関数やメソッドが対象となり、また関数やメソッドもテストがしやすいように１つの機能に抑えておくべきである。


## 円の面積を求めるプログラム

### 単純に実装してみる

circles.py

```python
from math import pi

def circle_area(r):

    return pi*(r**2)

```

### この関数に対するテストを実装する

テスト関数を書くファイルの名前は、`<filename>_test.py`のようにする

circles_test.py

```python
import unittest
from circles import circle_area
from math import pi

class TestCircleArea(unittest.TestCase):
    def test_area(self):
        # Test areas when radius >=0
        self.assertAlmostEqual(circle_area(1), pi)
        self.assertAlmostEqual(circle_area(0), 0)
        self.assertAlmostEqual(circle_area(2.1), pi * 2.1**2)
```

上のように`unittest.TestCase`を継承したクラスを定義する。クラス名は`Test`から始める必要がある。

テストを実行させる

```sh
$ python -m unittest circles_test.py
...
----------------------------------------------------------------------
Ran 3 tests in 0.000s

OK
```

### これで十分か？

テストを書いていると、「あれ、負の数はどうだろう、とか実数以外の時はどうだろう」という視点が持ててくる....

関数を呼ぶときに引数を毎回0以上の実数かチェックしても良いが、他の人に使ってもらうには引数に何が来ても関数内で対応できるようにしておきたい。

そこで、何が必要かをテスト関数から変更してみる。


### テスト関数の変更 

以下では負の数に対しては ValueError, 実数以外に関しては TypeError をあげるようにしている。

circles_test.py

```python
import unittest
from circles import circle_area
from math import pi

class TestCircleArea(unittest.TestCase):
    def test_area(self):
        # Test areas when radius >=0
        self.assertAlmostEqual(circle_area(1), pi)
        self.assertAlmostEqual(circle_area(0), 0)
        self.assertAlmostEqual(circle_area(2.1), pi * 2.1**2)
    
    def test_values(self):
        # Make sure value errors are raised when necessary
        self.assertRaises(ValueError, circle_area, -2)

    def test_types(self):
        self.assertRaises(TypeError, circle_area, 3+5j)
        self.assertRaises(TypeError, circle_area, True)
        self.assertRaises(TypeError, circle_area, "radius")
```

当然メイン関数を変更してないので、このテストは失敗する（テストは失敗させてなんぼ！）

```sh
$ python -m unittest circles_test.py
.FF
======================================================================
FAIL: test_types (circles_test.TestCircleArea)
----------------------------------------------------------------------
Traceback (most recent call last):
...
AssertionError: TypeError not raised by circle_area

======================================================================
FAIL: test_values (circles_test.TestCircleArea)
----------------------------------------------------------------------
Traceback (most recent call last):
...
----------------------------------------------------------------------
Ran 3 tests in 0.016s

FAILED (failures=2)
```

### メイン関数の実装の変更

必要な例外を全てあげたら、あとは丁寧に実装する。

circles.py

```python
from math import pi

def circle_area(r):
    if type(r) not in [int, float]:
        raise TypeError("The radius must be a non-negative real number")
    
    if r < 0:
        raise ValueError("The radius cannot be negative.")
    return pi*(r**2)
```

これで関数を実行させると、無事テストが全て通る。

```sh
python -m unittest circles_test.py
...
----------------------------------------------------------------------
Ran 3 tests in 0.000s

OK
```

## おわりに
この記事では、pythonにおける Unit Test の実行方法を実例を使って紹介しました。

これからは自分も意識してテストを書いていきたいと思います！
