#define WLR_USE_UNSTABLE

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/ViewQuery.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/managers/EventManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/SharedDefs.hpp>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#include <dlfcn.h>
#include <chrono>
#include <algorithm>
#include <vector>
#include <unordered_map>
#include <string>

inline HANDLE PHANDLE = nullptr;

static std::vector<PHLWINDOWREF>                                             g_minimizedWindows;
static std::unordered_map<uintptr_t, std::chrono::steady_clock::time_point> g_lastRestoreTime;
static std::unordered_map<uintptr_t, std::chrono::steady_clock::time_point> g_lastMinimizeTime;

typedef Config::Actions::ActionResult (*origFocus)(PHLWINDOW);
inline CFunctionHook* g_pFocusHook = nullptr;

typedef void (*origActivate)(void*, bool);
inline CFunctionHook* g_pActivateHook = nullptr;

typedef Desktop::CViewQuery&& (*origSelector)(Desktop::CViewQuery*, std::string_view);
inline CFunctionHook* g_pSelectorHook = nullptr;

static Desktop::CViewQuery&& hkSelector(Desktop::CViewQuery* thisptr, std::string_view sv) {
    static thread_local std::string s_buffer;
    std::string s{sv};
    while (!s.empty() && (s.front() == ' ' || s.front() == '\t'))
        s.erase(s.begin());

    if (!s.starts_with("address:") && !s.starts_with("class:") && !s.starts_with("title:") &&
        !s.starts_with("initialclass:") && !s.starts_with("initialtitle:") && !s.starts_with("tag:") &&
        !s.starts_with("pid:") && !s.starts_with("floating") && !s.starts_with("tiled") &&
        !s.starts_with("active") && !s.starts_with("stableid:")) {
        std::string test = s;
        if (test.starts_with("0x"))
            test = test.substr(2);
        bool isHex = !test.empty() && std::all_of(test.begin(), test.end(), ::isxdigit);
        if (isHex && test.length() >= 6) {
            s_buffer = "address:0x" + test;
            return (*(origSelector)g_pSelectorHook->m_original)(thisptr, std::string_view(s_buffer));
        }
    }

    return (*(origSelector)g_pSelectorHook->m_original)(thisptr, sv);
}

// Strict protection against disturbing watched video/streams and Picture-in-Picture
static bool isProtectedWindow(PHLWINDOW pWindow) {
    if (!pWindow)
        return true;
    if (pWindow->m_pinned)
        return true;

    std::string title = pWindow->m_title;
    std::string ltitle = title;
    for (auto& c : ltitle)
        c = ::tolower(c);

    if (ltitle.find("picture-in-picture") != std::string::npos ||
        ltitle.find("picture in picture") != std::string::npos)
        return true;

    std::string cls = pWindow->m_class;
    std::string lcls = cls;
    for (auto& c : lcls)
        c = ::tolower(c);

    if (lcls.find("picture-in-picture") != std::string::npos)
        return true;

    return false;
}

static PHLWINDOW findWindowBySelector(const std::string& selector) {
    if (!selector.empty()) {
        std::string s = selector;
        while (!s.empty() && (s.front() == ' ' || s.front() == '\t'))
            s.erase(s.begin());

        // Parse hex address directly if provided (e.g. address:0x... or 0x...)
        std::string hexStr = "";
        if (s.rfind("address:0x", 0) == 0)
            hexStr = s.substr(10);
        else if (s.rfind("address:", 0) == 0)
            hexStr = s.substr(8);
        else if (s.rfind("0x", 0) == 0)
            hexStr = s.substr(2);

        if (!hexStr.empty()) {
            try {
                uintptr_t targetAddr = std::stoull(hexStr, nullptr, 16);
                for (auto const& w : Desktop::windowState()->windows()) {
                    if (w && (uintptr_t)w.get() == targetAddr)
                        return w;
                }
            } catch (...) {}
        }

        // Try Hyprland's internal query selector
        try {
            auto w = Desktop::viewState()->query().selector(s).runWindow();
            if (w)
                return w;
        } catch (...) {}

        // Explicit selector was provided but not found: DO NOT FALLBACK!
        return nullptr;
    }

    // When no selector is passed (e.g. titlebar minimize button clicked or Super+M):
    // Strictly target the currently focused active window! Zero cursor guessing!
    auto active = Desktop::focusState()->window();
    if (active && active->m_isMapped && !active->isHidden() && !isProtectedWindow(active)) {
        return active;
    }

    return nullptr;
}

