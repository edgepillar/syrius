#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <cstring>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gboolean ClipboardPngSizeIsSupported(const uint8_t* bytes, gsize size) {
  constexpr uint8_t header[] = {
      0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a,
      0, 0, 0, 13, 'I', 'H', 'D', 'R',
  };
  if (size < 24 || size > 1024 * 1024 ||
      std::memcmp(bytes, header, sizeof(header)) != 0) {
    return FALSE;
  }
  guint32 width, height;
  std::memcpy(&width, bytes + 16, sizeof(width));
  std::memcpy(&height, bytes + 20, sizeof(height));
  width = GUINT32_FROM_BE(width);
  height = GUINT32_FROM_BE(height);
  return width > 0 && width <= 1024 && height > 0 && height <= 1024;
}

static void HandleImageClipboard(FlMethodChannel*, FlMethodCall* call,
                                 gpointer) {
  if (std::strcmp(fl_method_call_get_name(call), "writePng") != 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(call, response, nullptr);
    return;
  }

  FlValue* args = fl_method_call_get_args(call);
  if (args && fl_value_get_type(args) == FL_VALUE_TYPE_UINT8_LIST) {
    const uint8_t* bytes = fl_value_get_uint8_list(args);
    const gsize size = fl_value_get_length(args);
    if (ClipboardPngSizeIsSupported(bytes, size)) {
      GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
      g_autoptr(GdkPixbufLoader) loader =
          gdk_pixbuf_loader_new_with_type("png", nullptr);
      if (clipboard && loader) {
        const gboolean read =
            gdk_pixbuf_loader_write(loader, bytes, size, nullptr);
        const gboolean complete = gdk_pixbuf_loader_close(loader, nullptr);
        GdkPixbuf* image = gdk_pixbuf_loader_get_pixbuf(loader);
        if (read && complete && image) {
          gtk_clipboard_set_image(clipboard, image);
          fl_method_call_respond_success(call, nullptr, nullptr);
          return;
        }
      }
    }
  }
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
      fl_method_error_response_new("clipboard-write-failed", nullptr, nullptr));
  fl_method_call_respond(call, response, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "syrius");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "syrius");
  }

  // gtk_window_set_icon_from_file(GTK_WINDOW(window), "linux/resources/app_icon.png", NULL);

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) clipboard = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "network.zenon.syrius/image_clipboard", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      clipboard, HandleImageClipboard, nullptr, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
