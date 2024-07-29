```
* What went wrong:
Execution failed for task ':core:common:lintDebug'.
> Lint found errors in the project; aborting build.
  
  Fix the issues identified by lint, or create a baseline to see only new errors:
  '''
  android {
      lint {
          baseline = file("lint-baseline.xml")
      }
  }
  '''
  
  For more details, see https://developer.android.com/studio/write/lint#snapshot
```
