/*  This file is part of corebird, a Gtk+ linux Twitter client.
 *  Copyright (C) 2013 Timm Bäder
 *
 *  corebird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  corebird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with corebird.  If not, see <http://www.gnu.org/licenses/>.
 */

class ComposeImageManager : Gtk.Container {
  private const int BUTTON_DELTA = 10;
  private const int BUTTON_SPACING = 12;
  private bool _upload_started = false;
  private GLib.GenericArray<AddImageButton> buttons;
  private GLib.GenericArray<Gtk.Button> close_buttons;
  private GLib.GenericArray<Gtk.ProgressBar> progress_bars;

  public int n_images {
    get {
      return this.buttons.length;
    }
  }
  public bool upload_started {
    set {
      this._upload_started = value;
      this.queue_draw ();
    }
  }
  public bool has_gif {
    get {
      for (int i = 0; i < buttons.length; i ++) {
        if (buttons.get (i).image_path.has_suffix (".gif")) {
          return true;
        }
      }
      return false;

    }
  }
  public bool full {
    get {
      return this.buttons.length == Twitter.max_media_per_upload ||
             this.has_gif;
    }
  }

  public signal void image_removed ();

  construct {
    this.buttons = new GLib.GenericArray<AddImageButton> ();
    this.close_buttons = new GLib.GenericArray<Gtk.Button> ();
    this.progress_bars = new GLib.GenericArray<Gtk.ProgressBar> ();
    this.set_has_window (false);
  }

  private void remove_clicked_cb (Gtk.Button source) {
    int index = -1;

    for (int i = 0; i < this.close_buttons.length; i ++) {
      if (close_buttons.get (i) == source) {
        index = i;
        break;
      }
    }
    assert (index >= 0);

    this.close_buttons.get (index).hide ();
    this.progress_bars.get (index).hide ();

    AddImageButton aib = (AddImageButton) this.buttons.get (index);
    aib.deleted.connect (() => {
      this.buttons.remove_index (index);
      this.close_buttons.remove_index (index);
      this.progress_bars.remove_index (index);
      this.image_removed ();
      this.queue_draw ();
    });

    aib.start_remove ();
  }

  // GtkContainer API {{{
  public override void forall (Gtk.Callback cb) {
    assert (buttons.length == close_buttons.length);
    assert (buttons.length == progress_bars.length);

    for (int i = 0; i < this.close_buttons.length;) {
      int size_before = this.close_buttons.length;
      cb (close_buttons.get (i));

      i += this.close_buttons.length - size_before + 1;
    }

    for (int i = 0; i < this.progress_bars.length;) {
      int size_before = this.progress_bars.length;
      cb (progress_bars.get (i));

      i += this.progress_bars.length - size_before + 1;
    }

    for (int i = 0; i < this.buttons.length;) {
      int size_before = this.buttons.length;
      cb (buttons.get (i));

      i += this.buttons.length - size_before + 1;
    }
  }

  public override void add (Gtk.Widget widget) {
    widget.set_parent (this);
    this.buttons.add ((AddImageButton)widget);
    var btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
    btn.set_parent (this);
    btn.get_style_context ().add_class ("image-button");
    btn.get_style_context ().add_class ("close-button");
    btn.clicked.connect (remove_clicked_cb);
    btn.show ();
    this.close_buttons.add (btn);

    var bar = new Gtk.ProgressBar ();
    bar.set_parent (this);
    bar.show_all ();
    this.progress_bars.add (bar);
  }

  public override void remove (Gtk.Widget widget) {
    widget.unparent ();
    if (widget is AddImageButton)
      this.buttons.remove ((AddImageButton)widget);
    else if (widget is Gtk.Button)
      this.close_buttons.remove ((Gtk.Button)widget);
    else
      this.progress_bars.remove ((Gtk.ProgressBar)widget);
  }
  // }}}

  // GtkWidget API {{{
  public override Gtk.SizeRequestMode get_request_mode () {
    return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
  }

