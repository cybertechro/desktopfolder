public class DesktopFolder.ResolutionSettings : Object {
    public int resx  { get; set; }
    public int resy  { get; set; }
    public int x  { get; set; }
    public int y  { get; set; }
    public int w  { get; set; }
    public int h  { get; set; }
}


/**
 * @name PositionSettings
 * @description abstract class to store a position x,y and a dimension width, height for a set of resolutions
 */
public abstract class DesktopFolder.PositionSettings : Object, Json.Serializable {
    /** the internal list of resolutions stored for this object */
    public SList <ResolutionSettings> _resolutions = new SList <ResolutionSettings>();
    private enum ResolutionStrategy {
        NONE,
        SCALE,
        STORE
    }

    // positions and dimensions for certain resolutions
    public SList <ResolutionSettings> resolutions {
        get {
            return this._resolutions;
        }
        set {
            this._resolutions = value.copy ();
        }
    }

    // current working position and dimensions
    public int resx  { get; set; }
    public int resy  { get; set; }
    public int x  { get; set; default = 0; }
    public int y  { get; set; default = 0; }
    public int w  { get; set; default = 0; }
    public int h  { get; set; default = 0; }

    /**
     * @name store_resolution_position
     * @description store the current position with the corresponding resolution
     */
    protected void store_resolution_position () {
        if (this.resx <= 0 || this.resy <= 0) {
            Gdk.Screen screen  = Gdk.Screen.get_default ();
            int        swidth  = screen.get_width ();
            int        sheight = screen.get_height ();
            this.resx = swidth;
            this.resy = sheight;
        }

        // getting the current screen resolution
        ResolutionSettings resolution = this.create_current_resolution ();
        resolution.x = this.x;
        resolution.y = this.y;
        resolution.w = this.w;
        resolution.h = this.h;
    }

    /**
     * @name get_resolution_strategy_setting
     * @description return the global setting resolution-strategy
     */
    private ResolutionStrategy get_resolution_strategy_setting () {
        GLib.Settings settings = new GLib.Settings ("com.github.spheras.desktopfolder");
        string[]      keys     = settings.list_keys ();
        bool          found    = false;
        for (int i = 0; i < keys.length; i++) {
            string key = keys[i];
            if (key == "resolution-strategy") {
                found = true;
                break;
            }
        }
        ResolutionStrategy resolution_strategy = ResolutionStrategy.STORE;
        if (found) {
            resolution_strategy = (ResolutionStrategy) settings.get_enum ("resolution-strategy");
        }
        return resolution_strategy;
    }

    /**
     * @name calculate_current_position
     * @description set the current position and size based on the strategy setting
     */
    public void calculate_current_position () {
        if (this._resolutions == null) {
            this._resolutions = new SList <ResolutionSettings>();
        }
        ResolutionStrategy strategy = this.get_resolution_strategy_setting ();
        switch (strategy) {
        case ResolutionStrategy.STORE:
            // debug("strategy store");
            this.strategy_store ();
            check_off_screen ();
            break;
        case ResolutionStrategy.SCALE:
            // debug("strategy scale");
            this.strategy_scale (this.resx, this.resy);
            check_off_screen ();
            break;
        default:
        case ResolutionStrategy.NONE:
            // nothing todo
            break;
        }
    }

