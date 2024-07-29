# Makefile で if 文を使って、変数の有無で処理を切り替える

## 変数の有無で処理を変える

以下のように設定します。

``` makefile
if-test:	## 
ifeq ($(name),)	## 引数がない時
	@echo Hello 名無さん
else	## 引数がある時
	@echo Hello $(name)
endif
```

引数がある時とない時で処理が変わります。

``` sh
# 引数がない時
$ make if-test
Hello 名無さん

# 引数がある時
$ make if-test name=john
Hello john
```

## 実用例 1

これを利用して、たとえば以下のような使い方ができます。

- 引数がない時は、現在のブランチから openapi の generator で生成する
- 引数がある時は、引数で指定したブランチ or コミットハッシュの箇所にチェックアウトし、

``` makefile
gen:	## t にブランチ・ハッシュ値を指定する
ifeq ($(t),)
	@echo 引数に指定がないため、現在のブランチで生成を行います。
	generate openapi
else
	@cd submodule/openapi && git fetch && git checkout $(t)
	generate openapi
endif
```

``` sh
$ make gen

$ make gen t=main
```

