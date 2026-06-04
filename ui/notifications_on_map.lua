-- Notification on Map (notifications_on_map)
-- Adds possibility to show the notification window in map mode.
-- Compatible with X4 9.00.

local ffi = require("ffi")
local C   = ffi.C

ffi.cdef[[
  typedef uint64_t UniverseID;

  typedef struct {
    int major;
    int minor;
  } GameVersion;

  GameVersion GetGameVersion(void);
  UniverseID  GetPlayerID(void);


	int GetConfigSetting(const char*const setting);
	void SetConfigSetting(const char*const setting, const bool value);
]]

-- *** constants ***

local PAGE_ID = 1972092425


-- *** module table ***

local nom = {
  menuMap           = nil,
  menuInteract      = nil,
  menuMapConfig     = {},
  isV9              = C.GetGameVersion().major >= 9,
  playerId          = nil,     -- set in nom.Init(); used to read MD blackboard config
  showNotification  = false,  -- set to false to disable showing notifications in map mode
  isMapShown        = false, -- track map visibility to avoid showing notifications when the map is hidden
  isSectionAdded   = false,
  switchViaContextMenu = false, -- whether to show the options to switch notifications on/off in map mode in the context menu of the notification window (instead of always showing them in the Interact Menu when the map is open)
}

local config = {
  contextMenuSection           = { id = "notificationsOnMap", text = ReadText(1972092425, 1), isorder = false },
  contextMenuActions           = {
    ["showNotifications"] = {
      type = "notificationsOnMap",
      actiontype = "lua;showNotifications",
      showNotification = true,
      text = ReadText(1972092425, 1001),
      scriptFunction = function()
        nom.changeNotificationsStateInConfig(true)
        nom.onConfigChanged()
        nom.forceNotificationsStateToReApply()
        nom.interactMenuFinishAction()
      end
    },
    ["hideNotifications"] = {
      type = "notificationsOnMap",
      actiontype = "lua;hideNotifications",
      showNotification = false,
      text = ReadText(1972092425, 1002),
      scriptFunction = function()
        nom.changeNotificationsStateInConfig(false)
        nom.onConfigChanged()
        nom.forceNotificationsStateToReApply()
        nom.interactMenuFinishAction()
      end
    },
  }
}

-- *** debug helpers ***

local debugLevel = "none"   -- "none" | "debug" | "trace"

local function debug(msg)
  if debugLevel ~= "none" and type(DebugError) == "function" then
    DebugError("NotificationsOnMap: " .. msg)
  end
end

local function trace(msg)
  if debugLevel == "trace" then
    debug(msg)
  end
end


function nom.setNotificationConfigState()
  local configState = C.GetConfigSetting("forceToShowNotifications") == 1
  local desiredState = nom.showNotification and nom.isMapShown
  debug("Current config state for showing notifications on map: " .. tostring(configState) .. ", desired state: " .. tostring(desiredState))
  if configState ~= desiredState then
    C.SetConfigSetting("forceToShowNotifications", desiredState)
    debug("Set config state for showing notifications on map to: " .. tostring(desiredState))
  end
end

function nom.onMenuCleanup(menu, config)
  nom.isMapShown = false
  nom.setNotificationConfigState()
  trace("Menu cleanup")
end

function nom.onMenuMinimize(menu, config)
  nom.isMapShown = false
  nom.setNotificationConfigState()
  trace("Menu minimize")
end

function nom.onCreateMainFrame(menu, config, firstTime)
  nom.isMapShown = menu ~= nil and menu.mode ~= "hire" and menu.mode ~= "selectCV"
  nom.setNotificationConfigState()
  trace("Menu main frame created, first time: " .. tostring(firstTime))
end

function nom.onConfigChanged()
  if nom.playerId == nil then return end
  local cfg = GetNPCBlackboard(nom.playerId, "$notificationsOnMapConfig")
  if cfg == nil then return end
  if cfg.debugMode ~= nil then
    local oldDebugLevel = debugLevel
    debugLevel = cfg.debugMode
    debug("debug mode set to: " .. tostring(debugLevel))
    local targetDebug = debugLevel ~= "none"
    local monitorsDebug = C.GetConfigSetting("forceToShowNotificationsDebug") == 1
    debug("monitorsDebug: " .. tostring(monitorsDebug))
    if targetDebug ~= monitorsDebug then
      C.SetConfigSetting("forceToShowNotificationsDebug", targetDebug)
      debug("Enabled showing debug notifications in monitors code")
    end
    if oldDebugLevel == "none" and debugLevel ~= "none" then
      nom.printGameEnvironmentStats()
    end
  end
  if cfg.switchViaContextMenu ~= nil then
    nom.switchViaContextMenu = cfg.switchViaContextMenu == 1
    debug("switchViaContextMenu set to: " .. tostring(nom.switchViaContextMenu))
  end
  if cfg.showNotifications ~= nil then
    nom.showNotification = cfg.showNotifications == 1
    debug("showNotifications set to: " .. tostring(nom.showNotifications))
    nom.setNotificationConfigState()
  end
end

function nom.changeNotificationsStateInConfig(show)
  if nom.playerId == nil then return end
  local cfg = GetNPCBlackboard(nom.playerId, "$notificationsOnMapConfig")
  if cfg == nil then return end
  if cfg.showNotifications ~= nil then
    local currentState = cfg.showNotifications == 1
    if currentState ~= show then
      cfg.showNotifications = show and 1 or 0
      SetNPCBlackboard(nom.playerId, "$notificationsOnMapConfig", cfg)
      debug("Changed showNotifications in config to: " .. tostring(show))
    end
  end
