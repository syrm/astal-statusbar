class Workspaces : Gtk.Box {
    private Gdk.Monitor monitor;
    private AstalHyprland.Monitor hyprlandMonitor;

    AstalHyprland.Hyprland hypr = AstalHyprland.get_default();
    public Workspaces(Gdk.Monitor monitor) {
        this.monitor = monitor;
        this.hyprlandMonitor = get_matching_hyprland_monitor(this.monitor);
        Astal.widget_set_class_names(this, {"Workspaces"});
        hypr.notify["workspaces"].connect(sync);
        sync();
    }

    void sync() {
        foreach (var child in get_children())
            child.destroy();

        var workarea = this.monitor.get_workarea();

        var workspaces = hypr.workspaces;
        workspaces.sort(compareWorkspace);
        
        foreach (var ws in workspaces) {
            // filter out special workspaces
            if (!(ws.id >= -99 && ws.id <= -2)) {
                if (ws.monitor.x == workarea.x && ws.monitor.y == workarea.y && ws.monitor.width == workarea.width && ws.monitor.height == workarea.height) {
                    add(button(ws));
                }
            }
        }
    }

    static int compareWorkspace(AstalHyprland.Workspace w1, AstalHyprland.Workspace w2) {
        if (w1.id < w2.id) {
            return -1;
        } else if (w1.id > w2.id) {
            return 1;
        }

        return 0;
    }

    private AstalHyprland.Monitor? get_matching_hyprland_monitor(Gdk.Monitor gdkMonitor) {
        var workarea = gdkMonitor.get_workarea();

        foreach (var monitor in hypr.monitors) {
            if (monitor.x == workarea.x &&
                monitor.y == workarea.y &&
                monitor.width == workarea.width &&
                monitor.height == workarea.height) {
                return monitor;
            }
        }

        return null;
    }

    void setFocusedWorkspace(Gtk.Button btn, AstalHyprland.Workspace ws) {
        if (this.hyprlandMonitor != null && this.hyprlandMonitor.active_workspace == ws) {
            Astal.widget_set_class_names(btn, {"focused"});
        } else {
            Astal.widget_set_class_names(btn, {});
        }
    }

    Gtk.Button button(AstalHyprland.Workspace ws) {
        var btn = new Gtk.Button() {
            visible = true,
            label = ws.id.to_string()
        };

        setFocusedWorkspace(btn, ws);

        hypr.notify["focused-workspace"].connect(() => {
            setFocusedWorkspace(btn, ws);
        });

        btn.clicked.connect(ws.focus);
        return btn;
    }
}

class Runcat : Gtk.Box {
    private Gtk.Label cat = new Gtk.Label("     ");
    private int step = 0;
    private CpuUsage cpu_monitor;
    private double cpu_usage;

    public Runcat() {
        Astal.widget_set_class_names(this, {"Runcat"});

        add(cat);

        cpu_monitor = new CpuUsage();

        Timeout.add(500, () => {
            cpu_usage = cpu_monitor.get_usage();
            return true;
        });

        Timeout.add(100, update_cat);
    }

    private bool update_cat() {
        Astal.widget_set_css(cat, @"background-image: url('resource://bouh/statusbar/cat/my-running-$step-symbolic.svg')");
        // Astal.widget_set_css(cat, @"background-image: url('resource://bouh/statusbar/mona/mona$step.png')");
        step++;

        if (step > 4) {
           step = 0;
        }

        double usage_factor = cpu_usage / 5.0;
        double clamped_usage = double.min(20.0, double.max(1.0, usage_factor));
        double interval_sec = 0.2 / clamped_usage;
        int delay = (int)(interval_sec * 1000);

        // stdout.printf("CPU: %.1f%%, Factor: %.2f, Clamped: %.2f, Interval: %.3fs, Delay: %dms\n", 
            // cpu_usage, usage_factor, clamped_usage, interval_sec, delay);

        Timeout.add(delay, update_cat);
        return false;
    }
}

class Media : Gtk.Box {
    AstalMpris.Mpris mpris = AstalMpris.get_default();
    Gtk.Label label = new Gtk.Label(null);

    public Media() {
        Astal.widget_set_class_names(this, {"Media"});
        add(label);
        mpris.notify["players"].connect(sync);
        sync();
    }

