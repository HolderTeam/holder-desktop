namespace HolderLinux.CalendarCompat {

public void set_date(Gtk.Calendar calendar, DateTime date) {
#if GTK_4_20
    calendar.set_date(date);
#else
    calendar.select_day(date);
#endif
}

}