end

function nom.forceNotificationsStateToReApply()
  C.SetConfigSetting("forceNotificationsStateToReApply", true)
  debug("Set temporary config to trigger re-application of notifications state in monitors code")
end

function nom.prepareSections(sections)
  if not nom.isSectionAdded then
    sections[#sections + 1] = config.contextMenuSection
    nom.isSectionAdded = true
  end
end

function nom.insertLuaAction(actionType, _)
  if nom.isSectionAdded and config.contextMenuActions[actionType] then
    nom.menuInteract.insertInteractionContent(config.contextMenuSection.id, {
      type = config.contextMenuSection.id,
      text = config.contextMenuActions[actionType].text,
      script = config.contextMenuActions[actionType].scriptFunction,
      mouseOverText = "",
      helpOverlayID = "",
      helpOverlayText = "",
      helperOverlayHighlightOnly = true
    })
  end
end

function nom.prepareActions(actions, definedActions)
  if nom.isSectionAdded and nom.menuMap.shown and nom.switchViaContextMenu then
    local isToBeDisplayed = false
    for _, action in pairs(config.contextMenuActions) do
      isToBeDisplayed = nom.isActionToBeDisplayed(action)
      if isToBeDisplayed then
        nom.addAction(actions, definedActions, action, isToBeDisplayed)
      end
    end
  end
end

function nom.addAction(actions, definedActions, action, isToBeDisplayed)
  table.insert(actions, {
    id = #actions,
    text = action.text,
    actiontype = action.actiontype,
    active = isToBeDisplayed,
    istobedisplayed = isToBeDisplayed
  })
  definedActions[action.actiontype] = #actions
end

function nom.isActionToBeDisplayed(action)
  local display = false
  if action.type == config.contextMenuSection.id then
    if nom.showNotification ~= action.showNotification then
      display = true
    end
  end
  return display

end

function nom.interactMenuFinishAction()
  if nom.menuInteract.shown then
    nom.menuInteract.onCloseElement("close")
  else
    Helper.resetUpdateHandler()
    local _config = nom.menuInteract.uix_getConfig()
    Helper.clearFrame(nom.menuInteract, _config.layer)
    Helper.returnFromInteractMenu(nom.menuInteract.currentOverTable, "refresh")
    nom.menuInteract.cleanup()
  end
end

function nom.printGameEnvironmentStats()
  if debugLevel == "none" then
    return
  end
  local lines = {}
  lines[#lines + 1] = "=== Game Environment ==="
  lines[#lines + 1] = "Version: " .. GetVersionString() .. "  Build: " .. ffi.string(C.GetBuildVersionSuffix())

  local extensions = GetExtensionList()
  local dlcList = {}
  local modList = {}
  for _, ext in ipairs(extensions) do
    if ext.enabled then
      if ext.egosoftextension and ext.enabledbydefault then
        dlcList[#dlcList + 1] = ext
      else
        modList[#modList + 1] = ext
      end
    end
  end

  lines[#lines + 1] = "--- Enabled DLCs (" .. #dlcList .. ") ---"
  for _, dlc in ipairs(dlcList) do
    lines[#lines + 1] = string.format("  id:%-30s  name:%-40s  v%-10s  date:%s", dlc.id, dlc.name, dlc.version, dlc.date)
  end

  lines[#lines + 1] = "--- Enabled Extensions (" .. #modList .. ") ---"
  for _, mod in ipairs(modList) do
    local source = mod.egosoftextension and "ego" or (mod.isworkshop and "workshop" or (mod.personal and "personal" or "local"))
    lines[#lines + 1] = string.format("  id:%-30s  name:%-40s  author:%-25s  [%s]  v%-10s  date:%s", mod.id, mod.name, mod.author or "", source, mod.version, mod.date)
  end

  debug(table.concat(lines, "\n"))
end

nom.Init = function(menuMap, menuInteract)
  nom.menuMap = menuMap
  nom.menuInteract = menuInteract
  nom.menuMapConfig = menuMap.uix_getConfig() or {}

  nom.playerId = ConvertStringTo64Bit(tostring(C.GetPlayerID()))

  menuMap.registerCallback("on_menu_cleanup", nom.onMenuCleanup)
  menuMap.registerCallback("on_menu_minimize", nom.onMenuMinimize)
  menuMap.registerCallback("on_create_main_frame", nom.onCreateMainFrame)

  menuInteract.registerCallback("prepareSections_on_start", nom.prepareSections)
  menuInteract.registerCallback("prepareActions_prepare_custom_action", nom.prepareActions)
  menuInteract.registerCallback("insertLuaAction_insert_custom_action", nom.insertLuaAction)

  RegisterEvent("NotificationsOnMap.ConfigChanged", nom.onConfigChanged)
  nom.onConfigChanged()
end


local function Init()
  debug("Initialising Notifications On Map")

  local menuMap = Helper.getMenu("MapMenu")
  if menuMap == nil or type(menuMap.registerCallback) ~= "function" then
    debug("MapMenu not found - kuertee UI Extensions not loaded?")
    return
  end

  local menuInteract = Helper.getMenu("InteractMenu")
  if menuInteract == nil or type(menuInteract.registerCallback) ~= "function" then
    debug("InteractMenu not found - kuertee UI Extensions not loaded?")
    return
  end

  nom.Init(menuMap, menuInteract)
end

Register_OnLoad_Init(Init)
