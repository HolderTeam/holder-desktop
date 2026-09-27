namespace HolderLinux.CalendarCompat {

public void set_date(Gtk.Calendar calendar, DateTime date) {
#if GTK_CALENDAR_HAS_SET_DATE
    calendar.set_date(date);
#else
    calendar.select_day(date);
#endif
}

}
