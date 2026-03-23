#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(430, 780);
  RECT work_area = {0};
  const bool has_work_area =
      ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0) != 0;

  const int screen_left = has_work_area ? work_area.left : 0;
  const int screen_top = has_work_area ? work_area.top : 0;
  const int screen_right =
      has_work_area ? work_area.right : ::GetSystemMetrics(SM_CXSCREEN);
  const int screen_bottom =
      has_work_area ? work_area.bottom : ::GetSystemMetrics(SM_CYSCREEN);

  const int screen_width = screen_right - screen_left;
  const int screen_height = screen_bottom - screen_top;

  const int origin_x = screen_left + (screen_width - size.width) / 2;
  const int origin_y = screen_top + (screen_height - size.height) / 2;
  Win32Window::Point origin(origin_x, origin_y);
  if (!window.Create(L"game_tournament", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