static void minimizeWindow(PHLWINDOW pWindow) {
    if (!pWindow || isProtectedWindow(pWindow) || pWindow->isHidden())
        return;

    uintptr_t addr = (uintptr_t)pWindow.get();

    // 1. Native hide and suspend (remains on current workspace!)
    pWindow->setHidden(true);
    pWindow->setSuspended(true);

    // 2. Track in stack
    g_minimizedWindows.emplace_back(pWindow);
    g_lastMinimizeTime[addr] = std::chrono::steady_clock::now();

    // 3. Post IPC event
    g_pEventManager->postEvent(SHyprIPCEvent{.event = "minimized", .data = std::format("{:x},1", rc<uintptr_t>(pWindow.get()))});

    // 4. Smooth focus transfer to next topmost visible window on same workspace
    auto ws = pWindow->m_workspace;
    PHLWINDOW nextFocus = nullptr;
    const auto& windows = Desktop::windowState()->windows();
    for (auto it = windows.rbegin(); it != windows.rend(); ++it) {
        auto cand = *it;
        if (!cand || cand == pWindow || !cand->m_isMapped || cand->isHidden())
            continue;
        if (cand->m_workspace != ws)
            continue;
        if (isProtectedWindow(cand))
            continue;
        nextFocus = cand;
        break;
    }

    if (nextFocus) {
        Desktop::windowState()->raise(nextFocus);
        Desktop::focusState()->fullWindowFocus(nextFocus, Desktop::FOCUS_REASON_DESKTOP_STATE_CHANGE);
        g_pHyprRenderer->damageWindow(nextFocus);
    } else {
        Desktop::focusState()->fullWindowFocus(nullptr, Desktop::FOCUS_REASON_DESKTOP_STATE_CHANGE);
    }

    // 5. Trigger monitor damage so screen updates immediately
    if (auto m = pWindow->m_monitor.lock())
        g_pHyprRenderer->damageMonitor(m);
}

static void restoreWindow(PHLWINDOW pWindow) {
    if (!pWindow)
        return;

    uintptr_t addr = (uintptr_t)pWindow.get();

    // Remove from minimized stack
    std::erase_if(g_minimizedWindows, [&](const auto& ref) {
        auto w = ref.lock();
        return !w || w == pWindow;
    });

    g_lastRestoreTime[addr] = std::chrono::steady_clock::now();

    // If window is on another workspace, switch smoothly
    if (auto mon = Desktop::focusState()->monitor()) {
        if (pWindow->m_workspace && mon->m_activeWorkspace != pWindow->m_workspace) {
            (void)Config::Actions::changeWorkspace(pWindow->m_workspace);
        }
    }

    // 1. Unhide & unsuspend
    pWindow->setHidden(false);
    pWindow->setSuspended(false);

    // 2. Elevate directly to top of Z-order
    Desktop::windowState()->raise(pWindow);

    // 3. Bring layout target to top (handles groups if any)
    if (pWindow->layoutTarget())
        g_layoutManager->bringTargetToTop(pWindow->layoutTarget());

    // 4. Give full window & keyboard focus (WITHOUT warping cursor)
    Desktop::focusState()->fullWindowFocus(pWindow, Desktop::FOCUS_REASON_DESKTOP_STATE_CHANGE);

    // 5. Post IPC event
    g_pEventManager->postEvent(SHyprIPCEvent{.event = "minimized", .data = std::format("{:x},0", rc<uintptr_t>(pWindow.get()))});

    // 6. Force immediate redraw
    g_pHyprRenderer->damageWindow(pWindow);
    if (auto m = pWindow->m_monitor.lock())
        g_pHyprRenderer->damageMonitor(m);
}