    /**
     * @name check_off_screen
     * @description check whether the new position is inside the monitor rectangle or not, and fix the position
     */
    protected void check_off_screen () {
        Gdk.Rectangle monitor_rect;
        Gdk.Screen    screen      = Gdk.Screen.get_default ();
        int           monitor     = screen.get_monitor_at_point (this.x, this.y);
        screen.get_monitor_geometry (monitor, out monitor_rect);
        Gdk.Rectangle widget_rect = Gdk.Rectangle ();
        widget_rect.x      = this.x;
        widget_rect.y      = this.y;
        widget_rect.width  = this.w;
        widget_rect.height = this.h;

        Gdk.Rectangle intersect_rect;

        bool intersect = monitor_rect.intersect (widget_rect, out intersect_rect);
        // debug(" intersection? %s, (%d, %d) - (%d,%d)",(intersect?"true":"false"),intersect_rect.width,intersect_rect.height,this.w,this.h);
        if (!intersect || intersect_rect.width < this.w || intersect_rect.height < this.h) {
            // debug("¡¡CAUTION - NO INTERSECTION (%d,%d,%d,%d)",intersect_rect.x,intersect_rect.y,intersect_rect.width,intersect_rect.height);
            if (this.y < monitor_rect.y) {
                var wingpanel_height_security = 50;
                this.y = monitor_rect.y + wingpanel_height_security;
            } else if (this.y > monitor_rect.y + monitor_rect.height) {
                this.y = monitor_rect.y + monitor_rect.height - this.h;
            }

            if (this.x < monitor_rect.x) {
                this.x = monitor_rect.x;
            } else if (this.x > monitor_rect.x + monitor_rect.width) {
                this.x = monitor_rect.x + monitor_rect.width - this.w;
            }

            // debug("MOVED TO-> (x:%d,y:%d,w:%d,h:%d)",this.x,this.y,this.w,this.h);
        } else {
            // debug("OK - INTERSCIONAN (%d,%d,%d,%d)",intersect_rect.x,intersect_rect.y,intersect_rect.width,intersect_rect.height);
            // debug("widget(%d,%d,%d,%d) - monitor(%d,%d,%d,%d)",widget_rect.x,widget_rect.y,this.w,this.h,monitor_rect.x,monitor_rect.y,monitor_rect.width,monitor_rect.height);
        }
    }

    /**
     * @name strategy_store
     * @description the positions are all stored for the concrete resolution, if it is stored, it is restaured
     */
    private void strategy_store () {
        ResolutionSettings rs = find_current_resolution ();
        if (rs != null) {
            // debug("\n1-strategy_store:(%d,%d,%d,%d)",this.x,this.y,this.w,this.h);
            this.x    = rs.x;
            this.y    = rs.y;
            this.w    = rs.w;
            this.h    = rs.h;
            this.resx = rs.resx;
            this.resy = rs.resy;
            // debug("\n1-strategy_store:(%d,%d,%d,%d)",this.x,this.y,this.w,this.h);
        } else {
            // debug ("strategy store: no resolution, lets scale");
            // should we resize?? not sure, normally I just add a monitor, don't need to resize, just to position it correctly
            // this.strategy_scale (oldresx, oldresy);
            this.create_current_resolution ();
        }
    }

    /**
     * @name strategy_scale
     * @description the positions are scaled to the new screen resolution
     */
    private void strategy_scale (int oldresx, int oldresy) {
        Gdk.Screen screen  = Gdk.Screen.get_default ();
        int        swidth  = screen.get_width ();
        int        sheight = screen.get_height ();

        if (this.resx > 0 && this.resy > 0) {
            // debug("1-strategy_scale:(%d,%d,%d,%d)",this.x,this.y,this.w,this.h);
            this.x    = (this.x * swidth) / oldresx;
            this.w    = (this.w * swidth) / oldresx;
            this.y    = (this.y * sheight) / oldresy;
            this.h    = (this.h * sheight) / oldresy;
            this.resx = swidth;
            this.resy = sheight;
            // debug("2-strategy_scale:(%d,%d,%d,%d)",this.x,this.y,this.w,this.h);
            // debug ("strategy scale: %d,%d  -  %d,%d", this.x, this.y, this.w, this.h);
        } else {
            // debug ("strategy scale: we don't know the resolution, default position");
            this.resx = swidth;
            this.resy = sheight;
            // nothing to do
        }
    }

    /**
     * @name create_current_resolution
     * @description find and create if necessary the current resolution
     * @return {ResolutionSettings} the current screen resolution
     */
    public ResolutionSettings create_current_resolution () {
        ResolutionSettings current = this.find_current_resolution ();
        if (current == null) {
            Gdk.Screen screen  = Gdk.Screen.get_default ();
            int        swidth  = screen.get_width ();
            int        sheight = screen.get_height ();

            current      = new ResolutionSettings ();
            current.resx = swidth;
            current.resy = sheight;
            current.x    = 0;
            current.y    = 0;
            current.w    = 0;
            current.h    = 0;
            this._resolutions.append (current);
        }
        return current;
    }

