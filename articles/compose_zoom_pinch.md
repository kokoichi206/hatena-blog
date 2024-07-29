# Jetpack Compose で画像をピンチしてズーム・移動・回転する

こんな感じのことをできるようにします。

![](./img/pinch_zoom.gif)

以下は drawable に貼った ai.png を対象とする例です。

``` kotlin
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.painterResource

@Composable
fun PinchZoomRotateImage() {
    var scale by remember {
        mutableFloatStateOf(1f)
    }
    var offset by remember {
        mutableStateOf(Offset.Zero)
    }
    var rotation by remember {
        mutableFloatStateOf(1f)
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
    ) {
        val state = rememberTransformableState { zoomChange, panChange, rotationChange ->
            scale = (scale * zoomChange).coerceIn(1f, 5f)

            rotation += rotationChange

            val extraWidth = (scale - 1) * constraints.maxWidth
            val extraHeight = (scale - 1) * constraints.maxHeight

            val maxX = extraWidth / 2
            val maxY = extraHeight / 2

            offset = Offset(
                x = (offset.x + panChange.x * scale).coerceIn(-maxX, +maxX),
                y = (offset.y + panChange.y * scale).coerceIn(-maxY, +maxY),
            )
        }
        Image(
            painter = painterResource(id = R.drawable.ai),
            contentDescription = "draw by ai",
            modifier = Modifier
                .fillMaxWidth()
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    translationX = offset.x
                    translationY = offset.y
                    rotationZ = rotation
                }
                .transformable(state)
        )
    }
}
```

**メモ**

- 使った Modifier
  - graphicsLayer
  - transformable
- 端っこまで移動した時、それ以上動いてしまわないように coerceIn されてます