static void toggleWindow(PHLWINDOW pWindow) {
    if (!pWindow || isProtectedWindow(pWindow))
        return;

    if (pWindow->isHidden()) {
        restoreWindow(pWindow);
        return;
    }

    if (Desktop::focusState()->window() == pWindow) {
        minimizeWindow(pWindow);
        return;
    }

    restoreWindow(pWindow);
}

// Hook: Config::Actions::focus(window)
static Config::Actions::ActionResult hkFocus(PHLWINDOW window) {
    if (!window)
        return {};

    if (isProtectedWindow(window)) {
        return (*(origFocus)g_pFocusHook->m_original)(window);
    }

    // 1. Minimized window -> restore to top on first click
    if (window->isHidden()) {
        restoreWindow(window);
        return {};
    }

    // 2. Visible window -> ensure it is raised and focus normally
    Desktop::windowState()->raise(window);
    return (*(origFocus)g_pFocusHook->m_original)(window);
}

// Hook: Desktop::View::CWindow::activate(bool)
static void hkActivate(void* thisptr, bool force) {
    if (!thisptr)
        return;

    auto pWindow = ((Desktop::View::CWindow*)thisptr)->m_self.lock();
    if (pWindow && !isProtectedWindow(pWindow) && pWindow->isHidden()) {
        restoreWindow(pWindow);
        return;
    }

    (*(origActivate)g_pActivateHook->m_original)(thisptr, force);
}

static void onWindowClosed(PHLWINDOW window) {
    if (!window)
        return;
    uintptr_t addr = (uintptr_t)window.get();
    std::erase_if(g_minimizedWindows, [&](const auto& ref) {
        auto w = ref.lock();
        return !w || w == window;
    });
    g_lastRestoreTime.erase(addr);
    g_lastMinimizeTime.erase(addr);
}

// Lua C API bindings for config.minimizer & lua scripts
static int luaMinimize(lua_State* L) {
    std::string arg = "";
    if (lua_gettop(L) >= 1 && lua_isstring(L, 1))
        arg = lua_tostring(L, 1);
    auto w = findWindowBySelector(arg);
    if (w)
        minimizeWindow(w);
    lua_pushboolean(L, w != nullptr);
    return 1;
}

static int luaRestore(lua_State* L) {
    std::string arg = "";
    if (lua_gettop(L) >= 1 && lua_isstring(L, 1))
        arg = lua_tostring(L, 1);
    PHLWINDOW w = nullptr;
    if (!arg.empty())
        w = findWindowBySelector(arg);
    else if (!g_minimizedWindows.empty()) {
        while (!g_minimizedWindows.empty() && !w) {
            w = g_minimizedWindows.back().lock();
            g_minimizedWindows.pop_back();
        }
    }
    if (w)
        restoreWindow(w);
    lua_pushboolean(L, w != nullptr);
    return 1;
}

static int luaToggle(lua_State* L) {
    std::string arg = "";
    if (lua_gettop(L) >= 1 && lua_isstring(L, 1))
        arg = lua_tostring(L, 1);
    auto w = findWindowBySelector(arg);
    if (w)
        toggleWindow(w);
    lua_pushboolean(L, w != nullptr);
    return 1;
}

