inspect = require 'inspect'
require 'logging.file'

awful = require 'awful'
gears = require 'gears'
uzful = require 'uzful'
beautiful = require 'beautiful'
filesystem = require 'lfs'
wibox = require 'wibox'
lain = require 'lain'
paths = require 'paths'
awful.rules = require 'awful.rules'
awmodoro = require 'awmodoro'

oldPrint = print
print = (printee) ->
  oldPrint inspect printee

logPreviousStartupErrors = ->
  if awesome.startup_errors
      logger\error 'error during previous startup:'
      logger\error awesome.startup_errors
  return

logRuntimeErrors = ->
  doneWithPreviousError = true
  awesome.connect_signal "debug:error", (error) ->
    if not doneWithPreviousError
      return
    else
      doneWithPreviousError = false
      logger\error error
      doneWithPreviousError = true
  return

setUpLogging = ->
  logPath = paths.log
  logFileName = "rc.lua.log"
  logger = logging.file logPath .. logFileName

logErrors = ->
  setUpLogging!
  logPreviousStartupErrors!
  logRuntimeErrors!
  return

logErrors!

fixJavaGUI = ->
  awful.util.spawn_with_shell 'wmname LG3D'
  return

fixJavaGUI!

disableCursorAnimations = ->
  oldspawn = awful.util.spawn
  awful.util.spawn = (spawnee) ->
    oldspawn(spawnee, false)
  return

disableCursorAnimations!

setUpTheme = ->
  beautiful.init paths.theme
  return

setUpTheme!

setWallpapers = (wallpapers, folder) ->
  for screen = 1, screen.count!
    wallpaper = folder .. wallpapers[screen]
    gears.wallpaper.maximized wallpaper, screen, true
  return

chooseRandomly = (aTable, quantity) ->
  if #aTable == 0 or quantity < 1
    return
  else
    chosenOnes = {}
    for itemsChosen = 1, quantity
      randomIndex = math.random #aTable
      choice = table.remove aTable, randomIndex
      table.insert chosenOnes, choice
    return chosenOnes

selectWallpapers = (wallpapers, quantity) ->
  return chooseRandomly wallpapers, quantity

isJpgOrPng = (fileName) ->
  return not (fileName == '.' or fileName == '..') -- TODO actually do what it says

compileListOfWallpapers = (folder) ->
  listOfWallpapers = {}
  for fileName in filesystem.dir folder
    if isJpgOrPng fileName
      table.insert listOfWallpapers, fileName
  return listOfWallpapers

setUpWallpapers = ->
  wallpaperFolder = paths.wallpapers
  allWallpapers = compileListOfWallpapers wallpaperFolder
  chosenOnes = selectWallpapers allWallpapers, screen.count!
  setWallpapers chosenOnes, wallpaperFolder
  return

setUpWallpapers!

panels = {}
memoryUsage = {}
cpuWidget = {}
dateWidget = {}
cpuGraph = {}
tagPanel = {}
taskbar = {}
clientLayouts = {}
pomodoro = {}

defineClientLayouts = ->
  clientLayouts = {awful.layout.suit.tile, awful.layout.suit.tile.top}
  return

defineClientLayouts!

createCpuGraph = ->
  cpuGraphOptions =
    fgcolor: '#D0752A'
    bgcolor: beautiful.bg_systray
    load:
      interval: 20
      text: '  <span size="x-small"><span color="#666666">$1</span>' ..
            '  <span color="#9A9A9A">$2</span>' ..
            '  <span color="#DDDDDD">$3</span></span>'
    big:
      width: 400
      height: 100
      interval: 1
    small:
      width: 42
      height: beautiful.menu_height
      interval: 1
  cpuGraph = uzful.widget.cpugraphs cpuGraphOptions
  return cpuGraph

createCpuWidget = (graph) ->
  cpuWidgetOptions =
    widget: graph.big.layout
    position: 'top'
    align: 'right'
    width: graph.big.width
    height: graph.big.height
  cpuWidget = uzful.widget.infobox cpuWidgetOptions
  return

