
import '../../shared/models/walk_model.dart';
import '../../shared/models/event_model.dart';

enum ActivityType {
  walk,
  event,
}

class ActivityItem {
  final ActivityType type;
  final WalkModel? walk;
  final EventModel? event;

  ActivityItem.walk(this.walk) : type = ActivityType.walk, event = null;
  ActivityItem.event(this.event) : type = ActivityType.event, walk = null;

  DateTime get date => type == ActivityType.walk ? walk!.date : event!.date;
  String get id => type == ActivityType.walk ? walk!.id : event!.id;
  String get title => type == ActivityType.walk ? walk!.title : event!.title;
  
  // Helper to sort a mixed list
  static List<ActivityItem> sort(List<ActivityItem> items) {
    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }
}