    /**
     * @name find_current_resolution
     * @description find the current screen resolution, null if nothing found
     * @return {ResolutionSettings} the resolution found, null if none
     */
    public ResolutionSettings find_current_resolution () {
        Gdk.Screen screen  = Gdk.Screen.get_default ();
        int        swidth  = screen.get_width ();
        int        sheight = screen.get_height ();

        this.resx = swidth;
        this.resy = sheight;

        return this.find_resolution (swidth, sheight);
    }

    /**
     * @name find_resolution
     * @description find a certain resolution, null if nothing found
     * @return {ResolutionSettings} the resolution found, null if none
     */
    public ResolutionSettings find_resolution (int width, int height) {
        // debug ("find resolution(%d,%d)", width, height);
        for (int i = 0; i < this._resolutions.length (); i++) {
            ResolutionSettings found = this._resolutions.nth_data (i);
            // debug ("found i=%d (%d,%d)", i, found.resx, found.resy);
            if (found.resx == width && found.resy == height) {
                // debug ("found!");
                return found;
            }
        }

        // debug ("not found!");
        // not found
        return null as ResolutionSettings;
    }

    // Serializable interface

    public unowned ParamSpec ? find_property (string name)
    {
        GLib.Type        type = this.get_type ();
        GLib.ObjectClass ocl = (GLib.ObjectClass)type.class_ref ();
        unowned GLib.ParamSpec ? spec = ocl.find_property (name);
        return spec;
    }

    public Json.Node serialize_property (string property_name, Value @value, ParamSpec pspec) {
        // debug("SERIALIZE -- property_name:%s",property_name);
        if (property_name == "resolutions") {
            var array = new Json.Array.sized (this._resolutions.length ());
            for (int i = 0; i < this._resolutions.length (); i++) {
                ResolutionSettings resolution = this._resolutions.nth_data (i);
                array.add_element (Json.gobject_serialize (resolution));
            }
            var node = new Json.Node (Json.NodeType.ARRAY);
            node.set_array (array);
            return node;
        }

        return default_serialize_property (property_name, @value, pspec);
    }

    public bool deserialize_property (string property_name, out Value @value, ParamSpec pspec, Json.Node property_node) {
        switch (property_name) {
        case "resolutions":
            this._resolutions = new SList <ResolutionSettings>();
            var array = property_node.get_array ();
            array.foreach_element ((a, i, n) => {
                this._resolutions.append (Json.gobject_deserialize (typeof (ResolutionSettings), n) as ResolutionSettings);
            });
            GLib.Type type = typeof (SList);
            @value = Value (type);
            // @value.set_boxed(this._resolutions);
            return true;
        }

        if (pspec.value_type == typeof (bool)) {
            @value = Value (typeof (bool));
            @value.set_boolean ((bool) property_node.get_boolean ());
            return true;
        }

        if (pspec.value_type == typeof (int)) {
            @value = Value (typeof (int));
            @value.set_int ((int) property_node.get_int ());
            return true;
        }

        if (pspec.value_type == typeof (string)) {
            @value = Value (typeof (string));
            @value.set_string (property_node.get_string ());
            return true;
        }

        if (pspec.value_type == typeof (string[])) {
            @value = Value (typeof (string[]));
            string[] result = {};
            var      array  = property_node.get_array ();
            array.foreach_element ((a, i, n) => {
                result += n.get_string ();
            });

            @value = Value (typeof (string[]));
            @value.set_boxed (result);
            return true;
        }

        debug ("WARNING! NOT DESERIALIZED!!  %s:%s", pspec.get_name (), pspec.value_type.name ());
        return default_deserialize_property (property_name, out @value, pspec, property_node);
    }

}