    AstalMpris.Player? getSpotifyPlayer() {
        foreach (var p in mpris.players)
            if (p.bus_name == "org.mpris.MediaPlayer2.spotify") {
                return p;
            }

        return null;
    }

    void sync() {
        var player = getSpotifyPlayer();
        
        if (player == null) {
            label.set_text("");
            return;
        }

        player.bind_property("metadata", label, "label", BindingFlags.SYNC_CREATE, (_, src, ref trgt) => {
            if (player.playback_status != AstalMpris.PlaybackStatus.PLAYING) {
                trgt.set_string("");
                return true;
            }
            
            var title = player.title;
            var artist = player.artist;
            trgt.set_string(@"󰵤 $artist - $title");
            return true;
        });

    }
}

bool array_search(string needle, string[] haystack) {
    foreach (string value in haystack) {
        if (needle.down() == value.down())
            return true;
    }
    return false;
}

class SysTray : Gtk.Box {
    HashTable<string, Gtk.Widget> items = new HashTable<string, Gtk.Widget>(str_hash, str_equal);
    AstalTray.Tray tray = AstalTray.get_default();

    public SysTray() {
        Astal.widget_set_class_names(this, { "SysTray" });
        tray.item_added.connect(add_item);
        tray.item_removed.connect(remove_item);
    }

    void add_item(string id) {
        if (items.contains(id))
            return;

        var item = tray.get_item(id);

        string[] blacklist = {
            "spotify",
            "firebot",
            "qbittorrent",
            "steam",
            "1password"
        };

        /*
        print(item.to_json_string());
        print("\n");
        print("\n");
        print("\n");
        */

        if (item.tooltip != null) {
            if (array_search(item.tooltip.title, blacklist)) {
                return;
            }
        }
        
        if (array_search(item.title, blacklist)) {
            return;
        }
        
        var btn = new Gtk.MenuButton() { use_popover = false, visible = true };
        var icon = new Astal.Icon() { visible = true };

        item.bind_property("tooltip-markup", btn, "tooltip-markup", BindingFlags.SYNC_CREATE);
        item.bind_property("gicon", icon, "gicon", BindingFlags.SYNC_CREATE);
        item.bind_property("menu-model", btn, "menu-model", BindingFlags.SYNC_CREATE);
        btn.insert_action_group("dbusmenu", item.action_group);
        item.notify["action-group"].connect(() => {
            btn.insert_action_group("dbusmenu", item.action_group);
        });

        btn.add(icon);
        add(btn);
        items.set(id, btn);
    }

    void remove_item(string id) {
        if (items.contains(id)) {
            remove(items.get(id));
            items.remove(id);
        }
    }
}

class Time : Astal.Label {
    string format;
    AstalIO.Time interval;

    void sync() {
        label = new DateTime.now_local().format(format);
    }

    public Time(string format = " %H:%M") {
        this.format = format;
        interval = AstalIO.Time.interval(1000, null);
        interval.now.connect(sync);
        destroy.connect(interval.cancel);
        Astal.widget_set_class_names(this, {"Time"});
    }
}

class Left : Gtk.Box {
    public Left() {
        Object(hexpand: true, halign: Gtk.Align.START);
        add(new Time());
        add(new Media());
        add(new Runcat());
    }
}

class Center : Gtk.Box {
    public Center(Gdk.Monitor monitor) {
        add(new Workspaces(monitor));
    }
}

class Right : Gtk.Box {
    public Right() {
        Object(hexpand: true, halign: Gtk.Align.END);
        add(new SysTray());
    }
}

class Bar : Astal.Window {
    public Bar(Gdk.Monitor monitor) {
        Object(
            anchor: Astal.WindowAnchor.TOP
                | Astal.WindowAnchor.LEFT
                | Astal.WindowAnchor.RIGHT,
            exclusivity: Astal.Exclusivity.EXCLUSIVE,
            gdkmonitor: monitor
        );

        Astal.widget_set_class_names(this, {"Bar"});

        add(new Astal.CenterBox() {
            start_widget = new Left(),
            center_widget = new Center(monitor),
            end_widget = new Right(),
        });

        show_all();
    }
}
