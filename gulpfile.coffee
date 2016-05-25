
gulp = require('gulp')
coffeelint = require('gulp-coffeelint')
sourceFiles = [
  'unipi-evok.coffee'
  './devices/*.coffee'
]



gulp.task('lint', ->
  gulp.src(sourceFiles)
  .pipe(coffeelint())
  .pipe(coffeelint.reporter())
)