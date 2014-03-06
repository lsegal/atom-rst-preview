path = require 'path'
{$, $$$, EditorView, ScrollView} = require 'atom'
_ = require 'underscore-plus'
{File} = require 'pathwatcher'
{extensionForFenceName} = require './extension-helper'

module.exports =
class RstPreviewView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: (state) ->
    new RstPreviewView(state)

  @content: ->
    @div class: 'rst-preview native-key-bindings', tabindex: -1, =>
      @div class: 'buffer-1'
      @div class: 'buffer-2'

  constructor: ({@editorId, filePath}) ->
    super

    @buffer1 = @find('.buffer-1')
    @buffer2 = @find('.buffer-2')
    @buffer1.show()
    @buffer2.hide()
    if @editorId?
      @resolveEditor(@editorId)
    else
      @file = new File(filePath)
      @handleEvents()

  serialize: ->
    deserializer: 'RstPreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @unsubscribe()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)
      @trigger 'title-changed' if @editor?
      @handleEvents()

    if atom.workspace?
      resolve()
    else
      atom.packages.once 'activated', =>
        resolve()
        @renderRst()

  editorForId: (editorId) ->
    for editor in atom.workspace.getEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @subscribe atom.syntax, 'grammar-added grammar-updated', _.debounce((=> @renderRst()), 250)
    @subscribe this, 'core:move-up', => @scrollUp()
    @subscribe this, 'core:move-down', => @scrollDown()

    changeHandler = =>
      @renderRst()
      pane = atom.workspace.paneForUri(@getUri())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @subscribe(@file, 'contents-changed', changeHandler)
    else if @editor?
      @subscribe(@editor.getBuffer(), 'contents-modified', changeHandler)

  renderRst: ->
    @showLoading()
    if @file?
      @file.read().then (contents) => @renderRstText(contents)
    else if @editor?
      @renderRstText(@editor.getText())

  renderRstText: (text) ->
    textBuffer = []
    spawn = require('child_process').spawn
    child = spawn('pandoc', ['--from', 'rst', '--to', 'html'])
    child.stdout.on 'data', (data) => textBuffer.push(data.toString())
    child.stdout.on 'close', =>
      [buffer, altBuffer] = []
      if @buffer1.isVisible()
        [buffer, altBuffer] = [@buffer2, @buffer1]
      else
        [buffer, altBuffer] = [@buffer1, @buffer2]
      html = @resolveImagePaths(@tokenizeCodeBlocks(textBuffer.join('\n')))
      buffer.html(html).show()
      altBuffer.hide()
    child.stdin.write(text)
    child.stdin.end()

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Preview"
    else if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "Rst Preview"

  getUri: ->
    if @file?
      "rst-preview://#{@getPath()}"
    else
      "rst-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  showError: (result) ->
    failureMessage = result?.message

    @buffer1.show()
    @buffer2.hide()
    @buffer1.html $$$ ->
      @h2 'Previewing Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @buffer1.show()
    @buffer2.hide()
    @buffer1.html $$$ ->
      @div class: 'rst-spinner', 'Loading ReStructuredText\u2026'

  resolveImagePaths: (html) =>
    html = $(html)
    imgList = html.find("img")

    for imgElement in imgList
      img = $(imgElement)
      src = img.attr('src')
      continue if src.match /^(https?:\/\/)/
      img.attr('src', path.resolve(path.dirname(@getPath()), src))

    html

  tokenizeCodeBlocks: (html) =>
    html = $(html)
    preList = $(html.filter("pre"))

    for preElement in preList.toArray()
      $(preElement).addClass("editor-colors")
      codeBlock = $(preElement.firstChild)

      # go to next block unless this one has a class
      continue unless className = codeBlock.attr('class')

      fenceName = className.replace(/^lang-/, '')
      # go to next block unless the class name matches `lang`
      continue unless extension = extensionForFenceName(fenceName)
      text = codeBlock.text()

      grammar = atom.syntax.selectGrammar("foo.#{extension}", text)

      codeBlock.empty()
      for tokens in grammar.tokenizeLines(text)
        codeBlock.append(EditorView.buildLineHtml({ tokens, text }))

    html