static int luaIsMinimized(lua_State* L) {
    std::string arg = "";
    if (lua_gettop(L) >= 1 && lua_isstring(L, 1))
        arg = lua_tostring(L, 1);
    auto w = findWindowBySelector(arg);
    lua_pushboolean(L, w && w->isHidden());
    return 1;
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    // 1. Resolve symbols for function hooks
    void* addrFocus = dlsym(RTLD_DEFAULT, "_ZN6Config7Actions5focusEN9Hyprutils6Memory14CSharedPointerIN7Desktop4View7CWindowEEE");
    void* addrActivate = dlsym(RTLD_DEFAULT, "_ZN7Desktop4View7CWindow8activateEb");

    if (addrFocus) {
        g_pFocusHook = HyprlandAPI::createFunctionHook(PHANDLE, addrFocus, (void*)&hkFocus);
        if (g_pFocusHook)
            g_pFocusHook->hook();
    }

    if (addrActivate) {
        g_pActivateHook = HyprlandAPI::createFunctionHook(PHANDLE, addrActivate, (void*)&hkActivate);
        if (g_pActivateHook)
            g_pActivateHook->hook();
    }

    void* addrSelector = dlsym(RTLD_DEFAULT, "_ZNO7Desktop10CViewQuery8selectorESt17basic_string_viewIcSt11char_traitsIcEE");
    if (addrSelector) {
        g_pSelectorHook = HyprlandAPI::createFunctionHook(PHANDLE, addrSelector, (void*)&hkSelector);
        if (g_pSelectorHook)
            g_pSelectorHook->hook();
    }

    // 2. Dispatchers (both colon and underscore versions for compatibility)
    auto dispatchMinimize = [](std::string args) -> SDispatchResult {
        auto w = findWindowBySelector(args);
        if (w)
            minimizeWindow(w);
        return {.success = true};
    };
    auto dispatchRestore = [](std::string args) -> SDispatchResult {
        PHLWINDOW w = nullptr;
        if (!args.empty()) {
            w = findWindowBySelector(args);
        } else if (!g_minimizedWindows.empty()) {
            while (!g_minimizedWindows.empty() && !w) {
                w = g_minimizedWindows.back().lock();
                g_minimizedWindows.pop_back();
            }
        }
        if (w)
            restoreWindow(w);
        return {.success = true};
    };
    auto dispatchToggle = [](std::string args) -> SDispatchResult {
        auto w = findWindowBySelector(args);
        if (w)
            toggleWindow(w);
        return {.success = true};
    };

    HyprlandAPI::addDispatcherV2(PHANDLE, "kypr:minimize", dispatchMinimize);
    HyprlandAPI::addDispatcherV2(PHANDLE, "kypr:restore", dispatchRestore);
    HyprlandAPI::addDispatcherV2(PHANDLE, "kypr:toggle", dispatchToggle);

    HyprlandAPI::addDispatcherV2(PHANDLE, "kypr_minimize", dispatchMinimize);
    HyprlandAPI::addDispatcherV2(PHANDLE, "kypr_restore", dispatchRestore);
    HyprlandAPI::addDispatcherV2(PHANDLE, "kypr_toggle", dispatchToggle);

    // 3. Lua API bindings (accessible as hl.plugin.kyprland.minimize(), etc.)
    HyprlandAPI::addLuaFunction(PHANDLE, "kyprland", "minimize", ::luaMinimize);
    HyprlandAPI::addLuaFunction(PHANDLE, "kyprland", "restore", ::luaRestore);
    HyprlandAPI::addLuaFunction(PHANDLE, "kyprland", "toggle", ::luaToggle);
    HyprlandAPI::addLuaFunction(PHANDLE, "kyprland", "is_minimized", ::luaIsMinimized);

    // 4. Event listeners for window lifecycle
    static auto P1 = Event::bus()->m_events.window.close.listen([](PHLWINDOW window) {
        onWindowClosed(window);
    });
    static auto P2 = Event::bus()->m_events.window.destroy.listen([](PHLWINDOWREF window) {
        onWindowClosed(window.lock());
    });

    return {"kyprland", "Native KDE Plasma-style window management for Hyprland", "Kyprland", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    if (g_pFocusHook) {
        g_pFocusHook->unhook();
        g_pFocusHook = nullptr;
    }
    if (g_pActivateHook) {
        g_pActivateHook->unhook();
        g_pActivateHook = nullptr;
    }
    if (g_pSelectorHook) {
        g_pSelectorHook->unhook();
        g_pSelectorHook = nullptr;
    }

    // Restore any hidden windows before unloading
    for (auto const& ref : g_minimizedWindows) {
        if (auto w = ref.lock()) {
            w->setHidden(false);
            w->setSuspended(false);
            Desktop::windowState()->raise(w);
        }
    }
    g_minimizedWindows.clear();
    g_lastRestoreTime.clear();
    g_lastMinimizeTime.clear();
}
