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

local PAGE_ID  = 1972092425


-- *** module table ***

local nom = {
  menuMap       = nil,
  menuMapConfig = {},
  isV9          = C.GetGameVersion().major >= 9,
  playerId         = nil,     -- set in nom.Init(); used to read MD blackboard config
  showNotification = true,  -- set to false to disable showing notifications in map mode
  isMapShown       = false, -- track map visibility to avoid showing notifications when the map is hidden
}

-- *** debug helpers ***

local debugLevel = "trace"   -- "none" | "debug" | "trace"

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
    debugLevel = cfg.debugMode
    debug("debug mode set to: " .. tostring(debugLevel))
  end
  if cfg.showNotifications ~= nil then
    nom.showNotification = cfg.showNotifications == 1
    debug("showNotifications set to: " .. tostring(nom.showNotification))
    nom.setNotificationConfigState()
  end
end

nom.Init = function(menuMap)
  nom.menuMap = menuMap
  nom.menuMapConfig = menuMap.uix_getConfig() or {}

  nom.playerId = ConvertStringTo64Bit(tostring(C.GetPlayerID()))

  menuMap.registerCallback("on_menu_cleanup", nom.onMenuCleanup)
  menuMap.registerCallback("on_menu_minimize", nom.onMenuMinimize)
  menuMap.registerCallback("on_create_main_frame", nom.onCreateMainFrame)

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

  nom.Init(menuMap)
end

Register_OnLoad_Init(Init)
