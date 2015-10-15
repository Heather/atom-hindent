{CompositeDisposable} = require 'atom'
{BufferedProcess} = require 'atom'
{dirname} = require 'path'
{statSync} = require 'fs'

prettify = (text, workingDirectory, {onComplete, onFailure}) ->
  lines = []
  proc = new BufferedProcess
    command: 'hindent'
    args: ['--style', 'chris-done']
    options:
      cwd: workingDirectory
    stdout: (line) ->
      lines.push(line)
    exit: -> onComplete?(lines.join(''))
  proc.onWillThrowError ({error, handle}) ->
    atom.notifications.addError "Hindent could not spawn #{shpath}",
      detail: "#{error}"
    console.error error
    onFailure?()
    handle()
  proc.process.stdin.write(text)
  proc.process.stdin.end()

prettifyFile = (editor, format = 'haskell') ->
  [firstCursor, cursors...] = editor.getCursors().map (cursor) ->
    cursor.getBufferPosition()
  try
    workDir = dirname(editor.getPath())
    if not statSync(workDir).isDirectory()
      workDir = '.'
  catch
    workDir = '.'
  prettify editor.getText(), workDir,
    onComplete: (text) ->
      editor.setText(text)
      if editor.getLastCursor()?
        editor.getLastCursor().setBufferPosition firstCursor,
          autoscroll: false
        cursors.forEach (cursor) ->
          editor.addCursorAtBufferPosition cursor,
            autoscroll: false
    onFailure: (text) ->
      atom.notifications.addError text

module.exports = Hindent =
  disposables: null
  menu: null

  activate: (state) ->
    @disposables = new CompositeDisposable
    @menu = new CompositeDisposable

    @disposables.add \
      atom.commands.add 'atom-text-editor[data-grammar~="haskell"]',
        'hindent:prettify': ({target}) =>
          prettifyFile target.getModel()

    @menu.add atom.menu.add [
      label: 'hindent'
      submenu : [
        {label: 'Prettify', command: 'hindent:prettify'}
      ]
    ]

  deactivate: ->
    # clear commands
    @disposables.dispose()
    @disposables = null

    @clearMenu()

  clearMenu: ->
    @menu.dispose()
    @menu = null
    atom.menu.update()