layoutWidgets = ->
  screenIndex = 1
  leftPartialLayout = wibox.layout.fixed.horizontal!
  rightPartialLayout = wibox.layout.fixed.horizontal!
  layout = wibox.layout.align.horizontal!

  layout\set_left leftPartialLayout
  layout\set_right rightPartialLayout
  layout\set_middle taskbar[screenIndex]

  memoryWidget = wibox.widget.background!
  memoryWidget\set_widget memoryUsage
  memoryWidget\set_bgimage beautiful.widget_display

  widgetBackgroundLeftEnd = wibox.widget.imagebox!
  widgetBackgroundLeftEnd\set_image beautiful.widget_display_l
  widgetBackgroundRightEnd = wibox.widget.imagebox!
  widgetBackgroundRightEnd\set_image beautiful.widget_display_r
  widgetBackgroundInBetweenWidgets = wibox.widget.imagebox!
  widgetBackgroundInBetweenWidgets\set_image beautiful.widget_display_c

  leftPartialLayout\add tagPanel[screenIndex]

  rightPartialLayout\add cpuGraph.small.widget
  rightPartialLayout\add widgetBackgroundLeftEnd
  rightPartialLayout\add memoryWidget
  rightPartialLayout\add widgetBackgroundInBetweenWidgets
  rightPartialLayout\add dateWidget
  rightPartialLayout\add widgetBackgroundRightEnd

  panels[screenIndex]\set_widget layout
  return

onMouseLeave = (widget, action) ->
  widget\connect_signal 'mouse::leave', action
  return

onMouseEnter = (widget, action) ->
  widget\connect_signal 'mouse::enter', action
  return

setUpDetailedGraphOnHover = (graph) ->
  showDetailedGraph = ->
    cpuWidget\update!
    cpuWidget\show!
    return

  onMouseEnter graph, showDetailedGraph
  hideDetailedGraph = cpuWidget.hide
  onMouseLeave graph, hideDetailedGraph
  return

enableGraphAutoCaching = ->
  uzful.util.patch.vicious!
  return

switchTimeDateOnHover = (clock, calendar) ->
  showDate = ->
    dateWidget\set_widget calendar
    return
  onMouseEnter dateWidget, showDate

  showTime = ->
    dateWidget\set_widget clock
    return

  onMouseLeave dateWidget, showTime
  return

createTaskbar = ->
  raiseClientOnClick = awful.button {}, 1, (aClient) ->
    if aClient == client.focus
       aClient.minimized = true
    else
       aClient.minimized = false
       client.focus = aClient
       aClient\raise!
  taskbarButtons = awful.util.table.join raiseClientOnClick
  taskbar[1] = awful.widget.tasklist 1, awful.widget.tasklist.filter.currenttags, taskbarButtons
  return

createTags = ->
  numberOfTags = 4
  -- this theme seems to enforce two character tag names
  defaultTagName = "  "
  tagNames =  {}
  for tagIndex = 1, numberOfTags
    tagNames[tagIndex] = defaultTagName
  defaultLayout = clientLayouts[1]
  screen = 1

  tags = {}
  tagMouseButtons = awful.button {}, 1, awful.tag.viewonly
  tags[screen] = awful.tag tagNames, screen, defaultLayout
  tagPanel[screen]  = awful.widget.taglist screen, awful.widget.taglist.filter.all, tagMouseButtons
  return

setUpDate = ->
  hoursAndMinutes = '%H:%M'
  clock = awful.widget.textclock hoursAndMinutes
  monthsAndDays = '%m-%d'
  calendar = awful.widget.textclock monthsAndDays

  dateWidget = wibox.widget.background!
  dateWidget\set_widget clock
  dateWidget\set_bgimage beautiful.widget_display
  switchTimeDateOnHover clock, calendar
  return

setUpMemoryUsage = ->
  roundToOneDecimal = (number) ->
    oneOrderOfMagnitude = 10
    scaledUp = number * oneOrderOfMagnitude + 0.5
    rounded = math.floor scaledUp
    scaledDownAgain = rounded / oneOrderOfMagnitude
    return scaledDownAgain

  options =
    settings: ->
      memoryScaledToGB = mem_now.used/1000
      memoryRounded = roundToOneDecimal memoryScaledToGB
      memoryAsDisplayed = memoryRounded .. "G"
      widget\set_markup memoryAsDisplayed
      return

  memoryUsage = lain.widgets.mem options
  return

setUpCpuGraph = ->
  enableGraphAutoCaching!
  cpuGraph = createCpuGraph!
  createCpuWidget cpuGraph
  setUpDetailedGraphOnHover cpuGraph.small.widget
  return

setUpPomodoro = ->
  widgetOptions =
    screen: 1
    position: 'bottom'
    height: 4
  pomodoroWidget = awful.wibox widgetOptions
  pomodoroWidget.visible = false

  colorGradient =
    type: 'linear'
    from: {0,0}
    to: {pomodoroWidget.width, 0}
    stops: {{0, "#AECF96"},{0.5, "#88A175"},{1, "#FF5656"}}

  options =
    minutes: 25
    do_notify: true
    active_bg_color: '#313131'
    paused_bg_color: '#7746D7'
    fg_color: colorGradient
    width: pomodoroWidget.width
    height: pomodoroWidget.height
    begin_callback: -> pomodoroWidget.visible = true
    finish_callback: -> pomodoroWidget.visible = false

  pomodoro = awmodoro.new options

  pomodoroWidget\set_widget pomodoro

