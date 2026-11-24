#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string_view>

#include "flutter_window.h"
#include "utils.h"
#include "app_links/app_links_plugin_c_api.h"

namespace {

void TraceInteractiveShutdown(std::string_view line) {
  constexpr std::wstring_view interactive = L"interactive";
  wchar_t mode[interactive.size() + 1];
  if (::GetEnvironmentVariableW(L"SYRIUS_HARNESS_FRAME_TIMING", mode,
                               static_cast<DWORD>(interactive.size() + 1)) !=
          interactive.size() ||
      std::wstring_view(mode, interactive.size()) != interactive) {
    return;
  }

  DWORD written;
  // Emit directly to the inherited runner pipe even if cleanup stalls later.
  ::WriteFile(::GetStdHandle(STD_OUTPUT_HANDLE), line.data(),
              static_cast<DWORD>(line.size()), &written, nullptr);
}

}  // namespace

bool SendAppLinkToInstance(const std::wstring& title) {
  // Find our exact window
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", title.c_str());

  if (hwnd) {
    // Dispatch new link to current window
    SendAppLink(hwnd);

    // (Optional) Restore our window to front in same state
    WINDOWPLACEMENT place = { sizeof(WINDOWPLACEMENT) };
    GetWindowPlacement(hwnd, &place);

    switch(place.showCmd) {
      case SW_SHOWMAXIMIZED:
          ShowWindow(hwnd, SW_SHOWMAXIMIZED);
          break;
      case SW_SHOWMINIMIZED:
          ShowWindow(hwnd, SW_RESTORE);
          break;
      default:
          ShowWindow(hwnd, SW_NORMAL);
          break;
    }

    SetWindowPos(0, HWND_TOP, 0, 0, 0, 0, SWP_SHOWWINDOW | SWP_NOSIZE | SWP_NOMOVE);
    SetForegroundWindow(hwnd);
    // END (Optional) Restore

    // Window has been found, don't create another one.
    return true;
  }

  return false;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (SendAppLinkToInstance(L"s y r i u s")) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  {
    flutter::DartProject project(L"data");

    std::vector<std::string> command_line_arguments =
        GetCommandLineArguments();

    project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

    FlutterWindow window(project);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1280, 720);
    if (!window.Create(L"s y r i u s", origin, size)) {
      return EXIT_FAILURE;
    }
    window.SetQuitOnClose(true);

    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0)) {
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
    TraceInteractiveShutdown("SYRIUS_RUNNER_SHUTDOWN messageLoopExited\n");

    ::CoUninitialize();
    TraceInteractiveShutdown("SYRIUS_RUNNER_SHUTDOWN comUninitialized\n");
  }

  TraceInteractiveShutdown("SYRIUS_RUNNER_SHUTDOWN runnerObjectsDestroyed\n");
  return EXIT_SUCCESS;
}
