url = require 'url'
fs = require 'fs-plus'

RstPreviewView = require './rst-preview-view'

module.exports =
  configDefaults:
    grammars: [
      'source.rst'
      'text.plain'
      'text.plain.null-grammar'
      'text.restructuredtext'
    ]

  activate: ->
    atom.workspaceView.command 'rst-preview:show', =>
      @show()

    atom.workspace.registerOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)
      pathname = decodeURI(pathname) if pathname
      return unless protocol is 'rst-preview:'

      if host is 'editor'
        new RstPreviewView(editorId: pathname.substring(1))
      else
        new RstPreviewView(filePath: pathname)

  show: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    grammars = atom.config.get('rst-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    previousActivePane = atom.workspace.getActivePane()
    uri = "rst-preview://editor/#{editor.id}"
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (rstPreviewView) ->
      if rstPreviewView instanceof RstPreviewView
        rstPreviewView.renderRst()
        previousActivePane.activate()