createWidgets = ->
  setUpCpuGraph!
  setUpMemoryUsage!
  setUpDate!
  setUpPomodoro!

setUpPanel = (screenIndex) ->
  panel = {}
  options =
    position: 'top'
    screen: screenIndex
    height: '22'
  panel = awful.wibox options
  panel\set_bg beautiful.panel
  return panel

createPanelForEachScreen = ->
  for screenIndex = 1, screen.count!
    table.insert panels, setUpPanel screenIndex
  return

setUpPanels = ->
  createPanelForEachScreen!
  createWidgets!
  createTags!
  createTaskbar!
  layoutWidgets!
  return

setUpPanels!

borderColorWhenFocused = '#D0752A'
borderColorWhenUnfocused = '#343434'

clientHotkeys = {}
clientButtons = {}

defineClientButtons = ->
  modkey = 'Mod4'
  mod = {modkey, nil}

  leftMouseButton = 1
  rightMouseButton = 3
  mouseWheelUp = 5
  mouseWheelDown = 4

  moveClient = awful.button mod, leftMouseButton, ->
    awful.mouse.client.move!
    return
  resizeClient = awful.button mod, rightMouseButton, ->
    awful.mouse.client.resize!
    return
  nextTag = awful.button mod, mouseWheelUp, (tag) ->
    currentScreen = awful.tag.getscreen tag
    awful.tag.viewnext currentScreen
    return
  previousTag = awful.button mod, mouseWheelDown, (tag) ->
    currentScreen = awful.tag.getscreen tag
    awful.tag.viewprev currentScreen
    return

  clientButtons = awful.util.table.join moveClient, resizeClient, nextTag,
    previousTag
  return

defineClientButtons!

defineAwesomeRules = ->
  awful.rules.rules = {}
  matchAllWindows = {}
  applyDefaultPropertiesToAllWindows =
    rule: matchAllWindows
    properties:
      border_width: 1
      border_color: borderColorWhenUnFocused
      focus: awful.client.focus.filter
      size_hints_honor: false
      raise: true
      keys: clientHotkeys
      buttons: clientButtons
  table.insert awful.rules.rules, applyDefaultPropertiesToAllWindows
  return

defineAwesomeRules!

setUpHotkeys = ->
  spawn = awful.util.spawn

  terminal = 'urxvt'
  filemanager = 'thunar'
  browser = 'chromium'
  guiEditor = 'atom'

  modkey = 'Mod4'
  mod = {modkey, nil}
  modShift = {modkey, 'Shift'}

  enter = 'Return'
  leftMouseButton = 1
  rightMouseButton = 2
  mouseWheelUp = 5
  mouseWheelDown = 4

  hotkeyTerminal = awful.key mod, enter, -> spawn terminal
  hotkeyRestartAwesome = awful.key modShift, 'r', awesome.restart
  hotkeyCycleLayouts = awful.key mod, 'Tab', -> awful.layout.inc clientLayouts, 1
  hotkeyFileManager = awful.key mod, 'e', -> spawn filemanager
  hotkeyBrowser = awful.key mod, 'w', -> spawn browser
  hotkeyGuiEditor = awful.key mod, 'q', -> spawn guiEditor
  hotkeyKillClient = awful.key mod, 'c', ->
    hoveredOverClient = mouse.object_under_pointer!
    hoveredOverClient\kill!
    return
  hotkeyStartPomodoro = awful.key mod, 'p', -> pomodoro\toggle!
  hotkeyStopPomodoro = awful.key modShift, 'p', -> pomodoro\finish!

  globalkeys = awful.util.table.join hotkeyTerminal,
    hotkeyRestartAwesome, hotkeyCycleLayouts, hotkeyKillClient,
    hotkeyFileManager, hotkeyBrowser, hotkeyGuiEditor, hotkeyStartPomodoro,
    hotkeyStopPomodoro

  root.keys globalkeys

  switchToTagOnClick = awful.button {}, leftMouseButton, awful.tag.viewonly

  tagPanel.buttons = awful.util.table.join switchToTagOnClick
  return

setUpHotkeys!

focusAndHighlightClientUnderMouse = ->
  client.connect_signal 'manage', (aClient, startup) ->
    aClient\connect_signal 'mouse::enter', (anotherClient) ->
      if (awful.layout.get anotherClient.screen ~= awful.layout.suit.magnifier) and (awful.client.focus.filter anotherClient)
        client.focus = anotherClient
      return
    return

  client.connect_signal "focus", (c) ->
    c.border_color = borderColorWhenFocused
    return

  client.connect_signal 'unfocus', (c) ->
    c.border_color = borderColorWhenUnfocused
    return

focusAndHighlightClientUnderMouse!