  public override void size_allocate (Gtk.Allocation allocation, int baseline, out Gtk.Allocation out_clip) {
    base.size_allocate (allocation, baseline, out out_clip);
    Gtk.Allocation child_allocation = {};

    if (this.buttons.length == 0) return;


    int default_button_width = (allocation.width - (buttons.length * BUTTON_SPACING)) /
                               buttons.length;

    child_allocation.x = allocation.x;
    child_allocation.y = allocation.y + BUTTON_DELTA;
    child_allocation.height = int.max (allocation.height - BUTTON_DELTA, 0);

    Gtk.Allocation close_allocation = {};
    close_allocation.y = allocation.y;
    for (int i = 0, p = this.buttons.length; i < p; i ++) {
      int min, nat;

      /* Actual image button */
      AddImageButton aib = this.buttons.get (i);
      aib.measure (Gtk.Orientation.HORIZONTAL, child_allocation.height,
                   out min, out nat, null, null);

      child_allocation.width = int.min (default_button_width, nat);
      aib.size_allocate (child_allocation, baseline, out out_clip);


      /* Remove button */
      Gtk.Widget btn = this.close_buttons.get (i);
      btn.measure (Gtk.Orientation.HORIZONTAL, -1, out close_allocation.width,  null, null, null);
      btn.measure (Gtk.Orientation.VERTICAL,   -1, out close_allocation.height, null, null, null);
      close_allocation.x = child_allocation.x + child_allocation.width
                           - close_allocation.width + BUTTON_DELTA;

      btn.size_allocate (close_allocation, baseline, out out_clip);


      /* Progress bar */
      int button_width, button_height;
      double scale;
      aib.get_draw_size (out button_width, out button_height, out scale);
      Gtk.Widget bar = this.progress_bars.get (i);
      Gtk.Allocation bar_allocation = {0};
      bar_allocation.x = child_allocation.x + 6;
      bar.measure (Gtk.Orientation.HORIZONTAL, -1, out bar_allocation.width, null, null, null);
      bar_allocation.width = int.max (button_width - 12, bar_allocation.width);
      bar.measure (Gtk.Orientation.VERTICAL, -1, out bar_allocation.height, null, null, null);
      bar_allocation.y = child_allocation.y + button_height - bar_allocation.height - 6;

      bar.size_allocate (bar_allocation, baseline, out out_clip);

      child_allocation.x += child_allocation.width + BUTTON_SPACING;
    }
  }

  public override void measure (Gtk.Orientation orientation,
                                int             for_size,
                                out int         min,
                                out int         nat,
                                out int         min_baseline,
                                out int         nat_baseline) {

    min = 0;
    nat = 0;

    for (int i = 0; i < buttons.length; i ++) {
      int m, n;
      var btn = buttons.get (i);
      btn.measure (orientation, for_size, out m, out n, null, null);

      if (orientation == Gtk.Orientation.HORIZONTAL) {
        min += m;
        nat += n;
      } else {
        min = int.max (m, min);
        nat = int.max (n, nat);
      }
    }


    if (orientation == Gtk.Orientation.HORIZONTAL) {
      min += buttons.length * BUTTON_SPACING;
      nat += buttons.length * BUTTON_SPACING;
    } else {
      min += BUTTON_DELTA;
      nat += BUTTON_DELTA;
    }

    min_baseline = -1;
    nat_baseline = -1;
  }

  public override void snapshot (Gtk.Snapshot snapshot) {
    for (int i = 0, p = this.buttons.length; i < p; i ++) {
      Gtk.Widget btn = this.buttons.get (i);
      this.snapshot_child (btn, snapshot);
    }

    for (int i = 0, p = this.close_buttons.length; i < p; i ++) {
      var btn = this.close_buttons.get (i);
      this.snapshot_child (btn, snapshot);
    }

    if (_upload_started) {
      for (int i = 0, p = this.progress_bars.length; i < p; i ++) {
        var bar = this.progress_bars.get (i);
        this.snapshot_child (bar, snapshot);
      }
    }
  }
  // }}}

  public void load_image (string path, Gdk.Pixbuf? image) {
#if DEBUG
    assert (!this.full);
#endif

    Cairo.ImageSurface surface;
    if (image == null)
      surface = (Cairo.ImageSurface) load_surface (path);
    else
      surface = (Cairo.ImageSurface) Gdk.cairo_surface_create_from_pixbuf (image,
                                                                           this.get_scale_factor (),
                                                                           this.get_window ());

    var button = new AddImageButton ();
    button.surface = surface;
    button.image_path = path;

    button.hexpand = false;
    button.halign = Gtk.Align.START;
    button.show ();
    this.add (button);
  }

  public string[] get_image_paths () {
    var paths = new string[this.buttons.length];

    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      paths[i] = btn.image_path;
    }

    return paths;
  }

  public void start_progress (string image_path) {
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      if (btn.image_path == image_path) {
        btn.get_style_context ().add_class ("image-progress");
        break;
      }
    }
  }

  public void set_image_progress (string image_path, double progress) {
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      if (btn.image_path == image_path) {
        var progress_bar = progress_bars.get (i);
        progress_bar.set_fraction (progress);
        break;
      }
    }
  }

  public void end_progress (string image_path, string? error_message) {
    for (int i = 0; i < buttons.length; i ++) {
      var btn = buttons.get (i);
      if (btn.image_path == image_path) {
        btn.get_style_context ().remove_class ("image-progress");

        if (error_message == null) {
          btn.get_style_context ().add_class ("image-success");
        } else {
          warning ("%s: %s", image_path, error_message);
          btn.get_style_context ().add_class ("image-error");
        }
        break;
      }
    }
  }

  public void insensitivize_buttons () {
    for (int i = 0; i < close_buttons.length; i ++) {
      close_buttons.get (i).set_sensitive (false);
    }
  }
}
