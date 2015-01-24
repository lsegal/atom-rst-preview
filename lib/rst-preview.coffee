url = require 'url'
fs = require 'fs-plus'
{$} = require 'atom-space-pen-views'

RstPreviewView = null #Defer until used
renderer = null # Defer until used

createRstPreviewView = (state) ->
  RstPreviewView ?= require './rst-preview-view'
  new RstPreviewView(state)

isRstPreviewView = (object) ->
  RstPreviewView ?= require './rst-preview-view'
  object instanceof RstPreviewView

atom.deserializers.add
  name: 'RstPreviewView'
  deserialize: (state) ->

module.exports =
  config:
    breakOnSingleNewline:
      type: 'boolean'
      default: false
    liveUpdate:
      type: 'boolean'
      default: true
    grammars:
      type: 'array'
      default: [
        'source.rst'
        'text.plain'
        'text.plain.null-grammar'
        'text.restructuredtext'
      ]

  activate: ->
    atom.commands.add 'atom-workspace',
     'rst-preview:toggle': =>
      @toggle()
    'rst-preview:copy-html': =>
      @copyHtml()
    'rst-preview:toggle-break-on-single-newline': ->
      keyPath = 'rst-preview.breakOnSingleNewline'

    previewFile = @previewFile.bind(this)
    atom.commands.add '.tree-view .file .name[data-name$=\\.rst]', 'rst-preview:preview-file', previewFile


    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'rst-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        new createRstPreviewView(editorId: pathname.substring(1))
      else
        new createRstPreviewView(filePath: pathname)

  toggle: ->
    if isRstPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    grammars = atom.config.get('rst-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "rst-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (rstPreviewView) ->
      if isRstPreviewView(rstPreviewView)
        previousActivePane.activate()

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "rst-preview://#{encodeURI(filePath)}", searchAllPanes: true

  copyHtml: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    renderer ?= require './renderer'
    text = editor.getSelectedText() or editor.getText()
    renderer.toHTML text, editor.getPath(), editor.getGrammar(), (error, html) =>
      if error
        console.warn('Copying Rst as HTML failed', error)
      else
        atom.clipboard.write(html)
