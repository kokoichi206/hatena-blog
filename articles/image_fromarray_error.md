# Image.fromarray で KeyError: ((1, 1, 3), '<f8')

PIL の `Image.fromarray` を使って ndarray から PIL オブジェクトを生成しようとした際、KeyError: ((1, 1, 3), '<f8') というエラーに遭遇しました。

## エラー詳細

### 発生箇所
ここで用いた ndarray (matrix_image) は、GAN により生成したものです。

``` python
from PIL import Image

# ndarrayをPILオブジェクトにする
image = Image.fromarray(matrix_image)
```

### エラーメッセージ
```
  File "/Users/kokoichi/.pyenv/versions/3.7.6/lib/python3.7/site-packages/PIL/Image.py", line 2813, in fromarray
    mode, rawmode = _fromarray_typemap[typekey]
KeyError: ((1, 1, 3), '<f8')

The above exception was the direct cause of the following exception:
```

## 解決策
`Image.fromarray`は各ピクセルの値として`0-255`を要求しているのに対し、渡している値が`0-1`の浮動小数点であることが原因。

値の範囲を揃えて、キャストしてから渡してあげる。

``` python
from PIL import Image

# PILオブジェクトにする
# 各ピクセル [0, 1]:float32 -> [0, 255]:uint8
matrix_image = (matrix_image*255.0).astype(np.uint8)
image = Image.fromarray(matrix_image)
```

## おわりに
気づけば単純なことですが、慣れておらず少し時間がかかってしましました。
